# Plan — B2 playfield & gates

## Files

- **`game/src/sim/`:**
  - `run_controller.gd`, the root of `scenes/run.tscn`:
    - Creates the `Run`, steps it in `_physics_process`, and syncs views in `_process`.
    - Routes input (drag/tap) and the phase overlays.
    - Reads launch arguments: `--seed`, `--autoplay`, `--skip-to-wave`, `--skip`, `--perf`,
      `--input`, `--quit-on-end`.
    - Exposes `tick(n)` and `sync_views()` so tests can drive it deterministically.
  - `field_view.gd`: lane stripes, the wall and its HP tint, and the playfield origin (the
    playfield is centred in a wider desktop window).
  - `enemy_view.gd`: one enemy, with a shape and colour per type, hit flash, and an HP bar for
    brutes and the boss. Pooled.
  - `gate_view.gd`: one gate banner, with its value text, good/bad colour, and a pulse when its
    value steps. Pooled.
  - `bullet_field.gd`: a `MultiMeshInstance2D` fed straight from the core bullet arrays.
  - `squad_view.gd`: the visible shooters in formation on the wall, and a count label.
  - `turret_row_view.gd`: the slots on the wall, with the turret type as colour and level pips.
  - `effects.gd`: pooled float-text popups and bursts, plus screen shake (its own RNG).
- **`game/src/ui/`:**
  - `gate_format.gd`: `GateFormat.text()` / `is_good()`. Pure, and unit-tested.
  - `hud.gd`: wave x/10, the wall HP bar, gold, shooters, and an input-mode toggle.
  - `phase_overlay.gd`: the placeholder BUILD/CARD continue panel and the win/lose panel.
- **`game/scenes/`:** `run.tscn` becomes the new main scene. The B0 placeholder `main.*` is
  removed.
- **`scripts/capture_clip.sh`:** Movie Maker → AVI → MP4, via ffmpeg if found. The output goes
  to `captures/` (git-ignored).
- **Tests:**
  - `tests/ui/gate_format_test.gd`.
  - `tests/integration/run_scene_test.gd`: instantiates `run.tscn` headless and drives it with
    `tick()`. It asserts that views match core state (enemy views = enemies, bullet instances
    = bullets, gate labels = values), that drag and tap input set the target, that the
    placeholder overlay advances the phases, and that a full autoplay run reaches WON/LOST
    with the scene alive.

## Done when

- A full 10-wave run is playable by hand and completes under autoplay.
- The scene test passes headless.
- Desktop frame time at peak load (wave 9) is measured and recorded.
- **👤 Checkpoint:** a 15 s gate clip, plus instructions to compare drag and tap.
