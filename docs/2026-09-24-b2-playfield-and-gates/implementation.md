# Implementation log — B2 playfield & gates

Running log, newest at the bottom. B2 ran from 2026-09-24 23:51 (`date` at the start) to
2026-09-25 00:06 (`date` at closeout). The steps below were written up at closeout; they are in
true order, and no step has an invented clock time.

## Setup

- The B2 folder was first created as `2026-09-25-…`. The clock said 2026-09-24, so it was
  renamed.
- **Correction to earlier logs:** the B0/B1 headings had estimated clock times (some said
  09-25). Reduced to the date, with a note in each file.

## Presentation layer

- `src/ui/gate_format.gd` (`GateFormat.text / landed_text / sentiment`), with
  `tests/ui/gate_format_test.gd`.
- `src/sim/`:
  - `field_view` — lanes and the wall, tinted by HP.
  - `gate_view` — a pooled banner, pulsing when its value steps.
  - `bullet_field` — a MultiMesh at a fixed capacity of 1024.
  - `squad_view`, `turret_row_view`.
  - `effects` — popups, bursts, shake, using its own RNG.
  - `run_controller` — ticks `Run` in `_physics_process` at `tick_rate` and syncs views in
    `_process`. Launch arguments; drag/tap input with a HUD toggle and T; placeholder
    BUILD/CARD via `PhaseOverlay`.
- `src/ui/hud.gd`, `src/ui/phase_overlay.gd`.
- `scenes/run.tscn` is the main scene. The B0 `scenes/main.*` placeholder was deleted.
- Clear colour set in `project.godot`.

## Verification, and what it found

1. **The scene runs headless end to end** (`--skip-to-wave=10 --autoplay --quit-on-end`): WON,
   with no script errors.
2. **The scene test** (`tests/integration/run_scene_test.gd`) drives the real scene with
   `tick()`. 94/95 on the first run. The failure was a wrong assumption, not a bug: **wave 1
   pays 12 gold and the cheapest turret costs 15**, so the first build phase has nothing
   affordable. The test now checks "builds exactly when it can afford to". The gold gap is
   noted for B4.
3. **Stills via Movie Maker** found three visual bugs, all fixed:
   - The "WAVE 1" banner persisted through a fast-forward.
   - The bullet fan offset reset every tick, so there were only 4 columns. It now uses a
     cosmetic counter in `CombatSim._fan`.
   - The HUD wall bar was grey on grey.
4. **Clips** (`scripts/capture_clip.sh`, ffmpeg from content-creation-factory's venv via
   `FFMPEG_BIN`):
   - The contact sheet showed the arc −3 → +0 → +6 → +13 → +19 → +25 → lands; the squad went
     from 5 to 30.
   - It also found **two toast bugs, fixed**: dark-green-on-dark contrast (now bright
     `LANDED_COLORS`), and text clipped off the playfield edge in lane 0 (popups are now
     clamped to the playfield; `test_popups_stay_inside_the_playfield` added).
5. **Desktop frame time:**
   - The real wave 9 never exceeds ~5 enemies alive (the balance is far too easy), so it
     can't show budget load. Added a dev-only `--stress` wave: ~260 enemies and ~500–560
     bullets.
   - **Finding:** the sim tick was cheap (0.6–0.9 ms), but **one node per enemy meant 599 draw
     calls and ~60 fps**.
   - **Fix:** `enemy_field.gd` batches enemies into one MultiMesh per type (flash as instance
     colour, HP bars in one pass). `enemy_view.gd` was deleted.
   - **Result at budget load: 80 draw calls, 130–186 fps (frame avg 5.4–7.7 ms, max
     ≤14.5 ms).** WSLg, OpenGL 3 via D3D12, RTX 3070.
   - Test `test_enemies_render_in_one_batch_per_type` added.
   - The perf metric was also fixed: the "cpu" figure summed process + physics per frame
     (double-counting). It's now the wall-clock frame time plus the average sim-tick cost,
     with 60 warm-up frames excluded.

## Tests

`scripts/test.sh` → **97/97 passed**, exit 0: B1's 85, `gate_format_test` (3), and
`run_scene_test` (9). The `ERROR:` lines in the output are expected push_error/JSON logs from
the tests that deliberately trigger them.

## Checkpoint material (for the user)

- `captures/gate-hook-A-current-speed.mp4` (24 s): the current tuning. A gate takes ~19 s from
  spawning to landing, so it doesn't fit in 15 s.
- `captures/gate-hook-B-fast-gates.mp4` (15 s): the same seed with the dev override
  `--gate-speed=110`, landing ~8 s after spawning.
- Drag vs tap: play by hand (`--input=tap` or the HUD toggle / T).

## Closeout

- Updated:
  - `docs/detailed-project-overview.md`: repo map, §3.5 presentation, dependency map, change
    log.
  - `README.md`: status, quick start (play, capture, dev args).
  - `CLAUDE.md` §6: commands.
  - `ROADMAP.md`: B2 done pending the checkpoint, current bundle B3, and the B4/B5 notes (gate
    speed and charge rate, wave-1 gold, 120 Hz interpolation).
- **Not done here, on purpose:**
  - Balance (B4).
  - The real build/card/meta UI (B3); the placeholder is marked in code.
  - Interpolation for >60 Hz displays (B5, on a real device).

## 2026-09-25 00:25 — 👤 checkpoint result (user feedback, recorded verbatim in substance)

1. **Clip B looks better:** gates faster, landing ~8 s after spawn (dev override
   `--gate-speed=110`). Not yet applied to the data; it goes into the B4 tuning pass.
2. **Enemies should get faster over time,** to build urgency and make it thrilling.
3. **There should be tricky situations that force genuine mistakes and losses.** It shouldn't
   always be a stroll in the park.
4. **The squad shoots too many shots too fast, making it super easy.** The target experience is
   "somewhat hard but not too hard": engaging.
5. Drag vs tap: not answered yet. Ask again when B4's build is playable.
6. (Follow-up the same evening.) **Different enemy types on a speed ↔ toughness trade-off:** some
   faster but easier to kill, some slower but with a larger health pool. **Later, design the
   enemies so the game is visually stunning.** Routed to B4 (tuning) and B10 (new types) for the
   roster, and to B6 (art direction) for the visuals.

The user asked to **save the feedback and continue tomorrow**. Nothing was changed in code or
data in response. It's routed to B4 in `ROADMAP.md`.

**Status: complete — checkpoint answered (see above).**
