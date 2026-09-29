# E5c — Artillery strike and unit synergies: plan

_2026-09-27. Built on `research.md`. The user approved both mechanics, with an effect per
combination._

## 1. Data

- **`RunConfig` artillery group:**
  - `strike_damage` 30 (× wave `hp_scale`);
  - `strike_radius` 70;
  - `strike_delay` 0.9;
  - `strike_cooldown` 25.
- **`RunConfig.synergy_range`** 200, and **`RunConfig.synergies: Array[SynergyDef]`**.
- **`StatBonus`** (a new Resource): `damage`, `reload`, `reach`, `splash`, `slow`,
  `slow_time`, `pierce`, `crit`, `beam_targets`, `chill`, `chill_time`. Each field defaults to
  no effect.
- **`SynergyDef`:** `id`, `title`, `description`, `unit_a`, `unit_b` (ids), `bonus_a`,
  `bonus_b` (`StatBonus`, for a and b; same-type pairs use `bonus_a` for both).
- **Content:**
  - `data/synergies/*.tres` (21) and a `strike_cooldown_bonus` modifier.
  - A new card, `fire_mission` (−30% strike cooldown).

## 2. Core

- **`Synergies`** (static):
  - `find(config, a, b)`;
  - `compute(plots, config)`, which fills each plot's summed `syn: StatBonus` and
    `links: Array` (`[other plot index, SynergyDef]`), counting each distinct synergy once
    per plot.
- **`CombatSim`:**
  - The stat functions add `plot.syn`: reload, damage, reach, splash, slow, pierce, crit, and
    beam cap.
  - Chill is applied on non-slow shots and hitscan hits.
  - `refresh_synergies()` recomputes and emits `synergies_changed`. It's called from
    `destroy_unit`, and by `Run` after build and sell.
- **The strike:**
  - `CombatSim.call_strike(pos, damage)` queues a `Strike` (pos, t, damage).
  - It lands in `step`, after the move pass, through `_apply_damage` (no chart, no armour).
  - Signals: `strike_called`, `strike_landed`.
  - `Run` owns the cooldown: `strike_ready()`, `strike_left()`, `call_strike(pos)`. It's WAVE
    only, ready again at each wave start, and ticks in `step`.
- **`Autoplay`:**
  - It uses the strike when a spot holds ≥ 5 threat within the radius, or a sieger stands at
    the gate. Candidates are checked every 12 ticks.
  - It prefers pads that form links when placing units (`synergy_pick`, on by default).

## 3. View

- **`HUD`:** a **StrikeButton** (under the HUD, top right) with a cooldown sweep. It's shown
  in WAVE only.
- **Aim mode:** time slows to `build_menu_time_scale`, and a crosshair follows the pointer.
  The next field tap calls the strike; tapping the button again cancels.
- **FX:**
  - On the call: a telegraph ring and a shell whistle streak.
  - On landing: a big explosion, a ring, a shake, a scorch decal.
- **`PlotField`:** draws link lines (a subtle animated dash), with a popup of the synergy
  name when a link forms.
- **`BuildMenu`:**
  - The ring shows a small link badge on units that would link on this pad.
  - The unit card lists "LINKS: Siege Battery (+15% dmg)".

## 4. Tests

- **`synergy_test`:**
  - Pairs found in either order.
  - Range.
  - Each distinct synergy counted once.
  - Recomputed on sell and destroy.
  - Every stat applied (reload, damage, reach, splash, beam targets, pierce, crit, chill).
- **`strike_test`:**
  - Lands after the delay and damages within the radius, ignoring armour.
  - Cooldown; not outside WAVE; ready at the next wave.
  - Deterministic, via `state_hash`, which includes the strike state.
- **`content_test`:**
  - 21 synergies cover every pair exactly once, with valid ids and non-empty effects.
  - Every map has linkable pads.
  - The strike numbers are sane.
- **Scene:**
  - The strike button arms and fires.
  - Link lines appear after two builds.
- **Integration:** the campaign curve keeps holding (re-tuned in B4 if needed).

## 5. Perf

- No per-tick synergy work.
- The strike is event-driven.
- Link lines are drawn only when links change or the pulse animates: one `_draw` of ≤ 30
  lines.
