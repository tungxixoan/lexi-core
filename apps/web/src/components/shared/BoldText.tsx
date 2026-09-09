import { parseBoldMarkup } from "@/lib/boldMarkup";

export function BoldText({ source }: { source: string }) {
  const paragraphs = parseBoldMarkup(source);
  return (
    <div className="bold-text">
      {paragraphs.map((runs, i) => (
        <p key={i}>
          {runs.map((run, j) =>
            run.bold ? <strong key={j}>{run.text}</strong> : <span key={j}>{run.text}</span>,
          )}
        </p>
      ))}
    </div>
  );
}
