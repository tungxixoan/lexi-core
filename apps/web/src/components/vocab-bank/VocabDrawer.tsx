"use client";

import type { Topic } from "@/lib/topics";
import type { VocabRecord } from "@/lib/vocabRecords";
import { computeMasteryPercent, resolveTopicNames } from "@/lib/vocabDisplay";
import { ttsLanguageCode } from "@/lib/pronunciation";
import { PronunciationButton } from "@/components/shared/PronunciationButton";

interface VocabDrawerProps {
  record: VocabRecord;
  topics: Topic[];
  onClose: () => void;
  onDelete: () => void;
  onEdit: () => void;
}

export function VocabDrawer({ record, topics, onClose, onDelete, onEdit }: VocabDrawerProps) {
  const mastery = computeMasteryPercent(record);
  const topicNames = resolveTopicNames(record.topicIds, topics);
  const ttsLang = ttsLanguageCode(record.targetLanguage);

  return (
    <aside className="vb-drawer">
      <div className="vb-drawer-inner">
        <div className="dh">
          <div className="titles">
            <h3>{record.headword}</h3>
            <div className="pr">
              {record.ipa}
              <PronunciationButton text={record.headword} language={ttsLang} tier="word" />
            </div>
          </div>
          <span className="cefr-pill">{record.cefrLevel.toUpperCase()}</span>
          <button className="closex" onClick={onClose} aria-label="Đóng">
            ✕
          </button>
        </div>
        <div className="db">
          <details className="sect" open>
            <summary>Nghĩa &amp; định nghĩa</summary>
            <div className="ct">
              <p>{record.meaning}</p>
              {record.definition && <p style={{ fontStyle: "italic" }}>{record.definition}</p>}
            </div>
          </details>
          <details className="sect" open>
            <summary>Ví dụ</summary>
            <div className="ct">
              {record.examples.length === 0 && <p>Chưa có ví dụ.</p>}
              {record.examples.map((ex, i) => (
                <div className="ex-item" key={ex}>
                  <span className="ex-item-text">
                    {i + 1}. {ex}
                  </span>
                  <PronunciationButton text={ex} language={ttsLang} tier="sentence" />
                </div>
              ))}
            </div>
          </details>
          <details className="sect">
            <summary>Từ đồng nghĩa &amp; chủ đề</summary>
            <div className="ct">
              <div className="chip-row">
                {record.synonyms.map((s) => (
                  <span className="chip" key={s}>
                    {s}
                  </span>
                ))}
              </div>
              <div className="chip-row">
                {topicNames.map((name) => (
                  <span className="chip topic" key={name}>
                    {name}
                  </span>
                ))}
              </div>
            </div>
          </details>
          <details className="sect">
            <summary>Ghi chú của bạn</summary>
            <div className="ct">{record.personalNotes || "Chưa có ghi chú."}</div>
          </details>
        </div>
        <div className="df">
          <div className="pm">
            <div className="l">
              <span>Độ thành thạo</span>
              <span>{mastery}%</span>
            </div>
            <div className="ptrack">
              <div className="pfill" style={{ width: `${mastery}%` }} />
            </div>
          </div>
          <div className="fa">
            <button onClick={onEdit}>Sửa</button>
            <button className="danger" onClick={onDelete}>
              Xoá
            </button>
          </div>
        </div>
      </div>
    </aside>
  );
}
