# Plan — build spots, loot crates, reload trade-off, art slice

Built on [`research.md`](./research.md), with the user's answers (§7) and the gates decision
(§8, "drop the gates", approved 2026-09-25: "sounds good, let's press forward").

## 1. Scope

### In

1. **Gates removed.** `GateDef`, `GateSpawn`, `GateMath`, `GateView`, `GateFormat`, the 5
   gate `.tres`, and the gate card/meta effects go.
2. **Build plots on the field** (`MapDef` → `PlotDef`s). Tap a plot to build one of the units;
   tap a built one to upgrade it. This works **any time**, mid-wave included.
3. **Units** (`UnitDef`, replacing `TurretDef`):
   - Each has a **reload** time, a range, an attack type and an optional splash or slow.
   - "Stronger means slower" is a **content test**.
   - Six units: Rifleman, MG nest, Frost projector, Mortar, Sniper, Rail cannon.
4. **Loot crates** (`CrateDef`):
   - They drift down a lane and only squad bullets break them. The reward is coins; a special
     crate gives a timed boost.
   - Crates that reach the wall are lost.
   - Crates are the main income, and kills pay a trickle.
5. **Squad upgrades bought with coins** (`SquadUpgradeDef`: shooters, damage, fire rate). They
   replace the gates as the way the squad grows.
6. **Phase flow:** the run opens in **BUILD** (prep). After that: WAVE → CARD (pick 1 of 3) →
   BUILD → WAVE … → WON/LOST. BUILD has a "Start wave" button, and building also works during
   WAVE.
7. **Health bars** on every enemy, redrawn as part of the art. HP retuned so no enemy dies to
   one squad bullet.
8. **Art slice (procedural, route A):**
   - The source art is **hand-written SVG** in `game/art/`. It's tracked and editable in
     Inkscape by a future artist; Godot rasterizes it at 2× on import (verified).
   - Direction: **"frontier outpost vs alien swarm"**:
     - A stylized top-down sci-fi military outpost: dirt lanes, rock and scrub verges, a
       stone-and-steel wall.
     - Chitinous alien bugs with glowing weak points. The speed ↔ toughness archetypes are
       readable by silhouette: runner = lean skitterer, grunt = drone, brute = armoured
       beetle, boss = hive queen.
   - Motion and VFX:
     - Walk bob and waddle, and turret heads that rotate to their target with recoil.
     - Muzzle flashes, glowing additive tracers, and mortar shells on an arc with a shadow.
     - Explosions, death bursts with debris particles, and a crate that bursts into coins
       that fly to the HUD.
     - Hit flash via a shader, a reload ring per unit, a range circle when a plot is
       selected, and a vignette.
   - A restyled HUD and a real card picker.
   - **The whole slice covers every existing object**, not just a sample: 4 enemies, 6 units, 3
     crates and the field. It's cheaper to do it in one style than to keep two.
9. **Autoplay** updated: aim policy (threat → crate → front enemy), a build policy, and cards.
   It's used by the tests and gives a first-pass tuning.
10. **Tests:** every changed core rule, content invariants, scene tests for plot input and the
    new flow, and determinism.

### Out (unchanged from the roadmap, or deferred)

- The meta screen and save wiring (B3).
- The full balance-bot report and fine tuning (B4). This item does a *first-pass* tune only:
  the bot must not win at zero meta with a large margin.
- Audio.
- Selling units.
- Enemies attacking units.
- More maps.
- Choosing between art directions. **One** direction is built; the user judges the clip, and a
  second direction is a follow-up if this one misses.

## 2. Rules (core)

- **Plots:** `MapDef.plots: Array[PlotDef]` (`position`, optional `allowed` tags). The
  first map is `data/maps/outpost.tres`, with 8 plots:
  - 6 on the lane dividers (x = 180, 360) at three depths.
  - 2 on the outer verges.
  - They sit in the gaps between enemy paths, which have ±30 px jitter around each lane
    centre.
- **Units** fire on their own. The target is the **enemy nearest the wall within range**
  ("first", as in Kingdom Rush). There's one countdown per unit: `cooldown -= dt`, and when
  it's ≤ 0 with a target in range, it fires and `cooldown = reload_eff`. Attack kinds:
  - `BULLET`: a homing projectile at `projectile_speed` (Rifleman, MG, Frost). If its target
    dies in flight, it fizzles.
  - `SHELL`: a ground-targeted arc to where the target **was** when fired, with splash on
    impact (Mortar). Fast enemies step out of it, which is the reload trade-off made
    physical.
  - `HITSCAN`: instant damage, with a cosmetic tracer (Sniper).
  - `BEAM`: instant damage to every enemy in the target's lane within range (Rail).
- **Levels:** +`level_damage_bonus` damage per level, and reload × (1 − `level_reload_bonus`)
  per level.
- **Modifiers:** `unit_rate_bonus` divides reload (Overclock); `unit_cost_discount`.
- **Crates:**
  - A lane object like gates were: sorted front-first, and hit only by squad RIFLE bullets
    when nearer the wall than the lane's front enemy.
  - When HP reaches 0, they pay `reward × (1 + crate_reward_bonus)` coins; a boost crate also
    sets a squad fire-rate multiplier for `boost_duration`.
  - A crate that reaches the wall is lost (signal `crate_lost`).
- **Squad:** `shooters = start + start_shooters_bonus + shooters_bonus`. `damage` and
  `fire_rate` come from the config × (1 + bonuses). Squad upgrades add to those modifier
  fields; cards and meta keep using `RunModifiers` keys. Caps as before.
- **Economy:**
  - `Economy.unit_cost / unit_upgrade_cost / squad_upgrade_cost / crate_reward`.
  - Kills pay `EnemyDef.gold`, now small.
  - Start coins cover about 2 cheap units.
- **Run API:**
  - `build(plot, unit_id)`, `upgrade(plot)`, `buy_squad_upgrade(id)`: allowed in **BUILD
    and WAVE**.
  - `start_wave()` from BUILD, `pick_card(i)` from CARD (→ BUILD).
  - `step()` in WAVE only.
- **Signals** for the views: `unit_fired(plot, shot)`, `shell_landed`, `crate_spawned`,
  `crate_hit`, `crate_broken(crate, coins)`, `crate_lost`, plus the enemy signals.
- **Determinism:** everything stays on the seeded streams. `state_hash()` covers plots,
  crates, shots and the boost.

## 3. File-level changes

| Area | Change |
| --- | --- |
| `src/defs/` | **New:** `unit_def.gd`, `crate_def.gd`, `crate_spawn.gd`, `plot_def.gd`, `map_def.gd`, `squad_upgrade_def.gd`. **Deleted:** `turret_def.gd`, `gate_def.gd`, `gate_spawn.gd`. **Edited:** `wave_def.gd` (`crates`), `run_config.gd` (`units`, `map`, `squad_upgrades`, `crate`/`start` numbers), `enemy_def.gd` (`look` id, unchanged rules). |
| `src/core/` | **Rewritten:** `combat_sim.gd` (crates, plots, shots, boost). **Edited:** `run.gd` (flow, build anywhere, squad upgrades, hash), `economy.gd`, `run_modifiers.gd` (gate keys out; `unit_*`, `crate_*`, `shooters_bonus` in), `wave_schedule.gd` (CRATE events), `autoplay.gd`, `squad_stats.gd` (gate mutators out), `save_data.gd` (**v3**: levels of the removed meta upgrade `gate_lore` are refunded as bricks, never dropped). **Deleted:** `gate_math.gd`. |
| `data/` | `units/` ×6 (replaces `turrets/`), `crates/` ×3, `maps/outpost.tres`, `squad/` ×3, waves 1–10 re-authored with crates, cards `lucky_gates`/`soft_gates` → `scavengers`/`crowbars`, meta `gate_lore` → `salvage`, `fifth_slot` → `war_chest`, enemies retuned. `gates/` deleted. |
| `art/` | **New:** SVG sources: `field/` (background, wall, plot), `enemies/` ×4, `units/` (base + head per unit), `crates/` ×3, `fx/` (tracer, glow, explosion, coin, shell, spark), `ui/` (coin icon). |
| `src/sim/` | **New:** `plot_field.gd` (plot nodes: base, rotating head, recoil, reload ring, level pips, range circle), `crate_field.gd` (pooled crate nodes with hit shake and HP bar), `shot_field.gd` (unit projectiles, tracers, beams, shell arcs), `fx_pool.gd` (pooled `CPUParticles2D` bursts, explosions, flying coins). **Rewritten:** `enemy_field.gd` (textured MultiMesh per type, hit-flash shader through custom data, shadow batch, walk animation, batched HP bars), `field_view.gd` (background art, wall damage states), `squad_view.gd` (soldier sprites), `bullet_field.gd` (additive tracer texture). **Edited:** `run_controller.gd` (new signals, plot input, build menu, flow). **Deleted:** `gate_view.gd`, `turret_row_view.gd`. |
| `src/ui/` | **New:** `build_menu.gd` (radial menu at a plot: unit icons with prices, greyed when unaffordable; upgrade/info for built plots), `card_picker.gd`, `squad_panel.gd` (squad upgrades), `theme.gd` (shared colours and styleboxes). **Edited:** `hud.gd` (coin counter with an icon and a count-up, wall bar, wave, "Start wave" / squad buttons), `phase_overlay.gd` (result screen only). **Deleted:** `gate_format.gd`. |
| `tests/` | `gate_math_test`, `gate_format_test` deleted. `combat_sim_test`, `run_test`, `economy_test`, `content_test`, `wave_schedule_test`, `squad_stats_test`, `save_data_test`, `fixtures`, both integration suites updated. **New:** `unit_rules` cases (reload, range, first-targeting, shell miss on runners, beam, hitscan, levels), crate cases, `build_menu`/plot-input scene cases. |
| docs | `detailed-project-overview.md`, `README.md`, `ROADMAP.md` (pivot recorded; B3/B4/B6 re-scoped), `CLAUDE.md` §1 description line, `project.godot` description. |

## 4. Input on a portrait phone

- **A tap that starts on a plot opens the build menu,** with a 34 px hit radius. It never
  moves the squad.
- **Everything else drives the squad,** as now: drag, or tap-a-lane.
- **While the menu is open,** the game runs at `build_menu_time_scale` (0.35, config), not
  paused. The pressure stays, but a decision is possible. Tapping outside closes it.
- **Autoplay and tests** call `Run.build` directly.

## 5. Testing strategy

**Unit tests (core):**

- Reload gates fire timing, and a stronger level fires sooner.
- Range: out-of-range enemies aren't shot. First-targeting picks the one nearest the wall.
- A shell lands where the target was: it hits a grunt and misses a runner outside the splash.
- Beam hits the whole lane within range. Hitscan is instant.
- Building and upgrading mid-wave charge coins. Building fails on an occupied plot or with
  too few coins.
- Crates are hit only by squad bullets, and only when in front; broken pays coins with the
  bonus; lost pays nothing; a boost crate raises the squad's bullets per second for its
  duration only.
- Phase flow: BUILD → WAVE → CARD → BUILD, and no cards skips CARD.
- Squad upgrades raise shooters and damage.
- Save v2 → v3 refund.

**Content tests:**

- Every unit's reload is non-decreasing in damage per shot.
- Single-target DPS spread across units ≤ 3×.
- Every plot is inside the field and off the enemy paths.
- Every wave has crates and enemies, and every crate is breakable at base squad DPS before it
  reaches the wall.
- No enemy dies to one base squad bullet.

**Integration:**

- Autoplay clears wave 1.
- A seeded full run is deterministic.
- The bullet budget holds.
- Autoplay's zero-meta median over 10 seeds does **not** win all runs (a first-pass
  difficulty guard).

**Scene tests:**

- A tap on a plot opens the menu and doesn't move the squad.
- Buying from the menu builds.
- The flow buttons work.
- Enemies stay one batch per type.
- Crate views are pooled.

**Visual:** stills and a clip via `scripts/capture_clip.sh`, checked frame by frame before
showing the user. Frame time measured at budget load (`--stress --perf`) before and after.

## 6. Performance budget impact

- **Enemies:**
  - They stay MultiMesh per type (now textured) plus one shadow batch.
  - HP bars are drawn in one `_draw` pass.
  - Target: at budget load, draw calls stay ≲ 100 (B2: 80), and the frame average stays under
    the 60 fps line with margin on desktop.
- **Units and crates** are ≤ 8 and ≤ ~4 nodes.
- **Particles:** a `CPUParticles2D` pool with a fixed size, and no new particle node per event.
- **Lighting:** no real-time 2D lights (research §6). Glow is additive sprites.
- **Art size:** SVG → ~2× raster textures, a few MB in total VRAM.

## 7. Risks

- **The art may not hit "stunning" for the user.** That's taste; the clip decides, and the
  SVG sources make revisions cheap.
- **A busy screen:** enemies, crates, units, tracers. Mitigation: crates get a distinct warm
  metal look with a hit counter, and effects stay short.
- **First-pass balance.** The bot guards against "trivial", and B4 does the real tuning.
- **WSL renders through OpenGL.** Shader and particle features are kept to the Compatibility
  and Mobile subset.

## 8. Rollout

Implement core → content → tests green → presentation → art → scene tests → stills and a clip
→ perf → docs. Log every step in `implementation.md`. The 👤 checkpoint is the clip plus a
playable build for the user to judge the feel and the art direction.
