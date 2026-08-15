"use client";

import { useState } from "react";
import type { Topic } from "@/lib/topics";

interface TopicFilterPopoverProps {
  topics: Topic[];
  selectedTopicIds: Set<string>;
  onApply: (ids: Set<string>) => void;
}

export function TopicFilterPopover({ topics, selectedTopicIds, onApply }: TopicFilterPopoverProps) {
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState<Set<string>>(new Set(selectedTopicIds));

  const openPopover = () => {
    setDraft(new Set(selectedTopicIds));
    setOpen(true);
  };

  const toggleDraft = (id: string) => {
    setDraft((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const apply = () => {
    onApply(draft);
    setOpen(false);
  };

  const label = selectedTopicIds.size > 0 ? `Chủ đề ▾ (${selectedTopicIds.size})` : "Chủ đề ▾";

  return (
    <div className="vb-topic-popover-wrap">
      <button
        type="button"
        className={`vb-chip${selectedTopicIds.size > 0 ? " active" : ""}`}
        onClick={() => (open ? setOpen(false) : openPopover())}
      >
        {label}
      </button>
      {open && (
        <div className="vb-topic-popover" role="dialog" aria-label="Chọn chủ đề">
          <div className="vb-topic-popover-opts">
            {topics.map((t) => (
              <button
                type="button"
                key={t.id}
                className={`vb-chip${draft.has(t.id) ? " active" : ""}`}
                onClick={() => toggleDraft(t.id)}
              >
                {t.emoji} {t.name}
              </button>
            ))}
          </div>
          <button type="button" className="vb-topic-popover-apply" onClick={apply}>
            Áp dụng
          </button>
        </div>
      )}
    </div>
  );
}
