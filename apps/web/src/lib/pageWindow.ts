const SIBLINGS = 2;

export function getPageWindow(current: number, total: number): (number | "…")[] {
  if (total <= 1) return total === 1 ? [1] : [];

  const left = Math.max(2, current - SIBLINGS);
  const right = Math.min(total - 1, current + SIBLINGS);

  const pages: (number | "…")[] = [1];
  if (left > 2) pages.push("…");
  for (let page = left; page <= right; page++) pages.push(page);
  if (right < total - 1) pages.push("…");
  pages.push(total);

  return pages;
}
