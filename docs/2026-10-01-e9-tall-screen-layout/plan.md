# E9 — Tall-screen layout: plan

The approach is from [`research.md`](./research.md) §3, option C, plus the thumb strip from §4.

## Target layout (design units, 540×1170)

| Band | y | Contents |
| --- | --- | --- |
| HUD | 0–50 | Unchanged |
| Field | 50–1030 (`wall_y` = **980**, was 860) | Every map shifted +120; top-edge paths extended up to y = −10 |
| Wall | 1014–1126 (art); spots at about `wall_y` + 0…30 | Unchanged art, lower |
| Thumb strip | the bottom 84 of the viewport (1086–1170 at 19.5:9) | BUILD: Repair + Start Wave; WAVE: the special attack |

On 16:9 the viewport is 658×1170 (`expand`): the field is centred with about 59 units at each
side, and the strip spans the full width. On 20:9 and taller the strip stays at the bottom
edge; any gap above it shows the clear colour.

## Changes

1. **`project.godot`:**
   - the viewport becomes 540×1170;
   - a desktop window override of 405×878 (it fits a 1080p screen; tests and headless runs
     are unaffected).
2. **`data/run_config.tres`:** `wall_y = 980`. The `RunConfig.wall_y` default stays 860,
   because the fixture-based tests build their own configs.
3. **Maps** (all 6 `data/maps/*.tres`), through a one-off script `shift_maps.py` in this
   folder:
   - plots, barricade slots, zone centres and path points: y += 120;
   - a path whose first point has y ≤ 0 gets a new first point at (x, −10), straight above
     its shifted start (the old first segment is vertical on every map; the script asserts
     it).
   - `gen_maps.py` gets a note that it predates E9; the `.tres` files are the truth.
4. **Art:** `terrain.py` and `props.py` read the field height from
   `game/data/run_config.tres` (`wall_y`) instead of `FIELD_H = 860`. Then `uv run gen-art`.
5. **UI:**
   - `BuildBar` keeps only the NEXT preview at the top. A new **`ThumbBar`** (`src/ui/`),
     anchored bottom-wide, holds Repair + Start Wave.
   - `AbilityButton` moves to the strip's right side.
   - `RunController._layout` places them.
   - The tests' "no plot under the bar" check covers both bars.
6. **Heuristics:** review `wall_y * k` fractions in `RunController` and `Autoplay`; switch
   them to `wall_y - d` where the intent is "near the gate".
7. **Tools and scripts:**
   - `capture_clip.sh --resolution 540x1170`;
   - the clip crop note in `clips/cli.py`;
   - `toolchain_test` asserts 540×1170;
   - `campaign_flow_test` lays out at 540×1170.

## Testing

- **The full GdUnit suite and the tools suite.** Content tests already check that plots are
  in the field and off paths, that paths end at `wall_y`, the barricade band and the zone
  bounds, so they validate the shifted maps.
- **Balance:** `uv run balance --maps all --strategies smart,casual --seeds 30`, compared
  with E8's Stage 4 report. Tolerance: each sector's win rate within ±10 points. If a sector
  goes easier beyond that, tune that sector's wave knobs (HP) and record it.
- **On the phone:** screenshots in BUILD and WAVE on the S24, plus a 30 s clip. On desktop,
  `--resolution 658x1170` for the 16:9 look.

## Risks

- **The approach makes runs easier.** Measured by the bot; the knobs exist.
- **Tip cards and menus that position themselves** against the viewport (`TipLayer`,
  `BuildMenu`, `BarricadeMenu`) read `get_viewport_rect()`, so they adapt. Check them in
  screenshots.
- **The tutorial clips** (`game/clips/*.ogv`) were recorded at the old layout. They are
  crops around the action, so the shift only changes the backdrop. Re-record them with
  `uv run make-clips` if they look off.
