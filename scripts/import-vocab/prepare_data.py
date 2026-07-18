"""
One-off data prep for bulk vocab import (docs/Từ vựng tiếng anh.xlsx -> Master_List).
Deterministic pass only: merge/dedupe rows, normalize POS, map topics, parse existing
synonyms. Leaves `cefrLevel` null and `synonymsNeedsAi=true` for entries that still need
AI enrichment (done separately, not in this script).
"""
import json
import re
import openpyxl

SRC = "docs/Từ vựng tiếng anh.xlsx"
OUT = "scripts/import-vocab/prepared.json"

# headword(lowercase) -> topic slug (new topics get full metadata below)
TOPIC_MAP = {
    "workplace": "business",
    "negotiation": "business",
    "office english": "business",
    "it/technical": "technology",
    "daily life": "daily-life",
    "academic": "academic",
    "project management": "project-management",
    "personal well-being": "personal-well-being",
    "meetings": "meetings",
}

NEW_TOPICS = {
    "project-management": {"name": "Project Management", "emoji": "📋"},
    "personal-well-being": {"name": "Personal Well-being", "emoji": "🌱"},
    "meetings": {"name": "Meetings", "emoji": "🗓️"},
}

# Manual resolution for the 12 duplicate-headword groups (indices are 0-based
# among that headword's rows, in sheet order). "merge" = combine distinct senses
# with (pos) tags; "pick" = keep exactly one row, discard the rest.
DUP_RESOLUTION = {
    "routine": {"mode": "pick", "keep": 0},
    "commute": {"mode": "merge", "tags": ["v", "n"]},
    "prioritize": {"mode": "pick", "keep": 0, "fix_definition": "Decide what is most important"},
    "clarify": {"mode": "pick", "keep": 0},
    "deadline": {"mode": "pick", "keep": 0},
    "update": {"mode": "merge", "tags": ["n", "v"],
               "fill_definition": {1: "To make something more current or modern"}},
    "follow up": {"mode": "merge", "tags": ["phr.v", "n"]},
    "overhead": {"mode": "merge", "tags": ["n", "adv"],
                 "fill_definition": {1: "Above one's head, in the sky"}},
    "latency": {"mode": "pick", "keep": 0},
    "acknowledge": {"mode": "pick", "keep": 0},
    "feasible": {"mode": "pick", "keep": 1},
    "compromise": {"mode": "merge", "tags": ["v", "n"]},
}


def parse_synonyms(raw):
    if not raw:
        return []
    text = str(raw).strip()
    if text.lower() == "none" or not text:
        return []
    out = []
    for line in text.split("\n"):
        s = line.strip()
        s = re.sub(r"^-\s*", "", s)
        s = s.rstrip(",").strip()
        if s and s.lower() != "none":
            out.append(s)
    return out


def norm_pos(raw):
    return (raw or "").strip()


def detect_input_type(headword):
    return "phrase" if len(headword.strip().split()) >= 2 else "word"


def map_topic(raw_topic):
    key = (raw_topic or "").strip().lower()
    return TOPIC_MAP.get(key, "other")


def row_dict(r):
    return {
        "headword": str(r[0]).strip(),
        "pos": norm_pos(r[1]),
        "ipa": (r[2] or "").strip(),
        "synonyms_raw": r[4],
        "definition": (r[5] or "").strip() if r[5] else "",
        "meaning": (r[6] or "").strip() if r[6] else "",
        "example": (r[8] or "").strip() if (r[8] and str(r[8]).strip().lower() != "none") else "",
        "topic_raw": r[10],
    }


def build_record(rows, resolution=None):
    if len(rows) == 1 or (resolution and resolution["mode"] == "pick"):
        idx = resolution["keep"] if resolution else 0
        row = rows[idx]
        definition = resolution.get("fix_definition", row["definition"]) if resolution else row["definition"]
        return {
            "headword": row["headword"],
            "ipa": row["ipa"],
            "definition": definition,
            "meaning": row["meaning"],
            "examples": [row["example"]] if row["example"] else [],
            "synonyms": parse_synonyms(row["synonyms_raw"]),
            "topic_raw": row["topic_raw"],
        }
    # merge mode: combine distinct senses with (pos) tags
    tags = resolution["tags"]
    fill = resolution.get("fill_definition", {})
    def_parts, mean_parts, examples, synonyms, ipas = [], [], [], [], []
    for i, (row, tag) in enumerate(zip(rows, tags)):
        d = fill.get(i, row["definition"])
        if d:
            def_parts.append(f"({tag}) {d}")
        if row["meaning"]:
            mean_parts.append(f"({tag}) {row['meaning']}")
        if row["example"]:
            examples.append(row["example"])
        synonyms.extend(parse_synonyms(row["synonyms_raw"]))
        if row["ipa"] and row["ipa"] not in ipas:
            ipas.append(row["ipa"])
    ipa = ipas[0] if len(ipas) == 1 else "; ".join(f"{t}: {v}" for t, v in zip(tags, ipas)) if len(ipas) == len(tags) else (ipas[0] if ipas else "")
    return {
        "headword": rows[0]["headword"],
        "ipa": ipa,
        "definition": "; ".join(def_parts),
        "meaning": "; ".join(mean_parts) if len(set(mean_parts)) > 1 else (mean_parts[0].split(") ", 1)[-1] if mean_parts else ""),
        "examples": examples,
        "synonyms": sorted(set(synonyms)),
        "topic_raw": rows[0]["topic_raw"],
    }


def main():
    wb = openpyxl.load_workbook(SRC, data_only=True)
    ws = wb["Master_List"]
    raw_rows = [r for r in ws.iter_rows(min_row=2, values_only=True) if r[0] not in (None, "")]
    rows = [row_dict(r) for r in raw_rows]

    groups = {}
    for row in rows:
        groups.setdefault(row["headword"].strip().lower(), []).append(row)

    records = []
    for key, group_rows in groups.items():
        resolution = DUP_RESOLUTION.get(key)
        rec = build_record(group_rows, resolution)
        topic_slug = map_topic(rec.pop("topic_raw"))
        rec["topicSlug"] = topic_slug
        rec["inputType"] = detect_input_type(rec["headword"])
        rec["cefrLevel"] = None
        rec["synonymsNeedsAi"] = len(rec["synonyms"]) == 0
        records.append(rec)

    records.sort(key=lambda r: r["headword"].lower())

    out = {
        "newTopics": NEW_TOPICS,
        "records": records,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    needs_ai = sum(1 for r in records if r["synonymsNeedsAi"])
    print(f"Total unique records: {len(records)}")
    print(f"Records needing AI-generated synonyms: {needs_ai}")
    print(f"Records needing CEFR (all): {len(records)}")
    print(f"Written to {OUT}")


if __name__ == "__main__":
    main()
