"use client";

import type { BilingualSentence } from "@/lib/readingPassage";

interface TypingSentenceProps {
  completedSentences: string[];
  currentSentence: BilingualSentence;
  typed: string;
  onTypedChange: (value: string) => void;
}

export function TypingSentence({
  completedSentences,
  currentSentence,
  typed,
  onTypedChange,
}: TypingSentenceProps) {
  const target = currentSentence.target;
  const typedChars = typed.split("").map((ch, i) => ({
    ch,
    ok: ch === target[i],
  }));
  const pending = target.slice(typed.length);

  return (
    <div className="reading-passage-wrap">
      <p className="reading-passage">
        {completedSentences.length > 0 && (
          <span className="reading-completed">{completedSentences.join(" ")} </span>
        )}
        <span className="reading-current">
          {typedChars.map((c, i) => (
            <span key={i} className={c.ok ? "reading-char-ok" : "reading-char-bad"}>
              {c.ch}
            </span>
          ))}
          <span className="reading-pending">{pending}</span>
        </span>
      </p>
      <div className="reading-vn-row">{currentSentence.vietnamese}</div>
      <input
        className="reading-type-input"
        value={typed}
        onChange={(e) => onTypedChange(e.target.value)}
        placeholder="Gõ câu tiếng Anh ở đây…"
        autoComplete="off"
        data-testid="reading-type-input"
      />
    </div>
  );
}
