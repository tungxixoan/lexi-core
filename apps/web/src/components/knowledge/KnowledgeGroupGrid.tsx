import Link from "next/link";
import { knowledgeGroupsFor } from "@/lib/knowledgeGroups";
import type { TargetLanguage } from "@/lib/languages";

export function KnowledgeGroupGrid({
  language,
  counts,
}: {
  language: TargetLanguage;
  counts: Record<string, number>;
}) {
  return (
    <div className="knowledge-group-grid">
      {knowledgeGroupsFor(language).map((group) => {
        const count = counts[group.id] ?? 0;
        return (
          <Link
            key={group.id}
            href={`/knowledge/group/${group.id}`}
            className={`knowledge-group-card${count === 0 ? " knowledge-group-card-dim" : ""}`}
          >
            <span className="knowledge-group-card-label">{group.label}</span>
            <span className="knowledge-group-card-count">{count}</span>
          </Link>
        );
      })}
    </div>
  );
}
