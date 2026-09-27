# Maps from paths (E4): plan

## Defs

- **`PathDef`** (new):
  - `points: PackedVector2Array` (y strictly increasing, ending at `wall_y`);
  - `spread` (30);
  - `opens_at_wave` (1).
- **`ZoneDef`** (new): `kind` (MUD, HIGH_GROUND), `center`, `radius`, `value`.
- **`MapDef`:** `paths`, `plots`, `plot_unlock_waves`, `barricade_slots`, `zones`, `waves`,
  `display_name`.
- **`RunConfig`:**
  - `lane_count`/`lane_width`/`lane_jitter` are replaced by `field_width` (540);
    `playfield_width()` stays.
  - `maps: Array[MapDef]`; `for_map(map) -> RunConfig` (a shallow copy with `map` and
    `waves` set).
- **`SpawnEntry.lane` and `CrateSpawn.lane`** are renamed `path` (-1 = a random open path).

## Core

- **`PathGeo`** (new, pure): cumulative lengths, `point_at(d)`, `normal_at(d)`,
  `d_at_y(y)`, `length`, and `distance_to(p)` / `nearest_d(p)` for the barricade.
- **`CombatSim`:**
  - `path_enemies` and `path_crates` (per path, sorted by `d` descending).
  - `Enemy.d`, `Enemy.offset`, `Enemy.path`; `x`/`y` are updated from the geometry each move.
  - `first_in_reach`: per path, binary search on `d` within the window mapped from the reach
    circle's y range (`PathGeo.d_at_y`), with the path's spread as margin; best = least
    remaining distance.
  - The gate is reached at `d >= length`.
  - Mud: an enemy's speed × the zone value while inside.
  - The barricade: `blocked` holds per-path stop distances, computed when it's placed.
  - Escort, beam and spit keep working per path.
- **`WaveSchedule.build(wave, open_paths, rng)`**: random path picks come only from open paths.
- **`Run`:**
  - `plot_open(i)` (the unlock wave) gates `build`.
  - Plot `reach_bonus` comes from high ground and is folded into `plot_reach`.
  - `open_paths()` for the current wave.
  - `newly_open_paths()` for the build-phase announcement.
- **`Autoplay`:**
  - The barricade slot is chosen by the threat of the paths it blocks.
  - It builds only on open plots.

## Art (`tools/`)

- `field/ground_bare`;
- `field/dirt` (a tiling strip texture);
- `field/portal` and `field/portal_sealed`;
- `field/mud`;
- `field/ridge`.

## Views

- **`FieldView`:** per-path `Line2D`s (edge + dirt), portals, zones, and a closed-path dim with
  "W4".
- **`PlotView`:** a locked look (padlock + "W4"), and a ridge under high-ground plots.
- **`RunController`:**
  - `--map=id`;
  - map-name banner at start;
  - "NEW BREACH" in the build phase when a path opens that wave;
  - the result screen's "PLAY <next map>".

## Data

- **`outpost.tres`:** 3 straight paths plus its waves (moved in). Content is unchanged.
- **`canyon.tres`:** 4 paths (2 merging, 2 flanks opening at waves 4 and 7), 12 plots (4
  unlock later), 3 barricade slots, mud, high ground, and 10 waves.

## Tests

- **`PathGeo`:** `point_at`, `d_at_y`, `length`, nearest point.
- **Core:**
  - enemies follow a bent path;
  - the gate is reached at the end of the path;
  - a merged choke's barricade blocks both paths;
  - mud slows;
  - high ground adds reach;
  - locked plots can't be built until their wave;
  - random spawns only use open paths;
  - targeting on bent paths picks the enemy nearest the gate by remaining distance.
- **Content**, for every map:
  - paths monotonic, starting at or above the top of the field and ending at `wall_y`;
  - plots off every path (distance to the polyline) unless on the wall;
  - barricade slots on some path;
  - spawns only use paths open by that wave;
  - every map has 10 waves with a boss in the last;
  - wave threat rises.
- **Scene:**
  - the Canyon loads and renders paths;
  - locked plots won't open a menu;
  - the breach banner appears;
  - the result screen switches map.
- **Integration:** the bot on both maps. The Canyon should be harder: zero meta clears fewer
  waves than on the Outpost.
