export type ToeicContext =
  | "general"
  | "business"
  | "technology"
  | "travel"
  | "foodAndDrink"
  | "health"
  | "academic"
  | "socialCasual";

export const TOEIC_CONTEXTS: ToeicContext[] = [
  "general",
  "business",
  "technology",
  "travel",
  "foodAndDrink",
  "health",
  "academic",
  "socialCasual",
];

export const CONTEXT_LABELS: Record<ToeicContext, string> = {
  general: "Chung",
  business: "Kinh doanh",
  technology: "Công nghệ",
  travel: "Du lịch",
  foodAndDrink: "Ẩm thực",
  health: "Sức khỏe",
  academic: "Học thuật",
  socialCasual: "Xã hội / Đời thường",
};

export type EconomyVolume = "vol2" | "vol3" | "vol4" | "vol5";

export const ECONOMY_VOLUMES: EconomyVolume[] = ["vol2", "vol3", "vol4", "vol5"];

export const VOLUME_LABELS: Record<EconomyVolume, string> = {
  vol2: "Vol 2 (500–600+)",
  vol3: "Vol 3 (650–750+)",
  vol4: "Vol 4 (800–900+)",
  vol5: "Vol 5 (900+)",
};

// Fed into the AI prompt to calibrate question difficulty — ported verbatim
// from Flutter's EconomyVolume.promptHint. Deliberately English (it's model
// instruction text, not UI copy) and part-agnostic, shared by Part 6/7 too.
export const VOLUME_PROMPT_HINTS: Record<EconomyVolume, string> = {
  vol2: "easy-medium difficulty, standard trap depth, close to or slightly easier than the real exam",
  vol3: "medium-high difficulty, some advanced vocabulary, longer passages",
  vol4:
    "high difficulty, equal to or harder than the real exam, longer/more complex passages, unusual grammar/vocabulary traps",
  vol5: "very high difficulty, dense advanced vocabulary and the deepest grammar traps",
};
