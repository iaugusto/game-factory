# Art readability and resolution: implementation log

## 2026-09-27: comparison sheet (generator only, the game is unchanged)

**Generator changes (`tools/src/gf_tools/art/`)**
- `svg.py`: `RASTER` 4.0 is the default; `FIELD_RASTER` 2.0 is used by the grounds
  (`terrain.py`) and the wall (`props.py`).
- `enemies.py`: a zoom per enemy in `ENEMIES`, `LEG_MIN`, `EYE_BOOST`, and shell ink 1.4.
- `palette.py`: Ravager is crimson and Mender is bone. Added the damage-type accents
  `KINETIC`, `EXPLOSIVE`, `PIERCING` and `CRYO_TYPE`.
- `units.py`: `HEAD_ZOOM` 1.35 through `_zoom`, accents on the heads, and a base per unit
  (`BASES`, `units/base_<id>`).

**Sheet**
- The proposed art went to the scratchpad (`gen-art --out`). `game/art/` is **not**
  regenerated yet.
- The sheet was rendered with a throwaway Godot probe (since removed from `game/`) to
  `captures/art-compare-ab.png`.

**Status:** waiting for the user's verdict on the sheet. Until `game/art` is regenerated, the
tools test `test_committed_art_matches_the_generator` fails by design.

## 2026-09-27: before/after review page

- `captures/art-compare/` (git-ignored) holds:
  - `before/` (the current `game/art` enemies and units)
  - `after/` (the proposed art)
  - `index.html`: one card per model on the real ground, with a screen-scale switch
    (1×/2×/2.67×/4×), the walk animation, notes per model saved in the browser, and
    "Copy all feedback"
  - `sheet.png`, the engine-rendered sheet
- The page was built by a scratch script from a template; that tooling was not added to
  `tools/`.
- Checked with a headless Chrome screenshot: all 14 models render.

## 2026-09-27: sizes brought back near the originals (user feedback)

- **Feedback:** the user judged the 1.25–1.35× enemies and 1.35× heads too big.
- **New sizes:**
  - Skitter, Drone and Mender: zoom 1.1
  - every other enemy (Hive Queen included): 1.0
  - unit heads (`HEAD_ZOOM`): 1.1
- **Unchanged:** the rest of the new look (ink, legs, eyes, recolours, damage-type accents,
  per-unit bases, 4× raster).
- **Crowd captures:** `captures/art-compare/crowd-wave2.png` (wave 2 at 14 s) and
  `crowd-wave6.png` (wave 6 at 20 s), both at seed 3 with the bot playing, before on the left
  and after on the right, at 1440×2560.
  - They come from scratch copies of `game/`; the "after" copy has the new art plus draft
    code changes: `Art.scale_of`, per-unit bases, mipmaps, and the shadow scale.
  - Godot's Movie Maker records at the base 540×960 size. To get phone resolution, each copy
    got an `override.cfg`: base 1440×2560, stretch scale 2.6667, run under `xvfb-run`.
- The sheet and the review page were rebuilt at the new sizes.

## 2026-09-27: the approved art goes into the game; crates, barricade and slots

**Approval:** the user approved the enemies and units ("look really good now"). They asked for:
- bigger crates and barricade
- a barricade-shaped slot (and tap area) instead of a rectangle
- background options

**Generator**
- `svg.py`: `Svg.zoomed()`; `units._zoom` now uses it.
- `props.py`:
  - `CRATE_ZOOM` 1.35.
  - The barricade redrawn at `BARRICADE_W`×`BARRICADE_H` (144×52, was 120×40): three
    staggered rows of bags; a frame in front at levels 2 and 3, spikes at level 3; the hazard
    stripe trimmed to the back row.
  - `props/barricade_slot`: the level-1 bags in white, for the game to tint.
  - The rubble is resized to match.
- `terrain.py`: the sealed portal is at `FIELD_RASTER`, since `field/` art is 2× by rule.
- `units.py`: the generic `base_troop`/`base_emplacement` are no longer shipped (each unit
  has `base_<id>`); the stale files were deleted from `game/art/`.

**Game**
- `art.gd`: `FIELD_SCALE`/`SPRITE_SCALE` and `scale_of(key)`; `size()` and `draw()` use it.
- `field_view.gd` uses `FIELD_SCALE`; `enemy_field.gd` uses `SPRITE_SCALE`.
- `plot_view.gd` and `unit_icon.gd` draw `units/base_<id>`.
- `barricade_field.gd`:
  - The footprint comes from the art's size.
  - Slots draw as an amber ghost pulsing at 0.35–0.75 alpha, with a teal ghost over them
    when selected.
  - `slot_at` is a footprint + `TAP_SLOP` 6 test (was a 40-unit circle, narrower than the
    120-wide rectangle that was drawn).
- `combat_sim.gd`: `BARRICADE_HALF_DEPTH` 12 → 16, so enemies stop at the deeper bags' front
  edge. This is a 4-unit change in the stop point, with no measurable balance effect expected.
- `data/crates/*.tres`: `radius` 18/22/18 → 24/30/24 (supply/cache/overdrive). Taps land on
  what's drawn; tapping is slightly easier.
- `project.godot`:
  - `[importer_defaults]` generates mipmaps for new textures.
  - `rendering/textures/canvas_textures/default_texture_filter=3` (linear with mipmaps).
  - Every existing `.svg.import` got `mipmaps/generate=true`.

**Tests**
- New: `test_a_barricade_slot_is_tapped_by_its_shape` (run_scene_test). A tap at the
  footprint's ends hits; a tap just above, below or past the ends misses.
- The tools art test now checks the per-prefix raster.
- Results: game 233/233 passing, tools 10/10 passing.

**Exercised the change** (the real game, 1440×2560 via `override.cfg` + xvfb on a scratch
copy): the build-phase slot ghosts, a built barricade at wave 3, and live crates at wave 2
without the bot. Before/after images are in `captures/art-compare/props-*.png`.

**Budgets**

Stress run (`--autoplay --stress --perf`, 540×960 under xvfb/llvmpipe, 260 enemies):

| | Before | After |
|---|---|---|
| Frame avg | 5.25 / 7.72 / 8.50 ms | 5.39 / 7.69 / 8.59 ms |
| Draw calls | 82–83 | 82–83 |

Frame time is unchanged within noise.

Texture memory (estimated from raster sizes, uncompressed RGBA, mipmaps +33%):

| Per run | Before | After |
|---|---|---|
| Sprites | ~2.5 MB | ~16.6 MB |
| One ground (with mips) | ~7.4 MB | ~9.9 MB |
| Total | ~11 MB | ~28 MB |

The project has no written memory budget yet (it's due with the Android device profile, B5).
28 MB of textures is small for a low-end Android device, but it should be re-checked on a real
device.

## 2026-09-27: background options (drafts, not in the game)

- `bg_variants.py` (a scratch script, not in `tools/`) paints three directions from the real
  map data:
  1. **Polish:** the dusk look, with sunken lanes (a lit lip and a shadow), wheel ruts,
     scorch marks, fences, casings and a vignette.
  2. **Biomes:** a palette per sector: desert outpost, red-rock canyon, frozen switchback.
  3. **Creep:** alien biomass, veins and pustules spreading from the burrows; concrete slabs
     and a floodlight near the wall.
- Each was rendered in the game (wave 5, 16 s, seed 3, the bot playing) on all three maps:
  `captures/art-compare/bg-<map>.png` (current | 1 | 2 | 3).
- **My read:**
  - Biomes changes the most and gives each sector an identity, while keeping sprites
    readable.
  - Polish is subtle.
  - Creep's veins are busy at the top of the field, where enemies spawn.
- **Status:** waiting for the user's pick.

## 2026-09-27: backgrounds, Biomes with a subtle Creep (user's pick)

**The user's pick:** "biomes is really cool, and creep too but it has to be more discrete (in
the image it was too much and too concentrated on the top part of the screen)."

**Data:** `MapDef.biome` (a StringName; only the generator reads it). Outpost is `desert`,
Canyon `canyon`, Switchback `tundra`.

**Generator (`terrain.py`)**
- `ground_for` is rewritten around a `Biome` palette. `BIOMES` holds dusk (the old look, the
  fallback), desert, canyon and tundra.
- Sunken lanes: a lit lip past the edge, and the left wall's shadow across the floor.
- A vignette on the edges.
- The draft's regressions are restored: mud puddles and claw tracks.
- `_creep`:
  - It's spread along the lane edges down the field (sampling biased toward the burrows),
    never within 200 of the wall, and never on the lane centre.
  - Faint stains, up to 4 thin veins and 3 small pustules per path, plus a modest stain
    around each burrow.
  - First pass: too faint to notice. Second pass (kept): more and larger patches, more
    veins; noticeable, but secondary to the sprites.
- `props._rock` takes the biome's stone colours.

**Tests**
- A new tools test: every map's biome is in `BIOMES`.
- Results: tools 11/11 passing, game 233/233 passing.

**Exercised:** all three maps in the real game at wave 5, 16 s, at 1440×2560:
`captures/art-compare/bg-final.png`. The review page has a "Backgrounds: in the game now"
section.

**Budgets:** the grounds are still one 2× texture per map (same size, same memory). Draw
calls are unchanged, since the ground is one sprite.

## 2026-09-27: summary (work item complete, pending the user's hand-play)

**Shipped in the game**
- 4× sprites with mipmaps.
- Readable enemies.
- Units coloured by damage type.
- Crates ×1.35.
- A 144×52 barricade, with a barricade-shaped slot ghost and tap area.
- Biome grounds with a subtle creep.

**Tests:** game 233/233 passing, tools 11/11 passing.

**Budgets:**
- Frame time unchanged.
- Texture memory about 11 → 28 MB per run (an estimate; re-check on the B5 device).

**Not done**
- The 4× look and the budgets have not been checked on a real phone (that needs B5).
- The user has not yet hand-played the change.
