import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/bloom/bloom.dart';
import '../di/app_providers.dart';
import '../../features/practice/domain/entities/saved_exercise.dart';
import '../../features/dictionary/domain/entities/language.dart';

/// "Lưu bài" — the block button on every AI result screen that persists the
/// just-finished exercise to Firestore so it can be re-drawn later. Owns the
/// whole `_saving` / `_savedId` state machine (three outcomes: saved,
/// signed-out, failed) so the five result screens don't each repeat it.
class SaveExerciseButton extends ConsumerStatefulWidget {
  const SaveExerciseButton({
    super.key,
    required this.type,
    required this.reusedFromId,
    required this.buildPassageJson,
    required this.generationFilters,
    required this.targetLanguage,
  });

  final SavedExerciseType type;

  /// Non-null when this exercise was itself loaded from a saved doc — the
  /// button renders as the "already saved" text and never calls save.
  final String? reusedFromId;

  /// Lazily builds the entity JSON (`() => result.set.toJson()`) — only called
  /// on tap, so a large `toJson` isn't run on every result-screen build.
  final Map<String, dynamic> Function() buildPassageJson;

  /// Already resolved by the caller (with its per-type fallback).
  final Map<String, dynamic> generationFilters;

  final Language targetLanguage;

  @override
  ConsumerState<SaveExerciseButton> createState() => _SaveExerciseButtonState();
}

class _SaveExerciseButtonState extends ConsumerState<SaveExerciseButton> {
  bool _saving = false;
  String? _savedId;

  @override
  void initState() {
    super.initState();
    _savedId = widget.reusedFromId;
  }

  @override
  Widget build(BuildContext context) {
    if (_savedId != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Đã lưu bài này',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.bloom.inkSoft, fontSize: 13),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BloomPillButton(
        label: _saving ? 'Đang lưu…' : 'Lưu bài',
        variant: BloomButtonVariant.secondary,
        block: true,
        onPressed: _saving ? null : _save,
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final id = await ref.read(savedExercisesServiceProvider).save(
            type: widget.type,
            passageJson: widget.buildPassageJson(),
            generationFilters: widget.generationFilters,
            targetLanguage: widget.targetLanguage,
          );
      if (!mounted) return;
      if (id == null) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa đăng nhập — không lưu được.')),
        );
        return;
      }
      setState(() {
        _savedId = id;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lưu bài thất bại. Thử lại sau.')),
      );
    }
  }
}
