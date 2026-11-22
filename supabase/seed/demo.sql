-- mostra — DEMO DATA. Preview environment only (CLAUDE.md §5: no fake content in production).
--
-- Applied by .github/workflows/supabase.yml to the PREVIEW project only
-- (`supabase db push --include-seed`), and by `supabase db start` locally.
-- The production job never passes --include-seed.
--
-- Every row is flagged is_demo = true and labelled "demo" in its visible text.
-- Demo accounts use the reserved ".invalid" domain: nobody can sign in as them.
-- Idempotent: safe to run again.

-- Guard: run only on a database marked as holding demo data (private.environment = 'demo'),
-- or on a fresh one with no real users yet (which then gets marked). A database with real
-- users and no mark — production — refuses. To allow it deliberately on a preview DB that
-- already has real testers, run once in its SQL editor:
--   insert into private.environment (name) values ('demo');
do $$
begin
  if not exists (select 1 from private.environment where name = 'demo')
     and exists (select 1 from auth.users where email not like '%@demo.mostra.invalid') then
    raise exception 'demo seed refused: this database has real users and is not marked as a demo/preview database';
  end if;
end $$;

insert into private.environment (name) values ('demo') on conflict do nothing;

-- ── demo accounts ───────────────────────────────────────────────────────────
insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data, email_confirmed_at, created_at, updated_at)
values
  ('d0000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'marta@demo.mostra.invalid',   '{"provider":"email","providers":["email"]}', '{"full_name":"Marta Silva (demo)"}',   now(), now(), now()),
  ('d0000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'joao@demo.mostra.invalid',    '{"provider":"email","providers":["email"]}', '{"full_name":"João Costa (demo)"}',    now(), now(), now()),
  ('d0000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ines@demo.mostra.invalid',    '{"provider":"email","providers":["email"]}', '{"full_name":"Inês Duarte (demo)"}',   now(), now(), now()),
  ('d0000000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'tiago@demo.mostra.invalid',   '{"provider":"email","providers":["email"]}', '{"full_name":"Tiago Reis (demo)"}',    now(), now(), now()),
  ('d0000000-0000-4000-8000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'prof@demo.mostra.invalid',    '{"provider":"email","providers":["email"]}', '{"full_name":"Prof. Helena Matos (demo)"}', now(), now(), now()),
  ('d0000000-0000-4000-8000-000000000006', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'galeria@demo.mostra.invalid', '{"provider":"email","providers":["email"]}', '{"full_name":"Rita Alves (demo)"}',    now(), now(), now()),
  ('d0000000-0000-4000-8000-000000000007', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'estudio@demo.mostra.invalid', '{"provider":"email","providers":["email"]}', '{"full_name":"Nuno Pires (demo)"}',    now(), now(), now())
on conflict (id) do nothing;

update public.profiles p set
  university_id = '00000000-0000-4000-8000-000000000001',
  roles = d.roles::public.user_role[],
  verified = d.verified,
  discipline = d.discipline,
  level = d.level::public.study_level,
  year = d.year,
  bio = d.bio,
  open_to = d.open_to::public.open_to[],
  is_demo = true
from (values
  ('d0000000-0000-4000-8000-000000000001'::uuid, '{student}',   true,  'Pintura',   'ma',  1, 'Perfil de demonstração.', '{commissions,jobs}'),
  ('d0000000-0000-4000-8000-000000000002'::uuid, '{student}',   true,  'Escultura', 'ba',  3, 'Perfil de demonstração.', '{collaborations}'),
  ('d0000000-0000-4000-8000-000000000003'::uuid, '{student}',   true,  'Fotografia','ba',  2, 'Perfil de demonstração.', '{}'),
  ('d0000000-0000-4000-8000-000000000004'::uuid, '{student,professor}', true, 'Multimédia', 'phd', 2, 'Perfil de demonstração (doutorando que também ensina).', '{studio_assistant}'),
  ('d0000000-0000-4000-8000-000000000005'::uuid, '{professor}', true,  'Desenho',   null,  null, 'Perfil de demonstração.', '{}'),
  ('d0000000-0000-4000-8000-000000000006'::uuid, '{partner}',   false, null,        null,  null, null, '{}'),
  ('d0000000-0000-4000-8000-000000000007'::uuid, '{partner}',   false, null,        null,  null, null, '{}')
) as d(id, roles, verified, discipline, level, year, bio, open_to)
where p.id = d.id;

-- ── organizations ───────────────────────────────────────────────────────────
insert into public.organizations (id, name, kind, website, status, approved_at, created_by, is_demo) values
  ('d1000000-0000-4000-8000-000000000001', 'Galeria Exemplo (demo)', 'gallery', null, 'approved', now(), 'd0000000-0000-4000-8000-000000000006', true),
  ('d1000000-0000-4000-8000-000000000002', 'Estúdio Exemplo (demo)', 'studio',  null, 'pending',  null,  'd0000000-0000-4000-8000-000000000007', true)
on conflict (id) do nothing;

insert into public.organization_members (org_id, profile_id) values
  ('d1000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000006'),
  ('d1000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000007')
on conflict do nothing;

-- ── works (media arrive with Phase 2 uploads) ──────────────────────────────
insert into public.works (id, owner_id, title, year, art_type, medium, dimensions, duration_seconds, statement, visibility, published_at, is_demo) values
  ('d2000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', 'Sem título (demo)',        2026, 'painting',     'óleo sobre tela',  '120 × 90 cm', null, 'Obra de demonstração.', 'everyone',   now(), true),
  ('d2000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000001', 'Estudo de luz (demo)',     2025, 'painting',     'acrílico',         '40 × 30 cm',  null, 'Obra de demonstração.', 'university', now(), true),
  ('d2000000-0000-4000-8000-000000000003', 'd0000000-0000-4000-8000-000000000002', 'Peso (demo)',              2026, 'sculpture',    'gesso e ferro',    '80 × 40 × 40 cm', null, 'Obra de demonstração.', 'everyone', now(), true),
  ('d2000000-0000-4000-8000-000000000004', 'd0000000-0000-4000-8000-000000000003', 'Margem sul (demo)',        2026, 'photography',  'impressão a jato', '60 × 40 cm',  null, 'Obra de demonstração.', 'everyone',   now(), true),
  ('d2000000-0000-4000-8000-000000000005', 'd0000000-0000-4000-8000-000000000004', 'Ruído de fundo (demo)',    2025, 'sound',        'áudio estéreo',    null,          270,  'Obra de demonstração.', 'everyone',   now(), true),
  ('d2000000-0000-4000-8000-000000000006', 'd0000000-0000-4000-8000-000000000004', 'Corpo em loop (demo)',     2026, 'audiovisual',  'vídeo HD',         null,          372,  'Obra de demonstração.', 'university', now(), true),
  ('d2000000-0000-4000-8000-000000000007', 'd0000000-0000-4000-8000-000000000003', 'Caderno (demo)',           2026, 'drawing',      'grafite',          'A4',          null, 'Obra de demonstração, só para a autora.', 'only_me', now(), true)
on conflict (id) do nothing;

-- ── opportunities ───────────────────────────────────────────────────────────
insert into public.opportunities (id, org_id, professor_id, type, title, description, pay_type, amount_eur, deadline, location, places, status, is_demo) values
  ('d3000000-0000-4000-8000-000000000001', 'd1000000-0000-4000-8000-000000000001', null, 'job',       'Montagem de exposição (demo)', 'Oportunidade de demonstração.', 'paid',      600, now() + interval '30 days', 'Lisboa', 2, 'open', true),
  ('d3000000-0000-4000-8000-000000000002', 'd1000000-0000-4000-8000-000000000001', null, 'open_call', 'Chamada para coletiva (demo)', 'Oportunidade de demonstração.', 'entry_fee', 25,  now() + interval '20 days', 'Lisboa', null, 'open', true),
  ('d3000000-0000-4000-8000-000000000003', null, 'd0000000-0000-4000-8000-000000000005', 'workshop', 'Oficina de desenho (demo)', 'Oportunidade de demonstração.', 'free', null, now() + interval '10 days', 'Belas-Artes', 15, 'open', true)
on conflict (id) do nothing;

-- ── events ──────────────────────────────────────────────────────────────────
insert into public.events (id, university_id, title, starts_at, location, kind, is_demo) values
  ('d4000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'Ateliers abertos (demo)', now() + interval '14 days', 'Belas-Artes, Chiado', 'open_studio', true)
on conflict (id) do nothing;

-- ── projects & materials ────────────────────────────────────────────────────
insert into public.projects (id, owner_id, title, description, opens_at, status, is_demo) values
  ('d5000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000002', 'Sala 3 (demo)', 'Projeto de demonstração.', now() + interval '40 days', 'open', true)
on conflict (id) do nothing;

insert into public.project_members (project_id, profile_id, role_label) values
  ('d5000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000002', 'curadoria')
on conflict do nothing;

insert into public.project_open_roles (id, project_id, label, deal, status) values
  ('d5100000-0000-4000-8000-000000000001', 'd5000000-0000-4000-8000-000000000001', 'luz e som', 'fee_split', 'open')
on conflict (id) do nothing;

insert into public.materials (id, owner_id, kind, material, title, quantity, location, status, project_id, is_demo) values
  ('d6000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000002', 'give', 'wood',   'Ripas de pinho (demo)', '12 peças', 'Belas-Artes, piso 2', 'available', 'd5000000-0000-4000-8000-000000000001', true),
  ('d6000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000001', 'want', 'frames', 'Molduras A3 (demo)',    '4',        'Lisboa',              'available', null, true)
on conflict (id) do nothing;
