import type { ReactNode } from "react";
import { targetWords, type BlankSpan } from "@/lib/dictation";

interface ClozeInputProps {
  target: string;
  blanks: BlankSpan[];
  answers: string[];
  onAnswerChange: (blankIndex: number, text: string) => void;
}

export function ClozeInput({ target, blanks, answers, onAnswerChange }: ClozeInputProps) {
  const words = targetWords(target);
  const segments: ReactNode[] = [];
  let wordIndex = 0;

  blanks.forEach((blank, blankIdx) => {
    if (blank.startWordIndex > wordIndex) {
      segments.push(<span key={`text-${blankIdx}`}>{words.slice(wordIndex, blank.startWordIndex).join(" ")} </span>);
    }
    segments.push(
      <input
        key={`blank-${blankIdx}`}
        type="text"
        className="cloze-blank-input"
        value={answers[blankIdx] ?? ""}
        onChange={(e) => onAnswerChange(blankIdx, e.target.value)}
        aria-label={`Chỗ trống ${blankIdx + 1}`}
      />
    );
    segments.push(" ");
    wordIndex = blank.startWordIndex + blank.wordCount;
  });

  if (wordIndex < words.length) {
    segments.push(<span key="text-end">{words.slice(wordIndex).join(" ")}</span>);
  }

  return <div className="cloze-text">{segments}</div>;
}
