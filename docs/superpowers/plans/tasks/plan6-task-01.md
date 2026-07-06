# Plan 6 — Task 01: Add Web Platform + Firebase Web Config

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plans 1–5 complete (mobile app running, Firebase configured for Android + iOS)

## Global Constraints
(see `plan6-global-constraints.md`)

## What This Task Delivers
Add the `web` platform to the existing Flutter project (creates the `web/` folder) and register a Firebase Web app so `firebase_options.dart` includes a web config.

## Files
- Create: `web/` (output of `flutter create --platforms web .`)
- Modify: `lib/firebase_options.dart` (output of `flutterfire configure`)

## Produces (used by Tasks 02–04)
- `web/index.html` — web entry point
- `DefaultFirebaseOptions.currentPlatform` — now resolves on `TargetPlatform.web` too

## Steps

- [ ] **Step 1: Add web platform via flutter create**

```bash
flutter create --platforms web .
```

Expected output: creates `web/` folder with `index.html`, `favicon.png`, `manifest.json`, `icons/`. The command prints something like:
```
Resolving dependencies...
...
  web/favicon.png (created)
  web/icons/Icon-192.png (created)
  web/icons/Icon-512.png (created)
  web/icons/Icon-maskable-192.png (created)
  web/icons/Icon-maskable-512.png (created)
  web/index.html (created)
  web/manifest.json (created)
```

- [ ] **Step 2: Register Firebase Web app**

Run flutterfire configure to add a web app to the existing Firebase project and update `firebase_options.dart`:

```bash
flutterfire configure --project=lexi-core --platforms=web --yes
```

Expected: updates `lib/firebase_options.dart` to add a `WebFirebaseOptions` block and the `web:` case in `DefaultFirebaseOptions.currentPlatform`.

If the command requires interactive input (e.g., "Select a Firebase Web app"), choose "Create a new Web app" and name it `lexi-core-web`. If `--yes` is not accepted, run without it and follow the prompts.

- [ ] **Step 3: Verify firebase_options.dart has web config**

After the command, open `lib/firebase_options.dart` and confirm it contains:

```dart
case TargetPlatform.linux:
  // or
TargetPlatform.windows when kIsWeb:
  // or similar
```

The exact guard depends on the flutterfire CLI version. Confirm there is a `WebFirebaseOptions` constant and that `currentPlatform` returns it when running on web.

- [ ] **Step 4: Analyze**

```bash
flutter analyze lib/firebase_options.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add web/ lib/firebase_options.dart
git commit -m "feat(plan6): add web platform + Firebase web config"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Build: flutter analyze output
Concerns: (if any — e.g., flutterfire prompts required, web app name chosen)
