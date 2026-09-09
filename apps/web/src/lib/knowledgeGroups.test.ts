import { describe, expect, it } from "vitest";
import { knowledgeGroupsFor, knowledgeGroupLabel, knowledgeOtherGroupId } from "./knowledgeGroups";

describe("knowledgeGroups", () => {
  it("English taxonomy: 12 groups, first en_tenses, last en_other", () => {
    const ids = knowledgeGroupsFor("english").map((g) => g.id);
    expect(ids[0]).toBe("en_tenses");
    expect(ids[ids.length - 1]).toBe("en_other");
    expect(ids).toContain("en_conditionals");
    expect(ids).toHaveLength(12);
  });
  it("per-language sizes match the spec", () => {
    expect(knowledgeGroupsFor("english")).toHaveLength(12);
    expect(knowledgeGroupsFor("chinese")).toHaveLength(11);
    expect(knowledgeGroupsFor("korean")).toHaveLength(9);
    expect(knowledgeGroupsFor("japanese")).toHaveLength(9);
    expect(knowledgeGroupsFor("vietnamese")).toHaveLength(5);
  });
  it("every language ends with an _other group", () => {
    for (const l of ["english", "chinese", "korean", "japanese", "vietnamese"] as const) {
      const ids = knowledgeGroupsFor(l).map((g) => g.id);
      expect(ids[ids.length - 1]).toMatch(/_other$/);
      expect(ids[ids.length - 1]).toBe(knowledgeOtherGroupId(l));
    }
  });
  it("all group ids are globally unique", () => {
    const all = (["english", "chinese", "korean", "japanese", "vietnamese"] as const)
      .flatMap((l) => knowledgeGroupsFor(l).map((g) => g.id));
    expect(new Set(all).size).toBe(all.length);
  });
  it("label lookup resolves a known id, passes an unknown one through", () => {
    expect(knowledgeGroupLabel("en_tenses")).toBe("Thì");
    expect(knowledgeGroupLabel("nope_nope")).toBe("nope_nope");
  });
  it("label lookup is immune to prototype keys", () => {
    expect(knowledgeGroupLabel("toString")).toBe("toString");
    expect(knowledgeGroupLabel("constructor")).toBe("constructor");
  });

  it("Vietnamese labels carry CJK annotations byte-for-byte", () => {
    const label = (id: string) => knowledgeGroupLabel(id);
    expect(label("zh_aspect_particles")).toBe("Thể & Trợ từ động thái (了/着/过)");
    expect(label("zh_complements")).toBe("Bổ ngữ (kết quả/xu hướng/khả năng/mức độ)");
    expect(label("zh_ba")).toBe("Câu chữ 把");
    expect(label("zh_bei")).toBe("Câu chữ 被 (bị động)");
    expect(label("zh_modal_particles")).toBe("Trợ từ ngữ khí (吗/呢/吧/啊)");
    expect(label("zh_comparison")).toBe("Cấu trúc so sánh (比/没有/一样)");
    expect(label("ko_particles")).toBe("Trợ từ (조사)");
    expect(label("ko_endings_honorifics")).toBe("Đuôi câu & Kính ngữ (존댓말/반말)");
    expect(label("ko_clause_connectors")).toBe("Liên kết vế câu (연결어미)");
    expect(label("ko_modifiers")).toBe("Định ngữ (관형사형)");
    expect(label("ko_irregulars")).toBe("Bất quy tắc (불규칙 활용)");
    expect(label("ja_particles")).toBe("Trợ từ (助詞)");
    expect(label("ja_verb_forms")).toBe("Chia động từ (辞書形/て形/た形…)");
    expect(label("ja_politeness_keigo")).toBe("Thể lịch sự & Kính ngữ (敬語)");
    expect(label("ja_connectors")).toBe("Liên kết câu (接続)");
    expect(label("ja_grammar_patterns")).toBe("Mẫu ngữ pháp (文型)");
  });

  it("knowledgeOtherGroupId returns the language-specific *_other id", () => {
    expect(knowledgeOtherGroupId("english")).toBe("en_other");
    expect(knowledgeOtherGroupId("chinese")).toBe("zh_other");
    expect(knowledgeOtherGroupId("korean")).toBe("ko_other");
    expect(knowledgeOtherGroupId("japanese")).toBe("ja_other");
    expect(knowledgeOtherGroupId("vietnamese")).toBe("vi_other");
  });
});
