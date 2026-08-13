# LexiCore — repo orientation

Personal Vietnamese-first language-learning app. Full feature list lives in `README.md` (kept current — trust it over anything below for "what features exist"). Detailed feature/architecture history lives in `docs/superpowers/specs/*.md` (one file per feature/initiative) and `.superpowers/sdd/progress.md`.

## Monorepo structure (as of 2026-08-11)

This is one GitHub repo hosting two apps:

- **Flutter app** (mobile + legacy web) — repo root: `lib/`, `pubspec.yaml`, `android/`, `ios/`, `web/`. Unchanged by the React redesign; still the only client for the mobile app indefinitely.
- **React web app** (new, replaces Flutter Web) — `apps/web/` (Next.js, deployed on **Firebase App Hosting**, backend id `lexicore-web`). Config lives in `firebase.json`'s `"apphosting"` block (`backendId`/`rootDir`) plus `apps/web/apphosting.yaml` (Cloud Run `runConfig` + `env:` list — non-secret env vars like Firebase Web config are committed there directly). Not Vercel — considered, then dropped mid-spec-review once the backend's role shrank to thin proxies that Cloud Functions does natively (see spec §3.1 for the full reasoning/trade-off).
- **Backend functions** — `functions/` (Firebase CLI convention, Node.js/TypeScript), a third sibling directory alongside `web/` and `apps/web/`. Deployed with `firebase deploy --only functions` (manual CLI push, same pattern as Flutter Web's deploy — not git-triggered auto-deploy). Test locally first with the Firebase Local Emulator Suite (`firebase emulators:start`).
- **Region: `asia-southeast1`** (Singapore) for both App Hosting and every Cloud Function (`onCall({region: "asia-southeast1"}, handler)`) — not the Firebase default `us-central1`. Chosen for Vietnam latency (~30-50ms vs ~200-250ms RTT). Client and server must agree on region or `httpsCallable` silently targets the wrong endpoint — `apps/web/src/lib/firebase.ts`'s `getFunctions(app, "asia-southeast1")` call must stay in sync with every `onCall(...)` in `functions/src/`.

**Naming gotcha — do not confuse these two:**
- `web/` (top-level, no `apps/` prefix) is Flutter's own web-platform scaffold — `index.html`, `manifest.json`, icons. `flutter build web` compiles from `lib/` + this folder into `build/web`, which `firebase.json`'s `hosting.public` points at. **Never put the Next.js app here.**
- `apps/web/` is the Next.js app. Its `node_modules`/`.next` are gitignored.

Both classic Firebase Hosting (Flutter Web, `build/web`) and Firebase App Hosting (Next.js, `apps/web/`) are Firebase Hosting-family products deploying from this same repo/Firebase project, and coexist during the migration — see `docs/superpowers/specs/2026-08-11-react-web-redesign-design.md` §3.6 for the rollout plan. Firebase Web stays live until the Next.js app has been tested and the production domain is deliberately cut over; don't touch that cutover without explicit confirmation.

## Backend/data decisions (see the spec above for full reasoning)

- **Everything lives in Firebase/Google Cloud** — one platform, not split across Firebase + Vercel. Database, hosting, and the AI-proxy backend are all Firebase/GCP products in the same project.
- **Database stays Firebase** (Firestore + Auth) for both apps — Supabase was evaluated and deliberately deferred, not adopted.
- **Backend = Cloud Functions for Firebase (2nd gen)**, scope limited to AI-proxy endpoints only (LLM, TTS, STT) — not a general data proxy. Firestore/Auth happen client-side via the JS SDK, same trust model as Flutter Web, existing security rules unchanged.
- Every AI-proxy function is an **`onCall`** function, which auto-verifies the caller's Firebase ID token — stops strangers from burning Cloud Functions quota, not AI spend (they'd still need their own BYOK key for that).
- **LLM calls** stay **BYOK**: the user's own provider API key is never stored server-side or in the DB — sent per-call, used in-memory, never logged.
- **TTS/STT use self-hosted open-source models** (Piper for TTS, faster-whisper for STT — not a paid third-party API), packaged in a Docker container on **Google Cloud Run** (free tier, scale-to-zero), called by the Cloud Functions proxy via same-project IAM (no public ingress, no hand-rolled shared secret). A separate deployable unit from the Next.js app/functions.
- **Pronunciation TTS (dictionary/vocab-example audio) is cached as real audio files** in Firebase Storage (= Google Cloud Storage, same category as S3/Azure Blob), keyed by `sha256(text+lang+voice)`, **shared across all users** — the first lookup of a word generates the file, everyone after that hits the same cached file, Cloud Run isn't called again for it. Nghe (Listening) audio is never cached — it's freshly AI-generated per session and always calls Cloud Run live.

## Deploy gotchas (learned the hard way during Plan 1)

- **Cloud Functions 2nd gen and Cloud Run both require the Blaze (pay-as-you-go) plan** — not available on the free Spark plan, even though usage stays within Blaze's free tier for a project this size. Upgrade at `https://console.firebase.google.com/project/lexi-core/usage/details` before the first `firebase deploy --only functions`.
- **New domains need adding to Firebase Auth's Authorized domains** (Console → Authentication → Settings → Authorized domains) or `signInWithPopup` silently opens and closes the OAuth popup with no visible error. Every new App Hosting domain (preview or production) needs this.
- **Firebase App Hosting's Console-based GitHub deploy has its own "App root directory" setting, separate from `firebase.json`'s `apphosting.rootDir`.** The CLI's `firebase init apphosting` sets the latter; connecting GitHub for auto-deploy through the Console (Settings → Deployment) does not inherit it and defaults to `/` — must be corrected to `apps/web` manually in the Console the first time.

## Workflow

Development follows the superpowers SDD flow: spec (`docs/superpowers/specs/`) → plan (`docs/superpowers/plans/`) → task-by-task subagent implementation → whole-branch review. When starting new feature work, invoke the `brainstorming` skill first, not straight to code.

## Deploy

- **Flutter Web:** `flutter build web --release` then `firebase deploy --only hosting` (from repo root).
- **Next.js web app:** push to the connected branch; Firebase App Hosting auto-deploys `apps/web/`. Production cutover is a manual, explicit step — not automatic on merge.
- **Cloud Functions:** test locally with `firebase emulators:start`, then `firebase deploy --only functions` — manual CLI push, not auto-deployed on git push (unless a CI workflow is added later).
