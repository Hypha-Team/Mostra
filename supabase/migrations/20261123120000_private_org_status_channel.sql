-- Organization status updates go to the organization's own members only.
--
-- postgres_changes is filtered by table RLS, and approved organizations are readable by everyone,
-- so any user subscribed to the table would receive another organization's approval. Instead,
-- status changes are broadcast on a PRIVATE channel per organization ("organization:<id>"),
-- authorized by an RLS policy on realtime.messages that admits members only.

do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'organizations'
  ) then
    alter publication supabase_realtime drop table public.organizations;
  end if;
end $$;

create function private.broadcast_organization_status() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status is distinct from old.status then
    perform realtime.send(
      jsonb_build_object('id', new.id, 'status', new.status),
      'status',
      'organization:' || new.id::text,
      true
    );
  end if;
  return new;
end $$;

create trigger broadcast_organization_status
after update of status on public.organizations
for each row execute function private.broadcast_organization_status();

-- Topic "organization:<uuid>" → only members of that organization may join and receive.
create function private.is_member_of_org_topic(p_topic text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare
  org uuid;
begin
  if p_topic is null or p_topic not like 'organization:%' then
    return false;
  end if;
  begin
    org := substr(p_topic, length('organization:') + 1)::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  return private.is_org_member(org);
end $$;

create policy "organization channel: members receive" on realtime.messages
  for select to authenticated
  using (private.is_member_of_org_topic((select realtime.topic())));
