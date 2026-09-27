# Gate siege and enemies that disable units: plan

## Core (`game/src/core/combat_sim.gd`, `run.gd`)

- **`Enemy`** gains:
  - `sieging: bool`;
  - `strike_timer: float`;
  - `spit_timer: float`.
- **`_move_enemies`:**
  - An enemy stops at `wall_y`: `sieging = true`, then its first strike.
  - Sieging enemies strike every `def.attack_interval`, adding to `pending_wall_damage`.
  - A new signal `enemy_struck(enemy, damage)`. It replaces `enemy_reached_wall`, which is
    removed (enemies no longer vanish at the wall).
- **`Plot`** gains `disabled: float` (seconds left).
  - `_fire_plots` skips disabled plots: their cooldown doesn't tick and they have no target.
  - The timer counts down each tick.
- **`Spit`** (a new class): `pos`, `dest`, the target `plot`, `speed`.
  - They are held in `spits` and moved in `_move_spits`.
  - On arrival: `plot.disabled = max(plot.disabled, duration)`, and the signal `unit_disabled`.
- **`_spit_enemies`:** each alive enemy with `def.spit_interval > 0` counts down its timer.
  When it's ready and a built plot within `spit_range` is not yet disabled (the nearest one;
  ties go to the lower index), it fires and the signal `spit_fired` goes out.
- **`begin_wave` / `end_wave`** clear the spits and reset plot `disabled` to 0.
- **`Run.state_hash`** includes spits and disabled timers.

## Defs and data

- **`EnemyDef`:**
  - `attack_interval` (1.0);
  - `spit_range`, `spit_interval`, `spit_speed`, `disable_duration` (all 0 = doesn't spit).
- **`data/enemies/spitter.tres`**, placed in waves 4–10.
- **Per-strike wall damage** is retuned by the probe, and the Queen stays at 999.

## Views

- **`EnemyField`:** sieging enemies freeze their walk frame and lunge with the strike timer.
- **`RunController`:**
  - `enemy_struck` → a wall hit fx and a −N popup.
  - `spit_fired` / `unit_disabled` → a splash on the plot.
  - LOST → the breach sequence:
    - an Fx shake;
    - a flash across the wall;
    - the banner;
    - `Engine.time_scale` 0.3 for 1.2 s of real time, then restored;
    - the overlay fades in after a delay (`PhaseOverlay.show_result(…, delay)`).
- **`ShotField`** draws spit globs: an additive green glow and a trail.
- **`PlotView`**, when disabled: a grey tint, a green goo overlay, and a countdown ring.
- **HUD:** "GATE". **`PhaseOverlay`:** "THE GATE FELL".
- **Art:** `tools/gf_tools/art/enemies.py` gains a `spitter` atlas, and `palette.SPITTER`.

## Tests

- **Siege:**
  - An enemy stops at the gate and strikes once per interval.
  - Killing it stops the damage.
  - The wave stays open while one is sieging.
  - The Queen breaks the gate in one strike.
  - Gate HP 0 → LOST.
- **Spit:**
  - A spitter in range disables the nearest built plot.
  - A disabled plot doesn't fire, and its cooldown doesn't tick.
  - The disable expires.
  - An out-of-range spitter doesn't spit.
  - Empty plots are never targeted.
  - An already-disabled plot is skipped.
- **Content:**
  - Some unit outranges every spitter.
  - Spitters only appear from wave 4.
  - `attack_interval > 0`.
- **Scene:**
  - A disabled plot's view shows the state.
  - A loss shows the result, with the breach banner, even when time is slowed.
  - The time scale is restored on restart.
- **Integration:** the zero-meta guard and determinism still hold.

## Budgets

The spit count is tiny: one per spitter every 3.5 s. Sieging enemies add no cost, since they
are still in the lane arrays. The frame time is re-measured under `--stress`.
