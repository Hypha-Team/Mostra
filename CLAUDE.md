# mostra — build brief for Claude Code

**mostra** is a platform for the students of Belas-Artes ULisboa (Faculdade de Belas-Artes da Universidade de Lisboa). Students show their work, find paid opportunities, and make things together; galleries, studios and recruiters find and hire them. It is the first university instance of **HYPHA**, the engine behind it (shown only as a small "powered by HYPHA" mark).

This file is the source of truth for the build. Read it fully before writing code. Work phase by phase (see *Phases*); finish and verify one phase before starting the next. When something here is unclear or impossible, stop and ask instead of guessing.

---

## 1. Stack

- **Next.js** (App Router, TypeScript, Server Components + Server Actions), deployed on **Vercel**.
- **Supabase**: Postgres, Auth, Storage, Row Level Security. Connect it through the Vercel ↔ Supabase integration so env vars are set automatically. Never hard-code keys; never expose the service-role key to the client.
- **Styling**: Tailwind CSS with the design tokens in section 6 as theme values. No component library that imposes its own look.
- **Motion**: GSAP (intro/detail timelines) + a hand-written `requestAnimationFrame` loop for the Aperture wall (section 7). No Lenis or smooth-scroll library on the wall page: the wall owns its own input.
- **Media**: `<model-viewer>` for 3D (`.glb`, `.usdz`), native `<video>`/`<audio>`, `wavesurfer.js` for audio waveforms, `next/image` for images.
- **i18n**: Portuguese (default) and English from day one (`next-intl` or equivalent). No hard-coded UI strings.
- **Testing**: Playwright for the acceptance checks in each phase.
- Check the current official docs of each library before using its API. Do not rely on memory for versions.

Repository: a new repo in the **Hypha-Team** GitHub organization (suggested name `mostra`), separate from the V1 prototype. Every pull request gets a Vercel preview deployment; the team reviews on the preview link.

---

## 2. Roles

One app, one shared wall of works. What changes per role: the home, the menu, the single magenta button, and who you can contact.

| | student (+ alumni) | professor (+ careers office) | partner (gallery, studio, company, recruiter) | visitor (no account) |
|---|---|---|---|---|
| Home | wall + opportunities for you + my projects | my students: new works, recommendation requests, my calls | talent search + my opportunities + applicants | public wall + open studios |
| Magenta button | add work | publish a call / recommend | post an opportunity | sign in |
| Menu | home · opportunities · projects · me | home · my students · explore · messages | talent · my posts · messages · account | explore · open studios · opportunities (read only) · sign in |
| Can message | students, professors, partners who wrote first | their students | students marked *open to* work, or students who applied to their opportunity | nobody |
| Sees | works not set to *only me* | works not set to *only me* | works set to *everyone* | works set to *everyone*, no contact details |
| Verified by | university email domain `[CONFIRM: ULisboa student email domain]` | staff email domain `[CONFIRM]` | an admin (careers office) approves the organization | — |

Rules:
- A partner cannot post or message until an admin approves the organization (`organizations.status = 'approved'`).
- Students choose who can contact them (`profiles.open_to`, plus per-work visibility).
- One account can hold two roles (e.g. PhD student who teaches). Role switch lives in the profile menu.
- Enforce all of this with **Supabase RLS**, not only in the UI. Write RLS tests.

---

## 3. Data model (Postgres)

Use enums where listed. Add `created_at`, `updated_at` everywhere. Every table has RLS enabled.

- `universities` (id, name, slug, email_domains text[]) — seed with Belas-Artes ULisboa. Model it as an entity now so other universities can be added later.
- `profiles` (id = auth.users.id, university_id, roles role[] — `student|alumni|professor|partner|admin`, full_name, discipline, level — `ba|ma|phd|alumni`, year, bio, avatar_path, open_to text[] — `commissions|jobs|collaborations|studio_assistant`, verified bool)
- `organizations` (id, name, kind — `gallery|studio|company|institution|association`, website, nif, status — `pending|approved|rejected`, approved_by, approved_at) + `organization_members` (org_id, profile_id)
- `works` (id, owner_id, title, year, art_type — `painting|photography|audiovisual|sculpture|drawing|design|sound|performance|printmaking|installation|text`, medium, dimensions, duration_seconds, statement, visibility — `everyone|university|only_me`, cover_media_id, published_at)
- `work_media` (id, work_id, kind — `image|video|model3d|audio|pdf|text|link`, storage_path or external_url, poster_path, aspect_ratio numeric, duration_seconds, position) — a work can have many media of different kinds.
- `saves` (profile_id, work_id), `shortlists` (org_id, student_id, note)
- `opportunities` (id, org_id or professor_id, type — `job|commission|open_call|workshop|residency|seminar`, title, description, pay_type — `paid|unpaid|entry_fee|free`, amount_eur, deadline, starts_at, location, places, status — `draft|open|closed`)
- `applications` (id, opportunity_id, student_id, message, work_ids uuid[], status — `sent|seen|shortlisted|accepted|declined`)
- `contracts` (id, application_id, terms jsonb — fee, dates, payment_days, rights, cancellation — pdf_path, status — `draft|sent|signed|void`, signed_at) — see Phase 4 for what is real and what is a stub.
- `recommendations` (id, professor_id, student_id, opportunity_id nullable, text, status — `requested|written|declined`)
- `projects` (id, owner_id, title, description, opens_at, status) + `project_members` (project_id, profile_id, role_label) + `project_open_roles` (project_id, label, deal — `paid|fee_split|shared_sales|unpaid_credited|materials_paid`, until, status)
- `materials` (id, owner_id, kind — `give|swap|want`, material — `textile|wood|metal|plaster_clay|paper|paint|frames|electronics|other`, title, quantity, location, available_until, source_work_id nullable, project_id nullable, reserved_by_project_id nullable, status — `available|reserved|taken|expired`, photo_path)
- `conversations` + `messages` — creation is allowed only when the contact rules in section 2 pass (enforce in RLS / a security-definer function).
- `events` (open studios, workshops: title, starts_at, location, kind).

Storage buckets: `work-media` (private; serve with signed URLs, public only when the work's visibility is *everyone*), `avatars`, `materials`, `contracts` (private). Limits: images ≤ 20 MB, audio ≤ 50 MB, video ≤ 300 MB or an external Vimeo/YouTube link, 3D ≤ 50 MB. Generate image sizes and video posters on upload.

---

## 4. Screens

Build mobile-first; every page works at 390 px and 1440 px. Screens (from the design canvas — screenshots go in `docs/design/`):

1. **Welcome / sign in** — faculty logo, "mostra", one line, magenta "enter with your university email", secondary "I'm a gallery, studio or organisation", "powered by HYPHA".
2. **Explore (the wall)** — the Aperture wall (section 7). Filters on top: first **type of art** (`art_type`, with counts), then an optional secondary **file** filter (`work_media.kind`). Non-image works show their poster with a small dark badge: `▶ 6:12`, `3D · rotate`, `♪ 4:30`, `24 pages`, `essay`.
3. **Work detail** — opens from the wall (section 7). Format tabs for every media the work has (photos, video, 3D, audio, pdf). Museum wall label: artist · *title, year* · medium, dimensions/duration · discipline, level, Belas-Artes ULisboa. Actions: view portfolio, invite to project, save (partners: + shortlist). Rights line: "© artist. Not to be reused without permission." Materials teaser: "offer leftover materials".
4. **Add work** — step 1: pick every format the work needs (multi-select); step 2: upload + wall-label fields (fields change with the format: dimensions vs duration); step 3: visibility (*everyone / Belas-Artes only / only me*).
5. **Profile / portfolio** — photo, name, discipline · level, verified badge, statement, *open to* chips, faculty recommendation, exhibitions, works grid, "download portfolio PDF". Partner view adds "offer an opportunity" + "add to shortlist".
6. **Opportunities** — list with deadline as date block, type, title, org + verified mark, pay tag always visible (`€600 · paid`, `unpaid`, `entry fee €25`, `free`). Filters: paid only, jobs, open calls, workshops, residencies, from the faculty.
7. **Apply** — choose up to 3 works from your portfolio, write a short message, send. (Missing from the canvas: design it in the same language.)
8. **Application → contract → invoice** — progress: applied, accepted, contract, work, invoice & paid. Contract summary in plain words (fee, dates, payment terms, your work stays yours, cancellation) + full PDF. "Next: getting paid" helper explaining *ato isolado* for students without an open activity at Finanças (link to the Portal das Finanças page; no tax advice beyond that).
9. **Projects & materials** — tabs: open calls for collaborators · my projects · materials. Project space: team with open roles, materials needed matched against the board, next dates, team chat, shared files. Materials board: to take / swap / wanted, filter by material, each item shows where it came from ("left from *Room 3*"). When a project closes, offer to put leftovers back on the board in one tap.
10. **Role homes** — student, professor, partner, visitor (section 2).
11. **Partner screens** — post an opportunity, review applicants (see applications with their selected works, shortlist, message, send contract).
12. **Admin (careers office)** — approve organizations, moderate reported content, publish faculty calls.
13. **Messages** — conversations tied to a context when possible (application, project, material).

Later (Phase 6, optional): **Enter gallery** — an immersive exhibition mode on the artist profile ("Explore Marta's works in an immersive exhibition"); the normal portfolio always stays one tap away.

---

## 5. Content and legal rules

- **No fake content in production.** Demo seed data is allowed only in the preview environment and every demo item is labeled "demo". Numbers like "86 kg reused" must be computed from real data or hidden.
- Real student works only with written consent (store consent date on the work).
- GDPR: privacy notice, consent at sign-up, export and delete my account, no tracking cookies without consent.
- Contracts: we provide templates and a plain-language summary; the templates must be reviewed by a lawyer before real use. Qualified e-signature (Chave Móvel Digital) is integrated through a certified provider, **not built by us**.
- Accessibility: WCAG 2.2 AA. Real buttons and links, labels on inputs, focus states, alt text required on upload, captions field for video.

---

## 6. Design system ("white cube")

- Ground `#FAFAF8`, ink `#111111`, label `#5F5F5F`, secondary text `#3A3A3A`, lines `#E6E5E0`, chip border `#DAD9D4`, soft panel `#F1F0EB`, chip bg `#ECEBE6`.
- **Faculty magenta `#D82E8A`: one per screen, only on the main action** (add work, sign, post, publish). White text on it.
- Verified blue `#1F5FA8`, trust marks only. Pay tags: paid `#E3EEDF`/`#24502A`, entry fee `#F6E3D6`/`#7A3410`, unpaid/free `#ECEBE6`/`#111`. Wanted materials `#FBEAF3`/`#8E1A58`.
- Type: **Instrument Sans** (400/500/600, italic for work titles). Section titles lowercase, 26–40 px, weight 600, letter-spacing −0.02 to −0.03em. Small caps labels: 11 px, uppercase, 0.08em tracking, `#5F5F5F`.
- Buttons: pills, 44 px min height; primary magenta, secondary ink, tertiary outline.
- Works are always bigger than UI. Work titles in italic. Every work has a wall label.
- Logos (in `public/brand/`): faculty logo (black, transparent PNG) and HYPHA logo in ink, used only as "powered by" at 10 px height in headers, 16 px on Welcome. Never red, never next to the magenta button.
- Desktop header: faculty logo · divider · "mostra" + powered by · lowercase nav with the active item underlined in ink · search · primary button · avatar.

---

## 7. The wall: "Aperture" lens motion

The Explore wall is an editorial photo wall that slowly drifts upward in a loop, **bends vertically like a lens** while you scroll or drag, and flattens again when you stop. Clicking a work opens the detail. Adapted from the *Aperture* motion study (motion.imshengli.com); keep its maths exactly, swap its content for mostra works.

### Architecture
Split into pure modules: `layout.ts` (deterministic positions), `motion.ts` (scroll/flick/boost/bow model), `render.ts` (applies transforms), `detail.ts` (open/close state + GSAP timelines). The rAF loop is the only owner of card transforms; GSAP may animate only opacity/intro offsets on wrappers, never the same properties as the loop. No iframes. Clean up listeners, rAF and GSAP timelines on unmount and route change.

### Static look
Background `#FAFAF8`, text `#111`. Full-screen stage, `overflow: hidden`, `touch-action: none`, cursor grab/grabbing. Wall: `perspective: 1400px`, `transform-style: preserve-3d`. Cards: radius 3px, no shadow, `object-fit: cover`, `filter: saturate(.96) contrast(1.03)`. Only hint: top-right 28px, "scroll · click to open", 10 px mono-style label, 0.24em tracking, opacity .5 (translated). Filters bar sits above the stage and does not scroll with it.

### Layout (W = viewport width)
**Desktop (W ≥ 760)** — editorial template of 13 slots, each `[x/W, baseY/W, width/W, aspect]`, `height = width / work aspect` (use the work's real cover aspect; the template aspect is the fallback):
```
[[-.02,.04,.3,.78],[.065,.47,.19,.8],[.05,.84,.22,.82],[.085,1.16,.15,.9],
 [.415,.1,.17,.78],[.44,.42,.12,.8],[.4,.6,.2,.85],[.425,.95,.15,.95],
 [.415,1.19,.17,.8],[.74,.02,.2,.78],[.74,.32,.2,.85],[.72,.72,.3,.8],[.76,1.12,.16,.8]]
```
One band = 13 works, band height `1.49W`. x may be negative on purpose (cards bleed off the edge). **Adaptation for mostra:** for more than 13 works, stack further bands of the same template below (band k offset by `k × 1.49W`); the loop length is `bands × 1.49W`.

**Mobile (W < 760)** — all works, two-column masonry:
- `random(i,k) = fract(43758.5453 · sin((i+1)·12.9898 + 7.233·k))`
- both column heights start at `.08W`; `column = (W − .1W − .055W) / 2`
- each work goes to the shorter column (left on ties); `width = column × (.82 + .18·random(i,1))`; `height = width / aspect`; `x = .05W + col × (column + .055W) + (column − width) × random(i,2)`; `baseY` = current column height; then column height += `height + .08W × (.7 + 1.1·random(i,3))`
- loop length = tallest column. Re-layout on resize and on filter change.

### Motion model
State `scroll = flick = boost = bow = 0`. Every frame when not dragging:
- `scroll −= (.35 − flick)`
- `flick *= min(.96, .9 + .012·boost)`; if `|flick| < .01` → 0
- `boost *= .95`; if `< .01` → 0
- `maxBow = .8 × (mobile ? .6 : 1)`; `target = clamp(sign(flick) × min(maxBow, .02·|flick|), −maxBow, maxBow)`
- `bow += (target − bow) × .04`; if `|bow| < .0006` and target is 0 → `bow = 0`
- While the detail is open, pause all motion.
- Wall `scale = 1 + .12·bow` (signed bow), 4 decimals.

Per card each frame:
- `repeat = round((H/2 − (baseY + scroll)) / loop)`; `y = baseY + repeat·loop + scroll` (each card wraps on its own; never rebuild the list)
- if `y + height < −280` or `y > H + 280` → opacity 0, skip the pose update
- else `cy = y + height/2`, `t = (cy − H/2) / (H/2)`, `amount = |bow|`, `dir = bow ≥ 0 ? 1 : −1`, `bend = t·amount·.36`, `curved = H/2 + (cy − H/2)·cos(|bend|)`, `z = −85·dir·amount·t²`, `rx = −dir·bend·26`
- `transform = translate3d(x, curved − height/2, z) rotateX(rx)` (x, y, rx to 2 decimals, z to 1), `z-index = round(2000 + z)`, opacity 1.

### Input
- Wheel: prevent default; if detail closed, `flick −= deltaY × .55`, `boost = 1`.
- Pointer down: `flick = 0`, store lastY, moved = 0, capture pointer. Move: `scroll += dy`, `flick = dy`, moved += |dy|. Up/cancel: if moved < 6, the card under the pointer (`elementFromPoint`) opens the detail.
- Keyboard: every card is a focusable button; Enter opens; arrow keys nudge `flick`. Detail blocks wheel and drag.

### Detail (replaces the study's camera data with a wall label)
Full-screen layer, z 200, background `#FAFAF8`.
- Desktop: media area left 49%, right 7%, top/bottom 9.5%, no radius/shadow, `object-fit: contain`, max-height 81vh. Video plays inline, 3D uses `<model-viewer>`, audio shows poster + player. Text column: left 4.5%, top 10%, bottom 6%, width 37%.
- Text: label (discipline · level) 10 px mono-style, .24em, opacity .5; **title** large lowercase Instrument Sans 600, `clamp(48px, 7.4vw, 108px)`, line-height .84, margin 24px 0; artist name; statement 12 px, max 40ch, line-height 1.6, opacity .62. Bottom: thin top rule, two columns, gap 12: medium · dimensions/duration · year · formats. Buttons: view portfolio (ink), save, partners: shortlist. Close button: 40 px circle at top 26 / right 24.
- Mobile (≤ 767): media left/right 20, top 60, bottom 48%, max-height 44vh; text left 24, top 55%, bottom 24, width `calc(100% − 48px)`, scrollable, padding-bottom 85; title 46 px, margin 15; statement 11 px; label 8 px.
- Open: scrim opacity 0→1 (.3s); media opacity 0 / scale .94 → 1 / 1 (.6s, power3.out); text children opacity 0 / y 16 → 1 / 0, delay .1, duration .5, stagger .08, power3.out. Close (button, backdrop, Escape): whole layer opacity → 0 in .28s, then `display: none`, clear inline opacity, resume the wall. No duplicate timelines, no re-entrant close. Opening updates the URL (`/work/[id]`) so details are shareable; back button closes.
- Intro: after the first works load, GSAP `fromTo` all cards opacity 0 / y 60 → 1 / 0, duration 1, stagger .03, power3.out; `gsap.ticker.lagSmoothing(0)`.

### Reduced motion
With `prefers-reduced-motion: reduce`: no drift, no bow, no intro; the wall is a static, normally scrollable grid with the same layout; detail opens with a plain fade. Same with JavaScript disabled: render a plain accessible grid server-side.

### Acceptance (Playwright, 1440×1000 and 390×844)
Initial state after 2800 ms; bend 180 ms after a 240 px wheel; flat again 1800 ms later; drag up; click opens the right work with the right label; Escape closes; reduced-motion shows a still grid; filter change re-lays out without duplicate cards; no console errors; 60 fps target on a mid-range phone with 40 works (lazy-load images, use posters for video, never autoplay video on the wall).

---

## 8. Phases

Stop after each phase, open a PR, and list what was verified on the Vercel preview.

0. **Setup** — Next.js app, Tailwind tokens, fonts, i18n (pt/en), Supabase project + Vercel integration, CI (lint, typecheck, Playwright), `docs/design/` folder.
1. **Data + auth + roles** — schema, enums, RLS with tests, magic-link auth, university-domain check for students, partner sign-up with pending approval, admin approval screen, seed script with labeled demo data.
2. **Works** — add work (multi-format upload), work detail, profile/portfolio, visibility rules, alt text and consent fields.
3. **The wall** — Aperture (section 7), filters (type of art → file), reduced-motion fallback, acceptance tests.
4. **Opportunities** — list, filters, partner posting, apply with selected works, applicant review, shortlist, recommendations, contract summary + PDF from template, *signature as a stub* ("sign with Chave Móvel Digital — coming soon"), ato isolado helper.
5. **Projects & materials** — open calls, project space, materials board, matching needs to materials, leftovers back to the board.
6. **Polish** — role homes, messages with contact rules, notifications (email), PDF portfolio export, analytics without personal data, optional *Enter gallery* mode.

---

## 9. What needs a human (ask, don't invent)
- ULisboa student and staff email domains.
- Faculty approval to use its logo and name publicly (the prototype uses them for the pitch only).
- Lawyer review of contract templates; choice of e-signature provider.
- Real works and consent from students.
- Who in the faculty acts as admin (careers office).
