-- Sign-up, roles and organization approval (CLAUDE.md §2)
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- ── shared fixture (rolled back at the end of the file) ──────────────────────
create schema tests;
grant usage on schema tests to anon, authenticated;

create function tests.login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

create function tests.login_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  execute 'set local role anon';
end $$;

create function tests.logout() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end $$;
create function tests.rows_affected(q text) returns int language plpgsql as $$
declare n int;
begin
  execute q;
  get diagnostics n = row_count;
  return n;
end $$;
grant execute on all functions in schema tests to anon, authenticated;

update public.universities
   set email_domains = array['alunos.test'], staff_email_domains = array['docentes.test']
 where slug = 'belas-artes-ulisboa';
insert into public.universities (id, name, slug, email_domains)
values ('00000000-0000-4000-8000-0000000000a2', 'Outra Universidade', 'outra', array['outra.test']);
insert into private.admin_emails (email, university_id)
values ('admin@admin.test', '00000000-0000-4000-8000-000000000001');

-- a1 ana (student) · a2 bruno (student, open to jobs) · a3 prof · a4 admin
-- a5 approved partner · a6 pending partner · a7 random · a8 carla (student, other university)
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', 'ana@alunos.test',     '{"full_name": "Ana", "privacy_consent": "true"}'),
  ('00000000-0000-0000-0000-0000000000a2', 'bruno@alunos.test',   '{}'),
  ('00000000-0000-0000-0000-0000000000a3', 'prof@docentes.test',  '{}'),
  ('00000000-0000-0000-0000-0000000000a4', 'Admin@Admin.test',    '{}'),
  ('00000000-0000-0000-0000-0000000000a5', 'galeria@mail.test',   '{"signup_as": "partner"}'),
  ('00000000-0000-0000-0000-0000000000a6', 'estudio@mail.test',   '{"signup_as": "partner"}'),
  ('00000000-0000-0000-0000-0000000000a7', 'random@mail.test',    '{}'),
  ('00000000-0000-0000-0000-0000000000a8', 'carla@outra.test',    '{}');

update public.profiles set open_to = array['jobs']::public.open_to[]
 where id = '00000000-0000-0000-0000-0000000000a2';

insert into public.organizations (id, name, kind, status, created_by) values
  ('00000000-0000-0000-0000-0000000000b1', 'Galeria Teste', 'gallery', 'approved', '00000000-0000-0000-0000-0000000000a5'),
  ('00000000-0000-0000-0000-0000000000b2', 'Estúdio Teste', 'studio',  'pending',  '00000000-0000-0000-0000-0000000000a6');
insert into public.organization_members (org_id, profile_id) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a5'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a6');

-- ana's works: c1 everyone · c2 university · c3 only me · c4 everyone but unpublished · c5 bruno's
insert into public.works (id, owner_id, title, art_type, visibility, published_at) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'Pública',     'painting',    'everyone',   now()),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000a1', 'Faculdade',   'drawing',     'university', now()),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000a1', 'Só eu',       'photography', 'only_me',    now()),
  ('00000000-0000-0000-0000-0000000000c4', '00000000-0000-0000-0000-0000000000a1', 'Rascunho',    'sculpture',   'everyone',   null),
  ('00000000-0000-0000-0000-0000000000c5', '00000000-0000-0000-0000-0000000000a2', 'Do Bruno',    'sound',       'everyone',   now());
-- ─────────────────────────────────────────────────────────────────────────────

select is(
  (select array_agg(schemaname || '.' || tablename order by tablename) from pg_tables
    where schemaname in ('public', 'private') and not rowsecurity),
  null,
  'every table has row level security enabled'
);

-- roles derived from the email at sign-up
select is((select roles from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), array['student']::public.user_role[], 'student domain → student');
select ok((select verified from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'student domain → verified');
select is((select university_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), '00000000-0000-4000-8000-000000000001'::uuid, 'student gets their university');
select isnt((select privacy_consented_at from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), null, 'privacy consent stored at sign-up');
select is((select full_name from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 'Ana', 'full name from sign-up metadata');
select is((select roles from public.profiles where id = '00000000-0000-0000-0000-0000000000a3'), array['professor']::public.user_role[], 'staff domain → professor');
select ok((select verified from public.profiles where id = '00000000-0000-0000-0000-0000000000a3'), 'staff domain → verified');
select is((select roles from public.profiles where id = '00000000-0000-0000-0000-0000000000a4'), array['admin']::public.user_role[], 'admin email (any case) → admin');
select ok((select verified from public.profiles where id = '00000000-0000-0000-0000-0000000000a4'), 'admin → verified');
select is((select roles from public.profiles where id = '00000000-0000-0000-0000-0000000000a5'), array['partner']::public.user_role[], 'partner sign-up → partner');
select ok(not (select verified from public.profiles where id = '00000000-0000-0000-0000-0000000000a5'), 'partner is not verified by email');
select is((select roles from public.profiles where id = '00000000-0000-0000-0000-0000000000a7'), '{}'::public.user_role[], 'unknown domain → no role');
select is((select roles from public.profiles where id = '00000000-0000-0000-0000-0000000000a8'), array['student']::public.user_role[], 'other university domain → student');
select is((select university_id from public.profiles where id = '00000000-0000-0000-0000-0000000000a8'), '00000000-0000-4000-8000-0000000000a2'::uuid, '… of the other university');

-- sign-in path check, callable by visitors
select tests.login_anon();
select is(public.email_signin_kind('x@alunos.test'), 'university', 'student email recognised');
select is(public.email_signin_kind('x@DOCENTES.test'), 'university', 'staff email recognised, case-insensitive');
select is(public.email_signin_kind('admin@admin.test'), 'university', 'admin email recognised');
select is(public.email_signin_kind('x@mail.test'), null, 'other email not recognised');
select throws_ok('select * from private.admin_emails', '42501', null, 'visitors cannot read the admin list');
select tests.logout();

-- profile edits
select tests.login('00000000-0000-0000-0000-0000000000a1');
select lives_ok($$update public.profiles set bio = 'olá' where id = '00000000-0000-0000-0000-0000000000a1'$$, 'student edits own bio');
select throws_ok($$update public.profiles set roles = array['admin']::public.user_role[] where id = '00000000-0000-0000-0000-0000000000a1'$$, '42501', null, 'student cannot change own roles');
select throws_ok($$update public.profiles set verified = false where id = '00000000-0000-0000-0000-0000000000a1'$$, '42501', null, 'student cannot change verification');
select throws_ok($$update public.profiles set university_id = null where id = '00000000-0000-0000-0000-0000000000a1'$$, '42501', null, 'student cannot change university');
select is(tests.rows_affected($q$update public.profiles set bio = 'x' where id = '00000000-0000-0000-0000-0000000000a2'$q$), 0, 'student cannot edit another profile');
select throws_ok('select * from private.admin_emails', '42501', null, 'members cannot read the admin list');
select throws_ok($$insert into public.profiles (id) values (gen_random_uuid())$$, '42501', null, 'profiles are only created by sign-up');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a7');
select throws_ok($$update public.profiles set roles = array['partner']::public.user_role[] where id = '00000000-0000-0000-0000-0000000000a7'$$, '42501', null, 'no self-promotion to partner');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a4');
select lives_ok($$update public.profiles set roles = roles || 'alumni'::public.user_role where id = '00000000-0000-0000-0000-0000000000a2'$$, 'admin can change roles');
select tests.logout();
select ok((select 'alumni' = any (roles) from public.profiles where id = '00000000-0000-0000-0000-0000000000a2'), 'role change by admin applied');

-- organizations
select tests.login('00000000-0000-0000-0000-0000000000a7');
select throws_ok($$insert into public.organizations (name, kind, status) values ('X', 'gallery', 'approved')$$, '42501', null, 'organizations cannot be inserted directly');
select lives_ok($$select public.create_organization('Studio Novo', 'studio', 'https://example.test', '123456789')$$, 'anyone signed in can register an organization');
select is((select status from public.organizations where name = 'Studio Novo'), 'pending'::public.organization_status, 'new organization is pending');
select ok((select 'partner' = any (roles) from public.profiles where id = '00000000-0000-0000-0000-0000000000a7'), 'registering an organization grants the partner role');
select throws_ok($$update public.organizations set status = 'approved' where name = 'Studio Novo'$$, '42501', null, 'partner cannot approve own organization');
select lives_ok($$update public.organizations set website = 'https://novo.test' where name = 'Studio Novo'$$, 'partner edits own organization details');
select tests.logout();

select tests.login_anon();
select throws_ok($$select public.create_organization('Anon', 'studio')$$, '42501', null, 'visitors cannot register organizations');
select is((select count(*)::int from public.organizations where status <> 'approved'), 0, 'visitors see only approved organizations');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a6');
select is((select array_agg(name order by name) from public.organizations where status <> 'approved'), array['Estúdio Teste'], 'pending partner sees only its own pending organization');
select ok(exists (select 1 from public.organizations where name = 'Galeria Teste'), 'pending partner sees approved organizations');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a5');
select is(tests.rows_affected($q$update public.organizations set status = 'approved' where name = 'Studio Novo'$q$), 0, 'other partners cannot touch a pending organization');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a4');
select is((select count(*)::int from public.organizations where status = 'pending' and name in ('Estúdio Teste', 'Studio Novo')), 2, 'admin sees every pending organization');
select lives_ok($$update public.organizations set status = 'approved' where name = 'Studio Novo'$$, 'admin approves');
select tests.logout();
select is((select approved_by from public.organizations where name = 'Studio Novo'), '00000000-0000-0000-0000-0000000000a4'::uuid, 'approval stamped with the admin');
select isnt((select approved_at from public.organizations where name = 'Studio Novo'), null, 'approval time stamped');
select ok(exists (
  select 1 from realtime.messages
  where topic = 'organization:' || (select id from public.organizations where name = 'Studio Novo')::text
    and event = 'status' and payload ->> 'status' = 'approved' and private
), 'status change is broadcast on the organization''s private channel');

-- notification contacts and realtime
select ok(not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'organizations'), 'organizations are not broadcast to every subscriber via postgres_changes');

-- private channel "organization:<id>": only members may receive (realtime.messages RLS)
select is(private.is_member_of_org_topic('organization:not-a-uuid'), false, 'malformed topic is refused');
select tests.login('00000000-0000-0000-0000-0000000000a6');
select set_config('realtime.topic', 'organization:00000000-0000-0000-0000-0000000000b2', true);
select ok(private.is_member_of_org_topic((select realtime.topic())), 'member may join own organization channel');
select set_config('realtime.topic', 'organization:00000000-0000-0000-0000-0000000000b1', true);
select ok(not private.is_member_of_org_topic((select realtime.topic())), 'partner may not join another organization channel (even an approved one)');
select tests.logout();
select tests.login('00000000-0000-0000-0000-0000000000a1');
select set_config('realtime.topic', 'organization:00000000-0000-0000-0000-0000000000b2', true);
select ok(not private.is_member_of_org_topic((select realtime.topic())), 'student may not join an organization channel');
select tests.logout();
select set_config('realtime.topic', '', true);
select tests.login('00000000-0000-0000-0000-0000000000a5');
select throws_ok($$select * from public.organization_contacts('00000000-0000-0000-0000-0000000000b2')$$, '42501', null, 'non-admins cannot read organization contacts');
select tests.logout();
select tests.login_anon();
select throws_ok($$select * from public.organization_contacts('00000000-0000-0000-0000-0000000000b2')$$, '42501', null, 'visitors cannot read organization contacts');
select tests.logout();
select tests.login('00000000-0000-0000-0000-0000000000a4');
select is((select array_agg(email) from public.organization_contacts('00000000-0000-0000-0000-0000000000b2')), array['estudio@mail.test'], 'admin gets the members'' emails');
select tests.logout();

select * from finish();
rollback;
