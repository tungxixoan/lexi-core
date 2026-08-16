import { describe, expect, it } from "vitest";
import { LANGUAGE_LABELS } from "./languages";

describe("LANGUAGE_LABELS", () => {
  it("has a native-script label for all 5 supported target languages, matching the Flutter app's Language enum", () => {
    expect(LANGUAGE_LABELS).toEqual({
      vietnamese: "Tiếng Việt",
      english: "English",
      chinese: "中文",
      korean: "한국어",
      japanese: "日本語",
    });
  });
});
