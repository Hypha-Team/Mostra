-- Works visibility (CLAUDE.md §2 "Sees")
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

insert into public.work_media (work_id, kind, storage_path, alt_text) values
  ('00000000-0000-0000-0000-0000000000c1', 'image', 'a/c1.jpg', 'pública'),
  ('00000000-0000-0000-0000-0000000000c2', 'image', 'a/c2.jpg', 'faculdade'),
  ('00000000-0000-0000-0000-0000000000c3', 'image', 'a/c3.jpg', 'só eu');

create function tests.ana_work_titles() returns text[] language sql as $$
  select coalesce(array_agg(title order by title), '{}') from public.works
  where owner_id = '00000000-0000-0000-0000-0000000000a1'
$$;
grant execute on function tests.ana_work_titles() to anon, authenticated;

select tests.login_anon();
select is(tests.ana_work_titles(), array['Pública'], 'visitor: only published works for everyone');
select is((select count(*)::int from public.work_media), 1, 'visitor: only media of public works');
select is((select count(*)::int from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), 1, 'visitor sees an artist with public works');
select is((select count(*)::int from public.profiles where id = '00000000-0000-0000-0000-0000000000a3'), 0, 'visitor does not see other profiles');
select throws_ok($$insert into public.works (owner_id, title, art_type) values ('00000000-0000-0000-0000-0000000000a1', 'x', 'painting')$$, '42501', null, 'visitor cannot add works');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a1');
select is(tests.ana_work_titles(), array['Faculdade', 'Pública', 'Rascunho', 'Só eu'], 'owner sees all own works, drafts included');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a2');
select is(tests.ana_work_titles(), array['Faculdade', 'Pública'], 'student: everyone + university, not only-me, not drafts');
select is((select count(*)::int from public.work_media), 2, 'student: media follow the works');
select throws_ok($$insert into public.works (owner_id, title, art_type) values ('00000000-0000-0000-0000-0000000000a1', 'x', 'painting')$$, '42501', null, 'cannot add a work for someone else');
select lives_ok($$insert into public.works (owner_id, title, art_type) values ('00000000-0000-0000-0000-0000000000a2', 'Nova', 'painting')$$, 'verified student adds own work');
select is(tests.rows_affected($q$update public.works set title = 'hack' where owner_id = '00000000-0000-0000-0000-0000000000a1'$q$), 0, 'cannot edit someone else''s work');
select is(tests.rows_affected($q$delete from public.works where owner_id = '00000000-0000-0000-0000-0000000000a1'$q$), 0, 'cannot delete someone else''s work');
select throws_ok($$insert into public.work_media (work_id, kind, storage_path) values ('00000000-0000-0000-0000-0000000000c1', 'image', 'x')$$, '42501', null, 'cannot add media to someone else''s work');
select throws_ok($$select public.unpublish_work('00000000-0000-0000-0000-0000000000c1')$$, '42501', null, 'only admins moderate');
select lives_ok($$insert into public.saves (profile_id, work_id) values ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000c2')$$, 'student saves a visible work');
select throws_ok($$insert into public.saves (profile_id, work_id) values ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000c3')$$, '42501', null, 'cannot save a work you cannot see');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a3');
select is(tests.ana_work_titles(), array['Faculdade', 'Pública'], 'professor: everyone + university');
select throws_ok($$insert into public.works (owner_id, title, art_type) values ('00000000-0000-0000-0000-0000000000a3', 'x', 'painting')$$, '42501', null, 'professors do not add works');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a4');
select is(tests.ana_work_titles(), array['Faculdade', 'Pública'], 'admin: everyone + university, never only-me');
select is(tests.rows_affected($q$update public.works set title = 'x' where id = '00000000-0000-0000-0000-0000000000c1'$q$), 0, 'admin cannot edit a student''s work');
select lives_ok($$select public.unpublish_work('00000000-0000-0000-0000-0000000000c1')$$, 'admin can unpublish (moderation)');
select tests.logout();
select is((select published_at from public.works where id = '00000000-0000-0000-0000-0000000000c1'), null, 'work is off the wall');
update public.works set published_at = now() where id = '00000000-0000-0000-0000-0000000000c1';

select tests.login('00000000-0000-0000-0000-0000000000a5');
select is(tests.ana_work_titles(), array['Pública'], 'approved partner: everyone only');
select throws_ok($$insert into public.works (owner_id, title, art_type) values ('00000000-0000-0000-0000-0000000000a5', 'x', 'painting')$$, '42501', null, 'partners do not add works');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a7');
select is(tests.ana_work_titles(), array['Pública'], 'unverified account: everyone only');
select throws_ok($$insert into public.works (owner_id, title, art_type) values ('00000000-0000-0000-0000-0000000000a7', 'x', 'painting')$$, '42501', null, 'unverified accounts do not add works');
select tests.logout();

select tests.login('00000000-0000-0000-0000-0000000000a8');
select is(tests.ana_work_titles(), array['Pública'], 'student of another university: everyone only');
select tests.logout();

select * from finish();
rollback;
