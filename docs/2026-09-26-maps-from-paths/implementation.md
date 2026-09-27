# Maps from paths (E4): implementation log

## 2026-09-26 — defs and core

- **New defs:**
  - `PathDef`: points (y strictly increasing, ending at the gate), `spread`,
    `opens_at_wave`.
  - `ZoneDef`: MUD or HIGH_GROUND, with center, radius and value.
- **`MapDef`** is now a level: `paths`, `plots`, `plot_unlock_waves` (with `plot_unlock_wave`),
  `barricade_slots`, `zones`, `waves`.
- **`RunConfig`:**
  - `lane_count`, `lane_width` and `lane_jitter` are replaced by `field_width`. `jitter_for`
    is now `static jitter_for(spread, radius)`.
  - New: `maps`, `for_map(m)` (a shallow copy with the map and its waves), `map_by_id`.
  - `run_config.tres` no longer lists waves: each map owns its own.
- **`SpawnEntry.lane` and `CrateSpawn.lane`** become `path` (-1 = a random open path).
- **`PathGeo`** (new, pure):
  - cumulative lengths and per-segment normals;
  - `point_at`, `direction_at`, `normal_at`, `d_at_y`, `nearest` (the closest centre-line
    point and its distance);
  - the walker cache `segment_from` / `point_on`.
- **`CombatSim`:**
  - `lane_*` becomes `path_enemies` / `path_crates`, sorted by `d` (distance along the path)
    instead of y.
  - Enemies carry `path`, `d`, `offset` and a cached `seg`. x and y are derived each move.
    Crates follow the centre line.
  - `first_in_reach`:
    - skips paths whose static `Plot.path_dist` is beyond reach + spread;
    - maps the reach circle's y range to a `d` window (`d_at_y`), binary-searches it, and
      takes the enemy with the **least distance left** across paths.
  - The gate is reached at `d >= length`.
  - `_terrain_speed` (mud).
  - `Plot.terrain_reach` (high ground) is folded into `plot_reach`.
  - `place_barricade`: `Barricade.stop_d` per path. Any path passing within 40 of the slot is
    blocked, so a slot on a merged trunk blocks both entrances.
  - `set_open_paths(wave)`, and `begin_wave(wave, wave_number)`.
  - Escorts compare the sideways `offset` on the same path.
- **`WaveSchedule.build(wave, open_paths, rng)`:** random picks come only from open paths.
- **`Run`:**
  - `plot_open`, which `build` and `open_plot` respect;
  - `open_paths`, and `newly_open_paths` (for the breach announcement);
  - `Plot.unlock_wave`;
  - `_place_barricade` delegates to the sim;
  - `state_hash` covers path and `d`.
- **`Autoplay`:**
  - The barricade slot is chosen by the threat of the paths it blocks.
  - It builds only on open plots.
  - It picks the most urgent crate by distance left.
  - **Mistake and fix:** my first edit to `_best_barricade_slot` cut from its comment to the
    next function's and deleted `_units_built`, `_under_siege`, `_plot_for_threat` and
    `_next_empty_plot`. The parse errors caught it; the functions were restored with the
    open-plot rule.

## 2026-09-26 — maps and waves

- **`outpost.tres`:** 3 straight paths (x 90/270/450, y 0 → 860, spread 30) and waves
  `wave_01..10` moved in. Its content and balance are unchanged.
- **`canyon.tres`, Canyon Pass:**
  - **Paths:** two entrances (portals at x 110 and 430) bend inward and **merge** at
    (270, 470) into a trunk to the gate, 911 long. A **left flank** (portal on the left edge
    at y 380, 517 long) **opens at wave 4**, and a mirrored **right flank** at **wave 7**.
  - **Plots:** 15. Pads at (180, 775) and (165, 420) unlock at wave 4; (360, 775) and
    (375, 420) at wave 7. Three wall spots at 85/270/455.
  - **Barricade slots** on the trunk and both flanks.
  - **Terrain:** mud on the trunk (270, 590) r 60 ×0.6, and high ground under the (175, 480)
    pad r 34 +25% reach.
  - Every pad's clearance from every path was checked by a script before writing (≥ 64 needed;
    the closest is 78).
- **`canyon_01..10`:**
  - The same pattern vocabulary as the Outpost: flank rushes and swarms on the new flanks,
    escorts on the flanks and trunk, and the Queen down the long left entrance with an escort.
  - Crates on random open paths.
  - HP: at first 1.15× the Outpost's schedule, then 1.5× (see Balance).

## 2026-09-26 — art

- **`tools/gf_tools/art/terrain.py`** (new):
  - It reads `game/data/maps/*.tres` (paths, plots, zones) and paints
    `field/ground_<map id>`.
  - Dirt strips follow each path's centre line with smoothed normals (merged paths blend into
    one trunk), with clods and claw tracks along the direction of travel.
  - Burrows at every path start; mud patches; ridge shelves under high-ground pads.
  - Verge decoration keeps clear of paths, plots and zones.
  - `field/portal_sealed`: a crusted mound with glowing cracks.
- **`props.py`:** the old fixed 3-lane `ground()` and its plot list are removed; it keeps the
  decoration helpers.
- **`cli`** registers `terrain`. **`test_art`:** every map `.tres` needs its
  `field/ground_<id>`.
- 43 SVGs; tools 5/5 OK.

## 2026-09-26 — views

- **`FieldView`:**
  - the map's ground texture;
  - a portal layer: sealed portals with "W4"/"W7" for paths not open yet, and a pulsing ring
    on the portal that opens this wave;
  - `wave_number` is set by `RunController`.
- **`PlotView`:**
  - a locked pad is dark, with a padlock and "W4";
  - high-ground pads get a gold rim.
  - `PlotField` sets both from the run.
- **`RunController`:**
  - `--map=ID`; `base_config` plus `config = base.for_map(...)`;
  - `next_map()` and `switch_map(m)`;
  - the map name at run start;
  - "NEW BREACH!" and a shake in the build phase when a path opens that wave;
  - the result screen's "PLAY <next map> ▶" (`PhaseOverlay.map_button`, signal
    `next_map_pressed`);
  - `open_plot` refuses locked plots.
- **Fix:** my first edit put the map banner in both `start_run` and the fast-forward refresh.
  It's now shown only at run start, as a popup above the "WAVE 1 INCOMING" banner.

## 2026-09-26 — tests

- **New `paths_test` (7 cases):**
  - `PathGeo` maths;
  - an enemy follows a bent path to the gate;
  - a barricade on a merged trunk blocks both entrances (not the flank);
  - portals open on their wave, random spawns wait for them, and `newly_open_paths` reports
    it;
  - plots unlock on their wave;
  - mud halves speed and high ground adds 25% reach;
  - targeting picks the least distance left across a long and a short path.
- **`content_test`**, now run per map:
  - 10 waves each;
  - complete waves; the boss only in the last;
  - plots off every path (the distance to the polyline);
  - paths monotonic, starting at a portal on the edge and ending at the gate, with one open
    at the start;
  - waves only use paths open by then;
  - unlock waves and zones sane;
  - a wall spot near every path end;
  - crates breakable on the shortest path;
  - spitters taught first;
  - threat rising;
  - **the second map out-threatens the first wave by wave**;
  - barricade slots each block a path.
- **`wave_schedule_test`:** random picks among open paths; a fixed path is kept.
- **`barricade_test`** asserts `blocks()`.
- **`run_scene_test` (+2):**
  - switching to the Canyon rebuilds the field (plots, views, ground), and a locked pad won't
    open;
  - the result screen offers the other map and switches to it.
- **`run_integration_test` (+1):** the Canyon is harder and plays to the end. Over 8 seeds its
  median clears no more waves than the Outpost's, it never wins, and every run ends.
- **Fixtures:** 3 straight paths, `sentinel_on(run, i)`.
- **Two test fixes:** an enemy position set by hand needs `d` (and `x`/`y` when a test reads
  them before the next step).
- **Result:** `scripts/test.sh` → **162/162 passed, 0 orphans**. Tools → **5/5 OK**.

## 2026-09-26 — balance

- **Per-wave threat** (`WaveSchedule.threat`): the Canyon at 1.15× was below the Outpost at
  wave 7 (698 vs 745). The test caught it.
- **The zero-meta bot, 12 seeds, with the Canyon's HP schedule at k× the Outpost's:**

  | k | Outpost median | Canyon median | Canyon wins |
  | --- | --- | --- | --- |
  | 1.1 | 8 | 8 | 1 |
  | 1.3 | 8 | 8 | 0 |
  | **1.5** | **8** | **7** | **0** |

- The merged choke, the mud and a barricade on the trunk make the Canyon's early game
  *easier*: no early deaths, where the Outpost loses about a third of runs to the first
  Carapace. Its difficulty comes later, from the flank breaches and higher HP. That's a
  reasonable sector-2 shape ("easy start, harsher end"), but it's the user's call to feel.
- **Applied: 1.5×.** The integration test (8 seeds): Outpost [2, 3, 7, 7, 8, 8, 8, 9], Canyon
  [6, 7, 7, 7, 8, 8, 8, 8].

## 2026-09-26 — running the game

- **Frame time** (`--autoplay --stress --perf`, WSLg):
  - **Outpost:** about 148 fps, frame 6.6–6.8 ms, sim tick 1.4–1.5 ms, 78–80 draw calls.
  - **Canyon:** about 141 fps, frame 7.0–7.1 ms, sim tick 1.5–1.8 ms, 96–110 draw calls (15
    plot views).
  - **Headless breakdown** (scratch probe, 260 enemies): `run.step` 0.70 ms (Outpost) and
    0.84 ms (Canyon); with the bot's turn, 0.85/0.94.
    - Enemy movement is the biggest part: about 0.6 ms, about 2.3 µs per enemy.
    - Caching each enemy's path segment (`PathGeo.segment_from`) didn't change it; the cost
      is spread over the per-enemy steps.
    - The in-game figure adds the signal handlers and WSLg variance.
  - This is within the desktop budget. **Flag for B5:** the sim tick roughly doubled since E2.
    It should be measured on the phone before more per-enemy rules land.
- **Clips** (`captures/`), checked with stills and a contact sheet:
  - `e4-outpost.mp4`: the regenerated Outpost ground (3 strips from the map data), the map
    banner, and the Drone intel card.
  - `e4-canyon-breach.mp4`: Canyon wave 4's build phase:
    - the Y of merged paths;
    - "NEW BREACH!";
    - the sealed right portal marked "W7";
    - a locked "W7" pad at the wall;
    - the Spitter intel card.
  - `e4-canyon-midgame.mp4`: seed 3, wave 7, autoplay:
    - both flank burrows open;
    - Carapaces and Skitters down the new right flank;
    - jams, the mud patch and high ground visible;
    - the bot's barricade on a flank.
- **Seen, for later:** at a breach wave, "NEW BREACH!", "WAVE N INCOMING" and an intel card
  stack in the first second. Stagger them in a UI pass.

**Status: complete.**

**👤 For the user:** play the Canyon (`-- --map=canyon`, or "PLAY CANYON PASS" on the result
screen). Does its shape read? Does the flank breach feel like the right escalation? Is 1.5× HP
fair?
