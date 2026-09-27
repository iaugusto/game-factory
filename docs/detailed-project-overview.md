# Detailed Project Overview

> **Purpose.** This is the canonical, always-current index of the project: every file, system
> and function, its rationale, and its dependencies. It exists so that humans and language
> models can load precise context in complex workstreams without reading the whole tree.
>
> **Maintenance rule.** Any change to the codebase structure must update this file in the
> same change. A stale overview is a bug. Mark each entry `existing` or `planned`.

_Last updated: 2026-09-27 — **new enemies, destroyable units and elites** (work item
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
- **Tests:** 173 game tests plus 5 tool tests pass.
- **Next:** E5b: sectors (a campaign of maps) with saves and a skill tree; then E5c, the
  active ability and synergies
  (`ROADMAP.md`; the plan is in `2026-09-26-escalating-difficulty/`).

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
- A pick-1-of-3 **card** follows each wave, and **bricks** buy permanent upgrades between runs.

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
| `docs/2026-09-26-counters-and-coin-sinks/` | existing | E3: the counter chart, sell, masteries, barricade, gate repair, preview and intel cards, escorts, waves re-authored, bot counter-picking, balance log. |
| `game/` | existing | Godot 4.7.2 project root. |
| `game/project.godot` | existing | Portrait 540×960, `canvas_items`/`expand` stretch, Mobile renderer, ETC2/ASTC, GdUnit4 plugin, autoload `Services`, `game/platform/provider` = `stub`. |
| `game/scenes/run.tscn` | existing | The main scene: one `Node2D` with `run_controller.gd`; children are built in code. |
| `game/src/core/` | existing | The rules, as pure `RefCounted` classes (§3.1). Everything here runs headless. |
| `game/src/defs/` | existing | Typed `Resource` classes the content is made of (§3.2). |
| `game/src/platform/` | existing | Platform services: interface, stub, registry autoload `Services` (§3.4). |
| `game/src/sim/` | existing | Presentation over core (§3.5). No rules. |
| `game/src/ui/` | existing | HUD, build menu, card picker, build bar, result screen, theme (§3.5). |
| `game/shaders/enemy.gdshader` | existing | Enemy batches: walk-frame atlas, hit flash and frost overlay from per-instance custom data. |
| `game/art/` | existing (generated) | SVG source art (46 files; one ground per map), **written by `tools/`** (`uv run gen-art`). Don't hand-edit; change the generator. Godot rasterizes at 2×. |
| `game/data/` | existing | The content as `.tres` (§3.2): `units/` (6), `crates/` (3), `maps/` (2 levels: `outpost.tres` with 3 straight paths, 11 plots and waves `waves/wave_01..10`; `canyon.tres` with 4 paths, 15 plots, mud and high ground, and waves `waves/canyon_01..10`), `enemies/` (8), `elites/` (3), `masteries/` (7), `barricade.tres`, `cards/` (11), `meta/` (6), and `run_config.tres` (lists the maps). |
| `game/addons/gdUnit4/` | existing | Vendored GdUnit4 v6.2.1 (MIT). Don't edit. |
| `game/tests/fixtures.gd` | existing | `Fixtures`: tiny explicit content builders plus a 4-plot map. |
| `game/tests/core/*_test.gd` | existing | One suite per core file, plus `content_test` (integrity and design rules of `res://data`), `platform_test` and `toolchain_test`. |
| `game/tests/integration/run_integration_test.gd` | existing | Real content plus Autoplay: wave 1 cleared with crates broken; deterministic full run; seeds diverge; unit-shot budget; **zero-meta difficulty guard**. |
| `game/tests/integration/run_scene_test.gd` | existing | The real scene, headless (24 cases): plot input and build menu, wall spots, crate taps, jammed units, the breach, sell and masteries, the barricade card, the wave preview and gate repair, intel cards, slow-mo, the flow screens, pooling, batching. |
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
| `path_geo.gd` | `PathGeo` | A path's geometry: distance along it ↔ position, normals, `d_at_y`, nearest point, and a walker's cached segment. | Lets enemies move by distance on bent paths while targeting stays a binary search. |
| `run.gd` | `Run` | One run. Phases `BUILD → WAVE → CARD → BUILD … → WON/LOST`; the run **opens in BUILD** (prep). State: the wall/gate (HP = max − damage taken), coins (`gold`), `plots` (from the map, with unlock waves), cards, the barricade (in the sim). `plot_open`, `open_paths`, `newly_open_paths`, `unit_repair_cost`/`repair_unit` (build sets unit HP; upgrade keeps damage taken). Methods: `start_wave()`, `step()`, `tap(field_pos)` (WAVE only); `build` (1 s setup mid-wave), `upgrade`, `sell` (50% of `Plot.spent`), `buy_mastery`, `build_barricade` (a free move in BUILD), `upgrade_barricade`, `repair_barricade` (**BUILD and WAVE**); `repair_gate` (BUILD); `pick_card(i)`. Also `bricks()`, `state_hash()`. | The state machine lives in core so a run plays headless. Spending mid-wave is the point: crate coins are meant to be used while the fight is on. |
| `combat_sim.gd` | `CombatSim` (+ `Enemy`, `Crate`, `Plot`, `Shot`, `Spit`) | The WAVE tick: spawns (elites applied); moves enemies (unit attackers stop at a unit in reach and destroy it: `unit_struck`, `unit_destroyed`; an enemy at the gate **sieges**: it stops and strikes every `attack_interval` until killed) and crates; spitters spit at the nearest working unit in range (not while sieging) and globs jam units (`Plot.disabled`); Menders heal neighbours (`mender_pulse`); Splitters burst into their brood on death (inserted in sorted order); fires every working plot; moves unit shots and globs; `end_wave()` cleans up. **Every hit goes through `effective_damage`** (armour, floored, then ×2 weak / ×0.5 resisted; `enemy_hit` reports the chart's effect). Per-plot stats (`plot_damage/reload/reach`) fold in modifiers, the mastery and the boost. **The barricade** (`Barricade`) stops enemies on the paths through it until it breaks. **Escorts:** a small enemy can't pass a much bigger one ahead on its path. Beams stop at `beam_max_targets`. The barricade blocks every path passing within 40 of its slot (`place_barricade`, per-path stop distances). `tap_crate_at(p, dmg)` is the only way to hit a crate. `reload_of` (with the Overdrive boost), `damage_of` and `reach_of` apply the run's modifiers. Unit shots can crit. Signals: `enemy_spawned/killed/struck/hit`, `crate_spawned/tapped/broken/lost`, `spit_fired`, `unit_disabled`, `unit_fired`, `shell_landed`, `boost_started`, `barricade_struck/broken`. | **Enemies and crates move by `d`** (distance along their path, `PathGeo`); paths are sorted by `d`. **Units** target "first in reach", the least distance left, by binary search over a `d` window per nearby path (a full scan was too slow for phones). Mud slows; high ground adds plot reach. Portals open per wave (`set_open_paths`). Attacks: BULLET (homing, fizzles), SHELL (lands where the target *was*; fast enemies dodge), HITSCAN, BEAM (up to `beam_max_targets` on the target's path within reach). Enemy `x` lives in core so range and shots match the drawing. |
| `wave_schedule.gd` | `WaveSchedule` | `WaveDef` → time-sorted ENEMY and CRATE events; random paths (among the open ones) resolved up front from the `spawn` stream. `enemy_counts`, `new_enemies` (first sight, for intel cards), `threat`. | Fixes the whole wave at its start. |
| `counters.gd` | `Counters` | Chart queries for the UI and tests: `units_strong_vs`, `units_weak_vs`, `enemies_countered_by`. | The damage math stays in `CombatSim.effective_damage`. |
| `economy.gd` | `Economy` | Kill reward (a trickle), crate reward (with `crate_reward_bonus`), unit build/upgrade prices (discounted, capped at 90%), bricks. | — |
| `card_pool.gd` | `CardPool` | The weighted pick-1-of-3 draw: no duplicates, skips maxed and weight-0 cards. | — |
| `run_modifiers.gd` | `RunModifiers` | Additive bonuses fed by cards and meta, addressed by field name; `has_key()` validates content. | A new bonus is one field plus the code that reads it. |
| `meta_progress.gd` | `MetaProgress` | Brick balance, meta levels, buying, `to_modifiers()`. | — |
| `save_data.gd` | `SaveData` | Versioned save (**v4**); migrations v1→v2→v3→v4. v3 refunds the removed `gate_lore`/`fifth_slot` levels as bricks, and v4 refunds `recruits` (`_refund_removed`). Atomic writes; an unreadable save goes to `.bad`. | `CLAUDE.md` §4: migrate, never reset. Not wired into the game until B3. |
| `rng_streams.gd` | `RngStreams` | Named streams (`spawn`, `cards`, `combat`), each seeded from `"<seed>:<name>"`. | Drawing more from one stream never shifts the others. |
| `autoplay.gd` | `Autoplay` | A scripted player. It taps the crate nearest the gate at `taps_per_second` (3, tick-based). It **counter-picks**: it fills the biggest gap, the enemy type its units kill slowest relative to count × threat, with the most cost-effective counter. It saves for that unit unless under siege, and builds next to siegers. It repairs units below 60% HP first. It raises the barricade where it blocks the most threat after 3 units, builds only on open plots, repairs the gate and barricade, and buys the cheapest upgrade (level, Overcharge, barricade level). `step_wave()` and `play()`. | Used by the tests, `--autoplay`, fast-forwards, and the balance probes. Knobs: `chase_crates`, `taps_per_second`, `counter_pick`, `build_order`, `max_units`, `barricade_after_units`, `repair_gate_below`, `card_choice`. |

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
  `barricade_slots`, `zones` (`ZoneDef`: MUD / HIGH_GROUND), `waves`.
- **`EliteDef`** (HP ×, speed ×, armour bonus, regen, tint); `SpawnEntry.elite` marks a group.
- **`MasteryDef`** (bonuses to damage, reach, reload, splash and slow, plus armour pierce) and
  **`BarricadeDef`** (HP per level, costs, repair per HP).
- **`EnemyDef`** (with `description`, the counters `weak_to`/`resists`/`armor`/`threat`,
  `attack_interval` for the siege and an optional Spit group:
  `spit_interval`, `spit_range`, `spit_speed`, `disable_duration`), **`SpawnEntry`**,
  **`WaveDef`** (spawns, crates,
  **`hp_scale`/`speed_scale`**: the difficulty ramp), **`CardDef`**, **`MetaUpgradeDef`**.
- **`RunConfig`:** the playfield (`field_width`, `wall_y`; `jitter_for(spread, radius)`), `maps`
  and `for_map(m)`, units (`crit_multiplier`,
  the chart's `weak_multiplier`/`resist_multiplier`/`armor_floor`, `sell_refund`,
  `build_setup_time`), crates (`tap_damage`, `tap_slop`), base (`gate_repair_hp`/`cost`,
  `barricade`), the presentation knob
  `build_menu_time_scale`, and the content lists (`map`, `waves`, `units`, `cards`,
  `meta_upgrades`).

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
  - The second map out-threatens the first, wave by wave.
- Every crate breaks in under half its travel time at 3 taps/s, and takes more than one tap.
- Every enemy strikes the gate on an interval. Some unit outranges every spitter, and
  spitters appear no earlier than wave 4, at most two at first.
- **The chart:** every enemy has exactly one weakness (never also a resistance) and an intel
  line. Every damage type is some enemy's answer and has a unit. Wave threat strictly
  rises. Every unit offers Overcharge plus its own trait. Barricade slots each
  block a path in front of the wall.

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
- **Cards (11):** bounty, crits (units), crowbars (taps), masonry, field repairs, overclock,
  permafrost, rangefinder (+10% reach), skitter bounty, sharpened (+15% unit damage),
  scavengers.
- **Meta (6):** engineers, salvage, drill (−5% reload per level), thick walls, treasury, war
  chest.

### 3.3 Rules in brief

- **Playfield:** 540 wide; the gate at y = 860; a fixed tick at 60 Hz.
- **Maps:**
  - **Frontier Outpost:** 3 straight paths.
  - **Canyon Pass:** two entrances merging into a trunk (with mud), a left flank breach at
    wave 4 and a right one at wave 7, pads unlocking at waves 4 and 7, and a high-ground pad.
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
- **Difficulty:** first pass. Outpost HP scale peaks at 6.8 (waves 8–10 carry their weight in
  new types and volume). Bot (12 seeds): Outpost zero meta median 7, mid meta 4/12 wins;
  Canyon median 6, 1/12. The zero-meta counter-picking bot
  clears a median of 8 waves with 0 wins; a mid meta wins 6 in 12. It gets by with Snipers and
  Mortars; making Skitters and Spitters demand their counters is open (E3 log). Without taps, every run dies at wave 2. Maxed-out runs pile up unspent
  coins (no late sink yet). B4 and the escalating-difficulty work tune it.

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
  - On LOST it plays the **breach**: a shake, blasts along the wall, "THE GATE HAS FALLEN",
    and 1.2 s of slow motion (`BREACH_TIME`) while the result waits to fade in.
  - While a menu is open mid-wave, `Engine.time_scale = build_menu_time_scale` (slowed, not
    paused).
  - Test seams: `tick(n)`, `sync_views()`, `handle_pointer()`, `open_plot()`, `start_wave()`,
    `fast_forward_to_wave(k)` (stops at BUILD of wave k), `fast_forward_seconds(s)`.
  - Maps: `--map=ID`; `base_config` and `config = base.for_map(...)`; `switch_map` and the
    result screen's "PLAY <next map>". The build phase announces "NEW BREACH!" when a portal
    opens.
  - Launch args: `--seed --map --autoplay --skip-to-wave --skip --perf --quit-on-end`, and dev-only
    `--stress --open-plot=N`.
- **Art:**
  - `Art` resolves `res://art/<key>.svg` (cached) and draws at `SCALE` 0.5, because the
    textures are 2×.
  - It also provides `quad()` (explicit-UV meshes for MultiMeshes) and `additive()`.
- **Batching is the performance rule:**
  - `EnemyField` is one textured MultiMesh per enemy type plus one shadow batch; HP bars sit
    on one layer. Elites are tinted (instance colour) and starred. `position_of` holds enemies at the wall's top edge and adds the siege
    lunge.
  - **Never add a node per enemy or bullet.** (B2: 599 → 80 draw calls; now 51–56 at budget
    load.)
- **Node-per-object is fine only for the few:**
  - `BarricadeField`: the slots (faint outlines between waves) and the barricade (level
    sprite or rubble, HP bar, shake).
  - `PlotField`/`PlotView` (≤ 11): base, turning head, recoil, muzzle flash, reload ring,
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
  - `UiTheme` holds the shared styles.
  - `Hud` shows wall HP, wave, the Overdrive timer, and a coin count-up and pulse.
  - `BuildMenu` is a radial unit ring with damage badges, prices and affordability. For a
    built plot it shows a card: stats, type and "strong vs", UPGRADE (or the two masteries at
    max level), and SELL.
  - `BarricadeMenu`: build, move here, upgrade, repair.
  - `IntelCard`: "NEW THREAT", shown before an enemy's first wave, with "weak to" and
    "shrugs off" as unit icons.
  - `EnemyIcon`: frame 0 of an enemy's atlas.
  - `CardPicker`, `BuildBar` (the next wave's preview, REPAIR GATE and START WAVE, at the top
    under the HUD, so the wall spots stay clear), and `PhaseOverlay` (the result screen, "THE GATE FELL"; after a loss it fades in once the breach
    has played).
  - `UnitIcon`.
- **The view layer holds no rules.** Every action is a `Run` call.

### 3.6 Tooling (`tools/`, Python via uv)

- `gf_tools.art` generates all game art as SVG. **`terrain` reads `game/data/maps/*.tres`**
  and paints each map's ground from its own paths, plots and zones, so art and rules can't
  disagree. `uv run gen-art [--only prefix]` writes
  `game/art/`.
- **Modules:**
  - `svg`: a builder with gradients, clip paths, outlined shapes, soft shadows, glows, limbs
    and Catmull-Rom paths, limited to features ThorVG rasterizes.
  - `palette`: the art direction's colours.
  - `enemies`: two-frame walk atlases (Drone, Skitter, Spitter, Carapace, Ravager, Splitter,
    Mender, Queen).
  - `units`: two bases, six heads and the plot pad.
  - `props`: wall, crates, the barricade (3 levels plus rubble), and decoration helpers.
  - `terrain`: per-map grounds and the sealed portal.
  - `fx`: effect sprites and UI icons, including the 4 damage-type badges.
- **Deterministic:** seeded RNGs, so regenerating unchanged code changes nothing.
- **Tests:** `uv run python -m unittest discover -s tests` (from `tools/`):
  - Well-formed SVG at 2×.
  - Determinism.
  - `game/art` matches the generator.
  - Every art key the game uses exists.

## 4. Dependency map

```
defs/*  ◀── data/*.tres ──(maps read by)──▶ tools/gf_tools.art ──(uv run gen-art)──▶ art/*.svg
  ▲                                                                                    ▲
core: RngStreams, RunModifiers, WaveSchedule, Counters, PathGeo, Economy, CardPool, MetaProgress
  ▲
core: CombatSim  (plots, crates and taps, shots; uses WaveSchedule, Economy, RngStreams)
  ▲
core: Run  (owns CombatSim and the plots; uses Economy, CardPool; meta via MetaProgress)
  ▲                      ▲
core: Autoplay ◀── sim/RunController ──▶ sim: FieldView, PlotField/PlotView, CrateField/CrateView,
                    │                        BarricadeField, EnemyField (+shaders/enemy), ShotField, Fx
                    │                        ── all draw through Art ──▶ art/
                    └──▶ ui: Hud, BuildBar (EnemyIcon), BuildMenu (UnitIcon), BarricadeMenu,
                             IntelCard, CardPicker, PhaseOverlay
                             ── styled by UiTheme
core: SaveData ── MetaProgress          platform: PlatformServices ◀── StubServices ◀── Services
```

## 5. Change log

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
