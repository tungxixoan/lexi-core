import '../../../dictionary/domain/entities/language.dart';

class KnowledgeGroup {
  const KnowledgeGroup(this.id, this.label);
  final String id;
  final String label;
}

const _en = <KnowledgeGroup>[
  KnowledgeGroup('en_tenses', 'Thì'),
  KnowledgeGroup('en_conditionals', 'Câu điều kiện'),
  KnowledgeGroup('en_relative_clauses', 'Mệnh đề quan hệ'),
  KnowledgeGroup('en_passive', 'Câu bị động'),
  KnowledgeGroup('en_reported_speech', 'Câu tường thuật'),
  KnowledgeGroup('en_modals', 'Động từ khuyết thiếu'),
  KnowledgeGroup('en_gerunds_infinitives', 'Danh động từ & Nguyên mẫu'),
  KnowledgeGroup('en_articles_nouns', 'Mạo từ & Danh từ'),
  KnowledgeGroup('en_prepositions', 'Giới từ'),
  KnowledgeGroup('en_conjunctions_linking', 'Liên từ & Nối câu'),
  KnowledgeGroup('en_spoken_structures', 'Cấu trúc nói thông dụng'),
  KnowledgeGroup('en_other', 'Khác'),
];

const _zh = <KnowledgeGroup>[
  KnowledgeGroup('zh_aspect_particles', 'Thể & Trợ từ động thái (了/着/过)'),
  KnowledgeGroup('zh_complements', 'Bổ ngữ (kết quả/xu hướng/khả năng/mức độ)'),
  KnowledgeGroup('zh_ba', 'Câu chữ 把'),
  KnowledgeGroup('zh_bei', 'Câu chữ 被 (bị động)'),
  KnowledgeGroup('zh_measure_words', 'Lượng từ'),
  KnowledgeGroup('zh_modal_particles', 'Trợ từ ngữ khí (吗/呢/吧/啊)'),
  KnowledgeGroup('zh_comparison', 'Cấu trúc so sánh (比/没有/一样)'),
  KnowledgeGroup('zh_conjunctions', 'Liên từ & Phức câu'),
  KnowledgeGroup('zh_word_order', 'Trật tự từ & Trạng ngữ'),
  KnowledgeGroup('zh_spoken_structures', 'Cấu trúc nói thông dụng'),
  KnowledgeGroup('zh_other', 'Khác'),
];

const _ko = <KnowledgeGroup>[
  KnowledgeGroup('ko_particles', 'Trợ từ (조사)'),
  KnowledgeGroup('ko_endings_honorifics', 'Đuôi câu & Kính ngữ (존댓말/반말)'),
  KnowledgeGroup('ko_tense_aspect', 'Thì & Thể'),
  KnowledgeGroup('ko_clause_connectors', 'Liên kết vế câu (연결어미)'),
  KnowledgeGroup('ko_modifiers', 'Định ngữ (관형사형)'),
  KnowledgeGroup('ko_grammar_patterns', 'Mẫu ngữ pháp thông dụng'),
  KnowledgeGroup('ko_irregulars', 'Bất quy tắc (불규칙 활용)'),
  KnowledgeGroup('ko_spoken_structures', 'Cấu trúc nói thông dụng'),
  KnowledgeGroup('ko_other', 'Khác'),
];

const _ja = <KnowledgeGroup>[
  KnowledgeGroup('ja_particles', 'Trợ từ (助詞)'),
  KnowledgeGroup('ja_verb_forms', 'Chia động từ (辞書形/て形/た形…)'),
  KnowledgeGroup('ja_politeness_keigo', 'Thể lịch sự & Kính ngữ (敬語)'),
  KnowledgeGroup('ja_tense_aspect', 'Thì & Thể'),
  KnowledgeGroup('ja_connectors', 'Liên kết câu (接続)'),
  KnowledgeGroup('ja_grammar_patterns', 'Mẫu ngữ pháp (文型)'),
  KnowledgeGroup('ja_voice', 'Khả năng / Bị động / Sai khiến'),
  KnowledgeGroup('ja_spoken_structures', 'Cấu trúc nói thông dụng'),
  KnowledgeGroup('ja_other', 'Khác'),
];

const _vi = <KnowledgeGroup>[
  KnowledgeGroup('vi_sentence_structure', 'Cấu trúc câu'),
  KnowledgeGroup('vi_word_classes', 'Từ loại & chức năng'),
  KnowledgeGroup('vi_linking', 'Liên kết câu'),
  KnowledgeGroup('vi_spoken_structures', 'Cấu trúc nói thông dụng'),
  KnowledgeGroup('vi_other', 'Khác'),
];

List<KnowledgeGroup> knowledgeGroupsFor(Language language) => switch (language) {
      Language.english => _en,
      Language.chinese => _zh,
      Language.korean => _ko,
      Language.japanese => _ja,
      Language.vietnamese => _vi,
    };

final Map<String, String> _labelById = {
  for (final g in [..._en, ..._zh, ..._ko, ..._ja, ..._vi]) g.id: g.label,
};

String knowledgeGroupLabel(String groupId) => _labelById[groupId] ?? groupId;

String knowledgeOtherGroupId(Language language) =>
    knowledgeGroupsFor(language).last.id;
