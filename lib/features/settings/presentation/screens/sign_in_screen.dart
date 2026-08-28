import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../../core/services/hive_migration_service.dart';
import '../providers/auth_notifier.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      final user = ref.read(authNotifierProvider).valueOrNull;
      if (user != null) {
        final migration = HiveMigrationService(
          vocabBox: Hive.box<String>('vocab_records'),
          topicsBox: Hive.box<String>('topics'),
        );
        await migration.migrateIfNeeded(user.uid);
      }
      // On success, the router's redirect (driven by authNotifierProvider's
      // stream) automatically navigates away from this screen — no
      // explicit navigation call needed here.
    } catch (e) {
      if (mounted) setState(() => _error = 'Đăng nhập thất bại. Thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Text('Đăng nhập để tiếp tục'),
              const SizedBox(height: 24),
              if (_loading)
                const CircularProgressIndicator()
              else
                FilledButton.icon(
                  onPressed: _signIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Đăng nhập với Google'),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
