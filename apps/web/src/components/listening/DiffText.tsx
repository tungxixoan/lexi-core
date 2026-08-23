interface DiffTextProps {
  typed: string;
  target: string;
}

export function DiffText({ typed, target }: DiffTextProps) {
  return (
    <p className="diff-text" data-testid="diff-text">
      {typed.split("").map((ch, i) => {
        const correct = i < target.length && ch.toLowerCase() === target[i].toLowerCase();
        return (
          <span key={i} className={correct ? "diff-char-correct" : "diff-char-wrong"}>
            {ch}
          </span>
        );
      })}
    </p>
  );
}
