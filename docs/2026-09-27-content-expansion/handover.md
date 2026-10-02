# Handover: next session (rewritten 2026-09-30, end of day)

**E8 (the content expansion) is done and reviewed.** The user said "looks good" to the
Stage 4 report. This file is the entry point for the next session; its §2–§5 keep the E8
record.

## 0. Start here tomorrow

1. **Check git.** Stages 3–4 were uncommitted at handover (92 paths).
   - If `git status` is still dirty, suggest the user commit first (they run it; see memory
     `github-push-setup`):
     `! git checkout -b e8-stages-3-4 && git add -A && git commit -m "feat: bosses and sectors 4-6 (E8 Stages 3-4)"`
   - Branch off `main` for new work.
2. **Next work item: B5, the Android build and performance** (`ROADMAP.md` § B5; the platform
   is Google Play first, per memory `platform-focus`). Create
   `docs/2026-09-30-b5-android-build/` (or the day's date), then `research.md` → `plan.md` →
   `implementation.md`.
3. **Ask before starting B5.** These are CLAUDE.md §5 approvals, marked 🔒 in the ROADMAP:
   - Godot 4.7.2 **export templates** (about 1.28 GB, into `.tools/`);
   - **JDK 17** and the **Android command-line SDK** (where they install: `.tools/`, not
     system-wide, if possible);
   - **the user's phone model** (the low-end budget profile) and how the APK gets there:
     USB/adb, or a sideload;
   - a **debug keystore** only; release signing and the package name are sensitive, so ask
     separately.
4. **B5's scope** (ROADMAP):
   - `scripts/build_android.sh` and a debug APK;
   - an on-device frame-time and memory capture at wave 10 and under `--stress --perf`;
   - a 30 s clip and playtest notes;
   - budgets recorded, met or not.
   - Bring in the numbers from §5 below, and add physics interpolation if the phone runs
     above 60 Hz.
5. **Things to keep in mind:**
   - Touch input is already mouse-emulation safe (`run_scene_test`).
   - The UI is 540×960 portrait.
   - `--perf` prints the frame and sim-tick stats.

## 1. Repository state

- **Branch `main`.** Stages 1–2 are committed (`dd52626`, `dd2951a`); **Stages 3 and 4 are
  uncommitted.**
- **The user commits and pushes; never do it yourself** (CLAUDE.md §5).
- **Tests at handover:** game 288/288, tools 12/12.
- `run_scene_test` prints "12 resources still in use at exit". This predates Stage 3 and is
  harmless.

## 2. What's done

| Step | Date | Where to read |
| --- | --- | --- |
| Stage 1: special attacks as data, the pick, clip tutorials, save v7 | 2026-09-27 | `implementation.md`, `balance-stage1*.md` |
| Napalm along the road; Stage 2: Wasp, Warden, Burrower, Bombardier | 2026-09-28 | `implementation.md` |
| Stage 3: `BossPhase`, a Queen who deals 50, Broodmother, Titan, Overmind, `BossBar` | 2026-09-29 | `implementation.md`, `balance-stage3.md` |
| Stage 4: Mire Crossing, Ashfall, The Hive; 30 waves; 18 stars; tree tier 6; bot fixes | 2026-09-30 | `implementation.md`, `balance-stage4.md`, `gen_maps.py`, `gen_waves.py` |

**Defaults that stand** (the user reviewed E8 and said "looks good"; revisit only if they raise one):
- **Stage 3:**
  - the Queen strikes every 3 s;
  - the Titan sheds all its armour at 50%;
  - `guard` is per phase;
  - escorts spawn ahead of the boss.
- **Stage 4:**
  - the Overmind finale is long (guarded for much of its walk);
  - the threat re-rating and the relaxed escalation test (per-sector totals and boss wave,
    not wave by wave);
  - mid-field breach portals are allowed;
  - tier-6 nodes Heavy Ordnance, Bastion and Fire Control;
  - sectors 4–6 unlock no new special attack (Overcharge is still the spare).
- **Balance:**
  - Canyon's *bot* score fell 35% → 18% on unchanged content, a side effect of the bot's
    toughness weighting, which sectors 4–6 need; I did not retune Canyon;
  - "fixed builds below smart" still fails (heavy-only is strong on Switchback and Hive);
  - casual runs sit at the top of the band.
- **Stage 2:** a slowed Burrower can't dive; the Warden's shield soaks after armour; the
  Bombardier's lime sac vs the Spitter's gland.

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

## 4. Regenerating sector content

`gen_maps.py` and `gen_waves.py` (this folder) wrote the Stage 4 maps and waves. The `.tres`
files are the source of truth. To redo them, run the scripts with the final knobs:

```
python3 gen_maps.py --write
python3 gen_waves.py --write mire.count=0.66 mire.addk=0.75 mire.hp=1.06 ashfall.count=0.52 ashfall.addk=0.5 ashfall.hp=0.95 hive.count=0.6 hive.addk=0.6 hive.hp=1.04
```

Then run `cd tools && uv run gen-art`, a Godot `--import`, the tests, and
`uv run balance --maps mire,ashfall,hive --strategies smart,casual --seeds 30` (about 3 min).

## 5. For B5 (Android), from this work item

- **Draw calls under stress:** Outpost 82, Canyon 109, Switchback 104, the new maps
  109–120.
- **Desktop sim tick:** about 1.3–2.4 ms.
- Measure both on the target phone.

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
