"use client";

import { useState } from "react";
import { useSettingsContext } from "@/lib/SettingsContext";
import { generateContent } from "@/lib/generateContent";
import { parseAiJsonObject } from "@/lib/parseAiJson";
import {
  buildKnowledgeNotePrompt,
  parseKnowledgeNoteDraft,
  type KnowledgeNoteDraft,
} from "@/lib/knowledgeNoteSource";
import { findRelatedNotes } from "@/lib/knowledgeDedup";
import type { CefrLevel, KnowledgeNote } from "@/lib/knowledgeNotes";
import type { TargetLanguage } from "@/lib/languages";
import { knowledgeGroupsFor } from "@/lib/knowledgeGroups";
import { SimpleDropdown, type SimpleDropdownOption } from "@/components/shared/SimpleDropdown";
import { EditKnowledgeNoteModal } from "@/components/knowledge/EditKnowledgeNoteModal";
import { RelatedNotesBanner } from "@/components/knowledge/RelatedNotesBanner";

interface AiComposeModalProps {
  existingNotes: KnowledgeNote[];
  targetLanguage: TargetLanguage;
  onClose: () => void;
  onSaved: (note: KnowledgeNote) => Promise<void>;
}

interface Hints {
  groupId: string | null;
  cefr: CefrLevel | null;
}

interface GenerateOpts {
  extendingNote: KnowledgeNote | null;
  overwriteNoteId: string | null;
  // Only true for the very first ("Soạn") submission when Layer 1 found no
  // client-side match — a fresh attempt may still resolve as a Layer-2 (AI
  // flagged `relatedNoteId`) hit. Never true for a proceedNew/extend
  // regeneration, matching the task-13 brief.
  resolveLayer2: boolean;
}

// Every non-idle state carries the `request` (and hint) that produced it, so
// a regeneration triggered from ANY of these states (RelatedNotesBanner's
// onExtend/onProceedNew, or "Thử lại" after an error) always has the
// original request available — never a stale/empty closure capture. This is
// the exact bug the Flutter port of this flow had to fix in review.
type ComposeState =
  | { status: "idle"; request: string; hints: Hints }
  | { status: "loading" }
  | { status: "related"; request: string; hints: Hints; related: KnowledgeNote[] }
  | { status: "ready"; draft: KnowledgeNoteDraft; overwriteNoteId: string | null; sourcePrompt: string }
  | { status: "error"; request: string; hints: Hints; message: string };

const NO_CEFR = "";
const NO_GROUP = "";
const CEFR_LEVELS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];
const CEFR_OPTIONS: SimpleDropdownOption<string>[] = [
  { value: NO_CEFR, label: "Không đặt" },
  ...CEFR_LEVELS.map((level) => ({ value: level, label: level.toUpperCase() })),
];

export function AiComposeModal({ existingNotes, targetLanguage, onClose, onSaved }: AiComposeModalProps) {
  const { settings } = useSettingsContext();
  const [state, setState] = useState<ComposeState>({
    status: "idle",
    request: "",
    hints: { groupId: null, cefr: null },
  });

  if (!settings) return null;
  const provider = settings.activeProvider;
  const activeConfig = settings.providers[provider];
  const aiAvailable = Boolean(activeConfig.apiKeyCiphertext);

  const groupOptions: SimpleDropdownOption<string>[] = knowledgeGroupsFor(targetLanguage).map((g) => ({
    value: g.id,
    label: g.label,
  }));

  // Explicit params (never read from `state`) so the caller decides exactly
  // which request/hints/note this generation is for — see the ComposeState
  // comment above for why that matters.
  async function generate(request: string, hints: Hints, opts: GenerateOpts) {
    if (!activeConfig.apiKeyCiphertext) return;
    setState({ status: "loading" });
    try {
      const prompt = buildKnowledgeNotePrompt({
        request,
        targetLanguage,
        hintGroupId: hints.groupId,
        hintCefr: hints.cefr,
        existingInScope: existingNotes,
        extendingNote: opts.extendingNote,
      });
      const response = await generateContent({
        provider,
        model: activeConfig.model,
        apiKeyCiphertext: activeConfig.apiKeyCiphertext,
        prompt,
      });
      const json = parseAiJsonObject(response.text);
      const draft = parseKnowledgeNoteDraft(json, targetLanguage);
      if (opts.resolveLayer2 && draft.relatedNoteId) {
        const match = existingNotes.find((n) => n.id === draft.relatedNoteId);
        if (match) {
          setState({ status: "related", request, hints, related: [match] });
          return;
        }
      }
      setState({
        status: "ready",
        draft,
        overwriteNoteId: opts.overwriteNoteId,
        sourcePrompt: request,
      });
    } catch (err) {
      setState({
        status: "error",
        request,
        hints,
        message: err instanceof Error ? err.message : String(err),
      });
    }
  }

  function handleCompose() {
    if (state.status !== "idle") return;
    const request = state.request.trim();
    if (request.length === 0) return;
    const related = findRelatedNotes({ prompt: request, notes: existingNotes });
    if (related.length > 0) {
      setState({ status: "related", request, hints: state.hints, related });
    } else {
      void generate(request, state.hints, {
        extendingNote: null,
        overwriteNoteId: null,
        resolveLayer2: true,
      });
    }
  }

  if (!aiAvailable) {
    return (
      <div className="modal-backdrop" role="presentation" onClick={onClose}>
        <div className="modal" role="dialog" aria-label="Nhờ AI soạn" onClick={(e) => e.stopPropagation()}>
          <div className="modal-header">
            <h3>Nhờ AI soạn</h3>
            <button className="closex" onClick={onClose} aria-label="Đóng">
              ✕
            </button>
          </div>
          <div className="modal-body">
            <p className="compose-ai-hint">
              Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm và nhờ AI soạn ghi
              chú.
            </p>
          </div>
        </div>
      </div>
    );
  }

  if (state.status === "ready") {
    return (
      <EditKnowledgeNoteModal
        draft={state.draft}
        overwriteNoteId={state.overwriteNoteId}
        sourcePrompt={state.sourcePrompt}
        targetLanguage={targetLanguage}
        existingNotes={existingNotes}
        onClose={onClose}
        onSave={onSaved}
      />
    );
  }

  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div className="modal" role="dialog" aria-label="Nhờ AI soạn" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>Nhờ AI soạn</h3>
          <button className="closex" onClick={onClose} aria-label="Đóng">
            ✕
          </button>
        </div>
        <div className="modal-body">
          {state.status === "loading" && <p className="compose-loading">Đang soạn…</p>}

          {state.status === "related" && (
            <RelatedNotesBanner
              related={state.related}
              onOpen={() => onClose()}
              onExtend={(note) =>
                void generate(state.request, state.hints, {
                  extendingNote: note,
                  overwriteNoteId: note.id,
                  resolveLayer2: false,
                })
              }
              onProceedNew={() =>
                void generate(state.request, state.hints, {
                  extendingNote: null,
                  overwriteNoteId: null,
                  resolveLayer2: false,
                })
              }
            />
          )}

          {state.status === "error" && (
            <div>
              <p role="alert">Không tạo được ghi chú: {state.message}</p>
              <button
                type="button"
                className="link-btn"
                onClick={() => setState({ status: "idle", request: state.request, hints: state.hints })}
              >
                Thử lại
              </button>
            </div>
          )}

          {state.status === "idle" && (
            <>
              <label className="modal-field">
                <span>Bạn muốn ghi chú về điều gì?</span>
                <textarea
                  value={state.request}
                  placeholder="Ví dụ: câu điều kiện loại 2"
                  onChange={(e) =>
                    setState({ status: "idle", request: e.target.value, hints: state.hints })
                  }
                />
              </label>
              <div className="modal-field">
                <span>Gợi ý (tuỳ chọn)</span>
                <div className="chip-row">
                  <SimpleDropdown
                    ariaLabel="Nhóm gợi ý"
                    triggerLabel={
                      state.hints.groupId
                        ? (groupOptions.find((g) => g.value === state.hints.groupId)?.label ?? "Chọn nhóm")
                        : "Chọn nhóm"
                    }
                    options={groupOptions}
                    value={state.hints.groupId ?? NO_GROUP}
                    onChange={(v) =>
                      setState({
                        status: "idle",
                        request: state.request,
                        hints: { ...state.hints, groupId: v === NO_GROUP ? null : v },
                      })
                    }
                    active={state.hints.groupId !== null}
                  />
                  <SimpleDropdown
                    ariaLabel="Cấp độ CEFR gợi ý"
                    triggerLabel={state.hints.cefr ? state.hints.cefr.toUpperCase() : "Cấp độ CEFR"}
                    options={CEFR_OPTIONS}
                    value={state.hints.cefr ?? NO_CEFR}
                    onChange={(v) =>
                      setState({
                        status: "idle",
                        request: state.request,
                        hints: { ...state.hints, cefr: v === NO_CEFR ? null : (v as CefrLevel) },
                      })
                    }
                    active={state.hints.cefr !== null}
                  />
                </div>
              </div>
            </>
          )}
        </div>
        {state.status === "idle" && (
          <div className="modal-footer">
            <button onClick={onClose}>Huỷ</button>
            <button className="save-btn" onClick={handleCompose} disabled={state.request.trim().length === 0}>
              Soạn
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
