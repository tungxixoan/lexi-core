export type AppContext =
  | "general"
  | "business"
  | "technology"
  | "travel"
  | "foodAndDrink"
  | "health"
  | "academic"
  | "socialCasual";

export const APP_CONTEXTS: AppContext[] = [
  "general",
  "business",
  "technology",
  "travel",
  "foodAndDrink",
  "health",
  "academic",
  "socialCasual",
];

// Mirrors lib/features/dictionary/domain/entities/app_context.dart's
// AppContextX.label/.emoji — kept in sync manually (no shared-types
// package between the Flutter and web apps).
export const APP_CONTEXT_LABELS: Record<AppContext, string> = {
  general: "General",
  business: "Business",
  technology: "Technology",
  travel: "Travel",
  foodAndDrink: "Food & Drink",
  health: "Health",
  academic: "Academic",
  socialCasual: "Social/Casual",
};

export const APP_CONTEXT_EMOJI: Record<AppContext, string> = {
  general: "🌐",
  business: "💼",
  technology: "💻",
  travel: "✈️",
  foodAndDrink: "🍜",
  health: "🏥",
  academic: "📚",
  socialCasual: "💬",
};
