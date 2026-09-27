# Fixed units and wall spots (no squad): research

_Work item opened 2026-09-26. It is step 1 of the plan in
[`../2026-09-26-escalating-difficulty/research.md`](../2026-09-26-escalating-difficulty/research.md)
(see §2 there for where the squad came from, and why it goes)._

## 1. The request

User, 2026-09-26:

> the troops don't move also, they are a fixed asset, just like a gun/tank/tourete placed at a
> given spot.

> there's no wall squad... the wall is also composed of fixed spots the player can place troops
> or weapons on.

The user then said to go ahead ("ok, after that we can keep working on the game itself")
without picking among the open questions. The recommended defaults are therefore used, and
each is kept easy to change (data or one small rule):

| Question | Default taken | Why |
| --- | --- | --- |
| Who breaks crates? | **The player taps them.** A tap deals `RunConfig.tap_damage` to the crate under the finger. | It keeps an active mid-wave verb and the greed-vs-safety choice (tap loot, or tap a spot to build) without an aimed weapon. This is Plants vs. Zombies' "tap the sun". |
| Wall spots | **3 spots on the wall, one per lane centre** (field y = 876, on the wall sprite) | Enemies are consumed at `wall_y` = 860, so spots behind that line never block a path. Lane centres give each spot a straight line up its lane. |

## 2. Everything the squad touches

Found by grepping for `squad|bullet|boost|drag|shooter|rocket|crit|target_x`:

- **Core:**
  - `SquadStats`, and in `CombatSim`: squad bullets (packed arrays), `_fire_squad`,
    `_move_bullets`, `_hit_crate`, `_hit_enemy`, `squad_x`/`target_x`, the boost.
  - In `Run`: `squad`, `set_target_x`, squad upgrades, `_sync_squad`, `state_hash`.
  - In `Autoplay`: `choose_target_x`, `danger_line`, `squad_first`.
  - In `Economy`: `squad_upgrade_cost`.
  - In `RunModifiers`: the shooters, squad damage/rate, rocket and crit fields.
- **Defs and data:**
  - `SquadUpgradeDef` and `data/squad/*` (3 files).
  - The `RunConfig` "Squad" group.
  - `CrateDef.boost_fire_rate_mult` (the Overdrive crate).
  - Cards: `rapid`, `sharpened`, `crits`, `mortar_crew` (rockets), `crowbars`.
  - Meta: `recruits` (start shooters).
- **Views:**
  - `SquadView`, `BulletField`, `SquadPanel`.
  - The HUD's SQUAD button.
  - The BuildBar's input toggle and `RunController`'s drag/tap modes.
  - The art keys `ui/squad` and `units/trooper`.
- **Tests:**
  - `squad_stats_test`.
  - The squad sections of `combat_sim_test` and `run_test`.
  - `economy_test`.
  - `content_test`'s squad-based rules (crate breakability, one-bullet kill).
  - The drag/tap scene tests.
  - The bullet-budget test.

## 3. Consequences worth noting

- **Balance resets.** Every number was tuned around a squad doing 10 DPS from second 0. The
  opening must now be carried by units alone: start coins and wave 1 need retuning. The
  zero-meta difficulty target is unchanged: the bot loses around waves 6–9, and meta makes
  wins reachable.
- **The bot must tap.** Balance is measured by `Autoplay`, so it taps crates at a human-like
  rate, a knob (`taps_per_second`, default 3). "Crates are breakable in time" becomes a content
  rule at that rate.
- **The build bar moves to the top.** At the bottom (118 px) it would cover the wall spots
  during BUILD. The top of the field is empty in BUILD, since enemies haven't spawned yet.
- **Save v4.** The meta upgrade `recruits` goes away. `SaveData` refunds its levels as bricks,
  like v3 did for `gate_lore` (`CLAUDE.md` §4: migrate, never reset).
- **Performance improves.** The squad's bullets were the biggest per-tick load (up to ~600).
  The stress config drops them.
