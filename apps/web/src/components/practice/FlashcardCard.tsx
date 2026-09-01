"use client";

import { useEffect, useRef, useState } from "react";
import type { VocabRecord } from "@/lib/vocabRecords";
import { splitMeaningSenses } from "@/lib/lookup";
import { PronunciationButton } from "@/components/shared/PronunciationButton";
import { ttsLanguageCode } from "@/lib/pronunciation";

interface FlashcardCardProps {
  record: VocabRecord;
  onGrade: (quality: 1 | 5) => void;
}

// Matches `.fc-card { transition: transform 0.55s }` in bloom.css. On a grade
// the card turns one more half-turn with EVERY face's content hidden
// (`.is-grading`), and only once that flip finishes does the parent swap in
// the next word (keyed remount in practice/page.tsx → the next headword fades
// in on the front). You never see the graded word's front face or the next
// word's meaning mid-rotation — the card just flips over blank into the next
// word.
const FLIP_MS = 550;

export function FlashcardCard({ record, onGrade }: FlashcardCardProps) {
  const [rotation, setRotation] = useState(0);
  const [grading, setGrading] = useState(false);
  const gradeTimer = useRef<number | null>(null);
  const showingFront = Math.round(rotation / 180) % 2 === 0;
  const ttsLang = ttsLanguageCode(record.targetLanguage);

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
    setGrading(true); // hide every face's content for the whole flip
    spin(); // one more half-turn — a blank card turning over
    gradeTimer.current = window.setTimeout(() => onGrade(quality), FLIP_MS); // then the next word
  }

  return (
    <div className="fc-scene">
      <div
        className={`fc-card${grading ? " is-grading" : ""}`}
        data-testid="flashcard-card"
        style={{ transform: `rotate3d(1,1,0,${rotation}deg)` }}
        onClick={handleFrontClick}
      >
        <div className="fc-face fc-face-front">
          <p className="fc-headword">{record.headword}</p>
          {record.ipa && <p className="fc-ipa">{record.ipa}</p>}
          {ttsLang && (
            <span className="fc-pron" onClick={(e) => e.stopPropagation()}>
              <PronunciationButton text={record.headword} language={ttsLang} tier="word" />
            </span>
          )}
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
