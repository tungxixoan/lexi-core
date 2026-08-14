# LexiCore Game Mode — Overworld / Combat / Hub UX Design

**Date:** 2026-08-14
**Status:** Draft — pending user review of this file
**Covers:** Navigation model, movement, and screen UX for the three core screens of the "LexiCore Game" expansion: **Overworld** (exploration), **Combat** (exercise-as-battle), **City Hub / Gia trang** (Companion husbandry + building). Explored via interactive HTML/CSS/JS prototyping in the superpowers visual-companion tool.
**Depends on:** existing `VocabRecord` / `Topic` / SM-2 infrastructure (`ComputeSM2`, `VocabRecord.nextDueAt`), existing AI exercise sources (`ExerciseGeneratorSource`, `Part5Source`, `Part6Source`, `Part7Source`, `ListeningPassageSource`), existing `AppContext` enum (`lib/features/dictionary/domain/entities/app_context.dart` — 8 values: general, business, technology, travel, foodAndDrink, health, academic, socialCasual).
**Origin:** the game concept (Region tiers, SM-2-driven "Expedition" content, Elite/Pity system, reuse-existing-AI-sources approach) came from an idea doc the user supplied outside this repo. This spec keeps that doc's core mechanics and data-reuse philosophy, but **replaces its navigation model** (static node-map, tap-to-enter) with a free-roam model arrived at through this brainstorming pass — see §6 for what was explicitly dropped/changed and why.

---

## 1. Goal & framing

Gamify the existing vocab-review loop as an explorable 2D world, without a separate content pipeline. Combat is existing exercise generation re-skinned with HP/damage framing; no new AI capability is introduced. This is a module inside the existing Flutter app (reuses `VocabRecord`, SM-2, and all AI sources in-process) — not a separate product, and not a redesign of underlying learning mechanics.

## 2. Scope of this spec

**In scope:** UX, navigation, interaction, and movement design for Overworld, Combat, and City Hub, plus the resulting technical-approach decision (Flame engine adoption).

**Out of scope / deferred** (tracked as open questions in §8): exact tier-unlock thresholds, economy/balancing numbers, Expedition/AI-response caching strategy, final art asset source, "Mảnh Bảo Vật" reward mechanics, persistence schema beyond what's needed to reason about UX.

## 3. Overworld

### 3.1 Navigation model — zone-based live map

The overworld is **one continuous map, permanently divided into 8 contiguous zones**, one per `AppContext` value. All 8 zones are visible/traversable at once — there is no "select a region, then enter it" step. Monster encounters render as **individual markers scattered directly inside their zone**, generated from that topic's due words (`nextDueAt <= now`). Walking a character into a monster marker's collision box starts Combat (§4) directly — no confirmation or lobby screen in between.

A zone that doesn't yet have enough vocab data renders **fogged** (dashed border, hazed fill, no monster markers) but remains walkable — signals "come back later," never hard-blocks movement.

Each zone's current Region Tier (Village → Town → Watchtower → Abyss) and progress toward the next tier render as a small label + progress bar directly on the map, anchored to the zone (not a separate screen).

### 3.2 Movement — free-roam via Flame engine

The player controls a walking character rather than tapping map nodes:

- **Input:** touch-and-drag virtual joystick. It spawns at the point of first touch (not a fixed on-screen pad), a draggable nub shows direction/magnitude within it, and releasing stops movement. No on-screen D-pad buttons.
- **Camera:** the world is larger than the viewport; the camera follows the character, clamped to world bounds.
- **Character:** a humanoid figure (head/torso/legs, not a static icon) with a walk-cycle leg animation while moving and a left/right facing flip. The current shape is a CSS placeholder — see §7 for real-sprite sourcing.
- **Collision:** monster markers (and, in the Hub, Companion/building markers) are solid; touching one both blocks further movement into it and fires its interaction trigger.

**Architecture implication:** this requires adding `flame` (and likely `flame_tiled` if a Tiled tilemap is used later) as a new Flutter dependency — the project's first game-engine dependency, a deliberate upgrade from a plain-`Stack`/`Positioned` node-map. Overworld and the City Hub (§5) each run inside their own Flame `GameWidget`, embedded as ordinary GoRouter routes. Every other screen (Combat, results, settings, etc.) stays a normal Flutter widget tree — Flame is scoped to the two free-roam scenes only.

### 3.3 Monster markers

| Monster tier | CEFR | Icon (placeholder) |
|---|---|---|
| Slime | A1/A2 | 🟢 |
| Chiến binh | B1/B2 | ⚔️ |
| Tướng quân | B2/C1 | ⚔️ (larger) |
| Trùm cuối vùng | C1/C2 | 🐉 |

Marker positions within a zone are randomized/regenerated as due words change. **Elite status is a hidden attribute** — an Elite monster looks identical to a normal one of its tier on the map (no glow, no visual cue, no advance warning). The reveal happens only at the start of Combat, as a surprise ("⭐ ELITE!" moment), not on the overworld. This is a deliberate reversal of the source idea doc's §5 suggestion (which proposed a rising glow cue as the pity counter approached its threshold) — the user chose surprise-on-encounter over telegraphed-in-advance.

## 4. Combat

### 4.1 Framing — full battle screen

Top ~50% of the screen is the battle arena: monster sprite, HP bars for monster and player/companion, floating damage numbers on hit, combo-streak counter. Bottom is the exercise panel (question + options), reusing existing exercise-format rendering per the monster-tier table in the source idea doc (MC/fill-blank/translation for Slime/Chiến binh, Part 5/6 for Tướng quân, Part 7/Nghe hiểu for the vùng boss).

### 4.2 Adaptive arena for long-form questions — tentative

Proposed: the arena auto-collapses to a thin HUD strip (monster mini-icon + HP bar only) when the question type is long-form (Part 7, Nghe hiểu), returning to full size for short-form types. This was proposed during brainstorming and not explicitly objected to, but hasn't had an explicit "yes" either — **flagged for confirmation during spec review** (§8).

### 4.3 Elite reveal

If the monster just walked into is Elite (hidden attribute, §3.3), Combat opens with a one-time reveal beat (e.g. a flash/banner "⭐ ELITE!") before the first question — this is the only place Elite status becomes visible to the player.

### 4.4 Underlying mechanics (unchanged from the source idea doc)

- Correct answer = one hit on the monster's HP bar; consecutive correct answers build a combo multiplier.
- Wrong answer = monster retaliates, player/companion HP drops.
- Reaching 0 HP forces a retreat; the monster's HP **does not reset** — the next attempt continues from where it was left, avoiding a wasted-effort feeling.
- Elite encounters keep the pity mechanic from the source doc (~8% base rate per region, escalating to guaranteed after 10-12 non-elite encounters in that region, counter resets on any elite appearance) — only its *visibility* changed (§3.3), not its underlying probability/escalation logic.

## 5. City Hub ("Gia trang")

Also free-roam, using the same Flame scene type, input scheme (touch-drag joystick), and humanoid character as the Overworld — a separate scene/route, not a sub-area of the overworld map.

- Each building plot maps 1-1 to a `Companion`, which maps 1-1 to a `VocabRecord`.
- Companion visual state reflects SM-2 retention: thriving/glowing when healthy, wilted/greyed when overdue ("đói"). Locked/unearned plots render dashed/muted. A district's landmark building (unlocked at N words learned in that topic) renders larger than a regular plot.
- Walking the character adjacent to a Companion or building surfaces an interaction prompt (feed / build / collect) — the same "walk up to trigger" interaction grammar as Overworld monster encounters, not a menu/list.
- Lexi Coin idle income is shown as a persistent HUD counter with a "+N chờ nhận" indicator, computed as offline/session-start progress (not a true background task — iOS doesn't support those reliably, per the source idea doc's own note).

## 6. Explicitly dropped or changed from the source idea doc

- **"Region = single node, tap → Expedition lobby" navigation model** — replaced by the zone-based live map (§3.1). The map no longer has a moment of "selecting" a region; you're always standing somewhere in one.
- **"Tiền sảnh" (Region Lobby) screen** — dropped entirely. It would have previewed due-word count, monster mix, and pity state behind a "Khởi hành" button before entering an Expedition. With monsters now visible and enterable directly on the map, that preview is redundant: the map *is* the preview. Region tier/progress now renders inline on the map (§3.1) instead.
- **Elite visual cue (rising glow near the pity threshold)** — replaced by a fully hidden attribute revealed only at combat start (§3.3, §4.3).
- The `Expedition` entity from the source doc's data model (a session-scoped batch of `MonsterEncounter`s, generated on "Khởi hành") is superseded by monsters being **ambient map entities** generated per-zone from due words directly — there's no explicit "start an expedition" action anymore. The underlying idea (session-scoped generation, not persisted long-term) still holds; only its UI expression changes.

## 7. Art direction & asset sourcing — deferred

Preferred direction from this brainstorming pass: **pixel-art adventure** (Stardew Valley/Pokémon-adjacent), decided before two user-supplied reference images (an isometric-illustration mobile game UI concept and a Freepik "gaming" template) raised the bar on expected visual fidelity. Neither reference is a licensable/downloadable source — the first is a Dribbble/Pinterest portfolio piece by a third-party designer, the second is a Freepik marketing template — both are mood-board references only, not assets to build from.

Candidate real asset sources found during research, none yet chosen:
- [Isometric Illustration Pack v1](https://www.figma.com/community/file/1489712653839625512/isometric-illustration-pack-v1) (Figma Community, free, includes a Gaming category)
- [Free 3D Isometric Designs & Scenes](https://www.figma.com/community/file/1110592333163661658/free-3d-isometric-designs-scenes) (Figma Community, 350+ elements)
- [Isometric Game Kit 1](https://mobilegamegraphics.itch.io/isometric-game-kit-1) / [Kit 2](https://mobilegamegraphics.itch.io/isometric-game-kit-2) (itch.io, ~$9.95, game-ready sprite sheets rather than illustration)

All mockups produced during this design pass use flat-color placeholder shapes deliberately — the user confirmed each of the 8 overworld zones should eventually be redrawn with distinct, detailed terrain per topic ("like each topic gets its own small country map"), not the flat rectangles used to validate layout.

## 8. Open questions (carried over + new)

Carried over from the source idea doc, still unresolved:
1. Exact tier-unlock formula (word count + % "graduated" per CEFR band) — needs real usage data, not to be hardcoded yet.
2. Economy balancing — Companion hunger/decay rate, Mảnh Bảo Vật drop rate, Lexi Coin values.
3. Expedition/monster-generation caching — avoid re-calling AI every time a zone is re-entered in the same session.
4. What "Mảnh Bảo Vật" (rare Elite currency) actually unlocks in the Hub.

New, raised by the navigation-model change:
5. Combat arena auto-collapse for long-form questions (§4.2) — needs an explicit yes/no.
6. Empty-zone UX: is "no monster markers visible" a sufficient signal for "nothing due here today," or does it need an explicit hint/label the first few times a player encounters it?
7. Monster marker regeneration timing: exactly when do markers refresh (app open, zone re-entry, fixed interval)? Affects whether a defeated monster can reappear mid-session.

## 9. Prototyping note

Every mockup built during this design pass is a throwaway HTML/CSS/JS prototype (`.superpowers/brainstorm/`, gitignored), used only to validate movement feel and screen layout in a browser — none of it is implementation code. The real implementation is Flutter + Flame (Dart), built from this spec during the planning phase.
