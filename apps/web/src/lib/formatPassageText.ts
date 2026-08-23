// AI-generated passage/document text sometimes carries markdown-style
// formatting (**bold**, # headers, "* " bullets) that renders as raw
// asterisks/hashes in plain <p> text instead of the intended emphasis, and
// is often one long unbroken line with no paragraph structure. This strips
// the markdown markers and splits on newlines so callers can render each
// resulting line as its own paragraph.
export function formatPassageLines(text: string): string[] {
  const stripped = text
    .replace(/\*\*(.*?)\*\*/g, "$1")
    .replace(/^#+\s*/gm, "")
    .replace(/^[*-]\s+/gm, "• ");
  return stripped
    .split(/\n+/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
}
