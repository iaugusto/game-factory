# Implementation log — B0 toolchain & skeleton

Running log, newest at the bottom. _Correction (2026-09-24 23:51): the clock times first written in these headings were estimates, not real clock readings, and some said 09-25; they have been reduced to the date. Entries are in true order. From B2 on, times come from `date`._

## 2026-09-24 — toolchain

- Godot 4.7.2 Linux x86_64 downloaded to `.tools/godot/`. The **SHA512 matched** the release's
  `SHA512-SUMS.txt`. `--version` → `4.7.2.stable.official.ed1daf0bf`.
- GdUnit4 v6.2.1 source archive downloaded; `addons/gdUnit4/` vendored into
  `game/addons/gdUnit4/` (2.0 MB, MIT). The archive's sha256
  (`ffb48847c46f386bf0c7a716fd68c6dace7d67730775cf7f748adce8ef3ed794`) is recorded here,
  because GitHub publishes no checksum for it.
- Downloads cached in `.tools/cache/` (git-ignored).
- Export templates deferred to B5 (1.28 GB; see `plan.md`).

## 2026-09-24 — project skeleton

- `game/project.godot`:
  - Portrait 540×960, `canvas_items` stretch with `expand` aspect, handheld orientation
    portrait.
  - Mobile renderer, ETC2/ASTC texture compression (Android).
  - Warning on untyped declarations (the static-typing standard in `CLAUDE.md` §4).
  - GdUnit4 plugin enabled.
- The plan §3 tree: `src/{core,defs,sim,platform,ui}`, `data/{enemies,gates,turrets,waves,
  cards,meta}`, `scenes/`, `tests/{core,integration}`. Empty folders carry `.gitkeep`.
- `scenes/main.tscn` + `main.gd`: a placeholder entry scene that prints the engine version.
- `tests/core/toolchain_test.gd`: guards the pinned engine minor (4.7) and the portrait base
  resolution.
- `scripts/test.sh`:
  - Runs an import pass (so a fresh checkout builds the class cache), then the GdUnit4
    command-line runner headless over `res://tests`.
  - The Godot path comes from `$GODOT_BIN`, falling back to `.tools/godot/`.
- `.gitignore`: `game/reports/` (GdUnit4 output). `*.uid` files are **tracked** on purpose:
  Godot 4.4+ uses them for stable resource references.

## 2026-09-24 — verification

- `scripts/test.sh` → 2/2 passed, exit 0, 4.7 s wall-clock.
- **The runner reports failure correctly:** a deliberately failing probe test made
  `scripts/test.sh` exit **100**. The probe was deleted, and the suite was back to exit 0.
- **The game runs:** `--quit-after 120` printed `Hold the Gate: engine 4.7.2-stable (official)`
  and exited 0.
- **The editor opens under WSLg:**
  - Vulkan is unavailable through WSL's D3D12 layer, so Godot falls back to **OpenGL 3
    (Mesa, D3D12 on the RTX 3070)**. That's fine for 2D.
  - With `--quit-after 600`, the editor exits 0 both with and without the GdUnit4 plugin.
  - No audio device in WSL, so Godot uses its dummy audio driver. That's harmless.
- **Known quirk:** `--editor --quit` (quit on the very first iteration) crashes with SIGSEGV
  during teardown, after the plugin unloads cleanly. `--quit-after N` doesn't, and neither does
  a normal session. It's an engine teardown edge case, not a project problem. Don't use
  `--quit` for editor smoke checks.

## 2026-09-24 — closeout

- Updated:
  - `docs/detailed-project-overview.md`: `game/`, `scripts/`, `.tools/` are now `existing`;
    systems and change log updated.
  - `README.md`: status and quick start.
  - `CLAUDE.md`: §4 engine line and §6 commands.
  - `ROADMAP.md`: B0 done, current bundle B1, export templates moved into B5's approvals.
- **Tested:** the full suite, the failure exit code, the game run and the editor launch (above).

**Status: complete.**
