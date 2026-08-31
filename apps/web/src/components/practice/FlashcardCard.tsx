"use client";

import { useEffect, useRef, useState } from "react";
import type { VocabRecord } from "@/lib/vocabRecords";
import { splitMeaningSenses } from "@/lib/lookup";

interface FlashcardCardProps {
  record: VocabRecord;
  onGrade: (quality: 1 | 5) => void;
}

// Matches the `.fc-card { transition: transform 0.55s }` in bloom.css: on a
// grade the card flips back to its OWN front, then — once that flip has
// settled — the parent swaps in the next word (which remounts this component
// fresh via the `key` on <FlashcardCard> in practice/page.tsx). Advancing
// immediately instead would animate the transform straight into the next
// word, flashing that word's back face into view mid-rotation.
const FLIP_MS = 550;

export function FlashcardCard({ record, onGrade }: FlashcardCardProps) {
  const [rotation, setRotation] = useState(0);
  const [grading, setGrading] = useState(false);
  const gradeTimer = useRef<number | null>(null);
  const showingFront = Math.round(rotation / 180) % 2 === 0;

  useEffect(
    () => () => {
      if (gradeTimer.current !== null) window.clearTimeout(gradeTimer.current);
    },
    []
  );

  function spin() {
    setRotation((r) => r + 180);
  }

  function handleFrontClick() {
    if (grading || !showingFront) return;
    spin();
  }

  function handlePeekClick(e: React.MouseEvent) {
    e.stopPropagation();
    if (grading) return;
    spin();
  }

  function handleGrade(e: React.MouseEvent, quality: 1 | 5) {
    e.stopPropagation();
    if (grading) return;
    setGrading(true);
    spin(); // flip the graded card back to its own front …
    gradeTimer.current = window.setTimeout(() => onGrade(quality), FLIP_MS); // … then advance
  }

  return (
    <div className="fc-scene">
      <div
        className="fc-card"
        data-testid="flashcard-card"
        style={{ transform: `rotate3d(1,1,0,${rotation}deg)` }}
        onClick={handleFrontClick}
      >
        <div className="fc-face">
          <p className="fc-headword">{record.headword}</p>
          {record.ipa && <p className="fc-ipa">{record.ipa}</p>}
          <div className="fc-hint">👆 Chạm vào thẻ để xem đáp án</div>
        </div>
        <div className="fc-face fc-face-back" onClick={handlePeekClick}>
          <div className="fc-back-scroll">
            <div className="fc-meaning">
              {splitMeaningSenses(record.meaning).map((sense, i) => (
                <p key={i}>{sense}</p>
              ))}
            </div>
            {record.examples[0] && <p className="fc-example">&quot;{record.examples[0]}&quot;</p>}
            <div className="fc-back-hint">↩ Chạm vùng này để xem lại mặt trước</div>
          </div>
          <div className="fc-grade-row">
            <button type="button" className="fc-grade-no" onClick={(e) => handleGrade(e, 1)}>
              Chưa hiểu
            </button>
            <button type="button" className="fc-grade-yes" onClick={(e) => handleGrade(e, 5)}>
              Đã hiểu
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
