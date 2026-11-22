# mostra

Platform for the students of Belas-Artes ULisboa — powered by HYPHA.
The build brief is [`CLAUDE.md`](./CLAUDE.md).

## Stack

Next.js 16 (App Router, TypeScript) · Tailwind CSS 4 · next-intl (pt default at `/`, en at `/en`) · Supabase (`@supabase/ssr`) · Playwright · Vercel.

## Develop

```bash
pnpm install
cp .env.example .env.local   # fill in the Supabase values
pnpm dev
```

| script | what |
|---|---|
| `pnpm lint` | ESLint (includes a no-hard-coded-UI-strings rule) |
| `pnpm typecheck` | Next route types + `tsc --noEmit` |
| `pnpm build` | production build |
| `pnpm test:e2e` | Playwright at 1440×1000 and 390×844, no backend needed (starts `pnpm start`; run `pnpm build` first) |
| `pnpm test:e2e:auth` | magic-link flows against a local Supabase (`supabase start`), reading mail from its inbox |
| `pnpm test:db` | RLS tests (pgTAP) on a throwaway local Postgres, when Docker is not available |

CI (`.github/workflows/ci.yml`) runs two jobs on every pull request:

- **checks** — lint, typecheck, build, Playwright (no backend).
- **supabase** — `supabase start` (migrations + demo seed), `supabase test db` (RLS tests in `supabase/tests/`), then the auth e2e suite against that local stack.

## Supabase

| | project | gets |
|---|---|---|
| production | `mostra` (EU) | migrations on merge to `main` — never demo data |
| preview | `mostra-preview` (EU) | migrations **and** `supabase/seed/demo.sql` on every pull request |

`.github/workflows/supabase.yml` applies them with `supabase db push`. GitHub repository secrets:

| secret | value |
|---|---|
| `SUPABASE_ACCESS_TOKEN` | personal access token (supabase.com → Account → Access Tokens) |
| `SUPABASE_PROJECT_REF` | production project ref (`mostra`) |
| `SUPABASE_DB_PASSWORD` | production database password |
| `SUPABASE_PREVIEW_PROJECT_REF` | preview project ref (`mostra-preview`) |
| `SUPABASE_PREVIEW_DB_PASSWORD` | preview database password |

The demo seed refuses to run on a database that has real users and is not marked as a demo database
(`private.environment`). Every demo row has `is_demo = true` and "(demo)" in its visible text.

University email domains are data, not code (`universities.email_domains` / `staff_email_domains`).
Until ULisboa confirms them they are `.invalid` placeholders, so nobody is auto-verified as a student or professor:

```sql
update public.universities
   set email_domains = array['<student-domain>'], staff_email_domains = array['<staff-domain>']
 where slug = 'belas-artes-ulisboa';
```

Admins come from `private.admin_emails` (see `supabase/migrations/*_reference_data.sql`).

## Environment variables

| name | where | required | notes |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Vercel: Production, Preview, Development | yes | `https://<ref>.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Vercel: Production, Preview, Development | yes* | `sb_publishable_…` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | same | *alternative | legacy anon key; used only if the publishable key is missing |

The service-role / secret key is not used in Phase 0. When it arrives (Phase 1) it is server-only and never prefixed with `NEXT_PUBLIC_`.

`GET /api/health` reports `{"supabase":"ok" | "missing_env" | "unreachable"}` without exposing any value.

## Layout

```
src/app/[locale]/        pages (root layout lives here)
src/app/api/health/      Supabase connectivity check
src/i18n/                next-intl routing, request config, navigation
src/lib/supabase/        server and browser clients
src/proxy.ts             locale routing (Next 16 "proxy", formerly middleware)
messages/{pt,en}.json    all UI copy
public/brand/            faculty logo, HYPHA ink logo
docs/design/             design canvas screenshots
docs/brand-archive/      assets not to be served (red HYPHA logo)
supabase/migrations/     schema, enums, RLS, reference data
supabase/tests/          RLS tests (pgTAP)
supabase/seed/demo.sql   demo data — preview and local only
tests/e2e/               Playwright, no backend
tests/e2e-auth/          Playwright, magic-link flows on a local Supabase
```

`/dev/tokens` shows the design tokens on previews; it returns 404 in production.
