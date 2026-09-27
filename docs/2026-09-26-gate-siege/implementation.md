# Gate siege and enemies that disable units: implementation log

## 2026-09-26 — core: the siege, spits, jammed units

- **`CombatSim`:**
  - **The siege:** an enemy that reaches `wall_y` stops (`Enemy.sieging`), strikes at once,
    then strikes every `EnemyDef.attack_interval` (`strike_timer`), adding its `wall_damage`
    to `pending_wall_damage`.
  - The signal `enemy_struck(enemy, damage)` **replaces** `enemy_reached_wall`. Enemies no
    longer vanish at the wall; a sieging enemy holds the wave open until killed.
  - **Spits:**
    - A new `Spit` class and a `spits` list.
    - `_spit_enemies`: each spitter spits at `spit_target`, the nearest built plot in range
      that isn't jammed (ties go to the lower index). Its timer then resets to
      `spit_interval`.
    - `_move_spits`: globs always land (plots don't move). On landing, the plot gets
      `Plot.disabled = max(disabled, duration)` and the signal `unit_disabled` goes out.
    - The signal `spit_fired` is new.
  - **`Plot.disabled`:** a jammed plot doesn't fire, and its cooldown doesn't tick. The timer
    counts down in `_fire_plots`.
  - `begin_wave` and `end_wave` clear the spits and the disabled timers.
- **`EnemyDef`:** `attack_interval` (1.0), plus a Spit group: `spit_interval`, `spit_range`,
  `spit_speed`, `disable_duration`.
- **`Run.state_hash`:** includes the strike and spit timers, the globs in flight, and the
  plots' disabled timers.

## 2026-09-26 — Spitter content and art

- **`data/enemies/spitter.tres`:** HP 14, speed 30, 4 per strike, gold 2, radius 13. It spits
  every 3.5 s from range 140 and jams for 4 s.
- **Waves:** 4 (2, lane 1), 5 (2), 6 (3), 7 (3), 8 (4), 9 (5), 10 (4).
- **Art:** `gf_tools/art/enemies.py` gains `spitter`, a squat teal bug under a glowing lime acid
  gland, with a dripping spout. `palette.SPITTER` added; 33 SVGs. A preview sheet checked its
  silhouette against the Drone, Skitter and Carapace.

## 2026-09-26 — views

- **`EnemyField.position_of`:**
  - Enemies are drawn held at the wall's top edge rather than half under it.
  - A sieging enemy lunges 7 px on each strike (recoiling in 0.22 s).
  - Its walk frame freezes (y no longer changes).
- **`RunController`:**
  - `enemy_struck` → `Fx.gate_strike` (new: sparks and a small shake) and a "−N" popup.
    `wall_hit` would have shaken the screen nonstop with several enemies striking every
    second.
  - `spit_fired` → a flash at the mouth.
  - `unit_disabled` → `Fx.acid_splash` (new) and a "JAMMED Ns" popup.
  - **LOST → `_breach()`:**
    - a 24-unit shake and 5 blasts along the wall;
    - the banner "THE GATE HAS FALLEN";
    - `Engine.time_scale` 0.3 for `BREACH_TIME` 1.2 real seconds, then restored.
  - The result is shown with a matching delay.
- **`PhaseOverlay.show_result(…, delay)`:**
  - It stays transparent and unclickable (the button is disabled) for `delay` real seconds,
    then fades in over 0.35 s.
  - The title is now "THE GATE FELL".
- **`ShotField`:** draws globs as a lime glow with a trail.
- **`PlotView`:** a jammed unit is greyed with lime goo and a countdown ring, and has no
  "charged" glow.

## 2026-09-26 — tests

- **Fixtures:**
  - A fifth plot, `WALL_SPOT` (270, 876).
  - `Fixtures.sentinel(run)` puts a long-reach gun there. Flow tests need waves to end, and
    enemies at the gate no longer leave by themselves.
- **`combat_sim_test`**, siege:
  - An enemy stops and strikes once per interval: first on arrival, then every 60 ticks, and
    it holds the wave open.
  - Killing the sieger stops the damage and the wave ends.
  - The gate breaks → LOST.
  - A Queen breaks the gate in one strike.
- **`combat_sim_test`**, spits:
  - A spitter jams the nearest unit in range only.
  - A jammed unit holds fire, then recovers.
  - Spitters ignore empty, jammed and out-of-range plots.
  - Spits are cleared with the wave.
  - A spitter at the gate stops spitting (below).
- **`run_test`:** uses the sentinel; wall/gold expectations updated; regen uses a
  one-strike enemy.
- **`content_test`:**
  - 5 enemies.
  - Every enemy strikes on an interval.
  - Some unit outranges every spitter.
  - The disable lasts less than 2 spit intervals.
  - Spitters are introduced (at most 2) no earlier than wave 4.
- **`run_scene_test`:**
  - A jammed unit's view shows the state and recovers.
  - Losing plays the breach, then the result: slow motion, the button disabled until the fade
    ends, the time scale restored, and restart resets.
- Two fixes while writing them:
  - a misplaced indent in `plot_view.gd` (a parse error);
  - a test that checked for the unit's next shot before its paused reload had finished.
- **Result:** `scripts/test.sh` → **123/123 passed**. Tools → **5/5 OK**.

## 2026-09-26 — balance

First probe after the siege, 12 seeds:
- **Zero meta:** clears a median of **5** waves, 0 wins.
- **Mid meta:** clears a median of 7, 0 wins.
- Much too hard.

The investigation:

1. **Per-strike damage barely mattered** (×1, 0.6, 0.4 and 0.3 all gave a median of 5).
2. **A trace of a loss** (seed 1, wave 6) showed siegers reached only by jammed units, with
   **Spitters at the gate jamming the wall spots point-blank**. That's a death spiral: the
   units that should kill them are the ones jammed. **Rule: a sieging spitter strikes and
   no longer spits.** Test added.
3. **That alone changed nothing** (the probe gave the same result).
   - (The probe's jam counter read 0 throughout, because GDScript lambdas capture locals by
     value. That's a probe bug, not a game bug.)
   - The real cause: a leak used to cost a fixed amount. **Now every leak strikes until
     killed, so units must kill essentially a wave's whole HP**, and the ×14 HP ramp
     outgrows zero-meta firepower at waves 5–6.
4. **The grid** (HP ramp scale `m` × strike damage `k`):

   | m | k | Zero meta: median, wins | Mid meta: median, wins |
   | --- | --- | --- | --- |
   | 0.80 | 1.0 | 7, 0 | 8, 2 |
   | **0.65** | **1.0** | **7, 0** | **8, 4** |
   | 0.65 | 0.6 | 8, 0 | 9, 5 |
   | 0.50 | 1.0 | 8, 2 | 10, 9 |

   **Applied: m = 0.65, strike damage unchanged.** `hp_scale` per wave is now 1.00, 1.55,
   2.31, 3.18, 4.13, 5.13, 6.19, 7.29, 8.44, 9.61 (it was up to 14.25). It's re-verified on
   the real data: zero meta [5–8], median 7, 0 wins; mid meta 4/12 wins. It happens to lean
   toward the research's point that HP sponges shouldn't carry the ramp. E3's threat budget
   will replace this ramp.
5. **The integration guard** (8 seeds): cleared [6, 8, 8, 7, 8, 6, 8, 7], 0 wins.

## 2026-09-26 — running the game

- **Frame time** (`--stress --perf`, WSLg): 118–141 fps, frame average 7.1–8.5 ms (max ≈ 16
  ms after warm-up), sim tick 0.61–0.73 ms, 74–79 draw calls.
  - That's somewhat slower than E1's measurement (5.2–7.3 ms, sim tick 0.5–0.6 ms).
  - The stress wave's enemies are too slow to siege, and it has no spitters, so the extra
    per-tick cost is the spitter scan plus `position_of`, and WSLg run-to-run variance.
  - Still well inside the 16.6 ms budget. The phone measurement is B5.
- **Clips** (`scripts/capture_clip.sh`), checked with contact sheets:
  - `captures/siege-spitters.mp4` (24 s, seed 1, wave 5, autoplay): Spitters jam units
    (lime goo, "JAMMED 4s", the countdown ring), and the units recover.
  - `captures/gate-breach.mp4` (16 s, seed 11, 42 s into wave 6):
    - Carapaces pound the gate: lunges, "−15" every second, the gate going 56 → 0.
    - Then "THE GATE HAS FALLEN" in slow motion, and the result fading in as "THE GATE
      FELL".
- **Seen in the clips, for later (not bugs):**
  - Carapaces (15 per strike) are the real gate-breakers. That's by design: slow and tough
    means "kill it before it arrives".
  - A sieger in lane 0 or 2 overlaps the top of that lane's wall spot a little.

**Status: complete.**

**👤 For the user:** the two clips. Does the siege read, and does the breach land? Should
Spitters feel stronger or weaker?
