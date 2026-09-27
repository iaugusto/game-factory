# Implementation log — build spots, loot crates, reload, art slice

Running log, newest at the bottom.

## 2026-09-25 — setup

- Work item opened from the user's request. `research.md` written (web sources for Kingdom
  Rush plots, Last War barrels, Steam AI disclosure, Kenney CC0, Godot 2D lights on mobile).
- The user answered: build any time; plots on the field; procedural art, slice first. Gates
  questioned by the user; research §8 recommends dropping them, and the user approved ("sounds
  good, let's press forward").
- Baseline before any change: `scripts/test.sh` → **97/97 passed**.
- Probe: Godot 4.7.2 imports a hand-written SVG with a radial gradient at its `width/height`
  (2× the viewBox) with transparent edges. So the art source can be SVG, with no bake step.
- `plan.md` written.

_The entries below were written at 23:30 from the session's working notes. They are in true
order; only this heading has a clock time. (The log should have been appended step by step.
It was batched here, and the notes are exact about what happened.)_

## 2026-09-25 23:30 — core rules, content, first-pass balance

- **Safety snapshot.** Nothing in the repo is committed yet, so `game/` and the docs were
  tarred to the session scratchpad (`game-before-spots.tgz`) before any deletion.
- **Defs:**
  - New: `unit_def.gd` (Attack BULLET/SHELL/HITSCAN/BEAM, Role, reload, reach, splash/slow,
    per-level growth, `damage_at/reload_at/dps_at`), `crate_def.gd`, `crate_spawn.gd`,
    `map_def.gd` (plots as `PackedVector2Array`), `squad_upgrade_def.gd`.
  - Deleted: `turret_def`, `gate_def`, `gate_spawn`.
  - `wave_def` gained `crates`, plus `hp_scale`/`speed_scale` (see balance).
  - `run_config` gained `map`, `units`, `squad_upgrades`, `lane_jitter`/`jitter_for()`,
    `build_menu_time_scale`, and `start_gold` 45. `turret_slots` is gone.
- **Core:**
  - `combat_sim.gd` rewritten. It covers:
    - Plots with reload-driven fire and "first in reach" targeting.
    - Unit shots: homing bullets that fizzle, ground-targeted shells, hitscan, and lane beams.
    - Crates hit only by squad rifle bullets when in front, lost at the wall.
    - A boost crate.
    - Enemy `x` in core (the lane spread moved from the view, so shots and range agree with
      what is drawn).
  - `run.gd`:
    - The run opens in BUILD, and `start_wave()` starts each wave.
    - A cleared wave goes to CARD, then BUILD.
    - build/upgrade/squad upgrades work in BUILD and WAVE.
    - `state_hash` covers plots, crates, shots, boost and squad levels.
  - Also changed: `economy` (unit/crate/squad prices), `run_modifiers` (gate keys out;
    `shooters_bonus`, `crate_reward_bonus`, `crate_damage_bonus`, `unit_*` in),
    `squad_stats` (gate mutators out), `wave_schedule` (CRATE events), and `autoplay`
    (threat → crate → front aim; build order, plot order, cheapest-upgrade spending;
    `step_wave`).
  - `gate_math.gd` deleted.
- **Save v3.** `REMOVED_META_COSTS` refunds `gate_lore` and `fifth_slot` levels as bricks.
  `SaveData` isn't wired into the game yet (B3), so no real save exists; the migration is for
  correctness.
- **Reload epsilon.** Found by `test_unit_fires_once_per_reload` while writing it: without an
  epsilon, float drift in `cooldown - dt` made a 0.5 s reload fire a tick late.
  `READY_EPSILON` added.
- **Content.** Written by a one-off generator (session scratchpad `gen_content.py` plus
  `tune.json`; the `.tres` files are the source of truth):
  - 6 units, 3 crates, the `outpost` map (8 plots), 3 squad upgrades.
  - Cards: `lucky_gates`/`soft_gates` replaced by `scavengers`/`crowbars`; the others rekeyed.
  - Meta: `gate_lore`/`fifth_slot` replaced by `salvage`/`war_chest`.
  - Enemies renamed in display only (Drone, Skitter, Carapace, Hive Queen).
  - 10 waves with crates.
  - `data/gates/` and `data/turrets/` deleted.
- **Tests:**
  - Fixtures rewritten.
  - `combat_sim_test` (20), `run_test` (12), `economy_test` (6), `content_test` (12, now
    including the design rules), and the integration suite (5, now including a zero-meta
    difficulty guard) rewritten.
  - `save_data_test` gained the v3 refund case.
  - `gate_math_test` and `gate_format_test` deleted.
  - First run: **91/92**. The failure was the difficulty guard: the bot won 8/8 at zero meta
    and the wall was never touched.

### Balance, first pass (the guard's finding)

1. **Probes** (scratch `balance_probe.gd`, `sweep.gd`, `sweep2.gd`, 8–12 seeds each):
   - Before: every seed WON with the wall at 100. The only wall damage all run was the Hive
     Queen.
   - Why: player DPS far exceeded enemy HP. Level 3 was ×2.8 DPS (+50% damage and −15%
     reload per level).
2. **Changes:**
   - Per-wave `hp_scale` (1 + 0.85·i^1.25 → ×14.25 at wave 10) and `speed_scale` (+3%/wave,
     the B2 feedback "enemies faster over time").
   - Per-level growth down to +35% damage and −10% reload (level 3 ≈ ×2.1).
   - Hive Queen `wall_damage` 999 (reaching the wall ends the run; before, a regen card could
     leave the wall at 0.0x HP and still WIN) and base HP 250.
3. **Result:**
   - Zero meta: waves cleared `[8, 9, 8, 7, 9, 7, 8, 7]`, **0 wins**.
   - A mid meta (+60 wall, +3 shooters, +30 coins, −16% prices, +20% crates): **3/12 wins**.
   - That matches the prototype plan's target (a first run loses around waves 6–8; meta makes
     wins reachable).
   - B4 still does the real tuning and the strategy comparison.

## 2026-09-25 23:30 — art pipeline and art slice

- **`tools/`** is now a real uv package (`gf-tools`, stdlib only, Python 3.12). `uv sync`
  fetched only the `hatchling` build backend.
  - `uv run gen-art` writes `game/art/**.svg` (34 files).
  - Modules: `svg` (builder and helpers), `palette`, `enemies`, `units`, `props`, `fx`, `cli`.
- **Previews.** A scratch Godot script rasterizes SVGs to contact sheets
  (`Image.load_svg_from_string`); every asset was checked this way before use.
- **Fixes from the sheets:**
  - Enemy legs were low contrast (limb highlight added).
  - The Queen's legs looked like sticks (thicker).
  - Skitter legs bled across atlas frames (shorter, and each frame clipped to its box).
- **Engine side** (`src/sim`, `src/ui`, `shaders/enemy.gdshader`):
  - New files:
    - Art: `Art` (texture registry).
    - Rendering: `PlotField`/`PlotView`, `CrateField`/`CrateView`, `ShotField`, `Fx`
      (replaces `Effects`).
    - UI: `UiTheme`, `UnitIcon`, `BuildMenu`, `CardPicker`, `SquadPanel`, `BuildBar`.
  - Rewritten: `EnemyField` (textured batches, shadow batch, shader custom data, HP-bar
    layer), `FieldView`, `BulletField`, `SquadView`, `Hud`, `PhaseOverlay` (result only),
    `RunController`.
  - Deleted: `gate_view`, `turret_row_view`, `effects`, `gate_format`.
  - Added `CombatSim.end_wave()`, so bullets and shells don't hang mid-air during BUILD and
    leftover crates are reported lost.
- **Stills** (Movie Maker, 540×960) found five bugs, all fixed:
  1. The Carapace under sustained fire was a solid white blob. The flash is now capped at
     0.55 and retriggers at most every 0.14 s: a flicker.
  2. Slowed enemies looked like ghosts (a multiplied tint). Frost is now a separate
     shader channel mixing toward icy blue.
  3. The squad was nearly invisible. Troopers are ×1.45 on a lit platform that follows them.
  4. The Drone read red rather than ember. Its palette moved toward orange.
  5. The upgrade card covered its own unit. It was positioned before its text was set; it is
     now placed after `sync`.
- **Dev-only launch args** `--open-plot=N` and `--open-squad`, for UI screenshots.

## 2026-09-25 23:30 — scene tests, performance

- `run_scene_test` rewritten (17 cases): BUILD bar and pads; tap a plot → menu → build;
  affordability greying; upgrade card; mid-wave slow-mo and restore; drag; a press on a plot
  never steers the squad; tap mode; emulated mouse ignored; autoplay ignores the pointer;
  views mirror core; clear → cards → build bar; squad panel buys; full run → result →
  restart; one batch per enemy type; crate views pooled; popups clamped.
- First run: 108/109. `test_views_mirror_core_state` assumed enemies were alive at 10 s into
  wave 1, but the defenders had killed them all. It now ticks until one is alive.
- **`scripts/test.sh` → 109/109 passed.**
- **Frame time** (`--stress --perf`, WSLg, OpenGL 3 via D3D12, RTX 3070; 260 enemies, ~560
  bullets, 8 plots firing):
  - First measure: sim tick 5.6 ms. Suspecting `first_in_reach` (a full scan per idle plot
    per tick), it was rewritten as a per-lane binary search over the y-sorted lanes. That's
    the right shape regardless.
  - A section profile (scratch `prof.gd`) then showed the whole sim at ~0.45 ms/tick in
    *every* window. The high first window is the monitor absorbing start-up hitches, not
    gameplay.
  - **Steady state: 160–165 fps, frame avg 6.1 ms (max ≤ 10 ms, one 33 ms spike),
    sim tick ~0.8 ms, 51–56 draw calls** (B2: 130–186 fps, 5.4–7.7 ms, 80 draw calls).
    Within budget on desktop. The phone measurement is still B5.

## 2026-09-25 23:35 — clips, tool tests, docs, closeout

- **Tool tests** (`tools/tests/test_art.py`, stdlib unittest via `uv run`): every asset is
  well-formed SVG at 2×; generation is deterministic; committed `game/art` matches the
  generator; every art key the game uses exists. **5/5 pass.**
- **Clips** (`scripts/capture_clip.sh`, checked frame by frame before handing over):
  - `captures/spots-loot-midgame.mp4` (24 s): seed 5, autoplay from wave 5's build phase.
  - `captures/spots-loot-boss.mp4` (22 s): seed 2, wave 10 with the Hive Queen.
  - The first boss take (seed 8) showed only the defeat screen: that seed loses at wave 8 in
    the fast-forward, which is the difficulty doing its job. Re-shot with seed 2, which
    reaches wave 10.
  - UI stills (build ring, upgrade card, squad panel, card picker) were checked the same way.
  - The scratch `probe1.mp4` was deleted.
- **Docs:**
  - `detailed-project-overview.md` rewritten (map, systems, rules, dependency map, change
    log).
  - `README.md`: status, layout, quick start, args.
  - `ROADMAP.md`: the pivot recorded; the pivot row added; B3 re-scoped to meta and save; B4
    status; B6 marked partly done.
  - `CLAUDE.md`: §1 status (it was stale: "concept selection"), §4 art-is-generated rule,
    §6 commands.
  - `project.godot`: the description.
- **Final:** `scripts/test.sh` → **109/109 passed**, exit 0. Tools → **5/5 OK**.

### Not done here, on purpose

- **Real device performance** (B5). Desktop is measured above.
- **Meta screen and save wiring** (B3).
- **Balance-bot report and fine tuning** (B4).
- **Audio** (B11).
- **Alternative art directions** (B6, if the user wants to compare).
- **Selling units, enemies that attack units, more maps.**

### Known rough edges (for the user's review, not bugs in the rules)

1. **The "WAVE N INCOMING" banner overlaps an open build menu** for its first second.
2. **The squad count label sits beside the platform.** At 60+ shooters the platform grows
   wide.
3. **Coin tags on crates are small at phone size.**
4. **Drag vs tap is still an open question** (from B2). The toggle is on the BUILD bar and on
   T.

**Status: complete.** 👤 Checkpoint pending: the user judges the clips and stills (the feel,
the loop and the art direction) and plays a build.
