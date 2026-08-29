import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/hive_migration_service.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../providers/auth_notifier.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

enum _Step { idle, signingIn, migrating }

class _SignInScreenState extends ConsumerState<SignInScreen> {
  _Step _step = _Step.idle;
  String? _signInError;
  String? _migrationError;

  Future<void> _signIn() async {
    setState(() {
      _step = _Step.signingIn;
      _signInError = null;
      _migrationError = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.idle;
          _signInError = 'Đăng nhập thất bại. Thử lại.';
        });
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Sign-in flow completed without an authenticated user (e.g. the
      // user dismissed the Google account picker) — quietly return to the
      // idle state, no error message needed for a user-initiated cancel.
      if (mounted) setState(() => _step = _Step.idle);
      return;
    }

    if (mounted) setState(() => _step = _Step.migrating);
    try {
      final migration = HiveMigrationService();
      await migration.migrateIfNeeded(user.uid);
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.idle;
          _migrationError =
              'Không thể chuyển dữ liệu từ vựng cũ lên máy chủ. Vui lòng thử lại.';
        });
      }
      return;
    }

    if (!mounted) return;

    // Best-effort: AiSettingsSyncService.bootstrapSync never throws (see its
    // class doc), so this deliberately has no try/catch and never blocks
    // navigation the way the Hive migration above does.
    await ref.read(aiSettingsSyncServiceProvider).bootstrapSync(
          user.uid,
          ref.read(userSettingsNotifierProvider.notifier),
        );

    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final loading = _step != _Step.idle;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'LexiCore',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _step == _Step.migrating
                    ? 'Đang chuyển dữ liệu từ vựng cũ…'
                    : 'Đăng nhập để tiếp tục',
              ),
              const SizedBox(height: 24),
              if (loading)
                const CircularProgressIndicator()
              else
                FilledButton.icon(
                  onPressed: _signIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Đăng nhập với Google'),
                ),
              if (_signInError != null) ...[
                const SizedBox(height: 12),
                Text(_signInError!, style: const TextStyle(color: Colors.red)),
              ],
              if (_migrationError != null) ...[
                const SizedBox(height: 12),
                Text(_migrationError!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _signIn,
                  child: const Text('Thử lại'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
