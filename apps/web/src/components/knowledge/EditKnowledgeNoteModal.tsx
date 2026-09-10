"use client";

import { useState } from "react";
import type { CefrLevel, KnowledgeExample, KnowledgeNote } from "@/lib/knowledgeNotes";
import type { KnowledgeNoteDraft } from "@/lib/knowledgeNoteSource";
import { knowledgeGroupLabel, knowledgeGroupsFor } from "@/lib/knowledgeGroups";
import type { TargetLanguage } from "@/lib/languages";
import { SimpleDropdown, type SimpleDropdownOption } from "@/components/shared/SimpleDropdown";

interface EditKnowledgeNoteModalProps {
  initial?: KnowledgeNote | null;
  draft?: KnowledgeNoteDraft | null;
  overwriteNoteId?: string | null;
  sourcePrompt?: string | null;
  targetLanguage: TargetLanguage;
  existingNotes: KnowledgeNote[];
  onClose: () => void;
  onSave: (note: KnowledgeNote) => Promise<void>;
}

const CEFR_LEVELS: CefrLevel[] = ["a1", "a2", "b1", "b2", "c1", "c2"];
const NO_CEFR = "";
const NO_GROUP = "";

const CEFR_OPTIONS: SimpleDropdownOption<string>[] = [
  { value: NO_CEFR, label: "Không đặt" },
  ...CEFR_LEVELS.map((level) => ({ value: level, label: level.toUpperCase() })),
];

export function EditKnowledgeNoteModal({
  initial,
  draft,
  overwriteNoteId,
  sourcePrompt,
  targetLanguage,
  existingNotes,
  onClose,
  onSave,
}: EditKnowledgeNoteModalProps) {
  const [title, setTitle] = useState(initial?.title ?? draft?.title ?? "");
  const [summary, setSummary] = useState(initial?.summary ?? draft?.summary ?? "");
  const [explanation, setExplanation] = useState(initial?.explanation ?? draft?.explanation ?? "");
  const [patterns, setPatterns] = useState<string[]>(initial?.patterns ?? draft?.patterns ?? []);
  const [examples, setExamples] = useState<KnowledgeExample[]>(
    initial?.examples ?? draft?.examples ?? [],
  );
  const [pitfalls, setPitfalls] = useState<string[]>(initial?.pitfalls ?? draft?.pitfalls ?? []);
  const [groupId, setGroupId] = useState<string | null>(
    initial?.groupId ?? draft?.suggestedGroupId ?? null,
  );
  const [cefrLevel, setCefrLevel] = useState<CefrLevel | null>(
    initial?.cefrLevel ?? draft?.suggestedCefr ?? null,
  );
  const [tags, setTags] = useState<string[]>(initial?.tags ?? draft?.suggestedTags ?? []);
  const [newTag, setNewTag] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const groupOptions: SimpleDropdownOption<string>[] = knowledgeGroupsFor(targetLanguage).map(
    (g) => ({ value: g.id, label: g.label }),
  );

  const addPattern = () => setPatterns((prev) => [...prev, ""]);
  const updatePattern = (index: number, value: string) =>
    setPatterns((prev) => prev.map((p, i) => (i === index ? value : p)));
  const removePattern = (index: number) =>
    setPatterns((prev) => prev.filter((_, i) => i !== index));

  const addPitfall = () => setPitfalls((prev) => [...prev, ""]);
  const updatePitfall = (index: number, value: string) =>
    setPitfalls((prev) => prev.map((p, i) => (i === index ? value : p)));
  const removePitfall = (index: number) =>
    setPitfalls((prev) => prev.filter((_, i) => i !== index));

  const addExample = () => setExamples((prev) => [...prev, { text: "", translation: "" }]);
  const updateExampleText = (index: number, value: string) =>
    setExamples((prev) => prev.map((ex, i) => (i === index ? { ...ex, text: value } : ex)));
  const updateExampleTranslation = (index: number, value: string) =>
    setExamples((prev) => prev.map((ex, i) => (i === index ? { ...ex, translation: value } : ex)));
  const removeExample = (index: number) =>
    setExamples((prev) => prev.filter((_, i) => i !== index));

  const addTag = () => {
    const trimmed = newTag.trim();
    if (trimmed.length === 0 || tags.includes(trimmed)) {
      setNewTag("");
      return;
    }
    setTags((prev) => [...prev, trimmed]);
    setNewTag("");
  };
  const removeTag = (tag: string) => setTags((prev) => prev.filter((t) => t !== tag));

  const handleSave = async () => {
    const trimmedTitle = title.trim();
    if (trimmedTitle.length === 0) {
      setError("Nhập tiêu đề cho ghi chú.");
      return;
    }
    if (groupId === null) {
      setError("Chọn một nhóm.");
      return;
    }

    setSaving(true);
    setError(null);
    try {
      const targetId = overwriteNoteId ?? initial?.id;
      const existing = existingNotes.find((n) => n.id === targetId) ?? initial ?? null;
      const source = draft
        ? existing === null || existing.source === "starter"
          ? "ai"
          : existing.source
        : (existing?.source ?? "manual");
      const now = new Date().toISOString();
      const note: KnowledgeNote = {
        id: overwriteNoteId ?? initial?.id ?? crypto.randomUUID(),
        title: trimmedTitle,
        summary: summary.trim(),
        explanation: explanation.trim(),
        patterns: patterns.map((p) => p.trim()).filter((p) => p.length > 0),
        examples: examples
          .map((ex) => ({ text: ex.text.trim(), translation: ex.translation.trim() }))
          .filter((ex) => ex.text.length > 0 || ex.translation.length > 0),
        pitfalls: pitfalls.map((p) => p.trim()).filter((p) => p.length > 0),
        groupId,
        tags,
        cefrLevel,
        targetLanguage,
        source,
        sourcePrompt: sourcePrompt ?? existing?.sourcePrompt ?? null,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      };
      await onSave(note);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : String(err));
      setSaving(false);
    }
  };

  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div className="modal" role="dialog" aria-label="Ghi chú kiến thức" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>{initial ? `Sửa "${initial.title}"` : "Ghi chú kiến thức"}</h3>
          <button className="closex" onClick={onClose} aria-label="Đóng">
            ✕
          </button>
        </div>
        <div className="modal-body">
          {error && <p role="alert">{error}</p>}

          <label className="modal-field">
            <span>Tiêu đề</span>
            <input value={title} onChange={(e) => setTitle(e.target.value)} />
          </label>

          <label className="modal-field">
            <span>Tóm tắt</span>
            <textarea value={summary} onChange={(e) => setSummary(e.target.value)} />
          </label>

          <label className="modal-field">
            <span>Giải thích</span>
            <textarea value={explanation} onChange={(e) => setExplanation(e.target.value)} />
            <span className="modal-hint">bọc **...** để in đậm</span>
          </label>

          <div className="modal-field">
            <span>Mẫu câu</span>
            {patterns.map((p, i) => (
              <div className="modal-example-row" key={i}>
                <input value={p} onChange={(e) => updatePattern(i, e.target.value)} />
                <button
                  type="button"
                  className="closex"
                  onClick={() => removePattern(i)}
                  aria-label="Xoá mẫu câu"
                >
                  ✕
                </button>
              </div>
            ))}
            <button type="button" className="link-btn" onClick={addPattern}>
              + Thêm mẫu câu
            </button>
          </div>

          <div className="modal-field">
            <span>Ví dụ</span>
            {examples.map((ex, i) => (
              <div className="modal-example-row" key={i}>
                <input
                  value={ex.text}
                  placeholder="Câu ví dụ"
                  onChange={(e) => updateExampleText(i, e.target.value)}
                />
                <input
                  value={ex.translation}
                  placeholder="Bản dịch"
                  onChange={(e) => updateExampleTranslation(i, e.target.value)}
                />
                <button
                  type="button"
                  className="closex"
                  onClick={() => removeExample(i)}
                  aria-label="Xoá ví dụ"
                >
                  ✕
                </button>
              </div>
            ))}
            <button type="button" className="link-btn" onClick={addExample}>
              + Thêm ví dụ
            </button>
          </div>

          <div className="modal-field">
            <span>Lỗi thường gặp</span>
            {pitfalls.map((p, i) => (
              <div className="modal-example-row" key={i}>
                <input value={p} onChange={(e) => updatePitfall(i, e.target.value)} />
                <button
                  type="button"
                  className="closex"
                  onClick={() => removePitfall(i)}
                  aria-label="Xoá lỗi thường gặp"
                >
                  ✕
                </button>
              </div>
            ))}
            <button type="button" className="link-btn" onClick={addPitfall}>
              + Thêm lỗi thường gặp
            </button>
          </div>

          <div className="modal-field">
            <span>Nhóm</span>
            <SimpleDropdown
              ariaLabel="Nhóm"
              triggerLabel={groupId ? knowledgeGroupLabel(groupId) : "Chọn nhóm"}
              options={groupOptions}
              value={groupId ?? NO_GROUP}
              onChange={(v) => setGroupId(v)}
              active={groupId !== null}
            />
          </div>

          <div className="modal-field">
            <span>Cấp độ CEFR</span>
            <SimpleDropdown
              ariaLabel="Cấp độ CEFR"
              triggerLabel={cefrLevel ? cefrLevel.toUpperCase() : "Không đặt"}
              options={CEFR_OPTIONS}
              value={cefrLevel ?? NO_CEFR}
              onChange={(v) => setCefrLevel(v === NO_CEFR ? null : (v as CefrLevel))}
              active={cefrLevel !== null}
            />
          </div>

          <div className="modal-field">
            <span>Thẻ</span>
            <div className="chip-row">
              {tags.map((tag) => (
                <button
                  type="button"
                  key={tag}
                  className="vb-chip active"
                  onClick={() => removeTag(tag)}
                >
                  {tag} ✕
                </button>
              ))}
            </div>
            <div className="modal-example-row">
              <input
                value={newTag}
                onChange={(e) => setNewTag(e.target.value)}
                placeholder="Thêm thẻ"
              />
              <button type="button" className="link-btn" onClick={addTag}>
                Thêm
              </button>
            </div>
          </div>
        </div>
        <div className="modal-footer">
          <button onClick={onClose} disabled={saving}>
            Huỷ
          </button>
          <button className="save-btn" onClick={() => void handleSave()} disabled={saving}>
            {saving ? "Đang lưu…" : "Lưu"}
          </button>
        </div>
      </div>
    </div>
  );
}
