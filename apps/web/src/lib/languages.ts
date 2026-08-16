export type TargetLanguage = "vietnamese" | "english" | "chinese" | "korean" | "japanese";

// Mirrors lib/features/dictionary/domain/entities/language.dart's
// Language.label — kept in sync manually (no shared-types package).
export const LANGUAGE_LABELS: Record<TargetLanguage, string> = {
  vietnamese: "Tiếng Việt",
  english: "English",
  chinese: "中文",
  korean: "한국어",
  japanese: "日本語",
};
