-- Opportunities, applications and contact rules (CLAUDE.md §2)
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

insert into public.opportunities (id, org_id, type, title, pay_type, amount_eur, status) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000b1', 'job', 'Montagem', 'paid', 600, 'open'),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000b1', 'commission', 'Rascunho', 'paid', 300, 'draft');

-- posting
select tests.login('00000000-0000-0000-0000-0000000000a6');
select throws_ok($$insert into public.opportunities (org_id, type, title, pay_type, status) values ('00000000-0000-0000-0000-0000000000b2', 'job', 'x', 'paid', 'open')$$, '42501', null, 'pending partner cannot post');
select throws_ok($$select public.start_conversation('00000000-0000-0000-0000-0000000000a2')$$, '42501', null, 'pending partner cannot message');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a5');
select lives_ok($$insert into public.opportunities (org_id, type, title, pay_type, status) values ('00000000-0000-0000-0000-0000000000b1', 'open_call', 'Chamada', 'entry_fee', 'open')$$, 'approved partner posts');
select throws_ok($$insert into public.opportunities (org_id, type, title, pay_type) values ('00000000-0000-0000-0000-0000000000b2', 'job', 'x', 'paid')$$, '42501', null, 'cannot post for an organization you are not in');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a3');
select lives_ok($$insert into public.opportunities (professor_id, type, title, pay_type, status) values ('00000000-0000-0000-0000-0000000000a3', 'workshop', 'Oficina', 'free', 'open')$$, 'professor publishes a call');
select is((select count(*)::int from public.opportunities where status = 'draft'), 0, 'others do not see drafts');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a1');
select throws_ok($$insert into public.opportunities (professor_id, type, title, pay_type) values ('00000000-0000-0000-0000-0000000000a1', 'job', 'x', 'paid')$$, '42501', null, 'students do not post opportunities');
select tests.logout();

select tests.login_anon();
select ok((select count(*)::int from public.opportunities where status = 'open') >= 1, 'visitors read open opportunities');
select is((select count(*)::int from public.opportunities where status = 'draft'), 0, 'visitors do not see drafts');
select tests.logout();

-- applying
select tests.login('00000000-0000-0000-0000-0000000000a1');
select throws_ok($$insert into public.applications (opportunity_id, student_id, work_ids) values ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000a1', array['00000000-0000-0000-0000-0000000000c5'::uuid])$$, '42501', null, 'cannot apply with someone else''s work');
select throws_ok($$insert into public.applications (opportunity_id, student_id) values ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000a1')$$, '42501', null, 'cannot apply to a draft');
select throws_ok($$insert into public.applications (opportunity_id, student_id, work_ids) values ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000a1', array['00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000c4']::uuid[])$$, '23514', null, 'at most 3 works');
select lives_ok($$insert into public.applications (id, opportunity_id, student_id, message, work_ids) values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000a1', 'Olá', array['00000000-0000-0000-0000-0000000000c1'::uuid])$$, 'student applies with own work');
select is(tests.rows_affected($q$update public.applications set status = 'accepted'$q$), 0, 'student cannot change the status');
select throws_ok($$select public.start_conversation('00000000-0000-0000-0000-0000000000a5')$$, '42501', null, 'student cannot start a conversation with a partner');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a5');
select is((select count(*)::int from public.applications), 1, 'partner sees applications to its opportunities');
select lives_ok($$update public.applications set status = 'shortlisted' where id = '00000000-0000-0000-0000-0000000000e1'$$, 'partner shortlists');
select throws_ok($$update public.applications set message = 'edited' where id = '00000000-0000-0000-0000-0000000000e1'$$, '42501', null, 'partner cannot edit the student''s message');
select lives_ok($$insert into public.contracts (application_id, terms) values ('00000000-0000-0000-0000-0000000000e1', '{"fee": 600}')$$, 'partner drafts a contract');
select lives_ok($$insert into public.shortlists (org_id, student_id) values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1')$$, 'approved partner shortlists a student');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a3');
select is((select count(*)::int from public.applications), 0, 'others do not see the application');
select is((select count(*)::int from public.contracts), 0, 'others do not see the contract');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a1');
select is((select count(*)::int from public.contracts), 1, 'student sees own contract');
select is(tests.rows_affected($q$update public.contracts set status = 'signed'$q$), 0, 'student cannot sign by editing the row');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a6');
select throws_ok($$insert into public.shortlists (org_id, student_id) values ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a1')$$, '42501', null, 'pending partner cannot shortlist');
select tests.logout();

-- contact rules
select tests.login('00000000-0000-0000-0000-0000000000a5');
select lives_ok($$select public.start_conversation('00000000-0000-0000-0000-0000000000a2')$$, 'approved partner → student open to work');
select lives_ok($$select public.start_conversation('00000000-0000-0000-0000-0000000000a1', 'application', '00000000-0000-0000-0000-0000000000e1')$$, 'approved partner → student who applied');
select throws_ok($$select public.start_conversation('00000000-0000-0000-0000-0000000000a8')$$, '42501', null, 'approved partner → student not open and not applied: refused');
select throws_ok($$select public.start_conversation('00000000-0000-0000-0000-0000000000a3')$$, '42501', null, 'partner → professor: refused');
select lives_ok($$insert into public.messages (conversation_id, body) select c.id, 'Olá Bruno' from public.conversations c join public.conversation_participants p on p.conversation_id = c.id and p.profile_id = '00000000-0000-0000-0000-0000000000a2'$$, 'partner writes first');
select throws_ok($$insert into public.conversations (created_by) values ('00000000-0000-0000-0000-0000000000a5')$$, '42501', null, 'conversations only through start_conversation');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a2');
select is((select count(*)::int from public.messages), 1, 'student reads the partner''s message');
select lives_ok($$insert into public.messages (conversation_id, body) select conversation_id, 'Olá!' from public.messages limit 1$$, 'student replies to a partner who wrote first');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a1');
select lives_ok($$select public.start_conversation('00000000-0000-0000-0000-0000000000a2')$$, 'student → student');
select lives_ok($$select public.start_conversation('00000000-0000-0000-0000-0000000000a3')$$, 'student → professor');
select throws_ok($$select public.start_conversation('00000000-0000-0000-0000-0000000000a8')$$, '42501', null, 'student → student of another university: refused');
select is((select count(*)::int from public.messages where body = 'Olá Bruno'), 0, 'non-participants cannot read a conversation');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a3');
select lives_ok($$select public.start_conversation('00000000-0000-0000-0000-0000000000a1')$$, 'professor → student');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a7');
select throws_ok($$select public.start_conversation('00000000-0000-0000-0000-0000000000a1')$$, '42501', null, 'unverified account cannot message');
select is((select count(*)::int from public.messages), 0, 'unverified account reads no messages');
select tests.logout();

select tests.login_anon();
select throws_ok($$select public.start_conversation('00000000-0000-0000-0000-0000000000a1')$$, '42501', null, 'visitors cannot message');
select tests.logout();

select * from finish();
rollback;
