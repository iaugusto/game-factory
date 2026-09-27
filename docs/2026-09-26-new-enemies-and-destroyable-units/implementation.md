# New enemies, destroyable units and elites (E5a): implementation log

## 2026-09-26 — defs and core

- **Defs:**
  - `UnitDef.hp` and `hp_at(level)` (+30% per level).
  - `EnemyDef`:
    - Unit attack: `unit_reach`, `unit_damage`.
    - Split: `split_into`, `split_count`.
    - Heal: `heal_radius`, `heal_per_second`.
  - New `EliteDef` (`hp_mult`, `speed_mult`, `armor_bonus`, `regen`, `tint`, text).
  - `SpawnEntry.elite`, carried through `WaveSchedule.Event`.
  - `RunConfig.unit_repair_cost_per_hp` (0.3).
- **`CombatSim`:**
  - `Plot.hp` and `max_hp`. `Enemy.target_plot`, `elite`, `pulse_timer`.
  - **Unit attackers:** after the barricade check, a walker with `unit_reach` stops at the
    nearest built plot in reach (`unit_in_reach`) and strikes it through the same `_strike`.
    At 0 HP, `destroy_unit` empties the plot (no refund) and emits
    `unit_destroyed(plot, def)`.
  - Stopped attackers walk on when their target is empty.
  - The priority is barricade > unit > gate.
  - **Splitters:** `_split` runs on death; children spawn just behind and spread sideways,
    are wave-scaled, and are inserted in sorted position (`_insert_sorted`), because this runs
    mid-tick.
  - **Menders:** `_heal(dt)` heals others within the radius, and emits `mender_pulse` once a
    second while healing.
  - **Elites:** HP and speed are applied at spawn, regen in the movement loop, and armour
    through `effective_damage(..., extra_armor)`.
- **`Run`:**
  - `build` sets the unit's HP; `upgrade` keeps the damage taken.
  - `unit_repair_cost` / `repair_unit`.
  - `sell` clears HP.
  - `state_hash` has plot HP and enemy elite.
- **`Autoplay`:** `_repair_worst_unit` (below 60% HP) runs before other spending.

## 2026-09-26 — content and art

- **`ravager.tres`:** HP 30, speed 40, armour 1. It stops at pads within 90 and strikes for 6
  every 0.8 s. Weak to kinetic, resists cryo; threat 8.
- **`splitter.tres`:** HP 22. Its brood is 3 Skitters. Weak to explosive, resists kinetic.
- **`mender.tres`:** HP 18. Heals 6% per second within 80. Weak to piercing, resists explosive.
- Each has an intel line.
- **Elites:** `armoured` (+3 armour, ×1.3 HP, gold), `swift` (×1.45 speed, cyan),
  `regenerating` (4% per second, green).
- **Unit HP** (after tuning): Rifleman 80, MG 120, Cryo 100, Mortar 140, Sniper 90, Rail 180.
- **Waves:**
  - **Outpost:** Ravager from wave 5 (1), Mender from 6, Splitter from 7, elites from 7
    (Swift), Armoured Carapaces at 9, Armoured Drones at 10.
  - **Canyon:** each a wave earlier. Its first Ravager comes down the new left flank at wave 4.
  - The script's added resource lines landed under the header line. All wave files were
    normalised (header, resources, body).
- **Art:** `enemies.py` gains `ravager` (spiked, rust, scything claws), `splitter` (a bloated
  sac with the brood visible) and `mender` (slender, glowing halo). The `palette` has entries
  for each. 46 SVGs, checked on a preview sheet.

## 2026-09-26 — views

- **`EnemyField`:** elites are tinted (instance colour) and get a star in their tint beside
  the HP bar (elites always show their bar).
- **`PlotView`:** an HP bar when damaged.
- **`RunController`:**
  - a unit strike → sparks;
  - `unit_destroyed` → an explosion, a scorch decal and "<UNIT> LOST", and the card closes if
    it was open on that plot;
  - `mender_pulse` → a green ring of its heal radius.
- **`BuildMenu`:** a "REPAIR h/max HP ● N" button (hidden at full HP).
- **`BuildBar`:** elite groups get a second preview entry, tinted, "★×N", with a tooltip.

## 2026-09-26 — tests

- **New `new_enemies_test` (7 cases):**
  - a Ravager mauls the unit beside its path, destroys it (no refund), then walks on;
  - it ignores empty and far pads, and the barricade comes first;
  - repair;
  - an upgrade keeps the damage taken;
  - a Splitter's brood spawns where it fell, and the list stays sorted;
  - a Mender heals its neighbour and not itself or the far one;
  - elites (HP, armour, speed, regen).
- **`content_test` (+3):**
  - every unit has HP, and repair has a price;
  - new types arrive at most 2 at first, with the unit-hunter, Splitter and Mender not before
    wave 4;
  - Splitters split into a real enemy, and elites come from wave 5 with a title.
  - The enemy count is now 8.
- **`run_scene_test` (+1):** the card repairs, and a fallen unit leaves an empty pad that opens
  the build ring.
- **`run_integration_test`:** "the Canyon is harder" now compares **mid-meta wins** (see
  Balance) and checks zero meta never wins there.
- **Result:** `scripts/test.sh` → **173/173 passed, 0 orphans**. Tools → **5/5 OK**.

## 2026-09-26/27 — balance

1. **With the new enemies added, runs got much harder.**
   - Outpost: zero meta median 6; mid meta 0/10 wins.
   - Canyon: zero meta median 5; mid meta 0/10.
   - Varying Ravager damage (8/5), Mender heal (6%/3%) and brood size (3/2) moved nothing.
2. **Traces of losing mid-meta runs:**
   - Ravagers destroyed 3–7 units a wave, mostly Snipers and Mortars, and the bot couldn't
     rebuild. A 45-HP Sniper died to one Ravager in about 4.5 s: **unit HP doubled**.
   - Ravager damage went 8 → 6 and its threat 4 → 8, so the bot counters it.
   - An **Armoured elite Carapace at wave 7** (armour 6) broke the gate against level-1
     Snipers. **Elites were rescheduled:** Swift Skitters come first (Outpost wave 7, Canyon
     wave 6), and the armoured ones at waves 9 and 10.
3. **HP:** waves 5+ ×0.8 on both maps, then waves 8–10 ×0.55. At 0.75 on waves 8–10, mid meta
   still won nothing; at 0.55 it won 5/10 on the Outpost.
   - The Canyon then won more than the Outpost at mid meta (4 vs 3 on the test's seeds), so its
     waves 7–10 got ×1.1 (×1.2 gave 0 wins).
4. **Final (bot, 12 seeds):**

   | Map | Zero meta | Mid meta |
   | --- | --- | --- |
   | Outpost | median 7, 0 wins | 4/12 wins |
   | Canyon | median 6, 0 wins | 1/12 wins |

   On the test's 8 seeds, mid-meta wins are Outpost 3, Canyon 1.
5. **Note:** the HP schedule now dips at wave 8 (1, 1.35, 1.8, 2.4, 2.72, 3.84, 5.44, 4.14,
   5.46, 6.82 on the Outpost). Waves 8–10 carry their weight in *new enemy types and volume*,
   not HP, which is the direction the research argued for. Wave threat still rises every wave
   (content test).

## 2026-09-27 — running the game

- **Frame time** (Canyon, `--stress --perf`, WSLg): 122–125 fps, frame 8.0–8.2 ms, **sim tick
  1.7–1.95 ms**, 103–127 draw calls.
  - The sim tick is up from E4's 1.5–1.8: the heal pass scans every enemy each tick even with
    no Mender on the field.
  - Still within the desktop budget; **the B5 phone measurement is now the gate before any
    more per-enemy work.**
- **Clips:**
  - `captures/e5a-wave8.mp4` (seed 2, Outpost wave 8, autoplay). The sheet shows Mender heal
    rings, Splitters and their broods, Ravagers at pads, units jammed, and elites.
  - `captures/e5a-preview.mp4`: wave 8's preview with all eight groups, including "★×8" Swift
    Skitters tinted cyan, and damaged units with HP bars.

**Status: complete.**

**👤 For the user:** play waves 5–10 on both maps. Do Ravagers feel like "kill that one
first"? Is losing a unit fair or frustrating? Do the elites read?
