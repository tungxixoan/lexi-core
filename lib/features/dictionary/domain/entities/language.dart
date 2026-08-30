// lib/features/dictionary/domain/entities/language.dart
enum Language {
  vietnamese,
  english,
  chinese,
  korean,
  japanese;

  String get code => switch (this) {
        Language.vietnamese => 'vi',
        Language.english => 'en',
        Language.chinese => 'zh',
        Language.korean => 'ko',
        Language.japanese => 'ja',
      };

  String get label => switch (this) {
        Language.vietnamese => 'Tiếng Việt',
        Language.english => 'English',
        Language.chinese => '中文',
        Language.korean => '한국어',
        Language.japanese => '日本語',
      };

  bool get requiresAi => this != Language.english;

  /// Matches apps/web/src/lib/pronunciation.ts's ttsLanguageCode() — the
  /// self-hosted Piper TTS service only has voices deployed for Vietnamese
  /// and English; null means no server-side pronunciation/audio is
  /// available for this target language.
  String? get ttsCloudCode => switch (this) {
        Language.vietnamese => 'vi',
        Language.english => 'en',
        _ => null,
      };
}
