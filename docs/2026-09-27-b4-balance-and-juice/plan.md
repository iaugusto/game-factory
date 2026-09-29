# B4 — Balance bot, tuning and juice: plan

_2026-09-27. Built on `research.md`._

## 1. The balance bot (reusable)

- **`Autoplay.preset(name)`** (core, static): the 8 strategies of research §3. The knobs live
  in one place, so tests and the tool share them.
- **`game/tools/balance_sim.gd`** (a SceneTree script, headless, `--script`). Arguments:
  - `map=ID`, `profile=T0|T3|T6`, `strategy=NAME`, `seeds=A-B`, `out=PATH`.

  It writes one JSON line per run with the fields of research §3, and it never touches
  autoloads.
- **`tools/src/gf_tools/balance/`** (Python, uv), with a `balance` console script:
  - **`runner`:** runs the matrix of sectors × strategies as parallel Godot processes (one
    per cell, up to the CPU count) into a temp directory.
  - **`report`:** pure functions that aggregate records (win rate, median and mean waves,
    gate, strikes, unspent coins, top leakers) and check the research §4 targets, then write
    `report.md`.
  - **CLI:** `uv run balance --seeds 50 --out ../docs/<item>/report.md`.
  - **Tests:** the aggregation and target checks on synthetic records (no Godot needed).

## 2. The tuning pass

Iterate report → data change → report. The levers, in order:
1. Per-sector wave `hp_scale` (the overall difficulty).
2. Counter enforcement, if `heavy`/`light` come close to `smart`: sharpen the chart's
   multipliers, or the resistances of the enemies that leak.
3. The strike or links only if one strategy's delta is out of line.
4. A late coin sink, if unspent coins at the end are large (the report shows it).

Every change is logged with its before/after numbers. The integration test's curve is kept in
step.

## 3. The juice pass

- **`UiTheme.style_button`** connects a press squash: a scale of 0.94, eased back over 0.12 s
  (pivot at the centre).
- **`PhaseOverlay`:** stars pop in one by one (a 0.18 s stagger, scale 1.4 → 1), and the gate
  % counts up.
- **The strike:** a shell streak falls toward the target during the delay.
- **Upgrades:** the unit pops, like on build.
- **Checked by eye** in a clip after the pass.

## 4. Tests

- Python: the report's aggregation and target checks.
- GdUnit: `Autoplay.preset` names and knobs; a smoke test that `balance_sim.gd`'s record
  builder returns the expected fields (its logic sits in a testable static function).
- The integration curve stays green.

## 5. Out of scope

- New enemies or content (B10).
- Audio (B11).
