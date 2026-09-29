# E5b — Sectors, skill tree, save/meta wiring: implementation log

Work item: `research.md` → `plan.md` (the user answered every research question with the
recommendation, 2026-09-27).

## 2026-09-27 — start

- Baseline: `scripts/test.sh` green (173 tests) before any change.

## 2026-09-27 — core: tree, campaign, save v5, rule nodes

- **Retired** (user answer 2): `MetaProgress`, `MetaUpgradeDef`, `data/meta/*` (6 files),
  `meta_progress_test`, `Economy.bricks_for_run`, `Run.bricks()`, `RunConfig.meta_upgrades` and
  `win_brick_bonus`.
- **New defs:** `SkillDef` (one `RunModifiers` key/value per node, like cards) and
  `SkillTreeDef` (branch titles and nodes). Content: `data/skills/*.tres` (15 nodes, exactly
  research §4.3) and `data/skill_tree.tres`, wired into `run_config.tres`.
- **`RunConfig` Campaign group:** `skill_tree`, `star_thresholds` [0.5, 0.9],
  `consolation_waves` 5, `death_blast_radius` 80.
  - **Deviation from research §4.4:** no `CampaignDef`. `RunConfig.maps` already is the ordered
    sector list.
- **Core:**
  - `SkillTree` (owned set; stars are never stored, free = earned − spent, so a reset can't
    drift).
  - `Campaign` (best stars per map, cleared set, consolation set).
- **`SaveData` v5:** campaign, tree, stats, legacy.
  - The v4 → v5 step moves bricks and levels into `legacy` verbatim. No tree nodes are granted,
    and this is documented in the schema history.
- **10 new `RunModifiers` fields**, read in `Run`, `Economy` and `CombatSim` (plan §2 table).
- **Last Stand and Iron Gate** happen inside `_move_enemies`, which walks the path arrays by
  index. A kill there would erase from the array being walked, so their damage is **queued** and
  applied right after the move pass (`_resolve_queued`). There's no per-tick cost when unused.
- **Card reroll** draws cards *other than* the ones shown, and tops up from the full pool if too
  few remain.
- **Tests:**
  - `skill_tree_test` (5), `campaign_test` (5), `tree_rules_test` (10).
  - `save_data_test` rewritten (v1…v4 → v5 chains; legacy survives a round trip).
  - `run_test` bricks assertions replaced by `gate_fraction`.
  - `content_test`: the tree is well formed (3 × tiers 1..5, costs 1/1/2/2/3 = 27), and ids are
    unique across skills and maps too.

## 2026-09-27 — flow and UI

- **`Session` autoload** (`src/ui/session.gd`) holds the save (lazy), `--save=PATH`, the active
  sector, `record()` and scene switching. Only runs launched from the campaign are recorded;
  direct, test, bot and capture runs never touch the save.
- **The main scene is now `scenes/campaign.tscn`** (`CampaignScreen`):
  - sector cards with the map's generated ground as a thumbnail, stars, and PLAY / REPLAY /
    LOCKED;
  - the stars total, and the skill-tree button (amber when stars are waiting).
  - **Any run argument jumps straight to the run scene,** so `capture_clip.sh`, `--perf` and the
    documented commands are unchanged.
- **`SkillTreePanel`:** three columns; tap to select, BUY, and a free RESET. States: owned
  (teal), affordable (amber), too expensive (steel), locked (dark).
- **`RunController`:**
  - `tree_mods` come from `Session`, or from `--tree=all|none|id,id`.
  - It records through `Session` at the end.
  - `next_map()` no longer wraps (there is no next after the last sector).
  - `unit_blast` triggers an explosion, a ring, a shake and "LAST STAND".
  - The reroll button is wired up.
- **`PhaseOverlay`:** ★★☆, gate-held %, NEW BEST +n ★ or the consolation line, and a hint for
  the missing stars. Buttons: NEXT: <sector> ▶ (wins only), RETRY / TRY AGAIN, CAMPAIGN.
- **`CardPicker`:** it shows 4 cards (shorter rows) and a "↻ REROLL (n free)" button.
- **Orphans:** removed UI children are now `free()`d, not `queue_free()`d (the GdUnit orphan
  quirk).
- `scripts/test.sh` → **193/193, 0 orphans.**

## 2026-09-27 — sector 3: Switchback Ridge

- **`data/maps/switchback.tres`:**
  - Path 0: the **switchback**, which crosses the field twice and then comes in to the centre
    gate.
  - Path 1: the **fork**. It shares the switchback's top, then runs down the left flank. It
    opens at wave 3.
  - Path 2: the **tunnel**, a short path from the right edge near the gate. It opens at wave 6.
  - 13 plots: a ridge pad covering both crossings, and 3 wall spots. The flank pad unlocks at
    wave 3, the tunnel's wall spot at wave 6.
  - Mud on the second crossing, high ground on the ridge pad.
  - All plots are ≥ 64 from every path; `content_test` passed first time.
- **Waves `switchback_01..10`** were authored from the Canyon's structure, with paths remapped
  and a little more volume. Every wave out-threatens the Canyon's (the content rule is now
  "every sector harder than the one before").
- They were written with a one-off scratchpad generator. The `.tres` files are the source.
- **The ground art** comes from the generator reading the map (`uv run gen-art`); no new code.

## 2026-09-27 — balance (bot, 12 seeds; T0 none, T3 tier-1s, T6 tiers 1–2)

**Baseline** (after E5a numbers, before re-tune):
- Outpost: T0 0/12, T3 4/12.
- Canyon: T0 0, T3 0, T6 1/12.
- Switchback: T0 0, T3 1, T6 2/12.

**HP factor search** (in the probe, then written into the data):
- Outpost:
  - ×0.8 gave T0 3, T3 5.
  - ×0.7 gave T0 6, T3 7.
  - **×0.75 gave T0 3, T3 8.**
- Canyon:
  - ×0.8 gave T3 0, T6 3.
  - ×0.7 gave T3 4, T6 6.
  - ×0.75 gave T3 1, T6 4.
  - **×0.72 was chosen.**
- Switchback: ×0.9 gave T3 2, T6 6. **×0.95 was chosen.**

**Final (12 seeds):**

| Sector | T0 | T3 | T6 |
| --- | --- | --- | --- |
| Outpost | 3/12 (median 8) | 7/12 | 12/12 |
| Canyon | 0/12 | 4/12 | 5/12 |
| Switchback | 1/12 | 1/12 | 4/12 |

Every plan §6 target is met:
- S1: T0 ≥ 3 and T3 ≥ 6.
- S2: T0 ≤ 1, and T3 in 2–6.
- S3: T3 ≤ 2, and T6 in 2–6.

**Observations for the user:**
- **Nearly every bot win ends at 90–100% gate:**
  - The bot repairs the gate between waves (below 70%), so the gate stars mostly measure
    **the last wave**.
  - That follows the approved rule ("the gate *ends* ≥ 50% / 90%"). A human who doesn't
    repair will see fewer 3-star wins.
  - Alternative: grade stars by *total damage taken over the run* (KR's "lives lost"). This is
    a taste call, flagged.
- **Tree power is modest per node:** T3 → T6 adds only +1 win on the Canyon. Bigger nodes are
  a knob if you want the tree to feel stronger.
- **The integration test** (`test_the_campaign_curve`, seeds 1–8): Outpost T0 2; Canyon
  T0/T3/T6 0/4/5; Switchback T0/T6 1/4. It asserts:
  - the curve's shape;
  - that more tree never wins less on the Canyon;
  - that every run ends.

## 2026-09-27 — UI polish, running the game, perf

- **The ★ glyph** falls back to a tiny asterisk in the UI font (seen in the first stills).
  - Stars are now **generated art**: `ui/star` and `ui/star_empty` in `gf_tools.art.fx`.
  - They are drawn with a new `StarRow` on the campaign cards, the result screen, and the
    tree's node costs.
  - The Skill Tree button's star icon rendered hollow on the amber button, so it's plain text
    now: "SKILL TREE · 2 stars to spend".
- **`--open-tree`** (dev, on the campaign screen) is for stills.
- **The probe pitfall, recorded:** `--script` runs have no autoloads, so a probe must not
  reference `RunController` (which uses `Session`). It re-implements arg parsing.
  - Also: `pkill -f <pattern>` matches the calling shell when the pattern is in its own
    command line. Use `pgrep -f "[G]odot…"`.
- **Frame time** (`--stress --perf`, WSLg, 260 enemies):

  | Map | Tree | fps | Frame | Sim tick |
  | --- | --- | --- | --- | --- |
  | Canyon | none | 134–136 | 7.35–7.46 ms | 1.92–2.24 ms |
  | Canyon | all | 135–138 | 7.23–7.39 ms | 1.87–2.15 ms |
  | Switchback | all | 132–143 | 7.0–7.6 ms | 2.11–2.86 ms (first window) |

  - The tree adds no measurable cost. Last Stand and Iron Gate are event-driven; with no tree,
    the only new per-tick work is two empty-array checks.
  - The Canyon tick is a little above E5a's recorded 1.7–1.95. The code path is the same with
    no tree, so this is read as run-to-run WSLg variance. The B5 phone measurement is still the
    gate before more per-enemy rules.
  - Draw calls: 93–104.
- **Clips and stills** in `captures/`:
  - `e5b-campaign.mp4/.png`: the campaign with 4 of 9 stars.
  - `e5b-tree.mp4/.png`: the tree panel.
  - `e5b-switchback-w6.mp4`: the tunnel breach at wave 6, with "NEW BREACH!".
  - `e5b-last-stand.mp4`: seed 5, wave 10. A Ravager kills a sniper; the pad erupts with
    "LAST STAND".
- **Tests:** `scripts/test.sh` → **197/197, 0 orphans**; tools **5/5**.
- **Docs updated:** `detailed-project-overview.md` (header, map, core/defs/rules/presentation,
  dependency map, change log), `README.md` (status, sectors, commands, launch args),
  `ROADMAP.md` (E5b and B3 ticked).

**Status: complete.**

**👤 For the user:**
1. **Play the campaign from a fresh save** (`… --path game`):
   - Is sector 1 winnable at zero tree?
   - Do the stars feel earned?
   - Does the tree feel like a real choice?
2. **The Switchback's layout** is a first pass for your judgment: the switchback, the fork, and
   the late tunnel near the gate.
3. **Two taste calls:**
   - Should gate stars count the whole run's damage instead of the gate at the end?
   - Are the tree nodes strong enough?
