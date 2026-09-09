// Vietnamese diacritic folding: each accented form → its base ASCII letter.
const DIACRITIC_FOLDS: Record<string, string> = {
  a: "áàảãạăắằẳẵặâấầẩẫậ",
  e: "éèẻẽẹêếềểễệ",
  i: "íìỉĩị",
  o: "óòỏõọôốồổỗộơớờởỡợ",
  u: "úùủũụưứừửữự",
  y: "ýỳỷỹỵ",
  d: "đ",
};

function foldChar(lower: string): string {
  for (const [base, accented] of Object.entries(DIACRITIC_FOLDS)) {
    if (accented.includes(lower)) return base;
  }
  return lower;
}

/**
 * Lowercase, fold Vietnamese diacritics (and đ→d), turn every non `[a-z0-9]`
 * char into a space, collapse whitespace, trim. Shared by the Knowledge
 * search box and the duplicate-check tokeniser so "câu điều kiện" and
 * "cau dieu kien" match. Port of lib/core/utils/text_normalize.dart.
 */
export function normalizeForSearch(input: string): string {
  let folded = "";
  for (const ch of input.toLowerCase()) {
    folded += foldChar(ch);
  }
  return folded.replace(/[^a-z0-9]+/g, " ").trim();
}
