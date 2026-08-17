"use client";

import { useState } from "react";
import type { VocabRecord } from "@/lib/vocabRecords";

interface FlashcardCardProps {
  record: VocabRecord;
  onGrade: (quality: 1 | 5) => void;
}

export function FlashcardCard({ record, onGrade }: FlashcardCardProps) {
  const [rotation, setRotation] = useState(0);
  const showingFront = Math.round(rotation / 180) % 2 === 0;

  function spin() {
    setRotation((r) => r + 180);
  }

  function handleFrontClick() {
    if (showingFront) spin();
  }

  function handlePeekClick(e: React.MouseEvent) {
    e.stopPropagation();
    spin();
  }

  function handleGrade(e: React.MouseEvent, quality: 1 | 5) {
    e.stopPropagation();
    spin();
    onGrade(quality);
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
          <p className="fc-meaning">{record.meaning}</p>
          {record.examples[0] && <p className="fc-example">&quot;{record.examples[0]}&quot;</p>}
          <div className="fc-back-hint">↩ Chạm vùng này để xem lại mặt trước</div>
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
