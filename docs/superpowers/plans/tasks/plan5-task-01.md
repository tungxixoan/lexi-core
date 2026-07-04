# Plan 5 — Task 01: Packages + Platform Config + Timezone Init

**Context:** First task of Plan 5 (Daily Review + Progress Dashboard). No prior Plan 5 tasks exist yet. See `plan5-global-constraints.md` for project-wide rules.

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/main.dart`

**Interfaces:**
- Produces: `flutter_local_notifications` and `timezone` available to all later tasks; `tz.initializeTimeZones()` called before `runApp`

---

- [ ] **Step 1: Add packages to pubspec.yaml**

Open `pubspec.yaml`. Under `dependencies:` (after `google_sign_in`), add:
```yaml
  flutter_local_notifications: ^17.0.0
  timezone: ^0.9.4
```

- [ ] **Step 2: Run flutter pub get**

```
flutter pub get
```

Expected: resolves without conflicts.

- [ ] **Step 3: Update AndroidManifest.xml**

Open `android/app/src/main/AndroidManifest.xml`.

Add 3 permission lines inside `<manifest>` (before `<application>`):
```xml
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Add 2 receivers inside `<application>` (after the `<meta-data android:name="flutterEmbedding".../>` tag):
```xml
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            </intent-filter>
        </receiver>
```

- [ ] **Step 4: Update main.dart**

Add import at top of `lib/main.dart`:
```dart
import 'package:timezone/data/latest.dart' as tz;
```

Add `tz.initializeTimeZones();` as the **first line** inside `main()` (before `WidgetsFlutterBinding.ensureInitialized()`).

Full updated `main()`:
```dart
void main() async {
  tz.initializeTimeZones();
  WidgetsFlutterBinding.ensureInitialized();
  // TODO(plan4-task-01): Uncomment once firebase_options.dart is generated:
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await Hive.openBox<String>('vocab_records');
  await Hive.openBox<String>('topics');
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const LexiCoreApp(),
  ));
}
```

- [ ] **Step 5: Run flutter analyze**

```
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 6: Run full test suite**

```
flutter test
```

Expected: all existing tests pass (currently 66 tests).

- [ ] **Step 7: Commit**

```
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml lib/main.dart
git commit -m "chore(plan5): add flutter_local_notifications + timezone packages and platform config"
```

**Report status:** DONE
