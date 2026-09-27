# Implementation log — B1 core rules layer

Running log, newest at the bottom. _Correction (2026-09-24 23:51): the clock times first written in these headings were estimates, not real clock readings, and some said 09-25; they have been reduced to the date. Entries are in true order. From B2 on, times come from `date`._

## 2026-09-24 — work item opened

`research.md` and `plan.md` written. The key decision: combat and the run state machine move
into `core/` so a run plays headless (determinism test, B4 bot).

## 2026-09-24 — defs

`src/defs/`: `EnemyDef`, `GateDef` (enum Kind), `TurretDef` (enum Kind, `max_level`),
`SpawnEntry`, `GateSpawn`, `WaveDef`, `CardDef`, `MetaUpgradeDef`, `RunConfig`. Every tunable
number is an `@export` field, with no constants in the rules.

## 2026-09-24 — core, pure pieces

`rng_streams`, `run_modifiers`, `squad_stats`, `gate_math`, `wave_schedule`, `economy`,
`card_pool`, `meta_progress`, `save_data` (v2 with a synthetic v1, atomic writes, `.bad`
quarantine).

## 2026-09-24 — combat sim, run, autoplay

- `combat_sim.gd`: lanes sorted nearest-the-wall first, packed-array bullets, fixed tick.
- **Bug caught while writing it:** I first reset the bullet arrays by looping over an `Array`
  literal of them. Packed arrays are copy-on-write values in GDScript, so that would have
  cleared copies. Replaced with `_resize_bullets()`, which names each array (commented in code).
- `run.gd` (the phase machine and `state_hash`) and `autoplay.gd` (the scripted policy).

## 2026-09-24 — platform layer

`PlatformServices` (fails safe), `StubServices` (records calls; `succeed` flag),
`services_registry.gd` as autoload `Services` + project setting `game/platform/provider`.

## 2026-09-24 — content

- A throwaway generator (`game/_gen_content.gd`, deleted after running) wrote every `.tres`
  file through `ResourceSaver`, so the format is exactly the editor's.
- Written: 4 enemies, 5 gates, 4 turrets, 12 cards, 6 meta upgrades, 10 waves, and
  `run_config.tres`.
- The numbers are first guesses, per the prototype plan. The `.tres` files are the source of
  truth now.

## 2026-09-24 — smoke run → two findings

Autoplay played 3 seeds headless: all WON, ~21k ticks, ~3.5–4.3 s each.

1. **Performance-budget bug in the rules:**
   - Peak bullets were **2,255** (budget: 600). The visible-shooter cap limited how many
     shooters fire, but not how fast they fire. Fire-rate gates stack multiplicatively, which
     reached 42 shots/s per shooter.
   - **Fixed in B1:** `SquadStats.max_bullets_per_second` (config
     `squad_max_bullets_per_second = 240`). Anything above the cap is folded into damage per
     bullet, so `dps()` is unchanged.
   - After the fix, peak bullets are **180**, and the run is faster (~1.4 s).
2. **Balance:** ~20,000 shooters by the end; the wall barely touched. Recorded under B4 in
   `ROADMAP.md`; not tuned here (that's B4's job, with the bot).

## 2026-09-24 — tests

- `tests/fixtures.gd` plus 14 suites and 1 integration suite: 85 test cases.
- First run: 83/85. Both failures were **test** bugs:
  - The turret fired on tick 1, before the rest of its enemy group had spawned.
  - The cannon test's loop appended on every tick.
- Fixed by giving a turret to a slot only once the group is on the field.
  `test_cannon_splash_hits_neighbours_only` now also checks that an enemy outside the radius is
  untouched.

## 2026-09-24 — verification

- `scripts/test.sh`: **85/85 passed**, exit 0.
- **The tests catch real bugs** (mutation check):
  - Swapping ADD/MUL in `APPLY_ORDER` failed 2 tests.
  - Removing the damage fold from `damage_per_bullet` failed 2 tests.
  - The code was restored and the suite is green again.
- A fresh `--import` (cache deleted) shows **no warnings** from `src/` or `tests/`. That
  includes untyped declarations, which are set to warn.
- Full headless run (seed 11): **21,022 ticks (350 s of play) in ~1.4 s; peak bullets 180; WON
  at wave 10.** That's the baseline B4 inherits: 50 runs × 3 strategies ≈ 3.5 min.

## Closeout

- Updated:
  - `docs/detailed-project-overview.md`: §1, the repo map, §3 systems (new), §4 dependency map,
    the change log.
  - `README.md`: status.
  - `CLAUDE.md`: §4 layout rule (all rules in core).
  - `ROADMAP.md`: B1 done, current B2, B2 reworded for render-over-core, the B4 balance note.
- **Not done here, on purpose:** balance tuning (B4) and any rendering (B2).

**Status: complete.**
