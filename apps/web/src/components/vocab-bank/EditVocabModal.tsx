"use client";

import { useState } from "react";
import type { Topic } from "@/lib/topics";
import type { VocabRecord, VocabRecordUpdate } from "@/lib/vocabRecords";

interface EditVocabModalProps {
  record: VocabRecord;
  topics: Topic[];
  mode?: "edit" | "create";
  onClose: () => void;
  onSave: (updates: VocabRecordUpdate) => Promise<void>;
}

const MAX_TOPICS = 2;

export function EditVocabModal({ record, topics, mode = "edit", onClose, onSave }: EditVocabModalProps) {
  const [meaning, setMeaning] = useState(record.meaning);
  const [examples, setExamples] = useState<string[]>(record.examples);
  const [topicIds, setTopicIds] = useState<string[]>(record.topicIds);
  const [personalNotes, setPersonalNotes] = useState(record.personalNotes);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const toggleTopic = (id: string) => {
    setTopicIds((prev) => {
      if (prev.includes(id)) return prev.filter((t) => t !== id);
      if (prev.length >= MAX_TOPICS) return prev;
      return [...prev, id];
    });
  };

  const updateExample = (index: number, value: string) => {
    setExamples((prev) => prev.map((ex, i) => (i === index ? value : ex)));
  };

  const removeExample = (index: number) => {
    setExamples((prev) => prev.filter((_, i) => i !== index));
  };

  const addExample = () => {
    setExamples((prev) => [...prev, ""]);
  };

  const handleSave = async () => {
    setSaving(true);
    setError(null);
    try {
      await onSave({
        meaning: meaning.trim(),
        examples: examples.map((ex) => ex.trim()).filter((ex) => ex.length > 0),
        topicIds,
        personalNotes: personalNotes.trim(),
      });
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : String(err));
      setSaving(false);
    }
  };

  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div
        className="modal"
        role="dialog"
        aria-label={mode === "create" ? `Lưu từ ${record.headword}` : `Sửa từ ${record.headword}`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="modal-header">
          <h3>
            {mode === "create"
              ? `Lưu "${record.headword}" vào Ngân hàng từ vựng`
              : `Sửa "${record.headword}"`}
          </h3>
          <button className="closex" onClick={onClose} aria-label="Đóng">
            ✕
          </button>
        </div>
        <div className="modal-body">
          {error && <p role="alert">Lỗi lưu: {error}</p>}
          <label className="modal-field">
            <span>Nghĩa</span>
            <input value={meaning} onChange={(e) => setMeaning(e.target.value)} />
          </label>
          <div className="modal-field">
            <span>Ví dụ</span>
            {examples.map((ex, i) => (
              <div className="modal-example-row" key={i}>
                <input value={ex} onChange={(e) => updateExample(i, e.target.value)} />
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
            <span>Chủ đề (tối đa {MAX_TOPICS})</span>
            <div className="chip-row">
              {topics.map((t) => (
                <button
                  type="button"
                  key={t.id}
                  className={`vb-chip${topicIds.includes(t.id) ? " active" : ""}`}
                  onClick={() => toggleTopic(t.id)}
                  disabled={!topicIds.includes(t.id) && topicIds.length >= MAX_TOPICS}
                >
                  {t.name}
                </button>
              ))}
            </div>
          </div>
          <label className="modal-field">
            <span>Ghi chú cá nhân</span>
            <textarea value={personalNotes} onChange={(e) => setPersonalNotes(e.target.value)} />
          </label>
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
