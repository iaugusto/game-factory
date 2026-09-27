# Fixed units and wall spots (no squad): implementation log

## 2026-09-26 — the user answers the open questions

The user answered while this was being built (recorded in
`../2026-09-26-escalating-difficulty/research.md` §6):

1. **Crate breaking** was left to "what gives better gameplay": **tap to break**, as built.
2. **Progression:** a campaign of maps.
3. **Units:** enemies may hurt or disable units. Losing needs a definition (§7 there).
4. **Maps:** lanes are stale; maps move to paths.

None of this changes step 1's scope.

## 2026-09-26 — core: the squad is removed, and crates break by tapping

- **`CombatSim`:**
  - Removed: squad movement, squad fire, rockets, and the packed squad-bullet arrays with
    their movement and hit code.
  - Added `tap_crate_at(p, damage)`: the nearest crate within radius + `tap_slop` takes the
    damage × (1 + `crate_damage_bonus`).
  - Added the signal `crate_tapped`, emitted by a hit that doesn't break the crate.
  - `boost_rate_mult()`: the Overdrive boost now divides every unit's reload (`reload_of`).
  - Added `damage_of()` (`unit_damage_bonus`) and `reach_of()` (`unit_reach_bonus`), used by
    targeting, beams and the reach ring.
  - Unit shots can crit (`crit_chance`, drawn from the `combat` stream).
- **`Run`:**
  - Removed: `squad`, `set_target_x`, the squad upgrades and `_sync_squad`.
  - Added `tap(field_pos)`, which works in WAVE only.
  - `state_hash` drops the squad fields.
- **Deleted:** `SquadStats` (and its test), `SquadUpgradeDef`, `data/squad/*`, and
  `Economy.squad_upgrade_cost`.
- **`RunModifiers`:**
  - Removed: `start_shooters_bonus`, `shooters_bonus`, `squad_damage_bonus`,
    `squad_fire_rate_bonus`, `rocket_bonus`.
  - Added: `unit_damage_bonus`, `unit_reach_bonus`.
- **`RunConfig`:** the Squad group is gone. It gains a Units group (`crit_multiplier`) and a
  Crates group (`tap_damage` 1, `tap_slop` 16). `squad_upgrades` is removed.
- **`CrateDef`:** `boost_fire_rate_mult` becomes `boost_rate_mult` (units). HP is now in taps.
- **`Autoplay`:**
  - Removed: aiming (`choose_target_x`, `danger_line`, `squad_first`).
  - It taps the crate nearest the wall at `taps_per_second` = 3, tick-based and
    deterministic, via `_tap_due`.
  - It buys unit upgrades only.
- **`SaveData` v4:** it refunds `recruits` levels as bricks (5/10/20/35/55). The v2→v3 code
  was generalised into `_refund_removed`.

## 2026-09-26 — data

- **Crates, in taps:** Supply 14 → 5, Munitions Cache 45 → 12, Overdrive 28 → 7. Overdrive
  gives ×2 unit fire for 8 s.
- **Cards:**
  - `crits` now covers unit shots.
  - `crowbars` now covers taps.
  - `sharpened` becomes +15% unit damage.
  - `rapid` and `mortar_crew` are deleted.
  - `rangefinder` is new: +10% reach, two stacks. That makes 11 cards.
- **Meta:** `recruits` is deleted. `drill` is new ("Drill Instructors": −5% reload per level;
  10/25/50 bricks).
- **Map:** `outpost.tres` gains 3 **wall spots** at (90/270/450, 876), one per lane, on the
  wall sprite behind `wall_y` = 860. That makes 11 plots.

## 2026-09-26 — views and UI

- **Deleted:** `SquadView`, `BulletField`, `SquadPanel`, the HUD's SQUAD button, and the build
  bar's input toggle. `RunController` loses the `InputMode` enum, drag handling, `--input` and
  `--open-squad`.
- **`RunController.handle_pointer`** handles presses only:
  - A press on a crate taps it (`Run.tap`).
  - A press on a plot opens its menu.
  - Emulated mouse input and autoplay are ignored.
- **`Fx.crate_tap`:** a small pop and splinters on each tap. Overdrive rings every built unit.
- **`BuildBar`** moved to the top, under the HUD (`HEIGHT` 104). The field there is empty
  during BUILD. At the bottom it would have covered the wall spots.
- **`PlotView`:**
  - The reach ring uses `reach_of`.
  - **Wall spots draw at z 6, above the wall sprite (z 5).** The first still showed them
    hidden under the wall; a scene test now checks this order.
- **Art generator:** `ui/squad` and `units/trooper` removed; 32 SVGs. Tool tests 5/5.

## 2026-09-26 — tests

- **Rewritten:**
  - `combat_sim_test`, with tap cases:
    - 5 taps break a crate;
    - taps miss outside the radius, and slop widens it;
    - a tap hits the crate under the finger;
    - no taps outside a wave;
    - crowbars;
    - reward bonus;
    - the boost halves reload for its duration only.
  - The unit damage, reach and crit bonuses each have a case.
  - The fizzle case now kills its target with a second unit.
- **`run_test`** drops the squad and meta-shooter cases.
- **`economy_test`** drops `squad_upgrade_cost`.
- **`meta_progress_test`** uses `wall_hp_bonus`.
- **`save_data_test`** adds v3 → v4.
- **`content_test`:**
  - Crates must break in under half their travel at 3 taps/s, and take more than one tap.
  - The wall must carry a spot per lane.
  - Wall spots are exempt from the path rule.
  - Counts are updated.
- **`run_scene_test`:** the drag and tap-mode cases are replaced by:
  - a wall spot builds, and is drawn above the wall;
  - a press on a crate taps it and opens no menu, and a release doesn't tap;
  - tapping a crate to zero pays out and releases its view;
  - empty ground does nothing;
  - emulated mouse input is ignored;
  - autoplay ignores the pointer;
  - the build bar covers no plot.
- **Integration:** the bullet budget becomes a unit-shot budget (≤ 20 per plot; the peak seen
  is 9).
- **Result:** `scripts/test.sh` → **110/110 passed**. Tools → **5/5 OK**.

## 2026-09-26 — balance probe (scratch script, deleted)

12 seeds, bot at 3 taps/s. Mid meta is +60 wall, +30 coins, −16% prices, +20% crate coins,
+10% reload speed.

| Setting | Waves cleared | Wins |
| --- | --- | --- |
| Zero meta, bot capped at 8 units | 6–9 | 0/12 |
| Mid meta, capped at 8 | 8–9 | 0/12 |
| No taps at all | 2 (all seeds) | 0/12 |
| **Zero meta, all plots** | **7–9** | **0/12** |
| **Mid meta, all plots** | 8–10 | **2/12** |
| Mid meta, all plots, Queen HP 180 | 8–10 | 4/12 |

- **Crates are the income:** without taps, every run dies at wave 2.
- **Mid meta was hitting a wall at wave 10.** A trace showed the bot sitting on 527 coins with
  3 plots empty: it capped itself at 8 units, and squad upgrades used to soak up the rest.
  `Autoplay.max_units` now defaults to 99 (fill every plot).
- **With that change,** zero meta clears 7–9 waves and mid meta wins 2/12. That's close to the
  pre-pivot numbers (7–9, and 3/12), so **the Queen's HP is unchanged**.
- **Finding for the next steps:** mid-meta runs end with 100–390 unspent coins once all 11
  plots are maxed. The late game has no coin sink. B4 or the difficulty work must add one
  (more unit levels, replacing a unit, or spending on the gate/wall).
- **The bot breaks 100% of crates at 3 taps/s,** so the greed-vs-safety decision has no
  pressure yet. Crate timing and placement belong to the enemy-mix step.

## 2026-09-26 — running the game

- **Frame time** (`--autoplay --stress --perf`, WSLg, OpenGL 3; 260 enemies, 11 plots built):
  - 138–168 fps, frame average 5.2–7.3 ms, max ≈ 12 ms in steady state.
  - **The sim tick is 0.47–0.61 ms,** down from ~0.8 ms. The squad's bullets are gone.
  - 74–82 draw calls, up from 51–56, because of the 3 extra plot views. That's well within
    budget.
- **Clips** (`scripts/capture_clip.sh`, ffmpeg from content-creation-factory's venv via
  `FFMPEG_BIN`):
  - `captures/fixed-build.mp4` (3 s): BUILD at wave 4. The bar is at the top, and the three
    wall spots sit on the wall.
  - `captures/fixed-midgame.mp4` (20 s): seed 5, autoplay, wave 5. It shows taps on crates,
    coin bursts, and a built wall spot.
- **Checked from stills and a contact sheet.** They found the hidden wall spots (fixed above).
  "WAVE N INCOMING" still overlaps "WAVE N" for a moment, a known rough edge from the pivot.
- **Not shown in the clips:** a human tapping. The bot's taps go through the same `Run.tap`,
  so the tap effect is visible, but finger feel on a phone is B5.

## 2026-09-26 — docs, closeout

- Updated:
  - `detailed-project-overview.md`: map, systems, rules, dependencies, change log.
  - `README.md`: status, launch args.
  - `ROADMAP.md`: this work item and the next steps.
  - `CLAUDE.md` §1 and §6.
  - The `project.godot` description.

**Status: complete.**

**👤 For the user:** the two clips, and a hand play to judge whether taps feel good.
