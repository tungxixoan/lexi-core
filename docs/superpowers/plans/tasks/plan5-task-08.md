# Plan 5 — Task 08: SettingsScreen "Thông báo" Section

**Context:** Task 08 of Plan 5 (final task). Tasks 01–07 must be complete. See `plan5-global-constraints.md` for project-wide rules.

**Files:**
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`

**Interfaces:**
- Consumes:
  - `userSettingsNotifierProvider.reminderEnabled` (Task 02)
  - `userSettingsNotifierProvider.reminderHour` (Task 02)
  - `userSettingsNotifierProvider.reminderMinute` (Task 02)
  - `UserSettingsNotifier.setReminderEnabled()`, `setReminderHour()`, `setReminderMinute()` (Task 02)
- Produces: "Thông báo" section in SettingsScreen with toggle + conditional time picker tile

**UI behavior:**
- `SwitchListTile` for reminder toggle ("Nhắc nhở hàng ngày")
- When `reminderEnabled == true`: a `ListTile` with current time displayed in `HH:MM` format; tapping opens `showTimePicker`
- When `reminderEnabled == false`: time picker tile is hidden

---

- [ ] **Step 1: Read current SettingsScreen structure**

Read `lib/features/settings/presentation/screens/settings_screen.dart` to understand the existing section pattern (`_SectionHeader`, `SwitchListTile`, `ListTile` usage) before editing.

- [ ] **Step 2: Add "Thông báo" section**

In `lib/features/settings/presentation/screens/settings_screen.dart`, add the `UserSettingsState` import if not already present. The type is available via the `user_settings_provider.dart` import chain, but add the entity import explicitly if needed:

```dart
import '../../../../features/dictionary/domain/entities/user_settings_state.dart';
```

Inside the `ListView`'s `children` list (after the `'Học tập'` section, before the closing `]`), add:

```dart
          // ── Thông báo ─────────────────────────────────────────
          _SectionHeader('Thông báo'),
          SwitchListTile(
            title: const Text('Nhắc nhở hàng ngày'),
            subtitle: const Text('Thông báo khi có từ cần ôn'),
            value: settings.reminderEnabled,
            onChanged: (v) => notifier.setReminderEnabled(enabled: v),
          ),
          if (settings.reminderEnabled)
            ListTile(
              title: const Text('Giờ nhắc cố định'),
              trailing: Text(
                '${settings.reminderHour.toString().padLeft(2, '0')}:'
                '${settings.reminderMinute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              onTap: () => _showTimePicker(context, ref, settings),
            ),
```

- [ ] **Step 3: Add _showTimePicker method**

Add `_showTimePicker` as a method on the `SettingsScreen` widget class (it is a `ConsumerWidget`, so it is a regular instance method):

```dart
  Future<void> _showTimePicker(
      BuildContext context, WidgetRef ref, UserSettingsState settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: settings.reminderHour, minute: settings.reminderMinute),
    );
    if (picked == null) return;
    ref
        .read(userSettingsNotifierProvider.notifier)
        .setReminderHour(picked.hour);
    ref
        .read(userSettingsNotifierProvider.notifier)
        .setReminderMinute(picked.minute);
  }
```

- [ ] **Step 4: Run flutter analyze**

```
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 5: Run full suite**

```
flutter test
```

Expected: all tests pass (66+ tests, all green).

- [ ] **Step 6: Commit**

```
git add lib/features/settings/presentation/screens/settings_screen.dart
git commit -m "feat(plan5): add Thông báo section to SettingsScreen with reminder toggle and time picker"
```

**Report status:** DONE

---

## Plan 5 Complete

All 8 tasks done. Run final checks:

```
flutter analyze lib/
flutter test
```

Expected: clean analyze, all tests pass.
