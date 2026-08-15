import type { VocabRecord } from "./vocabRecords";

export interface VocabFilterState {
  dueOnly: boolean;
  topicIds: Set<string>;
  cefrLevels: Set<string>;
}

export function isFilterActive(filters: VocabFilterState): boolean {
  return filters.dueOnly || filters.topicIds.size > 0 || filters.cefrLevels.size > 0;
}

export function matchesFilters(
  record: VocabRecord,
  filters: VocabFilterState,
  isDue: (record: VocabRecord) => boolean
): boolean {
  if (filters.dueOnly && !isDue(record)) return false;
  if (filters.topicIds.size > 0 && !record.topicIds.some((id) => filters.topicIds.has(id))) {
    return false;
  }
  if (filters.cefrLevels.size > 0 && !filters.cefrLevels.has(record.cefrLevel)) {
    return false;
  }
  return true;
}
