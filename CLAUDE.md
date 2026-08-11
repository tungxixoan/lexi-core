# LexiCore — repo orientation

Personal Vietnamese-first language-learning app. Full feature list lives in `README.md` (kept current — trust it over anything below for "what features exist"). Detailed feature/architecture history lives in `docs/superpowers/specs/*.md` (one file per feature/initiative) and `.superpowers/sdd/progress.md`.

## Monorepo structure (as of 2026-08-11)

This is one GitHub repo hosting two apps:

- **Flutter app** (mobile + legacy web) — repo root: `lib/`, `pubspec.yaml`, `android/`, `ios/`, `web/`. Unchanged by the React redesign; still the only client for the mobile app indefinitely.
- **React web app** (new, replaces Flutter Web) — `apps/web/` (Next.js, deployed on Vercel with Root Directory set to `apps/web/`).

**Naming gotcha — do not confuse these two:**
- `web/` (top-level, no `apps/` prefix) is Flutter's own web-platform scaffold — `index.html`, `manifest.json`, icons. `flutter build web` compiles from `lib/` + this folder into `build/web`, which `firebase.json`'s `hosting.public` points at. **Never put the Next.js app here.**
- `apps/web/` is the Next.js app. Its `node_modules`/`.next` are gitignored.

Both Firebase Hosting (Flutter Web) and Vercel (Next.js) deploy from this same repo and coexist during the migration — see `docs/superpowers/specs/2026-08-11-react-web-redesign-design.md` §3.6 for the rollout plan. Firebase Web stays live until the Next.js app has been tested and the production domain is deliberately cut over; don't touch that cutover without explicit confirmation.

## Backend/data decisions (see the spec above for full reasoning)

- **Database stays Firebase** (Firestore + Auth) for both apps — Supabase was evaluated and deliberately deferred, not adopted.
- AI calls (LLM prompts, TTS, future STT) move server-side for the web app via Vercel serverless functions, but stay **BYOK**: the user's own provider API key is never stored server-side or in the DB — sent per-request via header, used in-memory, never logged.

## Workflow

Development follows the superpowers SDD flow: spec (`docs/superpowers/specs/`) → plan (`docs/superpowers/plans/`) → task-by-task subagent implementation → whole-branch review. When starting new feature work, invoke the `brainstorming` skill first, not straight to code.

## Deploy

- **Flutter Web:** `flutter build web --release` then `firebase deploy --only hosting` (from repo root).
- **Next.js web app:** push to the connected branch; Vercel auto-deploys `apps/web/`. Production cutover is a manual, explicit step — not automatic on merge.
