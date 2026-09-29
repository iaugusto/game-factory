# E5b — Sectors, skill tree, save/meta wiring: plan

_2026-09-27. Built on `research.md` and the user's answers there: a permanent tree, stars,
the old meta folded in, a sector 3, and §4.3 as proposed._

## 1. Scope

**In:**
- The campaign: three sectors, unlocked in order; stars per sector; the loss consolation.
- The skill tree: 3 branches × 5 nodes, stars to buy, a free reset.
- Save v5 wired to the game.
- A campaign screen as the new main scene, a skill-tree panel, and a result screen with stars.
- Sector 3 (a new map and its 10 waves).
- A re-tune of the difficulty curve against tree profiles.
- Bot, tests and docs.

**Out:**
- A heroic or challenge mode.
- Cloud save.
- A title-screen art pass (B8).
- The E5a UI clutter item.
- E5c.

## 2. Data (`defs/`, `data/`)

- **`SkillDef`** (`defs/skill_def.gd`):
  - `id`, `title`, `description`, `branch` (0..2), `tier` (1..5), `cost` (stars);
  - `key` + `value`, a `RunModifiers` field, just as cards and the old meta did.
  - **Every node, including the rule nodes, is one modifier.** The tree stays pure data, and a new node is a `.tres` plus, at most, one field and its reader.
- **`SkillTreeDef`** (`defs/skill_tree_def.gd`): `branch_titles: PackedStringArray` and `skills: Array[SkillDef]`.
  - Content lives in `data/skills/*.tres` and `data/skill_tree.tres`.
- **`RunConfig`** changes:
  - It gains a Campaign group:
    - `skill_tree`;
    - `star_thresholds = [0.5, 0.9]` (the gate fraction for stars 2 and 3);
    - `consolation_waves = 5`;
    - `death_blast_radius = 80`.
  - `RunConfig.maps` stays the campaign order. **Deviation:** research §4.4 proposed a new `CampaignDef`, but `maps` already is exactly that list, so no new resource is added.
  - `meta_upgrades` and `win_brick_bonus` go.
- **Retired:** `MetaUpgradeDef`, `data/meta/*`, `MetaProgress`, `Economy.bricks_for_run`, `Run.bricks()`.

### New `RunModifiers` fields (and who reads them)

| Field | Node | Read by |
| --- | --- | --- |
| `loot_bonus` | Scavengers +0.10 | `Economy.kill_reward`, `crate_reward` |
| `unit_hp_bonus` | Reinforced Pads +0.30 | `Run.build` / `upgrade` (max HP) |
| `death_blast` | Last Stand: 25 dmg per unit level | `CombatSim.destroy_unit`: an EXPLOSIVE blast of `death_blast_radius` |
| `start_barricade` | Field Barricade 1 | `Run._init`: the barricade stands at L1 on slot 0 |
| `veteran_level` | Veteran Crews 1 | `Run.build`: the level starts at 1 + n (capped) and you pay level 1 |
| `gate_repair_bonus` | Masons +0.5 | `Run.repair_gate` |
| `card_rerolls` | Supply Drop 1 | `Run.reroll_cards()` (a new call; uses the `cards` stream) |
| `extra_cards` | Fourth Card 1 | the size of the `Run` card offer |
| `mastery_discount` | Overwatch 0.5 | `Run.mastery_cost` |
| `gate_thorns` | Iron Gate 5/s | `CombatSim._strike` on the gate: deals thorns × interval to the striker |

The old nodes map onto existing fields:
- Drill: `unit_rate_bonus` 0.08;
- Thick Walls: `wall_hp_bonus` 40;
- War Chest: `start_gold_bonus` 30;
- Sharpshooters: `unit_damage_bonus` 0.10;
- Engineers: `unit_cost_discount` 0.10.

**No per-tick cost is added.** Last Stand fires once per unit death, and thorns fire once per gate strike.

## 3. Core (`core/`, all unit tested)

- **`SkillTree`:**
  - Holds `owned: Dictionary[StringName, bool]`.
  - Methods: `spent(tree)`, `can_buy(tree, skill, stars)`, `buy(...)`, `reset()`, `to_modifiers(tree)`.
  - A node needs the node one tier above it in its branch.
  - Unknown ids (content removed later) are ignored and cost nothing.
- **`Campaign`:**
  - Holds `best: Dictionary[StringName, int]` (stars per map) and `consoled: Dictionary[StringName, bool]`.
  - Methods:
    - `static stars_for(won, gate_frac, thresholds)`;
    - `record(map_id, won, waves_cleared, gate_frac, cfg)` returns `{stars, gained, new_best}`;
    - `stars_total()`;
    - `is_unlocked(maps, index)`: index 0, or the previous map won, i.e. `best >= 1` without consolation.
  - A consolation star counts as best = 1 but doesn't unlock. The "won" set is kept apart: `cleared: Dictionary`.
- **`SaveData` v5:**
  - Shape: `{version: 5, campaign: {best, cleared, consoled}, tree: {owned: []}, stats: {runs, wins, best_wave}, legacy: {bricks, levels}}`.
  - Migration v4 → v5 moves `meta` into `legacy` verbatim. That's not a silent reset: the old progress is kept on file. No tree nodes are granted, because the prerequisites and star costs have no brick equivalent. No real v4 save exists, since nothing ever wrote one.
  - `record_run` becomes `record_result(map_id, run)`: it updates the stats and the campaign.
- **`Run`:**
  - Reads the new modifiers.
  - `reroll_cards()` and `rerolls_left`.
  - `gate_fraction()`.
  - Offer size = `cards_per_offer + extra_cards`.

## 4. Flow and UI

- **The `Session` autoload** (`src/ui/session.gd`):
  - Holds `save`, `save_path` (`--save=PATH`), `map_id`, and `active` (a run launched from the campaign).
  - `goto_campaign()`, `goto_run(map_id)`, `run_mods(cfg)` (from the tree), `record(run)` (then saves).
  - It holds no rules, only glue.
- **The main scene becomes `scenes/campaign.tscn`** (`ui/campaign_screen.gd`):
  - The title, "★ n / 9".
  - One card per sector: a mini path preview, its name, ★★☆, locked or PLAY.
  - A "SKILL TREE" button.
- **Dev shortcut:** any run argument (`--map`, `--seed`, `--autoplay`, `--stress`, `--skip*`, `--open-plot`, `--tree`) goes straight to the run. Capture scripts, `--perf` and the docs' commands keep working.
- **`ui/skill_tree_panel.gd`:**
  - Three columns of five nodes; a tap buys.
  - Each node shows owned, affordable, locked (tier), or too expensive.
  - The details line shows the tapped node's description.
  - "RESET (free)".
- **`RunController`:**
  - Mods come from `Session` when active, or from `--tree=none|all|<id,id>` for dev and clips. Default: none.
  - At the end it records through `Session` only when active and not on autoplay.
- **The result screen:**
  - ★ earned, "NEW BEST" and "+n ★".
  - Buttons: NEXT SECTOR ▶ (won, and a next map exists), RETRY, CAMPAIGN.

## 5. Sector 3: "Switchback Ridge" (first pass, for the user's judgment)

The new twist is a **switchback**: one long S-bending path that crosses the field twice, so pads in the middle cover it at two points. Around it:
- a **fork**: a second path shares the switchback's top and splits off down the left flank;
- a **tunnel** portal that opens at wave 6 low on the right flank, close to the gate (a short path: a late sudden threat).

It keeps the paths' y-monotone rule. Waves use every enemy type and elite by wave 10. It is tuned to the T6 profile.

## 6. Balance targets (the bot, 12 seeds)

**Tree profiles:**
- T0: none.
- T3: Drill, Thick Walls, War Chest.
- T6: tiers 1–2 of all three branches.
- T9: T6 + Last Stand + Field Barricade + Engineers (a 2-star node, so 10); called "T9+".

| Sector | Profile | Bot wins target |
| --- | --- | --- |
| 1 Outpost | T0 | ≥ 3/12 (winnable with no tree) |
| 1 Outpost | T3 | ≥ 6/12 |
| 2 Canyon | T0 | ≤ 1/12 |
| 2 Canyon | T3 | 2–6/12 |
| 3 Switchback | T3 | ≤ 2/12 |
| 3 Switchback | T6 | 2–6/12 |

The integration test encodes the curve's shape:
- S1 at T0 wins some;
- each sector at the previous sector's profile wins less than the one before;
- tree profiles never lose to lower ones on the same seeds (in aggregate);
- every run ends.

## 7. Tests

- **Unit:**
  - `skill_tree_test`: prerequisites, stars, reset, unknown ids, modifiers.
  - `campaign_test`: stars, thresholds, unlocking, consolation once, best kept.
  - `save_data_test`: v4 → v5, round-trip, v1 → v5 chain.
  - `run_test` / `combat_sim_test` for each rule node: blast, veteran, barricade start, thorns, reroll, 4 cards, mastery and repair.
  - `economy_test`: loot.
  - `content_test`: the tree is well formed (3 branches, tiers 1..5 contiguous, valid keys); sector 3 geometry; campaign maps are unique.
- **Scene:**
  - The campaign screen lists 3 sectors with 2 locked on a fresh save.
  - Buying in the tree panel updates stars.
  - A run started through `Session` records stars into a temporary save file.
  - Tests never touch `user://save.json`: they pass a temporary path.
- **Integration:** the curve in §6.

## 8. Risks

- **Retuning three maps is the long pole.** Plan: fix the bot profiles first, then scale per-map `hp_scale` in bulk with a probe, as E5a did.
- **Changing the main scene** could break `capture_clip.sh`. The dev shortcut covers it; check it with a real capture.
- **Test orphans** from the new UI: use `remove_child` + `free()` (see tooling quirks).
