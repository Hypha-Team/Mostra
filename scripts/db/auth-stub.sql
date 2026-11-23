-- Minimal stand-in for the parts of Supabase's Postgres that our migrations rely on.
-- Used ONLY by scripts/db/test-local.sh when Docker (and so `supabase db start`) is unavailable.
-- CI runs the same migrations and tests against the real Supabase image.

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin noinherit; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin noinherit; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin noinherit bypassrls; end if;
end $$;

create schema if not exists auth;
create schema if not exists extensions;
grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema extensions to anon, authenticated, service_role;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  instance_id uuid,
  aud varchar(255),
  role varchar(255),
  email varchar(255),
  encrypted_password varchar(255),
  email_confirmed_at timestamptz,
  raw_app_meta_data jsonb,
  raw_user_meta_data jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create or replace function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;

create or replace function auth.role() returns text language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;

create or replace function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;

-- Supabase grants table access to the API roles by default; RLS does the filtering.
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;

-- Realtime pieces used by the migrations (broadcast from the database + channel authorization).
create schema if not exists realtime;
grant usage on schema realtime to anon, authenticated, service_role;
create table if not exists realtime.messages (
  id bigserial primary key,
  topic text not null,
  extension text not null default 'broadcast',
  event text,
  payload jsonb,
  private boolean default false,
  inserted_at timestamptz not null default now()
);
alter table realtime.messages enable row level security;
grant select, insert on realtime.messages to anon, authenticated;
create or replace function realtime.topic() returns text language sql stable as $$
  select nullif(current_setting('realtime.topic', true), '')
$$;
create or replace function realtime.send(payload jsonb, event text, topic text, private boolean default true)
returns void language sql as $$
  insert into realtime.messages (topic, event, payload, private) values (topic, event, payload, private)
$$;
