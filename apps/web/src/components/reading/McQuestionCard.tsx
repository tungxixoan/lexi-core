interface McQuestionCardProps {
  label: string;
  options: string[];
  selected: number | null;
  onSelect?: (index: number) => void;
  correctIndex?: number;
  explanation?: string;
}

export function McQuestionCard({ label, options, selected, onSelect, correctIndex, explanation }: McQuestionCardProps) {
  const resultMode = correctIndex !== undefined;

  return (
    <div className="mc-question-card">
      <p className="mc-question-label">{label}</p>
      <div className="mc-options">
        {options.map((option, i) => {
          let className = "mc-option";
          if (resultMode) {
            if (i === correctIndex) className += " mc-option-correct";
            else if (i === selected) className += " mc-option-wrong";
          } else if (i === selected) {
            className += " mc-option-selected";
          }
          return (
            <button
              key={i}
              type="button"
              className={className}
              disabled={resultMode}
              aria-pressed={i === selected}
              onClick={() => onSelect?.(i)}
            >
              {option}
            </button>
          );
        })}
      </div>
      {resultMode && explanation && <p className="mc-explanation">Giải thích: {explanation}</p>}
    </div>
  );
}
