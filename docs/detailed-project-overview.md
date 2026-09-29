# Detailed Project Overview

> **Purpose.** This is the canonical, always-current index of the project: every file, system
> and function, its rationale, and its dependencies. It exists so that humans and language
> models can load precise context in complex workstreams without reading the whole tree.
>
> **Maintenance rule.** Any change to the codebase structure must update this file in the
> same change. A stale overview is a bug. Mark each entry `existing` or `planned`.

_Last updated: 2026-09-28 — **content expansion, Stage 2: four new enemies** (work item
`2026-09-27-content-expansion`), each with one new rule and one weakness:
- **Wasp** (`EnemyDef.flying`): over the barricade, mud and escorts; Mortar shells, mines and
  napalm miss it. Weak to kinetic.
- **Warden** (`shield_radius/amount/regen`): shields itself and every enemy near it
  (`Enemy.shield` soaks damage before hp; the aura refreshes at 10 Hz). Weak to explosive.
- **Burrower** (`burrow_every/length`): dives underground (untargetable, under the barricade;
  can't dive while slowed), surfaces further on. Weak to cryo.
- **Bombardier** (`siege_range`, `lob_time`): stops short of the gate and lobs globs at it
  (`CombatSim.Lob`). Weak to piercing.

They are content only until Stage 4 puts them in sector waves; `--showcase=IDS` plays them now.
Tests 270 game + 12 tool.

Earlier the same day, **napalm burns along the road** (the user's Stage 1 review): a
BURN attack now sets a stretch of path alight (`CombatSim.burn_layout`, `Stretch`), running
down every branch through the tapped spot.

Before that, 2026-09-27 — **content expansion, Stage 1: special attacks** (work item
`2026-09-27-content-expansion`; Stages 2–4 are planned):
- **Special attacks as data** (`AbilityDef`, `data/abilities/`): Artillery Strike, Cryo Bomb
  (freeze, then slow), Napalm Line (a burning stretch of road), Minefield (mines on a path) and Repair
  Drones (gate, units and barricade; no aim). The strike moved out of `RunConfig`.
- **One per run, picked when the map starts** (`AbilityPicker`). The campaign offers the
  unlocked ones: Strike and Cryo are free, and each of the first three sectors' first win
  unlocks one more (`AbilityDef.unlocked_by`). The last pick is saved (save v7).
- **A first-time tutorial per attack** (the `ability_intro` tip), with a looping clip
  (`TipCard.clip`, `game/clips/*.ogv`, made by `uv run make-clips`).
- Frozen enemies are drawn as blue ice. The bot uses every kind (`Autoplay.ability_target`),
  and `uv run balance --abilities …` compares them.
- **Tests:** 249 game + 12 tool tests.

Before that, **art readability and resolution** (work item
`2026-09-27-art-readability`):
- **Sharpness:** sprites are rasterized at 4× with mipmaps (`Art.scale_of`); `field/` art stays
  at 2×.
- **Enemies:**
  - Thicker ink, legs and eyes. Skitter, Drone and Mender are 10% bigger.
  - Mender recoloured bone and Ravager crimson, so no two enemies share a hue family.
- **Units:** heads ×1.1. Each unit has its own base (`units/base_<id>`), painted in its
  damage type's colour (the `ui/dmg_*` palette).
- **Crates:** ×1.35 (their `radius`, the tap area, grew with them).
- **Barricade:**
  - Now 144×52, with three rows of bags; `BARRICADE_HALF_DEPTH` 16.
  - Empty slots draw a ghost of the barricade (`props/barricade_slot`), and a tap anywhere on
    that footprint selects the slot.
- **Grounds:** a biome per map (`MapDef.biome`): a desert Outpost, a red-rock Canyon, a
  tundra Switchback. Lanes are sunken, the edges get a vignette, and the swarm's creep leaves
  sparse stains and veins on the lane edges, fading before the wall.
- **Tests:** 233 game + 11 tool tests.

Before that, **B4: the balance bot, tuning and juice** (work item
`2026-09-27-b4-balance-and-juice`):
- **`uv run balance`:** headless bot runs (8+ strategies × sectors × 50 seeds) and a
  Markdown report with target checks.
- **Tuning:**
  - The light units are stronger. Skitters resist explosive as well as piercing, hit harder,
    and come in bigger packs.
  - Switchback HP ×0.82.
  - The bot counter-picks by kill rate and gate damage.
- **Juice:** buttons squash on press, result stars pop in, the gate % counts up, shells fall
  before a strike, and upgrades pop.
- **Open for the user:** big guns still dominate Switchback, and the Hive Queen makes last
  waves all-or-nothing.
- **Tests:** 232 game + 10 tool tests.

Before that, **artillery strike and unit synergies** (work item
`2026-09-27-artillery-and-synergies`, step E5c):
- **The strike:** a STRIKE button (during waves) arms a strike, and the next field tap calls
  it. It lands after 0.9 s, dealing 20 × `hp_scale` in radius 70, past armour and the chart,
  on a 30 s cooldown that's ready at each wave's start. There's a "Fire Mission" card for it.
- **Links:** two built units within 200 of each other boost each other. Each of the 21 unit
  pairs has its own named effect (damage, fire rate, reach, splash, slow, chill, pierce,
  crit, beam targets). They're drawn as dashed lines, named when they form, and previewed in
  the build menu.
- **Balance:** wave HP ×1.35/1.25/1.1 per sector to compensate. The bot places for links and
  strikes.
- **Tips:** 2 new ones (20 in all).
- **Tests:** 229 game + 5 tool tests.

Before that, **visual style and contextual tutorials** (work item
`2026-09-27-style-and-tutorials`, step E6, which pulls parts of B6 and B8 forward):
- **One style, as data:** `StyleDef` (fonts, a type scale that never goes below 15 px, and a
  palette in which each colour has one meaning, plus shape and a field tint). The user picked
  the **hybrid** direction: Lilita One + Nunito, rounded chunky buttons, and navy/amber
  colours.
- **Tips:** the first time something new happens, a spotlight and 1–3 short cards (≤ 80
  characters each), with time stopped during a wave. That's 18 tips, and the NEW THREAT card
  is now one of them. Save v6 remembers what was read. The campaign screen's ⚙ turns tips on
  and off and replays them.
- **The banner lane:** big announcements queue instead of overlapping.
- **Descriptions:** all 80 characters or fewer.
- **Tests:** 211 game + 5 tool tests.

Before that, **sectors and the skill tree** (work item
`2026-09-27-sectors-and-skill-tree`, step E5b, which absorbs B3):
- **The campaign:** three sectors (Outpost, Canyon Pass, and the new **Switchback Ridge**),
  unlocked in order, each worth 1–3 stars.
- **The skill tree:** 3 branches × 5 nodes, bought with stars, with a free reset. It includes
  the user's "a fallen unit explodes" (Last Stand) and "+10% loot" (Scavengers).
- **Saves are wired in:** save v5 (the brick meta is retired to `legacy`).
- **Screens:** a campaign screen is the new main scene; the result screen shows stars.
- **Tests:** 197 game + 5 tool tests.

Before that, **new enemies, destroyable units and elites** (work item
`2026-09-26-new-enemies-and-destroyable-units`, step E5a):
- Units have HP, and the **Ravager** hunts them.
- The **Splitter** bursts into Skitters, and the **Mender** heals.
- **Elites** (Armoured, Swift, Regenerating) are tinted and starred.
- Units can be repaired.

Before that, **maps from paths** (`2026-09-26-maps-from-paths`, step E4). Lanes are gone:
- **Maps are levels:** paths from portals to the gate that bend, merge and open mid-run, pads
  that unlock at a wave, and terrain (mud, high ground).
- **Each map has its own waves.**
- **A second map, Canyon Pass.**
- **The ground is painted from each map's data.**

Earlier the same day, **counters and coin sinks** (`2026-09-26-counters-and-coin-sinks`, step
E3) added:
- the damage-type chart (every enemy has a right and a wrong weapon, plus armour);
- selling at 50%;
- masteries at max level;
- the one barricade;
- gate repair;
- the wave preview and first-sight intel cards;
- escorts (small enemies bunch behind big ones);
- waves re-authored from patterns.

Earlier the same day: **gate siege and Spitters** (`2026-09-26-gate-siege`, step E2): enemies that reach the gate stop and strike it until killed, and the run is lost
when it breaks. The new Spitter jams units from range. Before that, the same day:
**fixed units and wall spots, no squad** (`2026-09-26-fixed-units-wall-spots`).

- **Every unit is a fixed asset on a spot**, and the wall carries spots too. The aimed squad
  is gone: it was never the user's design (`2026-09-26-escalating-difficulty/research.md` §2).
- **Loop:** crates are broken by **tapping** them. The coins buy units on plots, any time.
- **Next:** E5c, the active ability and synergies (`ROADMAP.md`).

Previously: build spots, loot and the art slice (the gates removed); B2 playfield; B1 core
rules; B0 toolchain; repository bootstrap._

---

## 1. What this project is

**Hold the Gate** (working title) is a commercial 2D game for Google Play, the Apple App
Store and possibly Steam, from one Godot 4.7 codebase. A fixed base holds its gate against
an alien swarm:

- Every troop and weapon is a **fixed asset on a build plot**. The field has plots between
  the paths, and the **wall has spots of its own**. Nothing the player owns moves.
- **Loot crates** drift down the paths. The player **taps** them to break them for **coins**.
  Units never shoot crates.
- Coins buy units on plots and their **upgrades**, at any time, including mid-wave. The live
  decision is "tap loot now, or build".
- A pick-1-of-3 **card** follows each wave.
- **Progression:** a **campaign of sectors** (maps), each worth up to 3 **stars**. Stars buy
  nodes of a permanent **skill tree** between runs.

The concept came from `2026-09-24-market-research`; the prototype plan is
`2026-09-24-hold-the-gate-prototype`. The gate mechanic it started with was dropped in
`2026-09-25-build-spots-loot-and-art` (research §8): crates took over the "shoot this or the
enemies?" decision, and plots took over growth. The aimed squad that survived that pivot was
removed in `2026-09-26-fixed-units-wall-spots`.

## 2. Repository map

| Path | State | Purpose |
| --- | --- | --- |
| `README.md` | existing | Purpose, status, lifecycle, layout, quick start. |
| `CLAUDE.md` | existing | Working agreement for AI assistants. |
| `ROADMAP.md` | existing | Work grouped into single-session bundles (B0–B19) and user decision gates (D1–D3). |
| `.gitignore` | existing | Ignores for Godot, Python/uv, platform builds, and every kind of secret. |
| `.claude/settings.local.json` | existing (untracked) | Machine-local permission rules implementing `CLAUDE.md` §5. |
| `docs/detailed-project-overview.md` | existing | This file. |
| `docs/YYYY-MM-DD-*/` | convention | One folder per work item: `research.md` → `plan.md` → `implementation.md`. |
| `docs/2026-09-24-repo-bootstrap/` | existing | Log of this repository's creation. |
| `docs/2026-09-24-market-research/` | existing | Genre/market scan that chose the concept and engine. |
| `docs/2026-09-24-hold-the-gate-prototype/` | existing | Research and plan for the 10-day prototype. |
| `docs/2026-09-24-b0-toolchain-skeleton/` | existing | B0: toolchain facts, verification log. |
| `docs/2026-09-24-b1-core-rules-layer/` | existing | B1: why combat moved into core, lane collision, determinism. |
| `docs/2026-09-24-b2-playfield-and-gates/` | existing | B2: rendering over core, batching finding, the user's checkpoint feedback. |
| `docs/2026-09-25-build-spots-loot-and-art/` | existing | Plots, crates, reload, gates dropped, first-pass balance, the art slice, perf. |
| `docs/2026-09-26-escalating-difficulty/` | existing (research) | How the map, enemy mixes and volume should escalate; the user's answers; the loss-condition options. Step 1 is the next row. |
| `docs/2026-09-26-fixed-units-wall-spots/` | existing | Squad removed, crates tapped, wall spots, save v4, rebalance probe. |
| `docs/2026-09-26-gate-siege/` | existing | E2: the siege loss, the Spitter (jams units), the breach presentation, the HP-ramp retune. |
| `docs/2026-09-26-new-enemies-and-destroyable-units/` | existing | E5a: unit HP, the Ravager, Splitter, Mender, elites, repair, balance and perf log. |
| `docs/2026-09-26-maps-from-paths/` | existing | E4: paths replace lanes (PathGeo), portals opening mid-run, plot unlocks, terrain, maps as levels, Canyon Pass, per-map ground painting, balance and perf log. |
| `docs/2026-09-27-sectors-and-skill-tree/` | existing | E5b: the campaign (stars, unlocks, consolation), the skill tree, save v5, Session and the campaign screen, Switchback Ridge, the re-tune against tree profiles, perf. |
| `docs/2026-09-27-style-and-tutorials/` | existing | E6: the style research (fonts, palette, readability numbers), three directions and the hybrid pick, the tip system (research, plan, log). |
| `docs/2026-09-27-art-readability/` | existing | Art readability and resolution: 4× sprites and mipmaps, readable enemies, damage-type colours on units, bigger crates and barricade, the slot ghost; the before/after review; background options. |
| `docs/2026-09-27-b4-balance-and-juice/` | existing | B4: research (the done-criteria restated, strategies, targets), plan, log (the baseline finding, 9 tuning iterations with numbers, the Switchback cliff), `report-baseline.md` and `report.md`. |
| `game/tools/balance_sim.gd` | existing | A headless SceneTree script: one balance cell (map, profile, strategy, seeds; optional `hp=`) → JSON lines of `BalanceRun.play` records. Called by `uv run balance`. |
| `docs/2026-09-27-artillery-and-synergies/` | existing | E5c: the artillery strike and unit synergies. Research (prior art, the 21-pair table), plan, and log (the balance probe, and why the strike was toned down rather than the HP raised further). |
| `docs/2026-09-26-counters-and-coin-sinks/` | existing | E3: the counter chart, sell, masteries, barricade, gate repair, preview and intel cards, escorts, waves re-authored, bot counter-picking, balance log. |
| `game/` | existing | Godot 4.7.2 project root. |
| `game/project.godot` | existing | Portrait 540×960, `canvas_items`/`expand` stretch, Mobile renderer, ETC2/ASTC, GdUnit4 plugin, autoloads `Services` and `Session`, `game/platform/provider` = `stub`. Main scene: `campaign.tscn`. |
| `game/scenes/campaign.tscn` | existing | **The main scene**: one `Control` with `campaign_screen.gd`. Any run argument (`--map`, `--seed`, `--autoplay`, …) jumps straight to `run.tscn`. |
| `game/scenes/run.tscn` | existing | The run: one `Node2D` with `run_controller.gd`; children are built in code. |
| `game/src/core/` | existing | The rules, as pure `RefCounted` classes (§3.1). Everything here runs headless. |
| `game/src/defs/` | existing | Typed `Resource` classes the content is made of (§3.2). |
| `game/src/platform/` | existing | Platform services: interface, stub, registry autoload `Services` (§3.4). |
| `game/src/sim/` | existing | Presentation over core (§3.5). No rules. |
| `game/src/ui/` | existing | HUD, build menu, card picker, build bar, result screen, theme (§3.5). |
| `game/shaders/enemy.gdshader` | existing | Enemy batches: walk-frame atlas, hit flash and frost overlay from per-instance custom data. |
| `game/shaders/spotlight.gdshader` | existing | The tip layer's dim: a rounded spotlight window with a soft edge, a rim, and a pulse ring. |
| `game/art/fonts/` | existing (source, not generated) | Lilita One (display) and Nunito variable (body), with their SIL OFL licences (`OFL-*.txt`). About 300 KB. |
| `game/art/` | existing (generated) | SVG source art (54 files; one ground per map, a base per unit, `props/barricade_slot`, and `ui/star`/`ui/star_empty`), **written by `tools/`** (`uv run gen-art`). Don't hand-edit; change the generator. Sprites are rasterized at 4× and `field/` art at 2×, all with mipmaps (`[importer_defaults]` in `project.godot`; the canvas filter is linear with mipmaps). |
| `game/data/` | existing | The content as `.tres` (§3.2): `units/` (6), `crates/` (3), `maps/` (2 levels: `outpost.tres` with 3 straight paths, 11 plots and waves `waves/wave_01..10`; `canyon.tres` with 4 paths, 15 plots, mud and high ground, and waves `waves/canyon_01..10`; `switchback.tres` with 3 paths, 13 plots, mud and a ridge, and waves `waves/switchback_01..10`), `enemies/` (12: the 8 in waves + Stage 2's `wasp`, `warden`, `burrower`, `bombardier`, not in waves until Stage 4), `elites/` (3), `masteries/` (7), `barricade.tres`, `cards/` (11), `skills/` (15) + `skill_tree.tres`, `synergies/` (21, one per pair of unit types), `styles/hybrid.tres` (the UI style), `tips/` (20 tips), and `run_config.tres` (lists the maps in campaign order and the tips). |
| `game/addons/gdUnit4/` | existing | Vendored GdUnit4 v6.2.1 (MIT). Don't edit. |
| `game/tests/fixtures.gd` | existing | `Fixtures`: tiny explicit content builders plus a 4-plot map. |
| `game/tests/core/*_test.gd` | existing | One suite per core file, plus `content_test` (integrity and design rules of `res://data`), `tree_rules_test` (the rule nodes of the skill tree), `platform_test` and `toolchain_test`. |
| `game/tests/integration/run_integration_test.gd` | existing | Real content plus Autoplay: wave 1 cleared with crates broken; deterministic full run; seeds diverge; unit-shot budget; **the campaign curve** (bot wins per sector and tree profile). |
| `game/tests/integration/campaign_flow_test.gd` | existing | The campaign loop against a temporary save: locks, stars, buying and resetting the tree (saved as it happens), a campaign run playing with the tree and recording its stars, a direct run recording nothing, and the campaign tip (shown once, saved, replay, tips off). |
| `game/tests/integration/run_scene_test.gd` | existing | The real scene, headless (24 cases): plot input and build menu, wall spots, crate taps, jammed units, the breach, sell and masteries, the barricade card, the wave preview and gate repair, slow-mo, the flow screens, pooling, batching, and tips (off in direct runs; the first run's enemy → build (a "do" card) → start order; no tip over a menu and none twice; a crate tip stopping time mid-wave). |
| `tools/` | existing | Python package `gf-tools` (uv, stdlib only, Python 3.12) (§3.6). |
| `scripts/test.sh` | existing | The one game test command (import pass, then GdUnit4 headless). Nonzero exit on failure. |
| `scripts/capture_clip.sh` | existing | `NAME SECONDS [game args]`: Movie Maker at 60 fps → `captures/NAME.mp4`. Needs a display (WSLg). |
| `captures/` | existing (git-ignored) | Recorded clips. |
| `scripts/build_*.sh` | planned | Desktop and Android builds (B5). |
| `.tools/` | existing (git-ignored) | Godot 4.7.2 editor binary. Export templates come in B5. |
| `prototypes/` | planned | Throwaway experiments; never imported by the game. |
| `.env.example` / `secrets.example.json` | planned | Shape of secrets once the first one exists. |
| `LICENSE` | planned | Deliberately absent (commercial; all rights reserved by default). |

## 3. Systems

### 3.1 Core rules (`game/src/core/`)

Pure logic; the only Godot types used are `RefCounted`, `Resource` data and
`RandomNumberGenerator`. Nodes read this state and call these methods; they hold no rules.

| File | Class | What it does | Why it's shaped this way |
| --- | --- | --- | --- |
| `path_geo.gd` | `PathGeo` | A path's geometry: distance along it ↔ position, normals, `d_at_y`, nearest point, a walker's cached segment, `stretch(d0, d1)` (the centre line between, bends kept) and `distance_to_polyline`. | Lets enemies move by distance on bent paths while targeting stays a binary search. |
| `run.gd` | `Run` | One run. Phases `BUILD → WAVE → CARD → BUILD … → WON/LOST`; the run **opens in BUILD** (prep). State: the wall/gate (HP = max − damage taken), coins (`gold`), `plots` (from the map, with unlock waves), cards, the barricade (in the sim). `plot_open`, `open_paths`, `newly_open_paths`, `unit_repair_cost`/`repair_unit` (build sets unit HP; upgrade keeps damage taken). Methods: `start_wave()`, `step()`, `tap(field_pos)` (WAVE only); `build` (1 s setup mid-wave), `upgrade`, `sell` (50% of `Plot.spent`), `buy_mastery`, `build_barricade` (a free move in BUILD), `upgrade_barricade`, `repair_barricade` (**BUILD and WAVE**); `repair_gate` (BUILD, `gate_repair_amount`); `pick_card(i)`, `reroll_cards()` (free rerolls from the tree; draws other cards). Tree hooks: veteran levels and `unit_max_hp` on build, the barricade standing from the start, cheaper masteries, bigger offers. Also `gate_fraction()` (stars), `state_hash()`. **The special attack:** `ability` (an `AbilityDef`; the pool's first by default), `choose_ability(def)` (BUILD before wave 1 only), `ability_cooldown_left` (0 at each wave start), `ability_cooldown()` (after `ability_cooldown_bonus`), `ability_ready()` (WAVE only), `call_ability(pos)` (damage × the wave's `hp_scale`); REPAIR's gate HP arrives as `combat.pending_gate_heal`. `build`/`sell` refresh the links. | The state machine lives in core so a run plays headless. Spending mid-wave is the point: crate coins are meant to be used while the fight is on. |
| `combat_sim.gd` | `CombatSim` (+ `Enemy`, `Crate`, `Plot`, `Shot`, `Spit`) | The WAVE tick: spawns (elites applied); moves enemies (unit attackers stop at a unit in reach and destroy it: `unit_struck`, `unit_destroyed`; an enemy at the gate **sieges**: it stops and strikes every `attack_interval` until killed) and crates; spitters spit at the nearest working unit in range (not while sieging) and globs jam units (`Plot.disabled`); Menders heal neighbours (`mender_pulse`); Splitters burst into their brood on death (inserted in sorted order); fires every working plot; moves unit shots and globs; `end_wave()` cleans up. **Every hit goes through `effective_damage`** (armour, floored, then ×2 weak / ×0.5 resisted; `enemy_hit` reports the chart's effect). Per-plot stats (`plot_damage/reload/reach`) fold in modifiers, the mastery and the boost. **The barricade** (`Barricade`) stops enemies on the paths through it until it breaks. **Escorts:** a small enemy can't pass a much bigger one ahead on its path. Beams stop at `beam_max_targets`. The barricade blocks every path passing within 40 of its slot (`place_barricade`, per-path stop distances). `tap_crate_at(p, dmg)` is the only way to hit a crate. `reload_of` (with the Overdrive boost), `damage_of` and `reach_of` apply the run's modifiers. Unit shots can crit. Signals: `enemy_spawned/killed/struck/hit`, `crate_spawned/tapped/broken/lost`, `spit_fired`, `unit_disabled`, `unit_fired`, `shell_landed`, `boost_started`, `barricade_struck/broken`, `unit_blast`, `synergies_changed`, `ability_called/landed`, `mine_exploded`. **Synergies:** the stat functions add `plot.syn` (reload, damage, reach), and `_fire_plot` adds its pierce, crit, beam targets, splash, slow and **chill** (a non-slowing unit's hits slow briefly). **Special attacks:** `cast(ability, pos, power)` queues a `Cast`; `_land_casts` (after the move pass) applies it by kind: STRIKE hits everything in its radius, FREEZE sets `Enemy.stun` (no moving, striking, spitting or healing) then a slow, BURN adds a `Hazard`: the road `burn_layout` picks, one `Stretch` per open path through the spot nearest the tap (within 2 px: a fork burns every branch, a shared trunk once), `burn_half_width` (path spread + 8) to each side; `_burn` each tick hits every enemy within reach of a stretch, whichever path it walks, MINES lays `Mine`s along the nearest open path (`nearest_open_path`, `mine_layout`; `_trip_mines` sets one off when an enemy reaches it), REPAIR heals units and the barricade and queues gate HP. All ability damage is raw, past the chart and armour. Casts and mines have their own id counter, so calling one never shifts enemy ids (which seed the spread). **Tree rules:** Last Stand (a destroyed unit's blast) and Iron Gate (thorns per gate strike) happen inside the move pass, so their damage is queued and applied right after it (`_resolve_queued`); a kill there would corrupt the path arrays being walked. | **Enemies and crates move by `d`** (distance along their path, `PathGeo`); paths are sorted by `d`. **Units** target "first in reach", the least distance left, by binary search over a `d` window per nearby path (a full scan was too slow for phones). Mud slows; high ground adds plot reach. Portals open per wave (`set_open_paths`). Attacks: BULLET (homing, fizzles), SHELL (lands where the target *was*; fast enemies dodge), HITSCAN, BEAM (up to `beam_max_targets` on the target's path within reach). Enemy `x` lives in core so range and shots match the drawing. |
| `wave_schedule.gd` | `WaveSchedule` | `WaveDef` → time-sorted ENEMY and CRATE events; random paths (among the open ones) resolved up front from the `spawn` stream. `enemy_counts`, `new_enemies` (first sight, for the new-enemy tips), `threat`. | Fixes the whole wave at its start. |
| `counters.gd` | `Counters` | Chart queries for the UI and tests: `units_strong_vs`, `units_weak_vs`, `enemies_countered_by`. | The damage math stays in `CombatSim.effective_damage`. |
| `economy.gd` | `Economy` | Kill reward (a trickle), crate reward (with `crate_reward_bonus`; both with the tree's `loot_bonus`), unit build/upgrade prices (discounted, capped at 90%). | — |
| `card_pool.gd` | `CardPool` | The weighted pick-1-of-3 draw: no duplicates, skips maxed and weight-0 cards. | — |
| `run_modifiers.gd` | `RunModifiers` | Additive bonuses fed by cards and skill-tree nodes, addressed by field name; `has_key()` validates content. E5b added `loot_bonus`, `unit_hp_bonus`, `death_blast`, `start_barricade`, `veteran_level`, `gate_repair_bonus`, `card_rerolls`, `extra_cards`, `mastery_discount`, `gate_thorns`. | A new bonus is one field plus the code that reads it. |
| `skill_tree.gd` | `SkillTree` | The owned nodes: `spent`, `is_reachable` (tier above owned), `can_buy`/`buy` against stars earned, `reset`, `to_modifiers`. | Stars are never stored as a balance (free = earned − spent), so a free reset can't drift. Unknown ids cost and give nothing. |
| `campaign.gd` | `Campaign` | Best stars per sector, the cleared set (unlocks) and the consolation set. `stars_for` (1 for a win, +1 per `star_thresholds` gate fraction met), `record`, `is_unlocked`, `stars_total`. | A loss that cleared `consolation_waves` of a never-won sector gives its first star once, so a player is never hard-stuck; it doesn't unlock. |
| `balance_run.gd` | `BalanceRun` | `PROFILES` (the T0/T3/T6 tree profiles), `profile_mods`, and `play(cfg, mods, seed, strategy, max_ticks, ability)`, which returns a flat record: won, waves, gate, ticks, ability, casts, links, unspent, crates, kills, leaks (gate damage per enemy type), units at the end. | Keeps the balance tool's logic in tested core; the tool script only loops. |
| `synergies.gd` | `Synergies` | Unit links: `find(cfg, a, b)` (either order); `compute(plots, cfg)`, which fills each `Plot.syn` (a summed `StatBonus`, each distinct synergy once per plot) and `Plot.links` for pads within `synergy_range`; `preview(plots, cfg, index, unit_id)`, what a build there would form. | Recomputed on build, sell and destruction only (`CombatSim.refresh_synergies`), so stats stay flat per tick. |
| `tip_director.gd` | `TipDirector` (+ `Pending`) | Which tip to show next: `notify(event, arg)` queues every unseen tip the event triggers, highest priority first. `pending()`, `done(p)` (marks it seen), `clear_queue()`. Per-argument tips (a new enemy) are seen once per argument (`key()` = `id:arg`). Lists the known `EVENTS`, `WAIT_EVENTS` and `FOCUSES`. | Pure, so the tip order is unit tested and a headless run never blocks. The seen set is the save's dictionary, so marking a tip seen persists with the save. |
| `save_data.gd` | `SaveData` | Versioned save (**v6**: campaign, tree, stats, legacy, **tips** `{seen, off}`); migrations v1→…→v6 (v5→v6 adds tips with none seen). v3/v4 refunded removed upgrades as bricks; **v5 retires bricks**: the old balance and levels move to `legacy` verbatim. `record_result`, `stars_free`. Atomic writes; an unreadable save goes to `.bad`. | `CLAUDE.md` §4: migrate, never reset. Written by `Session` after each campaign run and tree change. |
| `rng_streams.gd` | `RngStreams` | Named streams (`spawn`, `cards`, `combat`), each seeded from `"<seed>:<name>"`. | Drawing more from one stream never shifts the others. |
| `autoplay.gd` | `Autoplay` | A scripted player. It taps the crate nearest the gate at `taps_per_second` (3, tick-based). It **counter-picks**: it fills the biggest gap, the enemy type its units kill slowest relative to count × threat, with the most cost-effective counter. It saves for that unit unless under siege, and builds next to siegers. It repairs units below 60% HP first. It raises the barricade where it blocks the most threat after 3 units, builds only on open plots, repairs the gate and barricade, and buys the cheapest upgrade (level, Overcharge, barricade level). `step_wave()` and `play()`. | Used by the tests, `--autoplay`, fast-forwards, and the balance probes. Knobs: `chase_crates`, `taps_per_second`, `counter_pick`, `build_order`, `max_units`, `barricade_after_units`, `repair_gate_below`, `card_choice`, `PRESETS`/`preset(name)` (the balance strategies: smart, casual, no_ability, no_links, cycle, heavy, light, mixed, no_loot). **Counter-picking (B4):** over the coming two waves, the gap is the type with the most need (count × `wall_damage`) for the least coverage (`_kill_rate`: kills per second, counting overkill; splash is one target against fast enemies); then the unit that kills the gap fastest per √cost. `synergy_pick` (place where the unit links most), `ability_threat`/`ability_every_ticks`/`repair_below` (`ability_target`, per kind, over `best_cluster`: strike on the best cluster or a sieger; freeze only near the gate; napalm and mines just ahead of the cluster, on its path; repair when the gate or a unit is low). |

### 3.2 Content definitions (`game/src/defs/`) and data

- **`UnitDef`** (with `DamageType` KINETIC/EXPLOSIVE/PIERCING/CRYO, `masteries`, `mastery_cost`,
  `beam_max_targets`):
  - `Attack` BULLET/SHELL/HITSCAN/BEAM, and `Role` TROOP/EMPLACEMENT (visual only).
  - Cost and upgrade costs.
  - Damage, **reload**, reach, projectile speed, splash, slow.
  - Per-level growth; `damage_at/reload_at/dps_at(level)`.
- **`CrateDef`:** HP (in taps), reward, speed, radius; an optional unit fire-rate boost
  (`boost_rate_mult`) and its duration.
- **`CrateSpawn`** (`path`), and **`MapDef`**, a level: `paths` (`PathDef`: points with y
  increasing to the gate, `spread`, `opens_at_wave`), `plots` + `plot_unlock_waves`,
  `barricade_slots`, `zones` (`ZoneDef`: MUD / HIGH_GROUND), `waves`, and `biome` (the
  ground's palette; only the art generator reads it).
- **`EliteDef`** (HP ×, speed ×, armour bonus, regen, tint); `SpawnEntry.elite` marks a group.
- **`MasteryDef`** (bonuses to damage, reach, reload, splash and slow, plus armour pierce) and
  **`BarricadeDef`** (HP per level, costs, repair per HP).
- **`EnemyDef`** (with `description`, the counters `weak_to`/`resists`/`armor`/`threat`,
  `attack_interval` for the siege and an optional Spit group:
  `spit_interval`, `spit_range`, `spit_speed`, `disable_duration`; Stage 2 groups: `flying`,
  Shield `shield_radius`/`shield_amount`/`shield_regen`, Burrow `burrow_every`/`burrow_length`,
  Siege from range `siege_range`/`lob_time`), **`SpawnEntry`**,
  **`WaveDef`** (spawns, crates,
  **`hp_scale`/`speed_scale`**: the difficulty ramp), **`CardDef`**.
- **`StyleDef`:** fonts (display, body, `display_caps`), the type scale (caption 15, body 19,
  label 22, heading 28, display 44, outline), the palette (`panel`, `panel_raised`, `line`,
  `backdrop`, `dim`, `text`, `text_dim`, `text_outline`, `title`, `action` (primary buttons
  only), `coin`, `owned`, `threat`, `good`, `gate`), shape (`radius`, `corner_detail`,
  `border`, `button_lip`) and `field_tint`. `size_of(role)` and `font_of(role)`.
- **`StatBonus`** (a synergy's per-unit bonus: `damage`, `reload`, `reach`, `splash`, `slow`,
  `slow_time`, `pierce`, `crit`, `beam_targets`, `chill`, `chill_time`; `accumulate`,
  `summary`) and **`SynergyDef`** (`id`, `title`, `description`, `unit_a`, `unit_b`,
  `bonus_a`, `bonus_b`; `involves`, `bonus_for`).
- **`TipDef`** (`id`, `trigger`, `per_arg`, `priority`, `cards`) and **`TipCard`** (`title` ≤ 24
  characters, `body` ≤ 80, `icon`, `clip` (a looping `.ogv`), `focus`, `wait_for` for a "do"
  card).
- **`AbilityDef`** (existing): a special attack. `id`, `display_name`, `short_name`,
  `description`, `icon`, `clip`, `kind` (STRIKE, FREEZE, BURN, MINES, REPAIR), `unlocked_by`
  (a map id; empty = free), `cooldown`, `delay`, `radius`, `damage`, `duration`, `slow`,
  `slow_time`, `length` (BURN: road length), `mine_count`, `mine_spacing`, `gate_heal`, `unit_heal`;
  `targeted()`. Data: `data/abilities/` (strike 20 dmg r70 0.9 s/30 s; cryo_bomb r95 frozen
  4 s then ×0.5 for 3 s/30 s; napalm 90 of road, 5/s for 6 s/35 s, unlocked by outpost;
  minefield 5 mines 34 apart, 12 dmg r40/35 s, canyon; repair +35 gate, +50% units/40 s,
  switchback). Clips: `game/clips/<id>.ogv` (generated, tracked).
- **`SkillDef`** (a tree node: branch, tier, star cost, one `RunModifiers` key/value) and
  **`SkillTreeDef`** (branch titles, nodes; `at`, `branch_skills`, `total_cost`).
- **`RunConfig`:** the playfield (`field_width`, `wall_y`; `jitter_for(spread, radius)`), `maps`
  and `for_map(m)`, units (`crit_multiplier`,
  the chart's `weak_multiplier`/`resist_multiplier`/`armor_floor`, `sell_refund`,
  `build_setup_time`), crates (`tap_damage`, `tap_slop`), base (`gate_repair_hp`/`cost`,
  `barricade`), the presentation knob
  `build_menu_time_scale`, the campaign (`skill_tree`, `star_thresholds` [0.5, 0.9],
  `consolation_waves` 5, `death_blast_radius` 80), `abilities` (the special attacks, in pick
  order; `ability_by_id`), `synergy_range` 200 and
  `synergies`, `tips`, and the content lists (`map`,
  `waves`, `maps` in campaign order, `units`, `cards`).

**Design rules enforced by `content_test.gd`:**

- Reload never decreases as damage per shot rises.
- Single-target DPS spread ≤ 3×.
- **For every map:**
  - Plots sit inside the field and off every path, measured as the distance to the polyline.
    Wall spots (behind `wall_y`) are exempt, since nothing walks there.
  - Paths run down from a portal (at the top or a side edge) to the gate, and one is open at
    the start.
  - Waves only use paths open by then.
  - A wall spot sits near every path's end.
  - Each sector out-threatens the one before it, wave by wave.
- Every crate breaks in under half its travel time at 3 taps/s, and takes more than one tap.
- Every enemy strikes the gate on an interval. Some unit outranges every spitter, and
  spitters appear no earlier than wave 4, at most two at first.
- **The chart:** every enemy has exactly one weakness (never also a resistance) and an intel
  line. Every damage type is some enemy's answer and has a unit. Wave threat strictly
  rises. Every unit offers Overcharge plus its own trait. Barricade slots each
  block a path in front of the wall.
- **Synergies:** every pair of unit types has exactly one (21), with valid ids, a non-empty
  effect and short text. Every map has linkable pads.
- **Special attacks:** unique ids, short names ≤ 7, text within the tip limits, icon and clip
  exist, a reload well over the delay and duration, the per-kind numbers set, a known
  unlocking map, and exactly two free (the first among them).
- **Text:** every tip is well formed (a known trigger and focus, 1–3 cards, a title ≤ 24 and a
  body ≤ 80 characters, a "do" card has a spotlight, icons exist). Every enemy, unit,
  mastery, card and skill description is ≤ 80 characters.
- **The tree:** 3 branches of tiers 1..5, costs 1/1/2/2/3 (27 stars in all), valid keys, and
  the user's two nodes present.

**The roster:**

- **Units** (damage / reload): MG Nest 1/0.16 s, Rifleman 1.5/0.5 s, Cryo Projector
  2.5/1.0 s (slows), Mortar 8/2.4 s (splash shell), Sniper 18/3.0 s (hitscan), Rail Cannon
  26/4.2 s (beam).
- **Chart:** weak to (×2) / resists (×0.5) / armour: Skitter kinetic / piercing / 0;
  Drone explosive / piercing / 0; Spitter cryo / kinetic / 0; Carapace piercing / explosive
  / 3; Queen piercing / cryo / 4. MG and Rifleman are kinetic, Mortar explosive, Sniper and
  Rail piercing, Cryo cryo.
- **Enemies** (speed ↔ toughness), per gate strike:
  - Skitter: fast, fragile; 3.
  - Drone: 5.
  - **Spitter:** mid; 4. It jams the nearest unit within 140 for 4 s, every 3.5 s.
  - Carapace: slow, armoured; 15.
  - **Ravager:** mauls units within 90 of it (6 per 0.8 s); weak to kinetic.
  - **Splitter:** bursts into 3 Skitters; weak to explosive.
  - **Mender:** heals neighbours 6% per second; weak to piercing.
  - Hive Queen: boss; 999, so one strike breaks the gate.
  - **Elites:** Armoured, Swift and Regenerating.
- **Unit HP:** Rifleman 80, MG 120, Cryo 100, Mortar 140, Sniper 90, Rail 180 (+30% per
  level). A destroyed unit empties its plot with no refund; repair costs 0.3 coins per HP.
- **Crates** (taps to break): Supply 5, Munitions Cache 12, Overdrive Core 7 (×2 unit fire
  for 8 s).
- **Skitter (B4):** also resists explosive, deals 4 to the gate.
- **Cards (12):** fire mission (−30% special-attack reload), bounty, crits (units), crowbars (taps), masonry, field repairs, overclock,
  permafrost, rangefinder (+10% reach), skitter bounty, sharpened (+15% unit damage),
  scavengers.
- **Skill tree (15 nodes, stars):**
  - **Arsenal:** Drill Instructors (+8% reload), Sharpshooters (+10% damage), **Last Stand**
    (a destroyed unit explodes, 25 × its level, radius 80), Veteran Crews (built at level 2),
    Overwatch (masteries −50%).
  - **Bulwark:** Thick Walls (+40 gate), Reinforced Pads (+30% unit HP), Field Barricade (it
    stands at level 1 from the start), Masons (repairs +50%), Iron Gate (5/s to gate
    attackers).
  - **Logistics:** War Chest (+30 coins), **Scavengers** (+10% loot), Engineers (−10% prices),
    Supply Drop (a free card reroll), Fourth Card (4-card offers).

### 3.3 Rules in brief

- **Playfield:** 540 wide; the gate at y = 860; a fixed tick at 60 Hz.
- **Maps:**
  - **Frontier Outpost:** 3 straight paths.
  - **Canyon Pass:** two entrances merging into a trunk (with mud), a left flank breach at
    wave 4 and a right one at wave 7, pads unlocking at waves 4 and 7, and a high-ground pad.
  - **Switchback Ridge** (sector 3): one long path that zig-zags across the field twice (a
    ridge pad covers both crossings, mud on the second); a fork down the left flank opening at
    wave 3; a tunnel portal low on the right, close to the gate, opening at wave 6.
  - Enemies spread up to ±30 around their path's centre line (less for big ones).
- **Nothing the player owns moves.** There is no squad.
- **Units:**
  - 11 plots on `outpost` (three depths on each path divider, two on the verges, and **three
    wall spots** at y = 876, behind `wall_y`); 15 on `canyon`, 4 of them unlocking later.
  - Each unit fires at the enemy nearest the wall within its reach, once per reload.
  - Units never hit crates.
- **Crates:** tapped (1 damage per tap, with 16 units of slop) → broken → coins (+ boost);
  reaching the wall → lost; a cleared wave takes leftover crates with it.
- **Economy:** 45 starting coins; kills pay a trickle, crates are the income.
- **The gate siege:** an enemy that reaches the gate (`wall_y`) stops and strikes it on arrival,
  then every `attack_interval`, until killed. It stays targetable (the wall spots are
  point-blank), and the wave waits for it.
- **The barricade:** one, on a slot in front of the wall (it blocks every path through it), movable between
  waves; levels 1–3 (HP 60/140/260). Enemies on the paths through it stop and strike it until it breaks,
  then walk on. It stays as rubble until repaired.
- **Spending:**
  - Sell for 50% of all spent.
  - A unit built mid-wave waits 1 s.
  - Masteries at max level (Overcharge +25%, or the unit's trait).
  - Gate repair +25 HP for 20 coins, between waves.
- **Escorts:** a small enemy can't walk through a much bigger one ahead on its path.
- **Win and loss:** the run is lost when the gate breaks (wall HP ≤ 0), and won by clearing
  wave 10. On a loss, the view plays the breach before the result.
- **The campaign:** sectors unlock in order on a win. Stars: 1 for a win, +1 at ≥ 50% gate
  left, +1 at ≥ 90%. A loss after 5+ waves on a never-won sector gives 1 star once. The best
  per sector counts; stars buy tree nodes; a reset is free.
- **Difficulty after B4** (`docs/2026-09-27-b4-balance-and-juice/report.md`, 50 seeds, each
  sector at its profile): smart wins 38 / 38 / 46%, casual 48 / 34 / 42%, heavy 50 / 34 / 86%,
  cycle ≤ 6%, light 0%. Skitters resist piercing and explosive, deal 4 to the gate, and come
  ×1.6 from wave 5. Switchback `hp_scale` is ×0.82. The light units' damage was raised (MG 1.5,
  Rifleman 2.5, Cryo 3.5), the Rail's beam is capped at 2, and Mortar splash is 45.
- **Difficulty after E5c (bot strikes and places for links; seeds 1–8):** Outpost T0 6/8;
  Canyon T0/T3/T6 1/3/4; Switchback T0/T3/T6 1/3/3. Without strikes or link placement the
  bot still wins Outpost 2, Canyon 1/2/3 and Switchback 1/1/3. Wave HP is ×1.35 (Outpost),
  ×1.25 (Canyon) and ×1.1 (Switchback) over E5b.
- **Difficulty (E5b, against tree profiles; bot, 12 seeds):** T0 = no tree, T3 = the three
  tier-1 nodes, T6 = tiers 1–2 of every branch.
  - Outpost: T0 3/12 wins, T3 7/12.
  - Canyon: T0 0/12, T3 4/12, T6 5/12.
  - Switchback: T3 1/12, T6 4/12.
  - HP scales were cut ×0.75 (Outpost), ×0.72 (Canyon); the Switchback is ×0.95 of its first
    pass.
  - The bot gets by with Snipers and Mortars; making Skitters and Spitters demand their
    counters is open (E3 log). Maxed-out runs pile up unspent coins (no late sink yet).

### 3.4 Platform services (`game/src/platform/`)

- `PlatformServices`: the interface for rewarded ads, purchases, achievements and analytics.
- `StubServices`: records calls.
- `services_registry.gd`: autoload **`Services`**, which picks the provider from
  `game/platform/provider` (unknown names fall back to the stub).

### 3.5 Presentation (`game/src/sim/`, `game/src/ui/`)

- **`RunController`** (the root of `run.tscn`):
  - Ticks `Run` in `_physics_process` and syncs views in `_process`.
  - Maps core signals to effects.
  - Owns the input, which is presses only:
    - A press on a crate taps it (`Run.tap`).
    - Otherwise, a press within 34 px of a plot opens the `BuildMenu`, and one on a barricade
      slot opens the `BarricadeMenu`.
    - Emulated mouse events from touch are ignored.
  - **Banners** ("WAVE N INCOMING", a card's name, the map name, "NEW BREACH!") go through
    one lane (`_banner` → a queue). Each waits until the one before has faded (its life +
    `BANNER_GAP`, counted in game time), so none overlap. A skip clears the queue.
  - **Tips:** `tips` (a `TipDirector`) and `tip_layer` (`TipLayer`).
    - Core signals and the build phase (`_notify_build_tips`) report events.
    - `pump_tips()` shows the next tip when no menu, result or skip is in the way.
    - `_tip_pages` builds the cards. A new-enemy tip gets the portrait, the one line and the
      weak/strong unit rows.
    - `focus_rect(focus, arg)` resolves spotlights: pads, crates, the gate, portals, slots,
      HUD and build-bar buttons, and the offered cards. The layer re-measures them every
      frame.
    - During a WAVE a tip eases time down to `TIP_TIME_FLOOR`, and `_physics_process` skips
      ticks.
    - Tips are on in campaign runs (from the save, which is written as each is read), and
      in direct runs only with `--tips`.
    - `--autoplay --tips` is a demo: the bot reads each card for `TIP_DEMO_READ` s and does
      the "do" cards, for clips.
    - Test seams: `enable_tips`, `pump_tips`, `focus_rect`.
  - **The special attack:** when a hand-played run starts (`offer_pick`; off with
    `--ability`, `--autoplay`, skips and in tests), `AbilityPicker` opens over a hidden build
    bar with `ability_pool()` (the unlocked attacks in a campaign run, all in a direct run),
    preselecting `default_ability()` (`--ability`, else the save's `last_ability`). A pick is
    saved and notifies `ability_picked` (the per-attack intro tip, built by `ability_pages`:
    clip, numbers, then how to call it). `toggle_ability()` arms an aimed attack (time slows)
    or fires an untargeted one; `fire_ability(fp)` takes the next field tap, ahead of crates.
    Landing FX per kind (`_on_ability_landed`, `_on_mine_exploded`). `--pick=ID` answers the
    pick for captures. `--demo=ID` (dev) stages an attack for its clip (`demo_config`,
    `_demo_target`; prints `DEMO id field x y frame n`). `--showcase=IDS` (dev) plays one
    wave of those enemies among Drones with 400 coins (`showcase_config`); `--gold=N` (dev)
    overrides the starting coins; `--stress=mix` makes 40 of the stress wave Stage 2 enemies.
    Stage 2 FX: `_on_lob_landed` (acid splash at the gate), `_on_burrow` (`fx.dust`).
  - **Links:** `_on_synergies_changed` pops each new link's name at its midpoint and notifies
    the synergy tip.
  - On LOST it plays the **breach**: a shake, blasts along the wall, "THE GATE HAS FALLEN",
    and 1.2 s of slow motion (`BREACH_TIME`) while the result waits to fade in.
  - While a menu is open mid-wave, `Engine.time_scale = build_menu_time_scale` (slowed, not
    paused).
  - Test seams: `tick(n)`, `sync_views()`, `handle_pointer()`, `open_plot()`, `start_wave()`,
    `fast_forward_to_wave(k)` (stops at BUILD of wave k), `fast_forward_seconds(s)`.
  - Maps: `--map=ID`; `base_config` and `config = base.for_map(...)`; `switch_map` and the
    result screen's "NEXT: <sector>" (after a win; no wrap past the last). The build phase
    announces "NEW BREACH!" when a portal opens.
  - **The campaign:** launched from the campaign screen (`Session.active`), the run is on
    `Session.map_id` with the save's tree (`tree_mods`), and its result is recorded
    (`records`). A direct launch records nothing. `unit_blast` → explosion, ring, shake,
    "LAST STAND".
  - Launch args: `--seed --map --tree=all|none|id,id --autoplay --skip-to-wave --skip --perf
    --quit-on-end --save=PATH --tips --style=ID`, and dev-only `--stress --open-plot=N`
    (`parse_args`, `tree_from_arg`).
- **`Session`** (autoload, `ui/session.gd`): the save (loaded lazily from `--save` or
  `user://save.json`), the active sector, `run_mods`, `record` (then writes the save),
  `persist`, and scene switching (`goto_run`, `goto_campaign`). Tests point it at a temporary
  file with `use_save`.
- **`CampaignScreen`** (the root of `campaign.tscn`): the title, stars earned, one card per
  sector (its generated ground as a thumbnail, a `StarRow`, PLAY / REPLAY / LOCKED), and the
  SKILL TREE button (the action colour while stars wait). Its own `TipDirector` and `TipLayer`
  handle the `campaign_open` and `stars_to_spend` tips. The **⚙ settings** card has TIPS
  ON/OFF (`set_tips_on`) and REPLAY ALL TIPS (`replay_tips`), both saved. Dev: `--open-tree`.
- **`SkillTreePanel`:** three branch columns; tap to select, BUY, a free RESET; owned (teal),
  affordable (amber), too expensive (steel), locked (dark). It saves on every change.
- **`StarRow`:** gold stars and empty sockets from `ui/star` / `ui/star_empty`.
- **Art:**
  - `Art` resolves `res://art/<key>.svg` (cached) and draws each at `scale_of(key)`: 0.5
    (`FIELD_SCALE`) for `field/` art, which is 2×, and 0.25 (`SPRITE_SCALE`) for everything
    else, which is 4×. This mirrors the generator's `RASTER`/`FIELD_RASTER`; the tools test
    enforces it.
  - Why 4×: the 540-wide view is shown at up to ~2.9× on 1440p phones and tablets. Mipmaps
    keep sprites clean when shrunk on a 1× desktop window.
  - It also provides `quad()` (explicit-UV meshes for MultiMeshes) and `additive()`.
- **Batching is the performance rule:**
  - `EnemyField` is one textured MultiMesh per enemy type plus one shadow batch, one mound
    batch (burrowed enemies, `fx/mound`) and one bubble batch (Warden shields, `fx/bubble`;
    drawn one by one they cost ~1800 draw calls at the mixed stress load); HP bars and
    Bombardiers' globs (`fx/glob`, arcing) sit on one layer. Flyers are drawn lifted and
    bobbing over a small faint shadow. Elites are tinted (instance colour) and starred. `position_of` holds enemies at the wall's top edge and adds the siege
    lunge.
  - **Never add a node per enemy or bullet.** (B2: 599 → 80 draw calls; now 51–56 at budget
    load.)
- **Node-per-object is fine only for the few:**
  - `BarricadeField`:
    - The slots show as a pulsing amber ghost of the barricade (`props/barricade_slot`), teal
      when selected, between waves.
    - The barricade shows its level sprite or rubble, an HP bar and a shake.
    - `slot_at` hits the barricade's footprint (the art's size + `TAP_SLOP`), the shape the
      player sees.
  - `PlotField`/`PlotView` (≤ 11): base (`units/base_<id>`, in the damage type's colour), turning head, recoil, muzzle flash, reload ring,
    level chevrons, reach ring; an HP bar when damaged; a locked look (padlock, "W4"); a gold rim on high ground; a
    jammed look (grey, lime goo, a countdown ring). Wall spots
    draw at z 6, above the wall sprite (z 5).
  - `CrateField`/`CrateView` (pooled): wobble, hit shake, HP bar, coin tag, boost glow.
- **Effects:**
  - `ShotField` draws unit shots (bolts, and shells on an arc with a ground shadow) and
    spitter globs.
  - `Fx` covers particles (shards, splinters, sparks, coins that fly to the HUD), crate taps,
    gate strikes, acid splashes, chart hits (a gold spark when weak, a grey ping when
    resisted; throttled),
    flashes, rings, tracers, beams, popups and shake. It has its own RNG and caps (400 particles, 64
    flashes).
  - `FieldView` draws the map's ground (`field/ground_<id>`), sealed portals labelled with
    their wave (and a pulse on the one opening), fading decals (splats, scorch), and the
    wall, which is tinted by HP.
- **UI:**
  - **`UiTheme`** reads the active `StyleDef` (`look`): `DEFAULT_STYLE` = `hybrid`, or
    `--style=ID` (any scene). It also sets `ThemeDB.fallback_font` and the fallback size.
    - `label(text, role, color)`, `restyle`, `style_button(b, primary, role)` (with the lip),
      `panel`, `dim`, `icon`.
    - Call sites pass roles (caption/body/label/heading/display) and palette colours
      (`UiTheme.look.coin`), never raw sizes or hex values.
  - **`TipLayer`:** the spotlight dim (`shaders/spotlight`) and one compact card on the other
    half of the screen: a picture, title and body, an extra row, page dots, and "GOT IT ▸" /
    "TAP THE GLOW".
    - A tap turns the card, but taps in the first 0.35 s are ignored.
    - On a "do" card only a tap inside the spotlight counts, and it is passed through
      (`focus_pressed`), with a chevron bobbing above.
    - It animates on unscaled time and exposes `freeze` (0..1) for the owner to stop time.
    - `unit_row` builds the weak/strong icon rows.
  - `Hud` shows wall HP, wave, the Overdrive timer, and a coin count-up and pulse.
  - `BuildMenu` is a radial unit ring with damage badges, prices and affordability. For a
    built plot it shows a card: stats, type and "strong vs", UPGRADE (or the two masteries at
    max level), and SELL.
  - `BarricadeMenu`: build, move here, upgrade, repair.
  - `EnemyIcon`: frame 0 of an enemy's atlas.
  - `CardPicker` (3 or 4 cards; "↻ REROLL" while free rerolls remain), `BuildBar` (the next wave's preview, REPAIR GATE and START WAVE, at the top
    under the HUD, so the wall spots stay clear), and `PhaseOverlay` (the result screen: VICTORY / "THE GATE FELL", a `StarRow`, waves and
    gate held, NEW BEST or the consolation line; NEXT sector (wins), RETRY, CAMPAIGN; after a
    loss it fades in once the breach has played).
  - `UnitIcon`.
  - **`AbilityButton`:** round, top right under the HUD, WAVE only. It shows the picked
    attack's icon, a cooldown pie, its short name/"Ns"/"TAP FIELD", a pulse when ready and a
    ring when armed.
  - **`AbilityPicker`:** the pick at map start. A card per attack (icon, name, one line,
    `summary()` numbers); locked cards say which sector unlocks them; NEW on unseen ones;
    DEPLOY confirms (`chosen`). Test seam: `pick(id)`.
  - **`TipLayer`** shows a card's clip (`clip_player`: a looping, muted `VideoStreamPlayer`,
    260 px) above its text.
  - **`AbilityView`** (`sim/`, two instances):
    - **links** (under the plots): dashed lines between linked pads;
    - **attacks** (over enemies): per-kind telegraphs (a blast circle with a falling shell, a
      stretch of road filling in from the middle, mine rings), burning road (one merged band
      from `Geometry2D.offset_polyline`, flames along each branch, not doubled where branches
      share road; `fx/flame`), waiting mines (`fx/mine`).
      While armed, a pulsing frame in the attack's colour around the field, plus a preview
      (circle, the stretch of road, or the five mine spots) that follows the mouse once a real mouse has
      moved (touch has no hover).
  - **`EnemyField`** draws frozen enemies as blue ice (`_frost`: 0 / 0.5 slowed / 1 frozen
    in one custom-data channel; `shaders/enemy.gdshader` mixes the ice after the texture
    product).
  - **`BuildMenu`** shows a "LINK"/"LINK×N" tag on units that would link on this pad, and
    a built unit's card lists its links and their summed bonus.
- **The view layer holds no rules.** Every action is a `Run` call.

### 3.6 Tooling (`tools/`, Python via uv)

- **`gf_tools.balance`** (`uv run balance --seeds N --maps … --strategies … --hp map=x --out
  report.md [--records raw.json]`):
  - `runner` runs one headless Godot process per (map, profile, strategy) cell in parallel,
    through `game/tools/balance_sim.gd`.
  - `report` aggregates (win rate, median and mean wave, gate, casts, unspent coins, top
    leaks), checks the B4 targets, and renders Markdown. `--abilities a,b` adds `smart+ID` and
    `casual+ID` cells (the bot takes that attack; `report.label`).
- **`gf_tools.clips`** (`uv run make-clips [ids]`): records each attack's `--demo` with Movie
  Maker at 1080×1920 (a temporary game copy with an `override.cfg`), crops a 300-unit square
  around the call (`SHOTS` framing), and writes `game/clips/ID.ogv` (Theora 400 px q5, ~70
  KB/s) plus `captures/clips/ID.mp4` for review. Needs xvfb-run and `$FFMPEG_BIN`.
  - Tests: `tests/test_balance.py`, on synthetic records.

- `gf_tools.art` generates all game art as SVG. **`terrain` reads `game/data/maps/*.tres`**
  and paints each map's ground from its own paths, plots and zones, so art and rules can't
  disagree. `uv run gen-art [--only prefix]` writes
  `game/art/`.
- **Modules:**
  - `svg`: a builder with gradients, clip paths, outlined shapes, soft shadows, glows, limbs,
    Catmull-Rom paths and `zoomed()`, limited to features ThorVG rasterizes.
    - `RASTER` (4×) for sprites; `FIELD_RASTER` (2×) for `field/` art (the grounds, the wall,
      the sealed portal).
  - `palette`: the art direction's colours, including the damage-type accents (`KINETIC`,
    `EXPLOSIVE`, `PIERCING`, `CRYO_TYPE`).
  - `enemies`: two-frame walk atlases (Drone, Skitter, Spitter, Carapace, Ravager, Splitter,
    Mender, Queen), each with a zoom. Readability floors: `LEG_MIN` and `EYE_BOOST`.
  - `units`: a base per unit (`BASES`, painted in its damage type's colour), six heads
    (`HEAD_ZOOM`) and the plot pad.
  - `props`: the wall; crates (`CRATE_ZOOM`); the barricade (3 levels plus rubble,
    `BARRICADE_W`×`BARRICADE_H`) and its slot ghost; decoration helpers.
  - `terrain`: per-map grounds and the sealed portal.
    - `BIOMES` (dusk, desert, canyon, tundra) is picked by `MapDef.biome`.
    - Lanes are sunken (a lit lip and a left-wall shadow); a vignette darkens the edges.
    - `_creep`: sparse stains, veins and pustules on the lane edges, commonest near the
      burrows and none within 200 of the wall.
  - `fx`: effect sprites and UI icons, including the 4 damage-type badges, the campaign
    stars, the 5 special-attack badges (`ui/ability_*`), `fx/flame` and `fx/mine`.
- **Deterministic:** seeded RNGs, so regenerating unchanged code changes nothing.
- **Tests:** `uv run python -m unittest discover -s tests` (from `tools/`):
  - Well-formed SVG at its raster (`field/` at 2×, the rest at 4×).
  - Determinism.
  - `game/art` matches the generator.
  - Every art key the game uses exists.
  - Every map names a known biome.

## 4. Dependency map

```
defs/*  ◀── data/*.tres ──(maps read by)──▶ tools/gf_tools.art ──(uv run gen-art)──▶ art/*.svg
  ▲                                                                                    ▲
core: RngStreams, RunModifiers, WaveSchedule, Counters, PathGeo, Economy, CardPool
  ▲
core: CombatSim  (plots, crates and taps, shots; uses WaveSchedule, Economy, RngStreams)
  ▲
core: Run  (owns CombatSim and the plots; uses Economy, CardPool; tree mods via SkillTree)
  ▲                      ▲
core: Autoplay ◀── sim/RunController ──▶ sim: FieldView, PlotField/PlotView, CrateField/CrateView,
                    │                        BarricadeField, EnemyField (+shaders/enemy), ShotField, Fx
                    │                        ── all draw through Art ──▶ art/
                    ├──▶ ui: Hud, BuildBar (EnemyIcon), BuildMenu (UnitIcon), BarricadeMenu,
                    │        CardPicker, PhaseOverlay, TipLayer (+shaders/spotlight)
                    │        ── styled by UiTheme ◀── defs/StyleDef ◀── data/styles/*.tres, art/fonts
                    └──▶ core: TipDirector ◀── RunConfig.tips (data/tips/*.tres)
core: Synergies ◀── CombatSim, Run, Autoplay, ui/BuildMenu      (data/synergies/*.tres via RunConfig)
sim: AbilityView, ui: AbilityButton, AbilityPicker ◀── RunController   (defs/AbilityDef ◀── data/abilities)
tools/gf_tools.clips ──(RunController --demo)──▶ game/clips/*.ogv ◀── TipLayer
core: SaveData ── Campaign, SkillTree ◀── ui/Session (autoload) ◀── RunController, CampaignScreen
                                                                     (SkillTreePanel, StarRow)
platform: PlatformServices ◀── StubServices ◀── Services
```

## 5. Change log

- **2026-09-29 (tip card overflow, `docs/2026-09-29-tip-card-overflow/`):**
  - `TipLayer._fit_text` gives wrapping labels in a card's extra slot the text column's width
    (`TEXT_WIDTH`). The "How to use it" card had grown to 1222 px, a whole-screen "black
    screen".
  - The dim fades with `freeze`. `card_height()` for tests; 271 game tests.

- **2026-09-28 (content expansion, Stage 2: four enemies):**
  - `EnemyDef` groups Flying, Shield, Burrow, Siege from range; `data/enemies/wasp`,
    `warden`, `burrower`, `bombardier`.
  - `CombatSim`: `Enemy.shield/shield_max/surface_d/burrow_timer/lobbing`, `hittable()`,
    `on_ground()`, `burrowed()`; `Lob`, `lobs`; `_shield` (10 Hz, `SHIELD_PERIOD`), `_burrow`,
    `_surface`, `_lob`, `_move_lobs`, `can_target`; signals `enemy_lobbed`, `lob_landed`,
    `enemy_burrowed`, `enemy_surfaced`, `shield_hit`. Ground effects (shells, mines, fire, mud,
    the barricade, escorts) check `on_ground()`; targeting and blasts check `hittable()`.
  - `Autoplay._kill_rate`: shells score 0 on flyers, shields count as HP, burrowers' uptime.
  - Art: `enemies.py` wasp/warden/burrower/bombardier + palette; `fx/mound`, `fx/glob`,
    `fx/bubble`. `EnemyField` mounds, bubbles, globs, lifted flyers. `Fx.dust`.
  - `RunController`: `--showcase`, `--gold`, `--stress=mix`, lob and burrow FX.
  - Tests: `stage2_enemies_test` (13), content (every enemy file, rules present), a scene test
    for mounds, bubbles and globs; 270 game tests.

- **2026-09-28 (napalm follows the path, the user's Stage 1 review):**
  - `AbilityDef.depth` → `length`; BURN no longer uses `radius`. Napalm: 90 of road, 5/s.
  - `CombatSim.Stretch`, `Hazard.stretches`/`half_width`/`bounds`, `burn_layout`,
    `burn_half_width`, `nearest_open_path` (shared with `mine_layout`).
  - `PathGeo.stretch`, `PathGeo.distance_to_polyline`.
  - `AbilityView` draws the road band (preview, telegraph, fire); `RunController` landing FX
    along the road; `Autoplay`/demo aim down the cluster's path; `AbilityPicker.summary`.
  - Tests: 5 new (nearest road only, merged trunk, fork, bend, `stretch`); 254 game tests.

- **2026-09-27 (content expansion, Stage 1):**
  - `AbilityDef` and five attacks in `data/abilities/`; `RunConfig.strike_*` removed;
    `RunModifiers.ability_cooldown_bonus` (was `strike_cooldown_bonus`).
  - `CombatSim` casts (`Cast`, `Hazard`, `Mine`, `Enemy.stun`); `Run.choose_ability` /
    `call_ability`.
  - `AbilityPicker`, `AbilityButton` (was `StrikeButton`), `AbilityView` (was `StrikeView`).
  - Tips `ability_ready` and `ability_intro` (was `strike`); `TipCard.clip` and clips in
    `TipLayer`.
  - Save v7 (`abilities.last`); unlocks follow `campaign.cleared`.
  - The bot's `ability_target` per kind. `BalanceRun` records `ability`/`casts`. The tool
    gains `--abilities` and `uv run make-clips`.
  - Art: `ui/ability_*`, `fx/flame`, `fx/mine`; frozen enemies as ice.
  - 249 game + 12 tool tests.

- **2026-09-27 (art readability):**
  - 4× sprites and mipmaps (`Art.scale_of`, `RASTER`/`FIELD_RASTER`).
  - Readable enemies (ink, legs, eyes, recoloured Mender and Ravager, small ones ×1.1).
  - Damage-type colours and a base per unit; heads ×1.1.
  - Crates ×1.35 with radii 24/30/24.
  - Barricade 144×52, `BARRICADE_HALF_DEPTH` 16, the slot ghost and footprint taps.
  - Biome grounds (`MapDef.biome`, `terrain.BIOMES`), sunken lanes, a vignette and a subtle
    creep.
  - `props._rock` takes a biome's colours.
  - 233 game + 11 tool tests.

- **2026-09-27 (B4):**
  - The balance tool: `Autoplay` presets, `BalanceRun`, `balance_sim.gd`, and
    `gf_tools.balance`.
  - The counter-pick rewrite (kill rate, gate-damage need, look-ahead).
  - Tuning: light units up, Rail and Mortar trimmed, Skitters resist explosive, deal 4 and
    come ×1.6; Switchback HP ×0.82.
  - Juice: button squash, star pop-in, gate count-up, falling shell, upgrade pop.
  - 232 game + 10 tool tests.

- **2026-09-27 (E5c):**
  - The artillery strike (core `Strike`, `Run.call_strike`, the button, aim mode, FX) and the
    Fire Mission card.
  - Unit synergies: `StatBonus`, `SynergyDef`, `Synergies`, 21 pairs, link lines, previews.
  - Strike and synergy tips; the barricade tip waits for wave 2.
  - The bot places for links and strikes. Wave HP ×1.35/1.25/1.1 and the strike toned down
    to 20/30 s to hold the campaign curve.
  - 229 game + 5 tool tests.

- **2026-09-27 (E6):**
  - The visual style is data (`StyleDef`, `data/styles/hybrid.tres`). The user compared three
    directions and picked a hybrid: Arcade's fonts and shapes with Command's colours. Fonts
    are bundled (Lilita One, Nunito; OFL).
  - Every text size is now a role (nothing below 15 px), and every colour has one meaning.
  - The banner lane.
  - The build ring is wider; the build-bar hint is removed and the bar is 128 tall.
  - Contextual tips: `TipDirector`, `TipLayer`, 18 tips, save v6, a settings card. They
    replace the `IntelCard`.
  - Descriptions are ≤ 80 characters.
  - 211 game + 5 tool tests.

- **2026-09-27 (E5b):**
  - The campaign: stars per sector, unlocking in order, a consolation star.
  - The skill tree (15 nodes; 10 new modifier fields; Last Stand and Iron Gate queued after
    the move pass).
  - Save v5 wired in through `Session`. The brick meta is retired (`MetaProgress`,
    `MetaUpgradeDef`, `data/meta/`, bricks) and kept as `legacy`.
  - The campaign screen is the main scene; the skill-tree panel; stars on the result screen;
    card reroll.
  - Switchback Ridge (sector 3).
  - The difficulty curve re-tuned against tree profiles; star art.
  - 197 game + 5 tool tests.

- **2026-09-27 (E5a):**
  - Destroyable units (HP, repair).
  - The Ravager, Splitter and Mender; elites.
  - Waves on both maps extended and retuned; unit HP doubled after traces.
  - 173 game + 5 tool tests.
- **2026-09-26 (E4):**
  - Paths replace lanes (`PathGeo`, movement by distance, least-distance-left targeting).
  - Portals open mid-run, plots unlock, terrain (mud, high ground).
  - Maps are levels with their own waves; Canyon Pass is the second map.
  - Grounds are painted from map data; map switching.
  - 162 game + 5 tool tests.
- **2026-09-26 (E3):**
  - The counter chart (damage types, weaknesses, resistances, armour).
  - Selling at 50%, a 1 s setup mid-wave, masteries.
  - The barricade, gate repair, escorts, beam caps.
  - Preview and intel cards.
  - Waves re-authored.
  - The counter-picking bot.
  - 148 game + 5 tool tests.
- **2026-09-26 (E2):**
  - The gate siege: enemies stop at the gate and strike until killed, and the run is lost
    when it breaks, with the breach presentation.
  - The Spitter (it jams units from range; not at the gate), with generated art.
  - The HP ramp is ×0.65; 123 game + 5 tool tests.
- **2026-09-26:**
  - Fixed units and wall spots.
    - The aimed squad was removed with everything around it: `SquadStats`,
      `SquadUpgradeDef`, the squad views and panel, drag/tap input, and the squad
      cards/meta.
    - Crates now break by tapping (`Run.tap`); Overdrive boosts the units.
    - The wall gets 3 spots.
    - New modifiers: unit damage, reach, crit.
  - Save v4 refunds `recruits`. The build bar moved to the top.
  - 110 game + 5 tool tests.
  - The escalating-difficulty research opened (paths instead of lanes, enemy mixes, volume,
    sectors, the loss condition).
- **2026-09-25:**
  - Build spots, loot crates, reload trade-off; gates removed (pivot); first-pass balance
    (difficulty ramp per wave).
  - Procedural SVG art slice with a new `tools/` package; new UI (radial build menu, cards,
    squad panel); save v3.
  - 109 game + 5 tool tests.
- **2026-09-25:** B2: run scene and batched renderers, drag/tap input, placeholder BUILD/CARD,
  clip capture, `--stress`/`--perf`; 97 tests.
- **2026-09-24:** B1: core rules layer, defs, content, platform stub, 85 tests; squad
  bullet-per-second cap added.
- **2026-09-24:** B0: Godot 4.7.2 in `.tools/`, GdUnit4 6.2.1 vendored, `game/` skeleton,
  `scripts/test.sh`.
- **2026-09-24:** `ROADMAP.md` added (bundles B0–B19, gates D1–D3).
- **2026-09-24:** prototype work item opened (research + plan).
- **2026-09-24:** market research (base-defense section; recommendation).
- **2026-09-24:** repository created.
