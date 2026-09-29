# Handover: content expansion (rewritten 2026-09-29, end of session)

Read this first when resuming. Then read `plan.md` (§ Stage 3 and Stage 4), `research.md`
(§3.3 has the bosses, §6 has the user's answers) and the end of `implementation.md`.

**Next action: Stage 3, bosses as data.** The user reviewed the build so far ("the game feels
good") and agreed to the plan: Stage 3, then Stage 4, then B5 on Android.

---

## 1. Repository state

- **Branch `main`**, one commit (`bc6c453 first commit`). **Everything since is uncommitted**
  (about 300 paths): E6, E5c, B4, art readability, and this work item's Stages 1–2 plus the
  fixes.
- **The user commits and pushes; never do it yourself** (CLAUDE.md §5; `git commit`/`push`
  are blocked here). At handover it was suggested that they branch and commit before Stage 3.
- **Tests at handover:** game 271/271 (`scripts/test.sh`), tools 12/12. All green.

## 2. What's done in this work item

| Step | Date | Where to read |
| --- | --- | --- |
| Stage 1: special attacks as data (Strike, Cryo Bomb, Napalm Line, Minefield, Repair Drones), the pick at map start, clip tutorials, save v7 | 2026-09-27 | `implementation.md`, `balance-stage1*.md` |
| The napalm fix: BURN burns a stretch of road, down every path through the tapped spot (user review) | 2026-09-28 | `implementation.md` |
| Stage 2: Wasp (flying), Warden (shield aura), Burrower (dives), Bombardier (siege from range) | 2026-09-28 | `implementation.md` |
| Tip card overflow ("black screen" after a card) | 2026-09-29 | `docs/2026-09-29-tip-card-overflow/` |

**Stage 2 enemies are not in any wave yet.** Stage 4 puts them in the sector 4–6 waves and
tunes their numbers. Until then `--showcase=wasp,warden,burrower,bombardier` plays them.

**Stage 2 defaults the user hasn't judged yet** (ask only if they come up):
- a slowed Burrower can't dive;
- the Warden's shield soaks damage after the chart and armour;
- the Bombardier reuses `wall_damage`/`attack_interval` for its globs;
- the Bombardier's lime sac may read too close to the Spitter's gland.

## 3. Decisions (the user's own; don't reopen)

- **Platform: Google Play first** (2026-09-29). Steam is deferred (ROADMAP: B9, D2, B13,
  B14). After E8: B5 (Android) → D1 → B15/B16/B17 → D3.
- **Content (research §6):**
  - one special attack per map, picked at map start, with a first-time clip tutorial;
  - the Queen's `wall_damage` goes 999 → **50**;
  - enemies: Wasp, Warden, Burrower, Bombardier;
  - sectors: Mire Crossing, Ashfall, The Hive;
  - bosses: Broodmother, Siege Titan, The Overmind;
  - work in stages, each ending with tests, perf, balance, clips, docs and a user review.
- **Settled earlier** (memory `game-design-decisions`):
  - units are fixed on spots, and crates break by tapping;
  - the gate siege is the loss;
  - only specific enemies destroy units, and selling refunds 50%;
  - one barricade;
  - maps are built from paths;
  - there's a right weapon per enemy (the damage chart).

## 4. Stage 3: where to start

**Plan (`plan.md`):**
- `defs/boss_phase.gd` (`BossPhase`): `at_hp_fraction`, `spawn` (`EnemyDef` × count),
  `armor_delta`, `speed_mult`, `shield_while_alive` (an `EnemyDef` id), `pause_seconds`.
- `EnemyDef.phases: Array[BossPhase]`.
- **Hive Queen:** wall_damage 50, and a phase at 50% (a Skitter swarm).
- **Broodmother:** births swarms at 66% and 33%; weak to explosive.
- **Siege Titan:** sheds armour and speeds up at 50%, spawns Wardens; weak to cryo.
- **The Overmind:** shielded while any Warden lives; phase 2 calls Wasps; phase 3 heals from
  Menders; weak to piercing.
- A boss HP bar at the top of the HUD with phase ticks.
- **Tests:** phases fire once each, in order, at their thresholds; shield-while-alive holds
  until the escort dies.

**Where the boss lives today:**
- `data/enemies/boss.tres` (id `boss`, "Hive Queen"): 250 hp, speed 11, wall_damage 999,
  armour 4, weak to piercing, resists cryo, radius 40.
- It closes wave 10 of every current map (`data/waves/wave_10.tres`, `canyon_10.tres`,
  `switchback_10.tres`).
- Art: `queen()` in `tools/src/gf_tools/art/enemies.py` (box 128).
- `content_test` references `&"boss"` (has_boss).

**Hooks to reuse:**
- `CombatSim._apply_damage`: the hp threshold check goes here. Mind that `_apply_damage` can
  run during `_resolve_queued`, never inside the move pass.
- Spawning mid-wave: follow `_split` (`_insert_sorted`, `_arrive(e)`, `enemy_spawned`).
- Stage 2 pieces a phase can use directly:
  - Wardens and `_wardens` for "shielded while any Warden lives";
  - `Enemy.shield`;
  - `Enemy.stun` for a pause.
- A boss HP bar belongs to `ui/hud.gd`. A tip per boss uses the `new_enemy` intel card (the
  description).

**Performance:** phase checks happen on damage, which is cheap. Keep `--stress=mix` and the
headless per-pass probe (§6) for A/B comparisons.

## 5. Stage 4, in brief

- **Maps:** Mire Crossing (swamp: mud, 4 narrow paths merging in pairs; Wasp, Warden),
  Ashfall (ash: a mid-field burrow; Burrower, Bombardier) and The Hive (infested; the
  finale).
- **Waves and progression:** 30 waves, 6 sector cards, and an 18-star tree with 6 new nodes
  (some for abilities).
- **Balance:** bot tree profiles T9/T12/T15, balanced across 6 sectors.
- **Also:** the Repair ability's balance, and the open B4 items (heavy dominates Switchback;
  Skitter and Spitter counters; the ability button's position).

## 6. Commands and tooling (all verified)

| What | Command |
| --- | --- |
| Run the game | `.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path game` (add `-- --map=canyon` or `--map=switchback`) |
| Meet the new enemies | `… --path game -- --showcase=wasp,warden,burrower,bombardier` (dev; add `--gold=N`) |
| Show tips as a first-timer | `… -- --tips` |
| Game tests | `scripts/test.sh` (about 2 min). Single suite: `cd game && ../.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests/core/X_test.gd`. **A non-existent `-a` path hangs.** |
| Tools tests | `cd tools && uv run python -m unittest discover -s tests` |
| Art | `cd tools && uv run gen-art`, then `--headless --path game --import` |
| Balance | `cd tools && uv run balance --seeds 50 [--strategies smart,casual] [--abilities napalm] --out <path>` (3–5 min) |
| Ability clips | `FFMPEG_BIN=<ffmpeg> uv run make-clips [ids]` → `game/clips/*.ogv` + `captures/clips/*.mp4` |
| Review clip | `FFMPEG_BIN=<ffmpeg> scripts/capture_clip.sh NAME SECONDS --seed=N --autoplay …` → `captures/NAME.mp4` |
| Perf | `xvfb-run -a -s "-screen 0 1600x2700x24" <godot> --path game --display-driver x11 --rendering-driver opengl3 --quit-after 2400 -- --seed=3 --autoplay --stress[=mix] --perf` |
| ffmpeg | `/home/italo/dev/personal/content-creation-factory/.venv/lib/python3.11/site-packages/imageio_ffmpeg/binaries/ffmpeg-linux-x86_64-v7.0.2` |

**Tooling notes** (details in memory `tooling-quirks`):
- **In-game sim-tick numbers swing ±50% run to run.** For an A/B comparison, time each
  `CombatSim` pass in a headless probe (`game/probe_tmp.gd`, `extends SceneTree`, run with
  `--script`; delete it afterwards). Stage 2 measured plain 1.01 vs mixed 1.16 ms/tick that
  way.
- **Render SVG to PNG** in a probe with `Image.load_svg_from_string`; nothing else is
  installed.
- **Reproduce UI bugs with real frames** in a throwaway GdUnit test that awaits
  `process_frame`.
- **Wrapping labels need a width** (the tip card bug).
- **Clips of undefended enemies:** use `--autoplay --gold=N`. `--skip` fast-forwards with the
  bot playing.

## 7. Definition of done per stage (CLAUDE.md §3)

1. Tests pass: unit tests for rules, a scene test for the view.
2. Exercise it in game and record clips for the user.
3. Budgets: `--stress --perf` (and `=mix`), plus the headless probe for the sim tick. Draw
   calls must stay about 90 or below; the Stage 2 bubble bug hit 1850 before batching.
4. Docs:
   - `implementation.md`, timestamped as you go;
   - `docs/detailed-project-overview.md` (files, systems, change log, test counts);
   - `README.md` status;
   - `ROADMAP.md`;
   - this handover.
5. Report honestly, and end with the play command and what to judge by hand.
