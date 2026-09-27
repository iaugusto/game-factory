# New enemies, destroyable units and elites (E5a): plan

## Defs

- **`UnitDef`:** `hp` (at level 1) and `hp_at(level)` (+30% per level).
- **`EnemyDef`:**
  - Unit attack: `unit_reach`, `unit_damage` (0 = never attacks units).
  - Split: `split_into: EnemyDef`, `split_count`.
  - Heal: `heal_radius`, `heal_per_second` (a fraction of the target's max HP).
- **`EliteDef`** (new): `id`, `title`, `hp_mult`, `speed_mult`, `armor_bonus`, `regen`, `tint`.
- **`SpawnEntry.elite`.**
- **`RunConfig.unit_repair_cost_per_hp`** (0.3).

## Core

- **`CombatSim`:**
  - `Plot.hp` and `Plot.max_hp` (set on build and upgrade by Run).
  - `Enemy.elite`, `Enemy.target_plot`.
  - **Movement:** a unit-attacker that isn't stopped looks for the nearest built plot within
    `unit_reach`. If it finds one, it stops (`sieging` + `target_plot`) and strikes it:
    `plot.hp -= unit_damage`. At 0 the unit is destroyed (signal `unit_destroyed(plot)`: the
    plot empties and targets are cleared), and the enemy walks on.
  - The priority is the barricade, then a unit, then the gate.
  - **Split:** in `_damage_enemy`, on death, spawn children at its path, `d` and nearby
    offsets. They're inserted into the path's sorted list (`_insert_sorted`), with hp scaled
    by the wave's `hp_scale` (elites don't pass their property on).
  - **Heal:** `_heal(dt)` for each Mender over the enemies on all paths within radius. It
    emits `mender_pulse` once per second for the view.
  - **Elites:** HP and speed are applied at spawn; `regen` ticks; armour goes through
    `effective_damage(..., extra_armor)`.
- **`Run`:**
  - `build` and `upgrade` set the plot's HP (an upgrade keeps the damage taken).
  - `unit_repair_cost` and `repair_unit`.
  - `state_hash` includes plot HP and elites.
- **`Autoplay`:** it repairs damaged units (cheapest first) before upgrades. A destroyed plot
  is just empty, so it rebuilds.

## Content

- `ravager.tres`, `splitter.tres`, `mender.tres` in `data/enemies`, each with an intel line.
- `data/elites/armoured|swift|regenerating.tres`.
- Unit HP: Rifleman 40, MG 60, Cryo 50, Mortar 70, Sniper 45, Rail 90.
- **Waves:**
  - **Outpost:** the Ravager from wave 5 (≤ 2), the Mender from 6, the Splitter from 7, elites
    from 7.
  - **Canyon:** a wave earlier each.

## Art

`enemies.py` gains `ravager` (a hunched, clawed brute; rust-red), `splitter` (a bloated sac
with visible brood; a sickly yellow) and `mender` (a slender bug with a glowing green halo
organ).

## Views

- **`EnemyField`:** instance tint from the elite; a ★ over elites' HP bars.
- **`PlotView`:** an HP bar when damaged; a "destroyed" flash is handled by the controller.
- **`RunController`:**
  - `unit_destroyed` → an explosion, "UNIT LOST" and a rubble decal;
  - `mender_pulse` → a green ring;
  - a unit-attack strike → sparks on the pad.
- **`BuildMenu`:** the card shows HP and "REPAIR ● N".
- **`BuildBar`:** elites in the preview (a tinted icon + ★).

## Tests

- **Core:**
  - a Ravager stops at a pad in reach, destroys it, then walks on;
  - it ignores empty and out-of-reach pads;
  - the barricade takes priority;
  - repair costs coins and restores HP;
  - an upgrade keeps the damage taken;
  - a Splitter's death spawns its brood at its spot, and they're sorted;
  - a Mender heals others and not itself;
  - elites apply HP, speed, armour and regen.
- **Content:**
  - every new enemy has one weakness, a description and art;
  - new types are introduced at most 2 at first, not before wave 5 on the Outpost;
  - elites only from wave 5 on;
  - every unit has `hp > 0`.
- **Scene:**
  - the card shows REPAIR and repairs;
  - a destroyed unit's view resets to an empty pad.
- **Integration:** the bot guards (zero meta doesn't win; the Canyon is harder), and the
  determinism test.
