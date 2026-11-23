-- Live organization status for its members, and the data needed to notify them by email.

-- Realtime: members watch their organization's status change. postgres_changes deliveries are
-- filtered through the subscriber's RLS (see "organizations: approved are public, members and
-- admins see own"), so a partner only receives rows they are allowed to select.
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'organizations'
  ) then
    alter publication supabase_realtime add table public.organizations;
  end if;
end $$;

-- Who to email about an organization decision. Admins only; emails live in auth.users.
create function public.organization_contacts(p_org uuid)
returns table (email text, locale text, full_name text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_admin() then
    raise exception 'admins only' using errcode = '42501';
  end if;
  return query
    select u.email::text,
           coalesce(u.raw_user_meta_data ->> 'locale', 'pt'),
           p.full_name
    from public.organization_members m
    join auth.users u on u.id = m.profile_id
    join public.profiles p on p.id = m.profile_id
    where m.org_id = p_org and u.email is not null;
end $$;

revoke execute on function public.organization_contacts(uuid) from public, anon;
grant execute on function public.organization_contacts(uuid) to authenticated;
