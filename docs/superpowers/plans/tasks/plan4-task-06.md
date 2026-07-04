# Plan 4 — Task 06: AuthNotifier (Google Sign-In)

**Plan file:** `docs/superpowers/plans/2026-07-02-plan4-firebase-settings-practice-filter.md`
**Global constraints:** `docs/superpowers/plans/tasks/plan4-global-constraints.md`
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 01 (Firebase packages installed + `firebase_options.dart` generated)

## What this task builds

A `@Riverpod(keepAlive: true)` stream-based notifier that wraps `FirebaseAuth.authStateChanges()`. Exposes `signInWithGoogle()` and `signOut()` methods. State is `AsyncValue<User?>` — `null` when signed out, `User` when signed in.

No unit tests — thin wrapper around Firebase SDK (testing requires Firebase emulator, out of scope for v1).

## Files

- Create: `lib/features/settings/presentation/providers/auth_notifier.dart`
- Generated: `lib/features/settings/presentation/providers/auth_notifier.g.dart`

## Interfaces consumed

```dart
// firebase_auth: FirebaseAuth.instance.authStateChanges()
// firebase_auth: FirebaseAuth.instance.signInWithCredential(credential)
// firebase_auth: FirebaseAuth.instance.signOut()
// google_sign_in: GoogleSignIn().signIn() → GoogleSignInAccount?
// google_sign_in: GoogleSignIn().signOut()
// firebase_auth: GoogleAuthProvider.credential(accessToken, idToken)
// firebase_auth: User — has .uid, .displayName, .email, .photoURL
```

## Interfaces produced

```dart
// authNotifierProvider: StreamNotifierProvider<AuthNotifier, User?>
// AsyncValue<User?> state — consumers use:
//   ref.watch(authNotifierProvider).valueOrNull → User? (null when signed out or loading)
//   ref.watch(authNotifierProvider).when(data: ..., loading: ..., error: ...)

class AuthNotifier extends _$AuthNotifier {
  Stream<User?> build();               // returns FirebaseAuth.instance.authStateChanges()
  Future<void> signInWithGoogle();     // opens Google OAuth picker, signs in to Firebase
  Future<void> signOut();              // signs out of both GoogleSignIn and FirebaseAuth
}
```

---

- [ ] **Step 1: Create the providers directory if needed**

```
lib/features/settings/presentation/providers/
```

This directory was created in Task 05 (`settings_screen.dart`). It may or may not exist yet. Create it if absent — just add the file; Dart doesn't need empty directories.

- [ ] **Step 2: Create AuthNotifier**

Create `lib/features/settings/presentation/providers/auth_notifier.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  Stream<User?> build() => FirebaseAuth.instance.authStateChanges();

  Future<void> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return; // user cancelled the picker
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
    // FirebaseAuth.authStateChanges() emits the new User automatically
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }
}
```

- [ ] **Step 3: Run build_runner**

```
dart run build_runner build --delete-conflicting-outputs
```

Expected: `auth_notifier.g.dart` generated.

- [ ] **Step 4: Analyze**

```
flutter analyze lib/features/settings/presentation/providers/auth_notifier.dart
```

Expected: no errors.

- [ ] **Step 5: Run tests**

```
flutter test
```

Expected: all prior tests still pass.

- [ ] **Step 6: Commit**

```
git add lib/features/settings/presentation/providers/auth_notifier.dart lib/features/settings/presentation/providers/auth_notifier.g.dart
git commit -m "feat(plan4): add AuthNotifier with Google Sign-In"
```

## Self-review checklist

- [ ] `@Riverpod(keepAlive: true)` — NOT `@riverpod` (must survive navigation)
- [ ] `build()` returns `Stream<User?>` — this makes it a `StreamNotifier`, not a plain `Notifier`
- [ ] `signInWithGoogle()` returns early (not throws) when user cancels (googleUser == null)
- [ ] `signOut()` calls both `GoogleSignIn().signOut()` AND `FirebaseAuth.instance.signOut()`
- [ ] Error from `signInWithCredential` is NOT caught here — callers (SettingsScreen) catch and show SnackBar
- [ ] `flutter analyze` clean
