"use client";

import { useState } from "react";
import type { PracticeExercise } from "@/lib/practiceExercise";

type TranslationExercise = Extract<PracticeExercise, { type: "translation" }>;

interface TranslationCardProps {
  exercise: TranslationExercise;
  onGrade: (quality: 1 | 5) => void;
}

// Port of lib/features/practice/presentation/widgets/translation_exercise_widget.dart.
// Self-graded: header, the prompt in a card (stripped of the
// "Translate to Vietnamese: " lead-in and any apostrophes), a 2-line textarea,
// "Xem đáp án" disabled while the textarea is empty. After reveal the answer
// shows in a success box with "Sai rồi" → onGrade(1) / "Đúng rồi" → onGrade(5).
function stripPrompt(prompt: string): string {
  return prompt.replace("Translate to Vietnamese: ", "").replaceAll("'", "");
}

export function TranslationCard({ exercise, onGrade }: TranslationCardProps) {
  const [value, setValue] = useState("");
  const [revealed, setRevealed] = useState(false);

  return (
    <div className="pe-tr" data-testid="translation-card">
      <p className="pe-tr-header">Dịch sang tiếng Việt</p>
      <p className="pe-tr-prompt">{stripPrompt(exercise.prompt)}</p>
      <textarea
        className="pe-tr-input"
        rows={2}
        value={value}
        disabled={revealed}
        placeholder="Nhập bản dịch của bạn…"
        onChange={(e) => setValue(e.target.value)}
      />
      {!revealed && (
        <button
          type="button"
          className="btn-primary pe-tr-reveal"
          disabled={value.trim().length === 0}
          onClick={() => setRevealed(true)}
        >
          Xem đáp án
        </button>
      )}
      {revealed && (
        <>
          <p className="pe-tr-answer">Đáp án: {exercise.answer}</p>
          <div className="pe-tr-grade-row">
            <button
              type="button"
              className="pe-tr-grade-no"
              onClick={() => onGrade(1)}
            >
              Sai rồi
            </button>
            <button
              type="button"
              className="pe-tr-grade-yes"
              onClick={() => onGrade(5)}
            >
              Đúng rồi
            </button>
          </div>
        </>
      )}
    </div>
  );
}
