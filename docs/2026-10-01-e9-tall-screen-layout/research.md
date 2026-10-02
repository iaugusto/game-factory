# E9 — Tall-screen layout: research

**Trigger (user, 2026-10-01, on the Galaxy S24):** "the bottom of the screen is unused — the
wall occupies 1/6 or 1/5 of the screen... can't we improve that and leverage more the screen
size?" Then: "Ideally the battlefield would be larger, no? How do publishers handle this?"
The user chose to **design for the tall 19.5:9 shape and scale down on 16:9**, with a bottom
thumb strip ("let's do it").

## 1. The problem, measured

The B5 screenshot (`captures/perf/`, Compatibility build, Canyon wave 4) shows the layout in
design units:
- The project is 540×960 with `canvas_items` / `expand`. On a 1080×2340 phone the viewport
  becomes **540×1170**, so Godot already gives the game 210 extra units of height.
- The battle screen ignores that space:
  - the HUD takes 0–50;
  - the field takes 50–910 (`RunConfig.wall_y` = 860);
  - the wall art takes 894–1006;
  - **1006–1170 is empty** (about 14% of the screen).
- The menus (campaign, tree, results) are anchored Controls, so they already stretch to 1170.
- The thumb zone (the bottom third) holds nothing interactive. The special attack sits top
  right, and the BUILD bar (wave preview, repair, Start Wave) sits at the **top**, under the
  HUD.
- The 960 design was already overflowing: the wall art ends at 1006, so a 16:9 phone crops
  its lower 46 units.

## 2. How shipped games handle aspect ratios

1. **A fixed play area, with extra space going to UI and scenery** (Clash Royale, Rush
   Royale). It's fair, and balance is identical on every phone, but the battlefield doesn't
   grow.
2. **Designing for the modern tall shape (about 9:19.5–9:20) and fitting older 16:9 phones**
   by scaling down or showing more at the sides. Most phones sold in recent years are
   19.5:9–20:9, the Galaxy A15 (the B5 budget profile) and the S24 included. The play area
   gets bigger and stays the same size in game units on every phone.
3. **A world larger than the screen, with a scrolling camera** (Kingdom Rush, Bloons). It suits
   landscape games with big maps, and adds panning to a tap game. Rejected.

The user chose **2**, plus the thumb strip from 1.

**Godot's mechanics:** with `stretch/aspect = "expand"` and a 540×1170 base:
- a 16:9 phone gets a 658×1170 viewport (more width; the field is already centred
  horizontally by `RunController.field_origin`), so nothing is cropped;
- a 20:9 or 21:9 phone gets 540×1200 or 540×1260 (more height).

UI anchored to the bottom follows the screen edge on every shape.

## 3. How to make the field taller: options

The field has to grow from `wall_y` 860 to about 980 (+120). Options:

| Option | What changes | Balance risk | Work |
| --- | --- | --- | --- |
| **A. Stretch map y by ×1.14** | Every path, plot and zone is scaled on y | High: ranges, auras, synergy distances, Ravager reach, Spitter range and burrow dives don't scale, so the geometry stretches under them. Every map needs retuning | Large |
| **B. Stretch, and speed enemies up by ×1.14** | A, plus all speeds | Walk time is preserved, but coverage is still distorted (ranges are circles) | Large |
| **C. Shift everything down by +120 and extend the top-edge paths up to the top** | Paths, plots, zones and slots move +120 in y; paths entering from the top get 120 more approach; side and mid-field portals just move | **Low:** every distance between plots, paths and zones is unchanged (a translation). Enemies from the top walk 120 units more (about 1.5–3 s at speeds 40–80) before reaching any defence | Small |

**Choice: C.**
- It's a rigid translation, so the combat geometry is exactly what was balanced in E8. The
  only change is a longer, undefended approach from the top portals. That slightly delays
  arrivals and slightly spreads crowds. The balance bot measures the effect, and wave tuning
  absorbs it if needed.
- The new top band (about 120 units) is room the BUILD phase's wave preview can use without
  covering plots. Future maps can put plots there; that's a design call for later, shown to
  the user.

## 4. The thumb strip

Today the BUILD bar holds three things at the top:
- the "NEXT" preview (enemy icons × count);
- Repair;
- Start Wave.

The special-attack button is top right during waves. On a tall phone those are the hardest
places to reach with one hand. The plan:
- **The bottom strip** (about 84 units) holds **Repair + Start Wave** in BUILD and the
  **special attack** in WAVE, anchored to the bottom edge. It overlays the lower, decorative
  part of the wall art; the wall spots sit in the top 60 units of the wall, above the strip.
- **The NEXT preview** stays at the top, where the field is empty before a wave. It's
  information, not a control.

## 5. Constraints and knock-ons

- **Ground art:** the generator paints each map's ground from the map data
  (`tools/src/gf_tools/art/terrain.py`, with `FIELD_H = 860`, and `props.py`). It must paint
  the taller field. `FIELD_H` should come from `run_config.tres` (data), not a second
  constant.
- **Tests:** `toolchain_test` pins 540×960, and `campaign_flow_test` lays the tree out at
  540×960. Fixture-based core tests use `RunConfig`'s default `wall_y` (860) and their own
  maps, and are unaffected.
- **Hard-coded fractions of `wall_y`** in views and the bot (`* 0.55`, `* 0.62`, `* 0.7`) are
  heuristics that shift slightly. They need review.
- **Desktop window:** a 540×1170 window doesn't fit a 1080p monitor, so a window override of
  about 405×878 is needed. `capture_clip.sh` (`--resolution 540x960`) and the clip tool's crop
  need updating.
- **`gen_maps.py`** (E8 Stage 4) holds the Stage 4 maps' source coordinates. It should get the
  same shift, or the doc should say the `.tres` files are the truth (they already are, per
  handover §4).

## 6. Sources

- Godot docs, *Multiple resolutions* (stretch aspect `expand`, and supporting several aspect
  ratios): https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
- Galaxy S24 / A15 screens (1080×2340, 19.5:9): https://www.gsmarena.com/samsung_galaxy_s24-12773.php,
  https://www.gsmarena.com/samsung_galaxy_a15-12637.php
- Clash Royale's fixed arena with a bottom card tray; Kingdom Rush's scrolling maps (common
  knowledge of shipped games; no single citation).
