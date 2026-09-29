# Handover: content expansion (written 2026-09-27, before a session compaction)

Read this first when resuming, then `research.md` (§6 has the user's answers) and `plan.md`.
**Update (2026-09-27 22:10): Stage 1 is done** (see `implementation.md`).
**Update (2026-09-28): the user's review item "napalm must burn along the path" is done**
(BURN is now a stretch of road down every path through the tapped spot).
**Update (2026-09-28): Stage 2 (four enemies) is done** (see the end of `implementation.md`):
Wasp, Warden, Burrower, Bombardier as data + rules + art, not yet in any waves (Stage 4 places
them); `--showcase=IDS` plays them. Tests 270 game + 12 tool. The next action is Stage 3
(bosses as data), after the user judges Stage 2.

---

## 1. Repository state

- Branch `main`. One commit (`bc6c453 first commit`). **Everything since is uncommitted**
  (about 290 paths in `git status`), across work items E6, E5c, B4, art readability and this
  plan.
- **The user commits and pushes; never do it yourself** (CLAUDE.md §5; git commit/push are
  blocked in this environment anyway).
- **Tests at handover:** game 233/233 (`scripts/test.sh`), tools 11/11
  (`cd tools && uv run python -m unittest discover -s tests`). All green.
- **Last completed work item:** `docs/2026-09-27-art-readability/` (done; still waiting on
  the user's hand-play):
  - 4× sprites and mipmaps
  - readable enemies
  - damage-type colours on units
  - crates ×1.35
  - a 144×52 barricade with a barricade-shaped slot ghost and tap area
  - biome grounds (`MapDef.biome`: outpost = desert, canyon = canyon, switchback = tundra)
    with a subtle creep
- **The review page** `captures/art-compare/index.html` (git-ignored) holds before/after art,
  crowds, props and backgrounds.

## 2. What the user asked for

> "let's add some levels and new enemies and bosses. I'd want to ship this with 6 levels at
> least, so 3 more. also, more special atacks would be nice."

## 3. Decisions (the user's own; don't reopen)

| # | Topic | Decision |
| --- | --- | --- |
| 1 | Special attacks | **One attack per map, picked when the map starts.** The first time each is offered, a **quick tutorial** covers what it does, its reload time, etc. The pool grows through the campaign (the Strike and Cryo Bomb start unlocked; clearing a sector unlocks one more). The user didn't object to unlocking. |
| 2 | Hive Queen | `wall_damage` 999 → **50**: 2 hits break a base gate (100 HP), 3 with any gate upgrade. |
| 3 | New enemies | **Wasp, Warden, Burrower, Bombardier**, as in research §3.2. |
| 4 | Names | Sectors: **Mire Crossing, Ashfall, The Hive**. Bosses: **Broodmother, Siege Titan, The Overmind**. |
| 5 | Process | **Stages** (1 → 4). Each stage ends with tests, a perf check, a balance run, **clips** and updated docs, then the user reviews before the next. |
| 6 | Clips in tutorials (new idea) | "we can use some for the tutorials / infos as well … only when beneficial, of course - like special atacks' effects." See §6. |

Settled earlier (memory: game-design-decisions):
- units are fixed on spots
- crates break by tapping
- the gate siege is the loss condition
- only specific enemies destroy units
- selling refunds 50%
- one barricade
- maps are built from paths
- Doom-Eternal-style "right weapon per enemy" (the damage chart)

## 4. The stages (details in `plan.md`)

1. **Special attacks as data, and the pick at map start.**
   - `AbilityDef`; the strike moves into `data/abilities/strike.tres`.
   - New: Cryo Bomb (freeze), Napalm Line (a burning strip), Minefield (mines on a path),
     Repair Drones (heals the gate and units).
   - A pick panel when a run opens, with a first-time tutorial per attack.
   - One `AbilityButton`. The bot casts every kind. Save v7.
2. **Four enemies.** New `EnemyDef` fields:
   - `flying` (skips the barricade, mud and shells)
   - Warden shields (`shield_*`)
   - Burrower submerge (`burrow_*`)
   - Bombardier siege from range (`siege_*`)

   Plus their art, chart entries and tips.
3. **Bosses as data.**
   - `BossPhase` (an HP threshold → spawn, armour, speed, shield-while-alive, pause).
   - The Queen gets 50 damage and a phase at 50%.
   - Broodmother, Siege Titan, Overmind.
   - A boss HP bar in the HUD.
4. **Sectors 4–6.**
   - Mire (swamp), Ashfall (ash, a mid-field burrow), The Hive (infested).
   - 30 waves.
   - 6 sector cards, and an 18-star tree (+6 nodes, including ability nodes).
   - Bot tree profiles T9/T12/T15, balanced across 6 sectors.

## 5. Stage 1: where the strike lives today (everything to generalize)

**Core**
- `game/src/defs/run_config.gd:52-58`: `strike_damage` 20, `strike_radius` 70,
  `strike_delay` 0.9, `strike_cooldown` 30. Values are in `game/data/run_config.tres`.
- `game/src/core/run.gd`:
  - `strike_cooldown_left` (l.37; reset at l.106; ticks at l.116)
  - `strike_ready()` (l.435), `call_strike(pos)` (l.441; damage × the wave's `hp_scale`)
  - `strike_cooldown()`
  - `state_hash` includes it (l.461)
- `game/src/core/combat_sim.gd`:
  - signals `strike_called`/`strike_landed` (l.72-73)
  - `class Strike` (l.211), `strikes` (l.255), cleared at l.352
  - `_land_strikes(dt)` after the move pass (l.468)
  - `call_strike(pos, damage)` (l.898+): raw damage, past the chart and armour
  - Note: `_strike(e)`, `strike_timer` and `sieging` are the **enemy's gate attack**. Same
    word, unrelated; don't rename them.
- `game/src/core/run_modifiers.gd:49`: `strike_cooldown_bonus` (the Fire Mission card
  `data/cards/fire_mission.tres`, and tree nodes).
- `game/src/core/autoplay.gd:32-35, 256-273`: `strike_threat`, `strike_every_ticks`,
  `strike_target`, and the `no_strike` preset.
- `game/src/core/balance_run.gd` counts strikes. The tools balance report has a Strikes
  column (`tools/src/gf_tools/balance/`).
- `game/src/core/tip_director.gd:13,21`: events `strike_ready` and `strike_button`;
  `game/data/tips/strike.tres`.

**Sim and UI**
- `game/src/sim/run_controller.gd`:
  - `strike_button` (l.76, 192-194, layout l.237, sync l.421-422)
  - `toggle_strike()` (l.794): aim mode slows time
  - `fire_strike(fp)` (l.807), `_on_strike_called/_landed` (l.813, 819)
  - the tip target rect (l.1039)
  - pointer routing: `if aiming: fire_strike(fp)` in `handle_pointer`
- `game/src/ui/strike_button.gd` (`StrikeButton`, `SIZE`), `game/src/sim/strike_view.gd`
  (the falling shell and blast), and `game/src/sim/fx.gd` (strike FX).

**Tests touching the strike:** `strike_test.gd`, `run_test.gd`, `combat_sim_test.gd`,
`barricade_test.gd`, `tree_rules_test.gd`, `content_test.gd`, `balance_run_test.gd` and
`run_scene_test.gd`. Keep `call_strike` working, as a wrapper, until they're migrated.

**The tip system:**
- `TipDef` (`id`, `trigger` from `TipDirector.EVENTS`, `per_arg`, `priority`,
  `cards: Array[TipCard]`), in `data/tips/*.tres`, listed in `RunConfig.tips`.
- `per_arg` = once per argument. Use it for "first time attack X is offered", with the
  argument being the ability id.
- Tips stop time. They're off in direct runs unless `--tips` is passed.
- Seen tips are saved (save v6 `tips_seen`).

## 6. Clips in tutorials: technical notes (decide in Stage 1)

- Godot 4 plays **Ogg Theora (`.ogv`) only**, via `VideoStreamPlayer` + `VideoStreamTheora`.
  MP4 isn't supported.
- Our ffmpeg (see §7) **has `libtheora`**:
  `ffmpeg -i in.mp4 -c:v libtheora -q:v 6 -an out.ogv`.
- **Build size:** a 4 s loop at 360×360 is roughly 150–400 KB. Five attack clips ≈ 1–2 MB.
  Record the numbers.
- **The alternative, a live demo:** a tiny sub-viewport running a scripted `CombatSim`
  vignette (e.g. 6 Drones walking into a Cryo Bomb).
  - Pros: always matches the current art and numbers, zero MB, crisp at any resolution.
  - Cons: more code, and must be deterministic.
- **Recommendation to put to the user:** use `.ogv` clips for the special-attack tutorial
  cards (simple, the user's idea), generated reproducibly by a script (`scripts/` or
  `tools/`) from seeded `--autoplay` runs. Treat them as generated artifacts (tracked, since
  they ship; regenerable).
- Add a `TipCard.clip` field (a path to the `.ogv`), shown looping above the card text.
- "Only when beneficial": clips for the special attacks (and maybe the boss phases); static
  cards everywhere else.
- Clips for the user's **review** (not in-game) still go to `captures/` (git-ignored) as MP4.

## 7. Commands and tooling (verified this session)

| What | Command |
| --- | --- |
| Run the game | `.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path game` (`-- --map=canyon`, `--map=switchback`) |
| Game tests | `scripts/test.sh` (about 2 min; ends "Overall Summary: N test cases … 0 failures") |
| Tools tests | `cd tools && uv run python -m unittest discover -s tests` |
| Regenerate art | `cd tools && uv run gen-art` (then `--headless --path game --import` to reimport) |
| Balance | `cd tools && uv run balance --seeds 50 --out <path>` (about 5 min, 15 jobs) |
| Perf (stress) | `xvfb-run -a -s "-screen 0 1600x2700x24" <godot> --path game --display-driver x11 --rendering-driver opengl3 --quit-after 2400 -- --seed=3 --autoplay --stress --perf` (prints `PERF …` lines; at handover about 7.7 ms frame and 1.1–1.5 ms sim tick, 82–83 draw calls) |
| Record a clip (540×960) | `FFMPEG_BIN=<ffmpeg> scripts/capture_clip.sh NAME SECONDS --seed=N --autoplay --skip-to-wave=W --skip=S` → `captures/NAME.mp4` |
| ffmpeg | `/home/italo/dev/personal/content-creation-factory/.venv/lib/python3.11/site-packages/imageio_ffmpeg/binaries/ffmpeg-linux-x86_64-v7.0.2` (not on PATH; has libtheora and libx264) |
| Game flags | `--seed=N --autoplay --skip-to-wave=W --skip=SECONDS --map=ID --tips --stress --perf --tree=… --open-plot=N --quit-on-end` |

**Phone-resolution stills and clips (1440×2560):** Movie Maker records at the base 540×960
size. To get phone resolution:
1. Copy `game/` to the scratchpad.
2. Add an `override.cfg` there:
   ```
   [display]

   window/size/viewport_width=1440
   window/size/viewport_height=2560
   window/stretch/scale=2.6667
   ```
3. Run `xvfb-run -a -s "-screen 0 1600x2700x24" <godot> --path <copy> --display-driver x11 --rendering-driver opengl3 --write-movie out.png --fixed-fps 60 --resolution 1440x2560 --quit-after 3 -- <game args>`.
4. The frames are `out00000002.png` and so on.
5. Re-import the copy (`--headless --path <copy> --import`) after swapping art.

Never write `override.cfg` into the real `game/`.

**Quirks** (memory: tooling-quirks):
- Probe scripts (`game/probe_tmp.gd`, `extends SceneTree`, run with `--script`) can't see
  autoloads. Delete them after use.
- Never `pkill -f` a pattern that's in your own command line.
- GdUnit counts removed-but-not-freed UI as orphans.
- WSLg falls back to OpenGL and dummy audio; that's expected.
- **Don't smoke-test with `--quit`**; it crashes on teardown. Use `--quit-after N`.

## 8. Definition of done per stage (CLAUDE.md §3)

1. Tests pass. Add unit tests for the new pure logic and integration tests for the flows.
2. Exercise the real change in the game, and record clips for the user (feel-sensitive
   things: attack effects, boss phases).
3. Budgets: `--stress --perf` before and after. Sim tick target ≤ 2.0 ms desktop. Draw calls
   and texture memory recorded.
4. Docs: the `implementation.md` log (timestamped, as you go); `docs/detailed-project-overview.md`
   (files, systems, change log, test counts); `README.md` status; `ROADMAP.md` (add this work
   item).
5. Report honestly: what was tested, what was skipped.

**Working style** (memory: working-style):
- The user wants one recommendation per decision, then autonomous building of the whole
  stage.
- End each stage with clips, the exact play command, and "what to judge by hand".
- Refer to the user as "the user" or "they" in docs.

## 9. Open items carried along

- **From B4:** big guns dominate Switchback (heavy bot 86%); the strike button's position;
  tip wording. The Queen's all-or-nothing is resolved by decision 2 (implemented in Stage 3).
- The art hand-play is pending.
- **B5 (Android)** only on the user's go. On-device checks are needed for the 4× art memory
  (about 28 MB of textures per run, estimated) and the sim tick.
