# Content expansion: plan

**Date:** 2026-09-27. **Status:** updated with the user's answers (research §6). Waiting on
their staging choice.

## Scope

- 3 new sectors (4–6), 30 new waves.
- 4 new enemies (Wasp, Warden, Burrower, Bombardier).
- 3 new bosses (Broodmother, Siege Titan, The Overmind) and a survivable Hive Queen.
- Abilities as data: the strike moves into it, and 4 new abilities are added (Cryo Bomb,
  Napalm Line, Minefield, Repair Drones). Overcharge is held back as a spare.
- **One special attack per map,** picked when the map starts, from those unlocked through the
  campaign. The first time each is offered, a quick tutorial covers what it does and its
  reload time.
- The skill tree is extended for 18 stars.
- All of it gets art, tips, bot play and balance.

**Out of scope:** Android (B5), audio, new unit types.

## Stages

Each stage ends with tests green, a stress-perf check, a balance run, clips, and the docs
updated. Then the user plays it or judges the clips before the next stage.

### Stage 1: abilities as data + the pick at map start

**Core**
- `defs/ability_def.gd` (`AbilityDef`): `id`, `display_name`, `description`, `icon`,
  `cooldown`, `targeted`, `delay`, `radius` and `kind` (STRIKE, FREEZE, BURN_LINE, MINES,
  REPAIR), plus per-kind numbers.
- `data/abilities/*.tres`: strike, cryo_bomb, napalm, minefield, repair.
- `RunConfig.abilities` (the pool); the `RunConfig.strike_*` fields move into
  `strike.tres`.
- `core/run.gd`:
  - `ability: AbilityDef` (the one picked for this run) and its cooldown.
  - `call_ability(pos)` and `ability_ready()`.
  - `call_strike` stays as a wrapper for tests.
- `core/combat_sim.gd`: generalize `Strike` → `AbilityCast`. Effects are resolved after the
  move pass, as now:
  - **freeze:** sets a timed `stun` on each enemy, which the move pass reads.
  - **burn:** a `Hazard` strip; enemies inside take damage over time.
  - **mines:** `Mine`s on the path; the first enemy to reach one's `d` sets it off.
  - **repair:** gate and unit HP.
- `core/save_data.gd`: `unlocked_abilities` and `last_ability` (the default next pick),
  saved as v7 with a migration from v6 (the strike and cryo unlocked).

**UI**
- `StrikeButton` → `AbilityButton` (one, top right), showing the picked attack's icon and
  cooldown ring.
- **The pick at map start:** when a run opens (in BUILD, before wave 1), a panel shows the
  unlocked attacks as cards: icon, name, one line, damage/effect, reload time. The last pick
  is preselected.
- **The first-time tutorial:** the first time an attack is offered, its card opens a tip.
  It stops time, uses the existing `TipDef` system, and covers what it does, how to aim and
  the reload time. On the first cast, a short "tap the field to aim" tip.

**Bot:** a target picker per ability kind (strike: the best cluster, as now; freeze: the
gate's siegers or the biggest threat near the wall; napalm: the densest path segment; mines:
ahead of the lead enemy; repair: gate < 50%).

**Art (`fx` icons):** ability icons; FX for freeze, burn, mines and repair.

**Tests:** unit tests for each effect kind; the pick at map start and the cooldown; the first-time tip; the save migration;
an integration test where each ability is cast in the scene.

### Stage 2: four new enemies

**`EnemyDef` fields:**
- `flying` (skips the barricade, mud, and SHELL hits)
- `shield_radius`, `shield_amount`, `shield_regen` (Warden)
- `burrow_every`, `burrow_length` (Burrower; untargetable while under)
- `siege_range`, `siege_damage`, `siege_interval` (Bombardier: stops at range and lobs at the
  gate)

**Sim:** each rule in `CombatSim`, keeping the binary-search targeting. Submerged enemies are
skipped by a flag check. Shields are absorbed in `effective_damage` order (the shield first,
then armour).

**Art:** four new walk atlases, each in its own hue. Proposed: Wasp amber-and-black; Warden
steel-blue with a visible shield bubble (drawn by `EnemyField`); Burrower earth-brown with a
dirt mound while under; Bombardier bile-green with a sac cannon.

**Chart:** Wasp weak to kinetic; Warden weak to explosive; Burrower weak to cryo; Bombardier
weak to piercing. Each gets an intel tip.

**Tests:** a unit test per rule (flying passes the barricade and ignores shells; shields
absorb and regenerate; submerged enemies can't be targeted; the Bombardier stops at range
and damages the gate). The content test checks every enemy has exactly one weakness.

### Stage 3: bosses as data

- `defs/boss_phase.gd` (`BossPhase`): `at_hp_fraction`, `spawn` (`EnemyDef` × count),
  `armor_delta`, `speed_mult`, `shield_while_alive` (an `EnemyDef` id), `pause_seconds`.
- `EnemyDef.phases: Array[BossPhase]`.
- **Hive Queen:** `wall_damage` 999 → 50 (the user's call: 2 hits on a base gate, 3 with any
  gate upgrade), and one phase at 50% (a Skitter swarm).
- **Broodmother, Siege Titan, The Overmind:** each gets art, phases and a tip.
- A boss HP bar at the top of the HUD while a boss is on the field, with phase ticks.
- **Tests:** phases fire once each, in order, at their thresholds; shield-while-alive holds
  until the escort dies.

### Stage 4: sectors 4–6 + progression + balance

**Maps:** `data/maps/mire.tres`, `ashfall.tres`, `hive.tres` (paths, plots, unlock waves,
barricade slots, zones, biome).

**Biomes:** `swamp`, `ash` and `infested` added to `terrain.BIOMES`. Infested turns the creep
up, which is fine for the finale.

**Waves:** 30 new `WaveDef`s:
- each new enemy appears alone first, then mixed in
- each new boss closes wave 10 of its sector
- the threat grows (the content test checks it)

**Progression**
- `RunConfig.maps` gets 6 entries.
- The campaign screen scrolls through 6 sector cards.
- Ability unlocks per sector.
- The skill tree gets a sixth row (3 nodes) and ability nodes (−20% ability cooldown,
  stronger attacks, a second charge).

**Balance**
- Tree profiles T9/T12/T15.
- `uv run balance` over all 6 sectors, with the same targets (smart 35–65%, casual 10–40%,
  and so on).

**Tips:** one per new enemy, boss and ability.

## Performance budget

- **Sim tick under stress:** no more than 2.0 ms on desktop (it's about 1.5–1.9 ms now).
  Every stage re-runs `--stress --perf`.
- **Draw calls:** each new enemy type adds one MultiMesh batch (12 types → about 90 calls at
  budget load, up from about 83), still far below the B2 problem level.
- **Texture memory:** 4 enemies + 3 bosses + FX, about +5 MB at 4×.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Scope slips | Stages ship independently; each is playable on its own. |
| The bot misplays new mechanics, so balance numbers mislead | Bot logic per ability and enemy in the same stage; a sanity check that the bot uses every ability and counter-picks every new enemy. |
| Sim cost | Per-stage stress numbers; the aura and phase checks run at most once per tick per enemy. |
| Save migration | Versioned (v6 → v7), with a unit test. Never reset. |

## Rollout

Stages 1 → 4, one after another, each ending with clips and the user's review. The step is
closed when all 6 sectors are playable, balance targets are met or waived by the user,
and the docs are updated.
