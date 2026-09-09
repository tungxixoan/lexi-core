// 1:1 port of lib/features/knowledge/domain/entities/knowledge_group.dart.
// The `id` strings and labels (incl. CJK annotations) MUST match the Dart
// source byte-for-byte — a note filed under `zh_ba` on Flutter must open
// under `zh_ba` here.
import type { TargetLanguage } from "./languages";

export interface KnowledgeGroup {
  id: string;
  label: string;
}

const EN: KnowledgeGroup[] = [
  { id: "en_tenses", label: "Thì" },
  { id: "en_conditionals", label: "Câu điều kiện" },
  { id: "en_relative_clauses", label: "Mệnh đề quan hệ" },
  { id: "en_passive", label: "Câu bị động" },
  { id: "en_reported_speech", label: "Câu tường thuật" },
  { id: "en_modals", label: "Động từ khuyết thiếu" },
  { id: "en_gerunds_infinitives", label: "Danh động từ & Nguyên mẫu" },
  { id: "en_articles_nouns", label: "Mạo từ & Danh từ" },
  { id: "en_prepositions", label: "Giới từ" },
  { id: "en_conjunctions_linking", label: "Liên từ & Nối câu" },
  { id: "en_spoken_structures", label: "Cấu trúc nói thông dụng" },
  { id: "en_other", label: "Khác" },
];

const ZH: KnowledgeGroup[] = [
  { id: "zh_aspect_particles", label: "Thể & Trợ từ động thái (了/着/过)" },
  { id: "zh_complements", label: "Bổ ngữ (kết quả/xu hướng/khả năng/mức độ)" },
  { id: "zh_ba", label: "Câu chữ 把" },
  { id: "zh_bei", label: "Câu chữ 被 (bị động)" },
  { id: "zh_measure_words", label: "Lượng từ" },
  { id: "zh_modal_particles", label: "Trợ từ ngữ khí (吗/呢/吧/啊)" },
  { id: "zh_comparison", label: "Cấu trúc so sánh (比/没有/一样)" },
  { id: "zh_conjunctions", label: "Liên từ & Phức câu" },
  { id: "zh_word_order", label: "Trật tự từ & Trạng ngữ" },
  { id: "zh_spoken_structures", label: "Cấu trúc nói thông dụng" },
  { id: "zh_other", label: "Khác" },
];

const KO: KnowledgeGroup[] = [
  { id: "ko_particles", label: "Trợ từ (조사)" },
  { id: "ko_endings_honorifics", label: "Đuôi câu & Kính ngữ (존댓말/반말)" },
  { id: "ko_tense_aspect", label: "Thì & Thể" },
  { id: "ko_clause_connectors", label: "Liên kết vế câu (연결어미)" },
  { id: "ko_modifiers", label: "Định ngữ (관형사형)" },
  { id: "ko_grammar_patterns", label: "Mẫu ngữ pháp thông dụng" },
  { id: "ko_irregulars", label: "Bất quy tắc (불규칙 활용)" },
  { id: "ko_spoken_structures", label: "Cấu trúc nói thông dụng" },
  { id: "ko_other", label: "Khác" },
];

const JA: KnowledgeGroup[] = [
  { id: "ja_particles", label: "Trợ từ (助詞)" },
  { id: "ja_verb_forms", label: "Chia động từ (辞書形/て形/た形…)" },
  { id: "ja_politeness_keigo", label: "Thể lịch sự & Kính ngữ (敬語)" },
  { id: "ja_tense_aspect", label: "Thì & Thể" },
  { id: "ja_connectors", label: "Liên kết câu (接続)" },
  { id: "ja_grammar_patterns", label: "Mẫu ngữ pháp (文型)" },
  { id: "ja_voice", label: "Khả năng / Bị động / Sai khiến" },
  { id: "ja_spoken_structures", label: "Cấu trúc nói thông dụng" },
  { id: "ja_other", label: "Khác" },
];

const VI: KnowledgeGroup[] = [
  { id: "vi_sentence_structure", label: "Cấu trúc câu" },
  { id: "vi_word_classes", label: "Từ loại & chức năng" },
  { id: "vi_linking", label: "Liên kết câu" },
  { id: "vi_spoken_structures", label: "Cấu trúc nói thông dụng" },
  { id: "vi_other", label: "Khác" },
];

const BY_LANGUAGE: Record<TargetLanguage, KnowledgeGroup[]> = {
  english: EN,
  chinese: ZH,
  korean: KO,
  japanese: JA,
  vietnamese: VI,
};

export function knowledgeGroupsFor(language: TargetLanguage): readonly KnowledgeGroup[] {
  return BY_LANGUAGE[language];
}

const LABEL_BY_ID: Map<string, string> = new Map(
  [...EN, ...ZH, ...KO, ...JA, ...VI].map((g) => [g.id, g.label] as const),
);

export function knowledgeGroupLabel(groupId: string): string {
  return LABEL_BY_ID.get(groupId) ?? groupId;
}

export function knowledgeOtherGroupId(language: TargetLanguage): string {
  const groups = knowledgeGroupsFor(language);
  return groups[groups.length - 1].id;
}
