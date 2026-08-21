import { highlightVocabWords, type BilingualSentence } from "@/lib/readingPassage";

interface PassageReviewProps {
  sentences: BilingualSentence[];
}

export function PassageReview({ sentences }: PassageReviewProps) {
  if (sentences.length === 0) return null;

  return (
    <div className="reading-review">
      <p className="reading-passage reading-review-passage">
        {sentences.map((sentence, sIdx) => (
          <span key={sIdx}>
            {highlightVocabWords(sentence.target, sentence.vocabWords).map((seg, segIdx) =>
              seg.highlighted ? (
                <mark className="reading-vocab-highlight" key={segIdx}>
                  {seg.text}
                </mark>
              ) : (
                <span key={segIdx}>{seg.text}</span>
              )
            )}{" "}
          </span>
        ))}
      </p>
      <p className="reading-review-translation">{sentences.map((s) => s.vietnamese).join(" ")}</p>
    </div>
  );
}
