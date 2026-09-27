# Fixed units and wall spots (no squad): plan

## Scope

1. **Remove the squad everywhere:** core, defs, data, views, UI, art keys, and tests.
2. **Crates break by tapping:**
   - Core API `Run.tap(field_pos) -> bool`: the crate under the point (within its radius plus
     `RunConfig.tap_slop`) takes `tap_damage × (1 + crate_damage_bonus)`.
   - A new signal `CombatSim.crate_tapped`.
   - Input: a press on a crate taps it; otherwise a press on a plot opens its menu. Nothing
     else reacts.
3. **The Overdrive crate** makes every unit reload ×2 for 8 s. The field is renamed
   `CrateDef.boost_rate_mult`, and the boost is applied in `CombatSim.reload_of`.
4. **Wall spots:** `outpost.tres` gains 3 plots at (90/270/450, 876). `content_test` exempts
   plots at or behind `wall_y` from the "off enemy paths" rule.
5. **Cards and meta:**

   | Card | Change |
   | --- | --- |
   | `crits` | Unit shots can crit |
   | `sharpened` | Unit damage +15% (new `unit_damage_bonus`) |
   | `crowbars` | Taps deal more to crates |
   | `rapid` | Deleted |
   | `mortar_crew` | Deleted |
   | `rangefinder` | New: unit reach +10% (new `unit_reach_bonus`), a placement-relevant card |

   - Meta: `recruits` is deleted. A new `drill` meta gives units −5% reload per level.
   - `SaveData` v4 refunds `recruits`.
6. **`Autoplay`:**
   - It taps the most urgent crate (nearest the wall) at `taps_per_second`.
   - It builds and upgrades units only.
   - It prefers wall spots last: `plot_focus` stays at the field centre.
7. **Rebalance:** start coins, wave 1–3 pressure, crate HP in taps, and unit prices. Probed
   with the bot over 8–12 seeds.
8. **UI:**
   - The BuildBar sits at the top (no input toggle); its hint reads "Tap a pad to build · tap
     crates for coins".
   - The HUD has no SQUAD button.
   - A tap on a crate shows a small hit spark.
9. **Docs:** the overview, README, ROADMAP, CLAUDE.md §1 (it says "an aimed squad"), and
   `project.godot`'s description.

## Interfaces

```gdscript
# Run
func tap(field_pos: Vector2) -> bool          # WAVE only; true if a crate was hit
# CombatSim
signal crate_tapped(crate: Crate)
func tap_crate_at(p: Vector2, damage: float) -> bool
func reach_of(def: UnitDef) -> float          # reach × (1 + unit_reach_bonus)
func damage_of(def: UnitDef, level: int) -> float
# Autoplay
var taps_per_second: float = 3.0
```

## Tests

- **Replaced:** the squad tests become tap tests:
  - A tap breaks a crate after N taps and pays.
  - A tap misses outside the radius.
  - A tap picks the crate under the finger, not the one behind.
  - Tapping outside WAVE does nothing.
  - The crowbar bonus applies.
  - The boost halves the reload for its duration only.
- **Units:** the damage bonus, reach bonus and crit (a forced 100% chance) each get a test.
- **Save:** v3 → v4 refunds `recruits`.
- **Content:**
  - Every crate is breakable in under half its travel time at 3 taps/s.
  - Wall spots are behind `wall_y`.
  - Counts are updated.
- **Scene:**
  - A press on a crate taps it and doesn't open a menu.
  - A press on a plot opens the menu.
  - Emulated mouse input and autoplay ignore the pointer.
  - The build bar sits at the top and doesn't cover any plot.
- **Integration:**
  - The determinism test stays.
  - The bullet budget becomes a unit-shot budget.
  - The zero-meta guard stays.

## Performance

Squad bullets are gone (they were up to ~600 in flight). `--stress` keeps 260 enemies and all
11 plots firing. Frame time is recorded before and after.

## Risks

- **The balance feel of an idle opening:** with no squad, the first seconds are quiet until
  units fire. Wave 1 is tuned so the first Drones meet a built unit.
- **Tap targets on phones:** crates are about 36 px, plus 16 px of slop. The clip will show
  whether that reads.
