# Plan — B1 core rules layer

Executes `ROADMAP.md` **B1**. No approvals needed.

## Deviations from the prototype plan (§3), and why

1. **Combat is simulated in `core/`** (`combat_sim.gd`), and the WAVE → BUILD → CARD state
   machine is in `core/run.gd`. `sim/run_controller.gd` (B2) becomes a thin node that ticks
   `Run` and renders it. Reason: the headless determinism test and the B4 bot (see
   `research.md`).
2. **The v1 save schema is synthetic.** Nothing has shipped, so "v1" is defined here only so the
   migration chain is exercised by a real test from day one.
3. **Bullets are plain arrays** of plain values (positions, damage, kind) inside `core/`, not
   nodes. In B2, `bullet_field.gd` only reads them into a MultiMesh.

## Units and rules (tunable values live in `data/run_config.tres`)

- **Playfield:**
  - 3 lanes, each 180 units wide. The wall is at y = 860; spawns are at y = 0.
  - The squad's x decides its lane. Input sets `target_x`, and the squad moves toward it at a
    fixed speed.
  - Fixed tick at 60 Hz.
- **Targets and bullets:**
  - Each lane keeps its enemies and gates sorted by y (nearest the wall first).
  - A squad rifle bullet hits the nearest target, **gates included**. Turret and rocket bullets
    hit enemies only.
  - **Rail** hits every enemy in the lane instantly.
  - **Cannon** and **rocket** bullets deal splash damage within a radius along the lane.
  - **Frost** bullets slow the enemy they hit.
- **Gates:**
  - value = base + (start_steps + ⌊hits / hits_per_step⌋ + bonus_steps) × step, clamped to
    [min, max].
  - A gate applies when it reaches the wall. Gates landing in the same tick apply in a fixed
    order: ADD → MUL → FIRE_RATE → DAMAGE → ROCKET.
  - Gates still on the field when a wave is cleared are discarded.
- **Squad:**
  - Shooters above the visible cap (60) are not drawn. Their share of damage is added to each
    visible shooter's bullet, so total damage per second is unchanged.
  - The squad never drops below 1 shooter.
- **Wall:** HP = max − damage taken, so an upgrade that raises max HP also raises current HP. An
  enemy reaching the wall deals its wall damage and is removed.
- **Wave end:** all spawns done and no enemies left → BUILD, or WON after the last wave. Wall HP
  ≤ 0 → LOST.
- **Bricks** (the meta currency): Σ of the wave numbers cleared, + 10 for a win.
- **Modifiers:**
  - Cards and meta upgrades both add into one `RunModifiers` object, each by a
    `(key, value)` pair declared in its data file.
  - A test fails if a data file names a key that doesn't exist.

## Files

- **`src/core/`:**
  - `rng_streams.gd` — named seeded random-number streams.
  - `run_modifiers.gd` — the bonuses cards and meta upgrades add into.
  - `squad_stats.gd` — shooters, damage, fire rate, visible-cap rule.
  - `gate_math.gd` — gate value formula and application.
  - `wave_schedule.gd` — turns a wave definition into timed spawn events.
  - `economy.gd` — gold, turret costs and upgrade prices.
  - `card_pool.gd` — the weighted pick-1-of-3 draw.
  - `meta_progress.gd` — bricks and permanent upgrades.
  - `save_data.gd` — the versioned save, with migrations.
  - `combat_sim.gd` — the per-tick combat.
  - `run.gd` — the run state machine.
  - `autoplay.gd` — the scripted policy, reused by the B4 bot.
- **`src/defs/`:** `enemy_def`, `gate_def`, `turret_def`, `spawn_entry`, `gate_spawn`,
  `wave_def`, `card_def`, `meta_upgrade_def`, `run_config`.
- **`src/platform/`:**
  - `platform_services.gd` — the interface: rewarded ads, purchases, achievements, analytics.
  - `stub_services.gd` — the only provider for now.
  - `services_registry.gd` — autoload `Services`, which picks the provider from project settings.
- **`data/`:**
  - Enemies: 4. Gates: 5. Turrets: 4. Cards: 12. Meta upgrades: 6. Waves: 10.
  - `run_config.tres` ties them together.
- **`tests/core/`:** one suite per core file, plus a content-integrity suite and a platform
  suite.
- **`tests/integration/`:**
  - Wave 1 is cleared by autoplay.
  - A full seeded run gives the same state hash twice.
  - Different seeds give different hashes.

## Done when

`scripts/test.sh` is green with every suite above. The full-run determinism test passes. Also
record the time a headless full run takes, since that's the baseline B4 inherits.
