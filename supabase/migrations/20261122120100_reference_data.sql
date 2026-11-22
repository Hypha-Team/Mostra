-- Reference data needed in every environment (production included). No demo content here.

-- Belas-Artes ULisboa.
-- The email domains are PLACEHOLDERS (".invalid" never matches a real address) until the
-- student association confirms them. To set the real ones:
--   update public.universities
--      set email_domains = array['<student-domain>'], staff_email_domains = array['<staff-domain>']
--    where slug = 'belas-artes-ulisboa';
insert into public.universities (id, name, slug, email_domains, staff_email_domains)
values (
  '00000000-0000-4000-8000-000000000001',
  'Faculdade de Belas-Artes da Universidade de Lisboa',
  'belas-artes-ulisboa',
  array['estudantes.a-confirmar.invalid'],
  array['docentes.a-confirmar.invalid']
)
on conflict (id) do nothing;

-- First admins (careers office to be added later).
insert into private.admin_emails (email, university_id)
values
  ('84968@novasbe.pt', '00000000-0000-4000-8000-000000000001'),
  ('galluzzo.tancredi@gmail.com', '00000000-0000-4000-8000-000000000001')
on conflict (email) do nothing;

-- Admins who signed up before being listed get the role now.
update public.profiles p
set roles = p.roles || 'admin'::public.user_role,
    verified = true,
    university_id = coalesce(p.university_id, a.university_id)
from auth.users u
join private.admin_emails a on a.email = lower(u.email)
where u.id = p.id and not ('admin' = any (p.roles));

-- Marks databases that may hold demo data (preview, local). Production never has a row here.
-- supabase/seed/demo.sql refuses to run on a database with real users and no 'demo' mark.
create table private.environment (
  name text primary key check (name = 'demo'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table private.environment enable row level security;
revoke all on private.environment from anon, authenticated;
create trigger set_updated_at before update on private.environment
  for each row execute function private.set_updated_at();
