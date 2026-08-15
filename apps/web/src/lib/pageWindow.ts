const SIBLINGS = 2;

export function getPageWindow(current: number, total: number): (number | "…")[] {
  if (total <= 1) return total === 1 ? [1] : [];

  const left = Math.max(2, current - SIBLINGS);
  const right = Math.min(total - 1, current + SIBLINGS);

  const window: (number | "…")[] = [1];
  if (left > 2) window.push("…");
  for (let page = left; page <= right; page++) window.push(page);
  if (right < total - 1) window.push("…");
  window.push(total);

  return window;
}
