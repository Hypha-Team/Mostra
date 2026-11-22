-- mostra — core schema (CLAUDE.md §2, §3)
-- Every table: created_at, updated_at, RLS enabled.
-- Access rules live in RLS + security-definer helpers in the `private` schema
-- (not exposed through the API). Client-callable RPCs live in `public`.

-- ─────────────────────────────────────────────────────────────────────────────
-- Schemas
-- ─────────────────────────────────────────────────────────────────────────────
create schema if not exists private;
grant usage on schema private to anon, authenticated, service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- Enums
-- ─────────────────────────────────────────────────────────────────────────────
create type public.user_role as enum ('student', 'alumni', 'professor', 'partner', 'admin');
create type public.study_level as enum ('ba', 'ma', 'phd', 'alumni');
create type public.open_to as enum ('commissions', 'jobs', 'collaborations', 'studio_assistant');
create type public.organization_kind as enum ('gallery', 'studio', 'company', 'institution', 'association');
create type public.organization_status as enum ('pending', 'approved', 'rejected');
create type public.art_type as enum (
  'painting', 'photography', 'audiovisual', 'sculpture', 'drawing', 'design',
  'sound', 'performance', 'printmaking', 'installation', 'text'
);
create type public.work_visibility as enum ('everyone', 'university', 'only_me');
create type public.media_kind as enum ('image', 'video', 'model3d', 'audio', 'pdf', 'text', 'link');
create type public.opportunity_type as enum ('job', 'commission', 'open_call', 'workshop', 'residency', 'seminar');
create type public.pay_type as enum ('paid', 'unpaid', 'entry_fee', 'free');
create type public.opportunity_status as enum ('draft', 'open', 'closed');
create type public.application_status as enum ('sent', 'seen', 'shortlisted', 'accepted', 'declined');
create type public.contract_status as enum ('draft', 'sent', 'signed', 'void');
create type public.recommendation_status as enum ('requested', 'written', 'declined');
create type public.project_status as enum ('draft', 'open', 'active', 'closed');
create type public.deal_type as enum ('paid', 'fee_split', 'shared_sales', 'unpaid_credited', 'materials_paid');
create type public.open_role_status as enum ('open', 'filled', 'closed');
create type public.material_kind as enum ('give', 'swap', 'want');
create type public.material_type as enum (
  'textile', 'wood', 'metal', 'plaster_clay', 'paper', 'paint', 'frames', 'electronics', 'other'
);
create type public.material_status as enum ('available', 'reserved', 'taken', 'expired');
create type public.event_kind as enum ('open_studio', 'workshop', 'exhibition', 'talk', 'other');
create type public.conversation_context as enum ('none', 'application', 'opportunity', 'project', 'material');

-- ─────────────────────────────────────────────────────────────────────────────
-- updated_at
-- ─────────────────────────────────────────────────────────────────────────────
create function private.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Tables
-- ─────────────────────────────────────────────────────────────────────────────
create table public.universities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  -- Student email domains (lowercase, no "@"). Matching sign-ups become verified students.
  email_domains text[] not null default '{}',
  -- Staff email domains. Matching sign-ups become verified professors.
  staff_email_domains text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Emails that become admins on sign-up. Not exposed through the API.
create table private.admin_emails (
  email text primary key check (email = lower(email)),
  university_id uuid references public.universities (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  university_id uuid references public.universities (id) on delete set null,
  roles public.user_role[] not null default '{}',
  full_name text,
  discipline text,
  level public.study_level,
  year smallint check (year between 1 and 12),
  bio text,
  avatar_path text,
  open_to public.open_to[] not null default '{}',
  verified boolean not null default false,
  privacy_consented_at timestamptz,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  kind public.organization_kind not null,
  website text,
  nif text,
  status public.organization_status not null default 'pending',
  approved_by uuid references public.profiles (id) on delete set null,
  approved_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organization_members (
  org_id uuid not null references public.organizations (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (org_id, profile_id)
);
create index on public.organization_members (profile_id);

create table public.works (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  year smallint,
  art_type public.art_type not null,
  medium text,
  dimensions text,
  duration_seconds integer check (duration_seconds >= 0),
  statement text,
  visibility public.work_visibility not null default 'only_me',
  cover_media_id uuid,
  published_at timestamptz,
  -- Date the student gave written consent to show the work (CLAUDE.md §5).
  consent_at timestamptz,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.works (owner_id);
create index on public.works (published_at desc) where published_at is not null;

create table public.work_media (
  id uuid primary key default gen_random_uuid(),
  work_id uuid not null references public.works (id) on delete cascade,
  kind public.media_kind not null,
  storage_path text,
  external_url text,
  poster_path text,
  alt_text text,
  captions_path text,
  aspect_ratio numeric check (aspect_ratio > 0),
  duration_seconds integer check (duration_seconds >= 0),
  page_count integer check (page_count >= 0),
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (storage_path is not null or external_url is not null)
);
create index on public.work_media (work_id, position);

alter table public.works
  add constraint works_cover_media_fk foreign key (cover_media_id)
  references public.work_media (id) on delete set null;

create table public.saves (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  work_id uuid not null references public.works (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (profile_id, work_id)
);

create table public.shortlists (
  org_id uuid not null references public.organizations (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (org_id, student_id)
);

create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.organizations (id) on delete cascade,
  professor_id uuid references public.profiles (id) on delete cascade,
  type public.opportunity_type not null,
  title text not null check (length(trim(title)) > 0),
  description text,
  pay_type public.pay_type not null,
  amount_eur numeric(10, 2) check (amount_eur >= 0),
  deadline timestamptz,
  starts_at timestamptz,
  location text,
  places integer check (places > 0),
  status public.opportunity_status not null default 'draft',
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (num_nonnulls(org_id, professor_id) = 1)
);
create index on public.opportunities (org_id);
create index on public.opportunities (professor_id);
create index on public.opportunities (status, deadline);

create table public.applications (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references public.opportunities (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  message text,
  work_ids uuid[] not null default '{}' check (cardinality(work_ids) <= 3),
  status public.application_status not null default 'sent',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (opportunity_id, student_id)
);
create index on public.applications (student_id);

create table public.contracts (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null unique references public.applications (id) on delete cascade,
  terms jsonb not null default '{}',
  pdf_path text,
  status public.contract_status not null default 'draft',
  signed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.recommendations (
  id uuid primary key default gen_random_uuid(),
  professor_id uuid not null references public.profiles (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  opportunity_id uuid references public.opportunities (id) on delete set null,
  text text,
  status public.recommendation_status not null default 'requested',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.recommendations (student_id);
create index on public.recommendations (professor_id);

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  description text,
  opens_at timestamptz,
  status public.project_status not null default 'draft',
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.project_members (
  project_id uuid not null references public.projects (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  role_label text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (project_id, profile_id)
);

create table public.project_open_roles (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  label text not null,
  deal public.deal_type not null,
  until date,
  status public.open_role_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.materials (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  kind public.material_kind not null,
  material public.material_type not null,
  title text not null check (length(trim(title)) > 0),
  quantity text,
  location text,
  available_until date,
  source_work_id uuid references public.works (id) on delete set null,
  project_id uuid references public.projects (id) on delete set null,
  reserved_by_project_id uuid references public.projects (id) on delete set null,
  status public.material_status not null default 'available',
  photo_path text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  context public.conversation_context not null default 'none',
  context_id uuid,
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.conversation_participants (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (conversation_id, profile_id)
);
create index on public.conversation_participants (profile_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  body text not null check (length(trim(body)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.messages (conversation_id, created_at);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  university_id uuid references public.universities (id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  starts_at timestamptz not null,
  ends_at timestamptz,
  location text,
  kind public.event_kind not null,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- updated_at triggers on every table
do $$
declare t text;
begin
  foreach t in array array[
    'public.universities', 'private.admin_emails', 'public.profiles', 'public.organizations',
    'public.organization_members', 'public.works', 'public.work_media', 'public.saves',
    'public.shortlists', 'public.opportunities', 'public.applications', 'public.contracts',
    'public.recommendations', 'public.projects', 'public.project_members',
    'public.project_open_roles', 'public.materials', 'public.conversations',
    'public.conversation_participants', 'public.messages', 'public.events'
  ] loop
    execute format(
      'create trigger set_updated_at before update on %s for each row execute function private.set_updated_at()', t
    );
  end loop;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Helper functions (security definer: they read tables the caller may not see)
-- ─────────────────────────────────────────────────────────────────────────────
create function private.profile_roles(p uuid) returns public.user_role[]
language sql stable security definer set search_path = '' as $$
  select coalesce((select roles from public.profiles where id = p), '{}')
$$;

create function private.has_role(r public.user_role) returns boolean
language sql stable security definer set search_path = '' as $$
  select r = any (private.profile_roles((select auth.uid())))
$$;

create function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select private.has_role('admin')
$$;

-- Verified student, alumni, professor or admin of a university.
create function private.is_university_member(p uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = p
      and verified
      and roles && array['student', 'alumni', 'professor', 'admin']::public.user_role[]
  )
$$;

create function private.is_verified_student(p uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = p and verified and roles && array['student', 'alumni']::public.user_role[]
  )
$$;

create function private.is_verified_professor(p uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = p and verified and 'professor' = any (roles)
  )
$$;

create function private.university_of(p uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select university_id from public.profiles where id = p
$$;

create function private.is_org_member(o uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.organization_members
    where org_id = o and profile_id = (select auth.uid())
  )
$$;

create function private.is_approved_org_member(o uuid, p uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.organization_members m
    join public.organizations org on org.id = m.org_id
    where m.org_id = o and m.profile_id = p and org.status = 'approved'
  )
$$;

create function private.is_approved_partner(p uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.organization_members m
    join public.organizations org on org.id = m.org_id
    where m.profile_id = p and org.status = 'approved'
  )
$$;

-- Section 2 "Sees": owner always; others only published works.
-- everyone → anyone (incl. visitors); university → verified members of the owner's university.
create function private.can_view_work(
  p_owner uuid, p_visibility public.work_visibility, p_published timestamptz
) returns boolean
language sql stable security definer set search_path = '' as $$
  select
    p_owner = (select auth.uid())
    or (
      p_published is not null
      and (
        p_visibility = 'everyone'
        or (
          p_visibility = 'university'
          and private.is_university_member((select auth.uid()))
          and private.university_of((select auth.uid())) = private.university_of(p_owner)
        )
      )
    )
$$;

create function private.can_view_work_id(w uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select private.can_view_work(owner_id, visibility, published_at) from public.works where id = w),
    false
  )
$$;

create function private.owns_work(w uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.works where id = w and owner_id = (select auth.uid()))
$$;

create function private.owns_all_works(ids uuid[]) returns boolean
language sql stable security definer set search_path = '' as $$
  select not exists (
    select 1 from unnest(ids) as w(id)
    where not exists (
      select 1 from public.works
      where works.id = w.id and owner_id = (select auth.uid())
    )
  )
$$;

-- Can the current user manage this opportunity (approved org member or its professor)?
create function private.owns_opportunity(o uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.opportunities op
    where op.id = o
      and (
        op.professor_id = (select auth.uid())
        or (op.org_id is not null and private.is_approved_org_member(op.org_id, (select auth.uid())))
      )
  )
$$;

create function private.opportunity_is_open(o uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.opportunities
    where id = o and status = 'open' and (deadline is null or deadline > now())
  )
$$;

create function private.application_party(a uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.applications ap
    where ap.id = a
      and (ap.student_id = (select auth.uid()) or private.owns_opportunity(ap.opportunity_id))
  )
$$;

create function private.owns_application_opportunity(a uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.applications ap
    where ap.id = a and private.owns_opportunity(ap.opportunity_id)
  )
$$;

create function private.owns_project(pr uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.projects where id = pr and owner_id = (select auth.uid()))
$$;

create function private.can_view_project(pr uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.projects p
    where p.id = pr
      and (
        p.owner_id = (select auth.uid())
        or exists (
          select 1 from public.project_members m
          where m.project_id = p.id and m.profile_id = (select auth.uid())
        )
        or (p.status <> 'draft' and private.is_university_member((select auth.uid())))
      )
  )
$$;

create function private.is_participant(c uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.conversation_participants
    where conversation_id = c and profile_id = (select auth.uid())
  )
$$;

-- Section 2 "Can message" — who may START a conversation with whom.
-- Replies inside an existing conversation are governed by participation (see messages policy).
create function private.can_contact(sender uuid, recipient uuid) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare
  s public.profiles;
  r public.profiles;
  student_roles constant public.user_role[] := array['student', 'alumni']::public.user_role[];
begin
  if sender is null or recipient is null or sender = recipient then
    return false;
  end if;
  select * into s from public.profiles where id = sender;
  if not found then return false; end if;
  select * into r from public.profiles where id = recipient;
  if not found then return false; end if;

  -- student/alumni → students, alumni, professors of the same university
  if s.verified and s.roles && student_roles
     and r.verified and r.roles && array['student', 'alumni', 'professor']::public.user_role[]
     and s.university_id is not distinct from r.university_id then
    return true;
  end if;

  -- professor → their students (until a professor–student link exists: verified students of the same university)
  if s.verified and 'professor' = any (s.roles)
     and r.verified and r.roles && student_roles
     and s.university_id is not distinct from r.university_id then
    return true;
  end if;

  -- approved partner → students open to work, or students who applied to one of the partner's opportunities
  if private.is_approved_partner(sender) and r.roles && student_roles then
    if cardinality(r.open_to) > 0 then
      return true;
    end if;
    if exists (
      select 1
      from public.applications a
      join public.opportunities o on o.id = a.opportunity_id
      join public.organization_members m on m.org_id = o.org_id and m.profile_id = sender
      join public.organizations org on org.id = o.org_id and org.status = 'approved'
      where a.student_id = recipient
    ) then
      return true;
    end if;
  end if;

  return false;
end $$;

-- Who may send messages at all: verified university members and approved partners.
create function private.can_send_messages(p uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.is_university_member(p) or private.is_approved_partner(p)
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Sign-up: create the profile and derive roles from the email domain
-- ─────────────────────────────────────────────────────────────────────────────
create function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  domain text := lower(split_part(coalesce(new.email, ''), '@', 2));
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_roles public.user_role[] := '{}';
  v_verified boolean := false;
  v_university uuid;
  v_admin_university uuid;
begin
  if domain <> '' then
    select id into v_university from public.universities where domain = any (email_domains) limit 1;
    if v_university is not null then
      v_roles := array['student']::public.user_role[];
      v_verified := true;
    else
      select id into v_university from public.universities where domain = any (staff_email_domains) limit 1;
      if v_university is not null then
        v_roles := array['professor']::public.user_role[];
        v_verified := true;
      end if;
    end if;
  end if;

  select university_id into v_admin_university
  from private.admin_emails where email = lower(new.email);
  if found then
    v_roles := v_roles || 'admin'::public.user_role;
    v_verified := true;
    v_university := coalesce(v_university, v_admin_university);
  end if;

  if meta ->> 'signup_as' = 'partner' and not ('partner' = any (v_roles)) then
    v_roles := v_roles || 'partner'::public.user_role;
  end if;

  insert into public.profiles (id, university_id, roles, verified, full_name, privacy_consented_at)
  values (
    new.id,
    v_university,
    v_roles,
    v_verified,
    nullif(trim(meta ->> 'full_name'), ''),
    case when (meta ->> 'privacy_consent') = 'true' then now() end
  );
  return new;
end $$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();

-- Is this statement running in a trusted context rather than directly as an API user?
-- True for migrations / SQL editor (postgres), the service role, and inside our own
-- security-definer RPCs (which run as their owner). False for PostgREST requests,
-- which run as `anon` or `authenticated`.
create function private.is_backend() returns boolean
language sql stable set search_path = '' as $$
  select current_user not in ('anon', 'authenticated')
$$;

-- Users may edit their own profile, but never their roles, verification, university or demo flag.
create function private.protect_profile_columns() returns trigger
language plpgsql set search_path = '' as $$
begin
  if private.is_backend() or private.is_admin() then
    return new;
  end if;
  if new.id is distinct from old.id
     or new.roles is distinct from old.roles
     or new.verified is distinct from old.verified
     or new.university_id is distinct from old.university_id
     or new.is_demo is distinct from old.is_demo
     or new.privacy_consented_at is distinct from old.privacy_consented_at then
    raise exception 'not allowed to change protected profile fields' using errcode = '42501';
  end if;
  return new;
end $$;

create trigger protect_profile_columns
before update on public.profiles
for each row execute function private.protect_profile_columns();

-- Organizations: only admins decide status; the decision is stamped.
create function private.protect_organization_status() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if not (private.is_backend() or private.is_admin()) then
      new.status := 'pending';
      new.approved_by := null;
      new.approved_at := null;
      new.is_demo := false;
    end if;
    return new;
  end if;

  if new.status is distinct from old.status
     or new.approved_by is distinct from old.approved_by
     or new.approved_at is distinct from old.approved_at
     or new.is_demo is distinct from old.is_demo then
    if not (private.is_backend() or private.is_admin()) then
      raise exception 'only admins can change the organization status' using errcode = '42501';
    end if;
    if new.status is distinct from old.status and not private.is_backend() then
      new.approved_by := (select auth.uid());
      new.approved_at := case when new.status = 'pending' then null else now() end;
    end if;
  end if;
  return new;
end $$;

create trigger protect_organization_status
before insert or update on public.organizations
for each row execute function private.protect_organization_status();

-- Applications: the opportunity owner may only change the status.
create function private.protect_application_columns() returns trigger
language plpgsql set search_path = '' as $$
begin
  if private.is_backend() then
    return new;
  end if;
  if new.opportunity_id is distinct from old.opportunity_id
     or new.student_id is distinct from old.student_id
     or new.message is distinct from old.message
     or new.work_ids is distinct from old.work_ids then
    raise exception 'only the application status can be changed' using errcode = '42501';
  end if;
  return new;
end $$;

create trigger protect_application_columns
before update on public.applications
for each row execute function private.protect_application_columns();

-- ─────────────────────────────────────────────────────────────────────────────
-- Client-callable RPCs
-- ─────────────────────────────────────────────────────────────────────────────

-- Which sign-in path an email belongs to, before sending a magic link.
-- Returns 'university' (student, staff or admin email) or null. Does not reveal which.
create function public.email_signin_kind(p_email text) returns text
language sql stable security definer set search_path = '' as $$
  select case
    when exists (
      select 1 from public.universities
      where lower(split_part(p_email, '@', 2)) = any (email_domains)
         or lower(split_part(p_email, '@', 2)) = any (staff_email_domains)
    )
    or exists (select 1 from private.admin_emails where email = lower(trim(p_email)))
    then 'university'
  end
$$;

-- Partner sign-up: create an organization (always pending) and join it.
create function public.create_organization(
  p_name text, p_kind public.organization_kind, p_website text default null, p_nif text default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  org uuid;
begin
  if uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles where id = uid) then
    raise exception 'profile missing' using errcode = '42501';
  end if;

  insert into public.organizations (name, kind, website, nif, status, created_by)
  values (trim(p_name), p_kind, nullif(trim(p_website), ''), nullif(trim(p_nif), ''), 'pending', uid)
  returning id into org;

  insert into public.organization_members (org_id, profile_id) values (org, uid);

  update public.profiles
  set roles = roles || 'partner'::public.user_role
  where id = uid and not ('partner' = any (roles));

  return org;
end $$;

-- Start (or reuse) a conversation, only when the contact rules allow it.
create function public.start_conversation(
  p_recipient uuid,
  p_context public.conversation_context default 'none',
  p_context_id uuid default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  conv uuid;
begin
  if not private.can_contact(uid, p_recipient) then
    raise exception 'you cannot start a conversation with this person' using errcode = '42501';
  end if;

  select c.id into conv
  from public.conversations c
  join public.conversation_participants a on a.conversation_id = c.id and a.profile_id = uid
  join public.conversation_participants b on b.conversation_id = c.id and b.profile_id = p_recipient
  where c.context = p_context and c.context_id is not distinct from p_context_id
  limit 1;

  if conv is null then
    insert into public.conversations (context, context_id, created_by)
    values (p_context, p_context_id, uid)
    returning id into conv;
    insert into public.conversation_participants (conversation_id, profile_id)
    values (conv, uid), (conv, p_recipient);
  end if;

  return conv;
end $$;

-- Moderation: admins take a work off the wall without being able to read drafts or only-me works.
create function public.unpublish_work(p_work uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_admin() then
    raise exception 'admins only' using errcode = '42501';
  end if;
  update public.works set published_at = null where id = p_work and visibility <> 'only_me';
end $$;
revoke execute on function public.unpublish_work(uuid) from public, anon;
grant execute on function public.unpublish_work(uuid) to authenticated;

revoke execute on function public.create_organization(text, public.organization_kind, text, text) from public, anon;
grant execute on function public.create_organization(text, public.organization_kind, text, text) to authenticated;
revoke execute on function public.start_conversation(uuid, public.conversation_context, uuid) from public, anon;
grant execute on function public.start_conversation(uuid, public.conversation_context, uuid) to authenticated;
grant execute on function public.email_signin_kind(text) to anon, authenticated;

-- private.admin_emails is never reachable through the API
revoke all on private.admin_emails from anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Row Level Security
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.universities enable row level security;
alter table private.admin_emails enable row level security;
alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.works enable row level security;
alter table public.work_media enable row level security;
alter table public.saves enable row level security;
alter table public.shortlists enable row level security;
alter table public.opportunities enable row level security;
alter table public.applications enable row level security;
alter table public.contracts enable row level security;
alter table public.recommendations enable row level security;
alter table public.projects enable row level security;
alter table public.project_members enable row level security;
alter table public.project_open_roles enable row level security;
alter table public.materials enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;
alter table public.events enable row level security;

-- universities
create policy "universities: anyone reads" on public.universities
  for select to anon, authenticated using (true);
create policy "universities: admins write" on public.universities
  for all to authenticated using (private.is_admin()) with check (private.is_admin());

-- profiles
create policy "profiles: members read" on public.profiles
  for select to authenticated using (true);
create policy "profiles: visitors read artists with public works" on public.profiles
  for select to anon using (
    exists (
      select 1 from public.works w
      where w.owner_id = profiles.id and w.visibility = 'everyone' and w.published_at is not null
    )
  );
create policy "profiles: edit own" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()) or private.is_admin())
  with check (id = (select auth.uid()) or private.is_admin());

-- organizations
create policy "organizations: approved are public, members and admins see own" on public.organizations
  for select to anon, authenticated
  using (status = 'approved' or private.is_org_member(id) or private.is_admin());
create policy "organizations: members and admins update" on public.organizations
  for update to authenticated
  using (private.is_org_member(id) or private.is_admin())
  with check (private.is_org_member(id) or private.is_admin());
create policy "organizations: admins delete" on public.organizations
  for delete to authenticated using (private.is_admin());

-- organization_members
create policy "org members: see own memberships and colleagues" on public.organization_members
  for select to authenticated
  using (profile_id = (select auth.uid()) or private.is_org_member(org_id) or private.is_admin());
create policy "org members: admins manage" on public.organization_members
  for all to authenticated using (private.is_admin()) with check (private.is_admin());

-- works
create policy "works: visible per visibility" on public.works
  for select to anon, authenticated
  using (private.can_view_work(owner_id, visibility, published_at));
create policy "works: verified students add their own" on public.works
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and private.is_verified_student((select auth.uid())));
create policy "works: owner edits" on public.works
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy "works: owner or admin deletes" on public.works
  for delete to authenticated
  using (owner_id = (select auth.uid()) or private.is_admin());

-- work_media
create policy "work media: follows the work" on public.work_media
  for select to anon, authenticated using (private.can_view_work_id(work_id));
create policy "work media: owner writes" on public.work_media
  for all to authenticated
  using (private.owns_work(work_id)) with check (private.owns_work(work_id));

-- saves
create policy "saves: own" on public.saves
  for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()) and private.can_view_work_id(work_id));

-- shortlists
create policy "shortlists: approved org members" on public.shortlists
  for all to authenticated
  using (private.is_approved_org_member(org_id, (select auth.uid())))
  with check (private.is_approved_org_member(org_id, (select auth.uid())));

-- opportunities
create policy "opportunities: open and closed are public; owners see drafts" on public.opportunities
  for select to anon, authenticated
  using (
    status in ('open', 'closed')
    or professor_id = (select auth.uid())
    or (org_id is not null and private.is_org_member(org_id))
    or private.is_admin()
  );
create policy "opportunities: approved partners and professors post" on public.opportunities
  for insert to authenticated
  with check (
    (org_id is not null and private.is_approved_org_member(org_id, (select auth.uid())))
    or (
      org_id is null
      and professor_id = (select auth.uid())
      and (private.is_verified_professor((select auth.uid())) or private.is_admin())
    )
  );
create policy "opportunities: owners edit" on public.opportunities
  for update to authenticated
  using (private.owns_opportunity(id))
  with check (
    (org_id is not null and private.is_approved_org_member(org_id, (select auth.uid())))
    or (org_id is null and professor_id = (select auth.uid()))
  );
create policy "opportunities: owners or admins delete" on public.opportunities
  for delete to authenticated using (private.owns_opportunity(id) or private.is_admin());

-- applications
create policy "applications: student and opportunity owner read" on public.applications
  for select to authenticated
  using (student_id = (select auth.uid()) or private.owns_opportunity(opportunity_id) or private.is_admin());
create policy "applications: verified students apply with their own works" on public.applications
  for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and private.is_verified_student((select auth.uid()))
    and private.opportunity_is_open(opportunity_id)
    and status = 'sent'
    and private.owns_all_works(work_ids)
  );
create policy "applications: opportunity owner updates status" on public.applications
  for update to authenticated
  using (private.owns_opportunity(opportunity_id))
  with check (private.owns_opportunity(opportunity_id));
create policy "applications: student withdraws while unseen" on public.applications
  for delete to authenticated
  using (student_id = (select auth.uid()) and status = 'sent');

-- contracts
create policy "contracts: both parties read" on public.contracts
  for select to authenticated using (private.application_party(application_id));
create policy "contracts: opportunity owner writes" on public.contracts
  for all to authenticated
  using (private.owns_application_opportunity(application_id))
  with check (private.owns_application_opportunity(application_id));

-- recommendations
create policy "recommendations: parties read, written ones are public to members" on public.recommendations
  for select to authenticated
  using (
    professor_id = (select auth.uid())
    or student_id = (select auth.uid())
    or status = 'written'
  );
create policy "recommendations: students request, professors write" on public.recommendations
  for insert to authenticated
  with check (
    (student_id = (select auth.uid()) and status = 'requested' and private.is_verified_student((select auth.uid())))
    or (professor_id = (select auth.uid()) and private.is_verified_professor((select auth.uid())))
  );
create policy "recommendations: professor updates" on public.recommendations
  for update to authenticated
  using (professor_id = (select auth.uid()))
  with check (professor_id = (select auth.uid()));
create policy "recommendations: student cancels a request, professor deletes" on public.recommendations
  for delete to authenticated
  using ((student_id = (select auth.uid()) and status = 'requested') or professor_id = (select auth.uid()));

-- projects
create policy "projects: visible to members of the university, team and owner" on public.projects
  for select to authenticated using (private.can_view_project(id));
create policy "projects: members create their own" on public.projects
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and private.is_university_member((select auth.uid())));
create policy "projects: owner edits" on public.projects
  for update to authenticated
  using (owner_id = (select auth.uid()) or private.is_admin())
  with check (owner_id = (select auth.uid()) or private.is_admin());
create policy "projects: owner or admin deletes" on public.projects
  for delete to authenticated using (owner_id = (select auth.uid()) or private.is_admin());

create policy "project members: visible with the project" on public.project_members
  for select to authenticated using (private.can_view_project(project_id));
create policy "project members: owner manages" on public.project_members
  for all to authenticated
  using (private.owns_project(project_id)) with check (private.owns_project(project_id));
create policy "project members: leave" on public.project_members
  for delete to authenticated using (profile_id = (select auth.uid()));

create policy "project roles: visible with the project" on public.project_open_roles
  for select to authenticated using (private.can_view_project(project_id));
create policy "project roles: owner manages" on public.project_open_roles
  for all to authenticated
  using (private.owns_project(project_id)) with check (private.owns_project(project_id));

-- materials
create policy "materials: university members read" on public.materials
  for select to authenticated
  using (owner_id = (select auth.uid()) or private.is_university_member((select auth.uid())));
create policy "materials: members post their own" on public.materials
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and private.is_university_member((select auth.uid())));
create policy "materials: owner edits" on public.materials
  for update to authenticated
  using (owner_id = (select auth.uid()) or private.is_admin())
  with check (owner_id = (select auth.uid()) or private.is_admin());
create policy "materials: owner or admin deletes" on public.materials
  for delete to authenticated using (owner_id = (select auth.uid()) or private.is_admin());

-- conversations (created only through public.start_conversation)
create policy "conversations: participants read" on public.conversations
  for select to authenticated using (private.is_participant(id));
create policy "conversation participants: participants read" on public.conversation_participants
  for select to authenticated using (private.is_participant(conversation_id));

-- messages
create policy "messages: participants read" on public.messages
  for select to authenticated using (private.is_participant(conversation_id));
create policy "messages: participants who may message send" on public.messages
  for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and private.is_participant(conversation_id)
    and private.can_send_messages((select auth.uid()))
  );

-- events
create policy "events: anyone reads" on public.events
  for select to anon, authenticated using (true);
create policy "events: admins write" on public.events
  for all to authenticated using (private.is_admin()) with check (private.is_admin());
