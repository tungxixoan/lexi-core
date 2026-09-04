"use client";

import { useEffect, useRef, useState } from "react";
import type { PracticeExercise } from "@/lib/practiceExercise";

type MultipleChoiceExercise = Extract<PracticeExercise, { type: "multiple_choice" }>;

interface MultipleChoiceCardProps {
  exercise: MultipleChoiceExercise;
  onGrade: (quality: 1 | 5) => void;
}

// Port of lib/features/practice/presentation/widgets/multiple_choice_widget.dart.
// Question centered, 4 option pills. First click locks: the correct option turns
// green, a wrong picked one red, and 800ms later the grade is reported
// (5 for the correct index, 1 otherwise).
const GRADE_DELAY_MS = 800;

export function MultipleChoiceCard({ exercise, onGrade }: MultipleChoiceCardProps) {
  const [picked, setPicked] = useState<number | null>(null);
  const gradeTimer = useRef<number | null>(null);

  useEffect(
    () => () => {
      if (gradeTimer.current !== null) window.clearTimeout(gradeTimer.current);
    },
    []
  );

  function handlePick(i: number) {
    if (picked !== null) return; // guard double-submit
    setPicked(i);
    const quality: 1 | 5 = i === exercise.correctIndex ? 5 : 1;
    gradeTimer.current = window.setTimeout(() => onGrade(quality), GRADE_DELAY_MS);
  }

  return (
    <div className="pe-mc" data-testid="multiple-choice-card">
      <p className="pe-mc-question">{exercise.question}</p>
      <div className="pe-mc-options">
        {exercise.options.map((option, i) => {
          let stateClass = "";
          if (picked !== null) {
            if (i === exercise.correctIndex) stateClass = " pe-mc-correct";
            else if (i === picked) stateClass = " pe-mc-wrong";
          }
          return (
            <button
              key={i}
              type="button"
              className={`pe-mc-option${stateClass}`}
              disabled={picked !== null}
              onClick={() => handlePick(i)}
            >
              {option}
            </button>
          );
        })}
      </div>
    </div>
  );
}
