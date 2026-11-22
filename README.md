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
| `pnpm test:e2e` | Playwright at 1440×1000 and 390×844 (starts `pnpm start`; run `pnpm build` first) |

CI (`.github/workflows/ci.yml`) runs all four on every pull request.

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
supabase/migrations/     SQL migrations (from Phase 1)
tests/e2e/               Playwright
```

`/dev/tokens` shows the design tokens on previews; it returns 404 in production.
