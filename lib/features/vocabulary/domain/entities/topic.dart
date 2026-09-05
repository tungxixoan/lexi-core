final class Topic {
  const Topic({
    required this.id,
    required this.name,
    required this.emoji,
    required this.isPredefined,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String emoji;
  final bool isPredefined;
  final DateTime createdAt;

  Topic copyWith({String? name, String? emoji}) => Topic(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        isPredefined: isPredefined,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'isPredefined': isPredefined,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: json['id'] as String,
        name: json['name'] as String,
        emoji: json['emoji'] as String? ?? '📌',
        isPredefined: json['isPredefined'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  static final predefined = <Topic>[
    Topic(
        id: 'daily-life',
        name: 'Daily Life',
        emoji: '🏠',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'travel',
        name: 'Travel',
        emoji: '✈️',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'food-drink',
        name: 'Food & Drink',
        emoji: '🍜',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'business',
        name: 'Business',
        emoji: '💼',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'technology',
        name: 'Technology',
        emoji: '💻',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'health',
        name: 'Health',
        emoji: '🏥',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'education',
        name: 'Education',
        emoji: '📚',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'entertainment',
        name: 'Entertainment',
        emoji: '🎭',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'nature',
        name: 'Nature',
        emoji: '🌿',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'emotion',
        name: 'Emotion',
        emoji: '💭',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'academic',
        name: 'Academic',
        emoji: '🎓',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'idioms',
        name: 'Idioms',
        emoji: '💬',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'phrasal-verbs',
        name: 'Phrasal Verbs',
        emoji: '🔗',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'slang',
        name: 'Slang',
        emoji: '😎',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'social',
        name: 'Social/Casual',
        emoji: '🗣️',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'sports',
        name: 'Sports',
        emoji: '⚽',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'art-culture',
        name: 'Art & Culture',
        emoji: '🎨',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'science',
        name: 'Science',
        emoji: '🔬',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'law-politics',
        name: 'Law & Politics',
        emoji: '⚖️',
        isPredefined: true,
        createdAt: DateTime(2026)),
    Topic(
        id: 'other',
        name: 'Other',
        emoji: '📌',
        isPredefined: true,
        createdAt: DateTime(2026)),
  ];
}
