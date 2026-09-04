"use client";

import { useEffect, useRef, useState } from "react";
import type { PracticeExercise } from "@/lib/practiceExercise";

type FillInBlankExercise = Extract<PracticeExercise, { type: "fill_in_blank" }>;

interface FillInBlankCardProps {
  exercise: FillInBlankExercise;
  onGrade: (quality: 1 | 5) => void;
}

// Port of lib/features/practice/presentation/widgets/fill_in_blank_widget.dart.
// Header, the sentence with the blank rendered inline, a text input + "Kiểm tra"
// button (Enter also submits). On submit compare input.trim().toLowerCase()
// against the already-normalized answer; show ✓/✗ and, if wrong, the answer.
// 1200ms later report the grade. The input is disabled after submit.
const GRADE_DELAY_MS = 1200;

export function FillInBlankCard({ exercise, onGrade }: FillInBlankCardProps) {
  const [value, setValue] = useState("");
  const [submitted, setSubmitted] = useState(false);
  const [correct, setCorrect] = useState(false);
  const gradeTimer = useRef<number | null>(null);

  useEffect(
    () => () => {
      if (gradeTimer.current !== null) window.clearTimeout(gradeTimer.current);
    },
    []
  );

  const parts = exercise.sentence.split("___");

  function submit() {
    if (submitted) return; // guard double-submit
    const isCorrect = value.trim().toLowerCase() === exercise.answer;
    setSubmitted(true);
    setCorrect(isCorrect);
    gradeTimer.current = window.setTimeout(
      () => onGrade(isCorrect ? 5 : 1),
      GRADE_DELAY_MS
    );
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Enter") {
      e.preventDefault();
      submit();
    }
  }

  return (
    <div className="pe-fill" data-testid="fill-in-blank-card">
      <p className="pe-fill-header">Điền vào chỗ trống</p>
      <p className="pe-fill-sentence">
        <span>{parts[0]}</span>
        <span className="pe-fill-slot" aria-hidden="true" />
        <span>{parts[1] ?? ""}</span>
      </p>
      <div className="pe-fill-row">
        <input
          type="text"
          className={
            "pe-fill-input" +
            (submitted ? (correct ? " pe-fill-input-ok" : " pe-fill-input-bad") : "")
          }
          value={value}
          disabled={submitted}
          placeholder="Nhập từ cần điền…"
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={handleKeyDown}
          autoFocus
        />
        {submitted && (
          <span className="pe-fill-mark" aria-hidden="true">
            {correct ? "✓" : "✗"}
          </span>
        )}
      </div>
      {submitted && !correct && (
        <p className="pe-fill-answer">Đáp án: {exercise.answer}</p>
      )}
      {!submitted && (
        <button type="button" className="btn-primary pe-fill-check" onClick={submit}>
          Kiểm tra
        </button>
      )}
    </div>
  );
}
