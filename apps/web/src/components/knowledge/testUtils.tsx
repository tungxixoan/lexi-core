import { render } from "@testing-library/react";
import type { ReactElement } from "react";
import { vi } from "vitest";
import { useAuthUser } from "@/lib/useAuthUser";
import { useSettingsContext } from "@/lib/SettingsContext";
import { getKnowledgeNotes, type KnowledgeNote } from "@/lib/knowledgeNotes";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { DEFAULT_SETTINGS } from "@/lib/settings";

/**
 * A `KnowledgeNote` with sensible defaults, overridable per test. Mirrors the
 * shape `parseKnowledgeNote` produces.
 */
export function noteFixture(overrides: Partial<KnowledgeNote> = {}): KnowledgeNote {
  return {
    id: "n1",
    title: "Câu điều kiện loại 2",
    summary: "Dùng cho tình huống giả định ở hiện tại.",
    explanation: "Nếu ... thì ...",
    patterns: [],
    examples: [],
    pitfalls: [],
    groupId: "en_conditionals",
    tags: [],
    cefrLevel: "b1",
    targetLanguage: "english",
    source: "manual",
    sourcePrompt: null,
    createdAt: "2026-01-01T00:00:00.000Z",
    updatedAt: "2026-01-01T00:00:00.000Z",
    ...overrides,
  };
}

interface RenderKnowledgePageOptions {
  notes?: KnowledgeNote[];
  records?: VocabRecord[];
  signedIn?: boolean;
}

/**
 * Renders a knowledge page under the standard signed-in-with-settings mocks.
 * The consuming test file must declare its own `vi.mock(...)` for
 * `@/lib/useAuthUser`, `@/lib/SettingsContext`, `@/lib/knowledgeNotes`, and
 * `@/lib/vocabRecords` (module mocking is per test file) — this helper only
 * configures the return values.
 */
export function renderKnowledgePage(ui: ReactElement, options: RenderKnowledgePageOptions = {}) {
  const { notes = [], records = [], signedIn = true } = options;

  vi.mocked(useAuthUser).mockReturnValue(
    signedIn
      ? ({ user: { uid: "u1" }, loading: false } as never)
      : ({ user: null, loading: false } as never),
  );
  vi.mocked(useSettingsContext).mockReturnValue({
    settings: signedIn ? DEFAULT_SETTINGS : null,
    loading: false,
    error: null,
    save: vi.fn(),
  } as never);
  vi.mocked(getKnowledgeNotes).mockResolvedValue(notes);
  vi.mocked(getVocabRecords).mockResolvedValue(records);

  return render(ui);
}
