import type { ReactNode } from "react";
import { isBlankCorrect, targetTextForBlank, targetWords, type BlankSpan } from "@/lib/dictation";

interface ClozeResultProps {
  target: string;
  blanks: BlankSpan[];
  answers: string[];
}

export function ClozeResult({ target, blanks, answers }: ClozeResultProps) {
  const words = targetWords(target);
  const segments: ReactNode[] = [];
  let wordIndex = 0;

  blanks.forEach((blank, blankIdx) => {
    if (blank.startWordIndex > wordIndex) {
      segments.push(<span key={`text-${blankIdx}`}>{words.slice(wordIndex, blank.startWordIndex).join(" ")} </span>);
    }
    const answer = answers[blankIdx] ?? "";
    const correct = isBlankCorrect(target, blank, answer);
    segments.push(
      <span key={`blank-${blankIdx}`} className={correct ? "cloze-answer-correct" : "cloze-answer-wrong"}>
        {answer.length > 0 ? answer : "___"}
      </span>
    );
    if (!correct) {
      segments.push(
        <span key={`hint-${blankIdx}`} className="cloze-answer-hint">
          {" "}
          (đúng: {targetTextForBlank(target, blank).toLowerCase()})
        </span>
      );
    }
    segments.push(" ");
    wordIndex = blank.startWordIndex + blank.wordCount;
  });

  if (wordIndex < words.length) {
    segments.push(<span key="text-end">{words.slice(wordIndex).join(" ")}</span>);
  }

  return <p className="cloze-text">{segments}</p>;
}
