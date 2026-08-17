// Ports lib/core/utils/ai_json_parser.dart's parseAiJsonObject. Even when a
// provider is explicitly asked for JSON-only output, it can still wrap the
// object in markdown code fences or append trailing prose/garbage after it.
// Strip markdown fences first, then — if the text still doesn't parse as-is —
// fall back to extracting just the balanced-brace JSON object substring
// (respecting string literals, so a `{`/`}` inside a JSON string value
// doesn't throw off the brace count).
export function parseAiJsonObject(raw: string): Record<string, unknown> {
  const stripped = stripCodeFences(raw.trim());
  try {
    return JSON.parse(stripped) as Record<string, unknown>;
  } catch {
    const extracted = extractBalancedObject(stripped);
    if (extracted === null) {
      throw new Error("No JSON object found in AI response.");
    }
    return JSON.parse(extracted) as Record<string, unknown>;
  }
}

const FENCE_PATTERN = /^```(?:json)?\s*([\s\S]*?)\s*```$/;

function stripCodeFences(text: string): string {
  const match = FENCE_PATTERN.exec(text);
  return match ? match[1].trim() : text;
}

function extractBalancedObject(text: string): string | null {
  const start = text.indexOf("{");
  if (start === -1) return null;
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < text.length; i++) {
    const char = text[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char === "\\") {
      escaped = true;
      continue;
    }
    if (char === '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;
    if (char === "{") depth++;
    if (char === "}") {
      depth--;
      if (depth === 0) return text.slice(start, i + 1);
    }
  }
  return null;
}
