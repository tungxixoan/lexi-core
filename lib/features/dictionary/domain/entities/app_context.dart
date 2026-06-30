// lib/features/dictionary/domain/entities/app_context.dart
enum AppContext {
  general,
  business,
  technology,
  travel,
  foodAndDrink,
  health,
  academic,
  socialCasual;

  String get label => switch (this) {
        AppContext.general => 'General',
        AppContext.business => 'Business',
        AppContext.technology => 'Technology',
        AppContext.travel => 'Travel',
        AppContext.foodAndDrink => 'Food & Drink',
        AppContext.health => 'Health',
        AppContext.academic => 'Academic',
        AppContext.socialCasual => 'Social/Casual',
      };

  String get emoji => switch (this) {
        AppContext.general => '🌐',
        AppContext.business => '💼',
        AppContext.technology => '💻',
        AppContext.travel => '✈️',
        AppContext.foodAndDrink => '🍜',
        AppContext.health => '🏥',
        AppContext.academic => '📚',
        AppContext.socialCasual => '💬',
      };
}
