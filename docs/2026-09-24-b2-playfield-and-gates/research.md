# Research — B2 playfield & gates

Executes `ROADMAP.md` **B2**. The design is covered by the prototype research. The rules
already exist in `core/` (B1), so this bundle is about **presentation**: how Godot nodes render
the core state cheaply, and how to capture a clip.

## Findings

- **Fixed-tick simulation vs rendering:**
  - The run steps in `_physics_process`, with `Engine.physics_ticks_per_second` set to
    `RunConfig.tick_rate` (60).
  - Views update in `_process` from core state. On a 60 Hz display the two line up.
  - On a 120 Hz display, positions would step every other frame. Interpolating between
    `Engine.get_physics_interpolation_fraction()` samples is the known fix; it's deferred until
    a real device shows the problem (noted for B5).
- **Bullets:**
  - A `MultiMeshInstance2D` draws every bullet in one draw call, given a fixed-capacity buffer
    and `visible_instance_count`, so the buffer is never reallocated per frame.
  - Per-instance colours need `use_colors`.
  - Transforms are written per instance (`set_instance_transform_2d`). At ≤600 instances that's
    cheap. If profiling says otherwise, writing the whole `buffer` in one call is the escape
    hatch.
- **Enemies and gates:**
  - Pooled `Node2D` views, keyed by core id, created and released through CombatSim's signals.
    At most ~250 enemies, so a node per enemy is fine.
  - Each draws itself once (`_draw`) and only redraws on a flash or HP change; motion is just
    `position`.
- **Cosmetic randomness** (screen shake, particle angles) uses its own
  `RandomNumberGenerator`, never an `RngStreams` stream, so visuals can never change the
  simulation.
- **Clip capture:**
  - Godot's **Movie Maker** mode (`--write-movie file.avi --fixed-fps 60`) renders every frame
    with no real-time pressure and writes MJPEG AVI + PCM audio. It needs a real display (WSLg
    works) and doesn't run headless.
  - A 60 fps AVI is large, so the capture script converts it to H.264 MP4 when ffmpeg is
    available. The binary is found via `$FFMPEG_BIN`, then `PATH`; there's no system ffmpeg
    here, but the content-creation-factory venv has one.
- **Input:**
  - Mouse events are handled alongside touch events explicitly, so desktop and phone behave the
    same without turning on the global "emulate touch" setting.
  - Two modes behind a flag (the prototype plan's A/B test): **drag** (the squad follows the
    finger's x) and **tap** (tap a lane to switch to it).

## Scope boundary with B3

A full 10-wave run needs the BUILD and CARD phases to be passable. B3 builds their real UI. B2
gets a **placeholder overlay**: "Wave N cleared → Continue". It auto-builds with `Autoplay`'s
build policy, takes the first card, and says what it did. B3 replaces it.
