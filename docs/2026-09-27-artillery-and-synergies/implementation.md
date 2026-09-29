# E5c — Artillery strike and unit synergies: implementation log

_Built on `plan.md` (approved in an earlier session). The user said "looks good, let's keep
going" after E6, so E5c was built next, with its own tips (E6's tip system)._

## 2026-09-27 — core

- **Defs:** `StatBonus` and `SynergyDef`. They were already stubbed by the earlier session and
  are used as written.
- **`RunConfig`:**
  - an Artillery group: `strike_damage`, `strike_radius`, `strike_delay`, `strike_cooldown`;
  - a Synergies group: `synergy_range` 200, `synergies`.
- **`RunModifiers.strike_cooldown_bonus`**, and the card `data/cards/fire_mission.tres`
  (−30% cooldown, 2 stacks).
- **`core/synergies.gd` (`Synergies`):**
  - `find` (either order);
  - `compute` fills `Plot.syn` (summed, each distinct synergy once per plot) and `Plot.links`
    (`[other index, SynergyDef]`);
  - `preview(plots, cfg, index, unit_id)`: what a build would form.
- **`CombatSim`:**
  - `Plot.syn` and `Plot.links`.
  - `reload_for`/`damage_for`/`reach_for` take an optional `syn`, and the `plot_*` functions
    pass `plot.syn`.
  - `_fire_plot` adds the synergy's pierce, crit chance, beam targets (only for capped beams),
    splash, and slow strength and time.
  - **Chill:** a unit without slow gets its bullet's slow from the synergy's chill, and
    hitscan and beam hits chill directly (`_chill`).
  - `refresh_synergies()` emits `synergies_changed`. It's called from `destroy_unit`.
  - **The strike:** a `Strike` class, `strikes`, `call_strike(pos, damage)` (`strike_called`),
    and `_land_strikes(dt)` after `_resolve_queued` in `step`. Landing applies raw damage
    through `_apply_damage` (past the chart and armour) to everything within the radius
    (+ half the enemy's radius), then emits `strike_landed`. `end_wave` clears strikes.
- **`Run`:**
  - `strike_cooldown_left`, reset to 0 at `start_wave` and counted down in `step`;
  - `strike_cooldown()` (with the modifier, floored at 10%), `strike_ready()` (WAVE only),
    `call_strike(pos)` (damage × the wave's `hp_scale`);
  - `refresh_synergies()` after `build` and `sell`;
  - `state_hash` includes the strike's cooldown and pending count.
- **`Autoplay`:**
  - `synergy_pick` (on): the placement goes to the open plot with the most previewed links,
    nearest the focus on a tie, except under siege.
  - `strike_target`: among the 8 enemies nearest the gate per path, the one with the most
    threat within the radius (a gate sieger counts as enough). It strikes when that's
    ≥ `strike_threat` 5, checked every `strike_every_ticks` 12.
- **Content:**
  - `data/synergies/*.tres`: the 21 pairs from research §3.2, with descriptions of 80
    characters or fewer, registered in `run_config.tres`;
  - Fire Mission in the card list.

## 2026-09-27 — view

- **`ui/strike_button.gd` (`StrikeButton`):**
  - A round button with a cooldown pie and "STRIKE", "Ns" or "TAP FIELD".
  - Ready shows a pulse; armed shows a red ring.
  - It sits top right under the HUD (placed in `RunController._layout`) and shows in WAVE
    only.
  - Its field was first called `ready`, which clashed with `Control.ready`; renamed
    `charged`.
- **`sim/strike_view.gd` (`StrikeView`), two instances:**
  - **links** (under the plots): an animated dashed line per link, in the owned colour;
  - **strikes** (over enemies): the telegraph (the blast radius plus a ring closing in until
    landing) and, while armed, a pulsing red frame around the field.
  - The aim crosshair follows the mouse only after a real (non-emulated) mouse move, since
    touch has no hover.
- **`RunController`:**
  - `toggle_strike()` arms or disarms. Arming closes menus and slows time to
    `build_menu_time_scale`.
  - `fire_strike(fp)` is taken from the next field tap, ahead of crate taps.
  - On landing: two explosions, a ring, a shake of 10, and a big scorch decal.
  - `_on_synergies_changed` pops the name of each new link at its midpoint and notifies the
    `synergy_formed` tip.
- **`BuildMenu`:**
  - A unit button shows "LINK" / "LINK×N" when it would link on that pad.
  - A built unit's card lists "LINKS: …" plus the summed bonus (`StatBonus.summary`).
  - The next-level stats include the plot's synergy.
- **Tips:**
  - `strike` (`strike_ready`, spotlighting the button): "Tap STRIKE, then tap the field. A
    shell lands there a moment later."
  - `synergy` (`synergy_formed`, spotlighting the unit): "Units near each other boost each
    other. Tap a unit to see its links."
  - That's 20 tips in all. The new events and the `strike_button` focus are added to
    `TipDirector`.
- **Pacing:** the barricade tip now waits until wave 2. The first build phase already teaches
  the enemy and building, and the demo clip showed the barricade card piling on in the first
  minute.

## 2026-09-27 — balance (the campaign curve)

The probe was the bot on seeds 1–8 per sector × tree profile, in scratch
`game/probe_tmp.gd` (deleted). The numbers are wins of 8:

| Variant | Outpost T0 | Canyon T0/T3/T6 | Switchback T0/T3/T6 |
|---|---|---|---|
| **Before E5c** (E5b log, 12 seeds) | 3/12 | 0/12, 4/12, 5/12 | –, 1/12, 4/12 |
| Links form by chance; the bot neither strikes nor picks | 5 | 2/3/6 | 1/2/3 |
| + synergy placement | 6 | 2/4/5 | 2/2/6 |
| + strike (25 s, 30 dmg) | 8 | 6/5/7 | 3/4/4 |
| Both | 8 | 5/5/5 | 2/4/5 |

**First approach: keep the strike and raise HP.** With both on, HP ×1.75/1.5/1.25 gives
Outpost 4, Canyon 0/3/4 and Switchback 1/2/2. But the no-strike bot at that HP wins **0** on
Outpost and averages wave 4.8. The strike would be mandatory and the curve would hang on
perfect strike use. Rejected.

**Chosen: a weaker strike plus milder HP.**
- The strike: 20 damage (× `hp_scale`), a **30 s** cooldown, radius 70. The plan had 30 / 25 s.
- Wave `hp_scale` ×1.35 (Outpost), ×1.25 (Canyon), ×1.1 (Switchback), applied to every
  `waves/*.tres`.

Results with both mechanics on: Outpost T0 6–7, Canyon 1/3/4, Switchback 1/3/3. With neither,
the bot still wins Outpost 2, Canyon 1/2/3 and Switchback 1/1/3. The strike is strong, but
you can play without it.

The integration test's curve reads: outpost T0 6 | canyon [1, 3, 4] | switchback T0/T6 [1, 3].
All its assertions hold. Outpost T0 at 6/8 for the bot is generous. A human will use
strikes and links less efficiently, so sector 1 should land near the old difficulty for a
new player. This is a hand-play call for the user, and B4 re-tunes with real play.

## 2026-09-27 — tests

**New suites:**
- `synergy_test` (7): either order; in range only; once per unit; sell and destruction
  remove links; the preview; splash, chill and slow into shots; beam targets and armour
  pierce.
- `strike_test` (5): not outside waves; lands after the delay through armour, then cools
  down; misses outside the radius; ready at the next wave and shortened by Fire Mission;
  deterministic.

**Added to existing suites:**
- `content_test`: every pair of units has exactly one synergy (21), with valid ids, a non-empty
  effect, and short text; every map has linkable pads; the strike is sane. The card count is
  now 12.
- `run_scene_test`: the strike button arms, the next tap calls it, time slows and restores,
  and it's inert while cooling; the button is hidden between waves; two linked units show
  LINKS on the card, and the synergy tip fires.

**Result:** 229 game tests and 5 tool tests, all green.

## 2026-09-27 — exercised

- `captures/strike-and-links.mp4` (`--seed=3 --autoplay --skip-to-wave=5`, 30 s): the button
  and its cooldown, strikes landing (blast, ring, scorch), link lines, and "RANGEFINDING" /
  "TWIN SCOPES" popups.
- `captures/links-plot3.png`, `links-plot5.png`: unit cards listing their links and bonuses.
- `captures/tips-first-session.mp4` (re-recorded): the Artillery tip spotlights the button at
  wave 1.
- **Not seen yet:** the armed state on a real touch screen. Tests cover it; judge it on the
  phone.
- **Perf:** there's no per-tick synergy work. The strike runs only when strikes are pending,
  and the link and strike views are one `_draw` each.

## 2026-09-27 — E5c complete

**Open for the user:**
1. **The strike's feel:** its button position (top right is far from the thumb; bottom right
   would be the ergonomic spot but crowds the wall spots), the delay (0.9 s), the blast and
   shake.
2. **The synergy list and link visibility:** are the dashed lines too busy with 6+ units?
3. **Difficulty:** Outpost is easy for the bot and needs a human check.
