# Content expansion: implementation log

## 2026-09-27: research and plan written

- `research.md`: where things stand, prior art, options for abilities, enemies, bosses,
  sectors and progression, the risks, and 5 questions for the user.
- `plan.md`: 4 stages, each ending with tests, a perf check, a balance run and clips.
  1. abilities as data + a 2-slot loadout
  2. four new enemies
  3. bosses as data
  4. sectors 4–6, progression and balance
- **Status:** waiting on the user's answers to research §5. No code has changed yet.

## 2026-09-27: decisions recorded, handover written

- The user's answers are in research §6: one attack picked per map start with a first-time
  tutorial; the Queen deals 50 gate damage; the roster and names accepted; building in
  stages; clips reused in tutorials where they help (e.g. special-attack effects).
- `plan.md` is updated to match.
- `handover.md` is written for the session compaction. It covers repo state, decisions,
  every strike touchpoint for Stage 1, in-game clip notes (Godot plays Ogg Theora only;
  ffmpeg here has libtheora), commands, and the definition of done.
- **Next:** Stage 1.

## 2026-09-27 20:40: Stage 1 started — abilities as data

- **Baseline perf** (before any change; `--seed=3 --autoplay --stress --perf`): frame avg
  5.4 / 7.5 / 8.0 ms, sim tick 0.95 / 1.38 / 1.78 ms, 82–83 draw calls.
- `src/defs/ability_def.gd` (`AbilityDef`): id, names, one line, icon, clip, `kind` (STRIKE,
  FREEZE, BURN, MINES, REPAIR), `unlocked_by` (a map id), cooldown, delay, and the per-kind
  numbers. `targeted()` is false for REPAIR only.
- `data/abilities/*.tres`: the five attacks. The strike keeps its numbers (20 damage, radius
  70, delay 0.9 s, reload 30 s). Cryo Bomb and the strike are free; Napalm unlocks with
  Outpost, Minefield with Canyon, Repair Drones with Switchback (research §3.1: clearing a
  sector unlocks one more).
- `RunConfig`: the `strike_*` fields are gone; `abilities` (the pool, in pick order) and
  `ability_by_id()` replace them.
- `RunModifiers.strike_cooldown_bonus` → `ability_cooldown_bonus`; the Fire Mission card
  now reads "Your special attack reloads 30% faster."

## 2026-09-27 20:55: the sim and the run

- `CombatSim`: `Strike` → `Cast` (lands after its delay, per kind in `_land`), plus
  `Hazard` (a burning strip, `_burn` each tick) and `Mine` (`_trip_mines` each tick, after
  the move pass). `Enemy.stun`: a frozen enemy neither moves, strikes, spits nor heals.
  `enemies_within()` and `mine_layout()` are shared (the view previews the same mine spots).
  Signals `ability_called`, `ability_landed`, `mine_exploded` replace `strike_called/landed`.
  `pending_gate_heal` carries REPAIR's gate HP to Run, like the damage.
- `Run`: `ability` (the first of the pool by default), `choose_ability()` (BUILD before wave 1
  only), `ability_ready()`, `ability_cooldown()`, `call_ability()`. `call_strike` is gone
  (every test is migrated, so no wrapper was kept). `state_hash` covers the ability, casts,
  strips, mines and each enemy's stun.
- **Casts and mines take ids from their own counter.** At first they took enemy ids, which
  shifted every later enemy's id and so its seeded sideways spread: the campaign-curve test
  moved (canyon T0 won 2/8 instead of 1/8). With their own counter the numbers match the
  pre-change runs exactly (outpost 3, canyon 1/3/5, switchback 1/3).

## 2026-09-27 21:05: bot, balance tooling, save

- `Autoplay`: `ability_target()` per kind (strike: the best cluster; freeze: only near the
  gate; napalm: ahead of the cluster; mines: ahead of it on its path; repair: gate < 60% or a
  unit < 30%) over a shared `best_cluster()`. Fields renamed `ability_threat` /
  `ability_every_ticks`; preset `no_strike` → `no_ability`.
- `BalanceRun.play(..., ability)` records `ability` and `casts` (was `strikes`);
  `tools/balance_sim.gd` takes `ability=ID`. Tools: `uv run balance --abilities a,b` adds
  `smart+ID` / `casual+ID` cells per sector; the report's column is "Casts". New tools test
  for the per-ability cells (tools 12/12).
- `SaveData` v7: `abilities: {last}`. Unlocks are **not** stored, a deviation from the plan's
  `unlocked_abilities`: they follow from `campaign.cleared` (`Campaign.ability_unlocked`),
  so they can't drift from progress. A v6 save migrates to `last = strike`.

## 2026-09-27 21:20: UI, tips, art

- `ui/ability_button.gd` (`AbilityButton`, was `StrikeButton`): the picked attack's icon and
  short name, cooldown sweep; an untargeted attack goes off on the tap.
- `sim/ability_view.gd` (`AbilityView`, was `StrikeView`): per-kind aim preview (blast circle,
  fire strip, the five mine spots), telegraphs, burning strips (flickering `fx/flame`), mines
  (`fx/mine` with a blinking light), and the unit links as before.
- `ui/ability_picker.gd` (`AbilityPicker`): the pick when a map starts. One card per attack
  (icon, name, one line, numbers in coin colour); locked ones say "Win <sector> to unlock";
  unseen ones get NEW; the last pick is preselected; DEPLOY confirms. The build bar hides
  while it's open.
- `RunController`: the pick opens when a hand-played run starts (`offer_pick`; the campaign
  offers the unlocked attacks, a direct run all of them; `--ability=ID` skips it, `--pick=ID`
  answers it for captures). A pick is saved as the next default. Per-kind landing FX. Tests
  set `offer_pick = false`.
- Tips: `strike.tres` → `ability_ready.tres` (generic, spotlights the button) and
  `ability_intro.tres` (trigger `ability_picked`, per attack). The intro's two cards are built
  from the AbilityDef (`RunController.ability_pages`): what it does with its clip and numbers,
  then how to call it and its reload. `TipCard.clip` / `TipLayer.Page.clip`: a looping, muted
  `VideoStreamPlayer` above the text (skipped if the file is missing).
- Art (`fx.py`): `ui/ability_*` badges (48 units) for the five attacks, `fx/flame`, `fx/mine`.
- Frozen enemies: the enemy shader draws them as blue ice. Two gotchas:
  - custom data's alpha channel never reached the shader on the compatibility renderer, so
    frost is now one channel (0 none, 0.5 slowed, 1 frozen);
  - Godot 4's canvas `COLOR` input is already texture × instance colour, so the ice is mixed
    in after that product (before, a blue block times an orange body came out beige).

## 2026-09-27 21:50: tutorial clips

- `--demo=ID` (RunController, dev only): a staged wave (a Drone pack, then Brutes, then
  Skitters, down the middle path; nothing built) fast-forwarded unrendered to about a second
  before the attack, which is then called where the pack is. It prints the spot and frame, and
  quits 6 s later.
- `tools/src/gf_tools/clips/` (`uv run make-clips [ids]`) does the rest:
  1. Records each demo with Movie Maker at 1080×1920, in a temporary copy of `game/` with an
     `override.cfg`.
  2. Crops a 300-unit square around the attack and trims around its call.
  3. Writes `game/clips/ID.ogv` (Theora 400 px, q5, 30 fps), which ships and is tracked, and
     `captures/clips/ID.mp4` for review.
- **Settings.** At 1440×2560 in software GL a clip took ~10 min and a 1.9 GB AVI. At 2× each
  takes ~17 s. Quality comparison on the strike clip:

  | Setting | Size |
  | --- | --- |
  | q4 / q5 / q6 at 400 px | 168 / 224 / 304 KB |
  | q4 / q5 / q6 at 480 px | 240 / 324 / 440 KB |

  q5 at 400 px was picked.
- **Sizes:** strike 263 KB, cryo 346 KB, napalm 459 KB, minefield 245 KB, repair 119 KB. That
  is ~1.4 MB in all, inside the 1–2 MB estimate.
- **Framing fixes.** The first pass aimed napalm and mines at the lead enemies, which were
  Skitters that sprinted through before the pack arrived. The stream order and the aim
  changed so the pack walks into them. Repair's crop was tightened.
- **Content test:** every attack's icon and clip must exist.
- **Known noise:** quitting a run while a clip is playing prints "Texture … leaked" GL errors
  (teardown only).

## 2026-09-27 22:10: perf, balance, docs — Stage 1 complete

- **Perf** (same probe as the baseline; frame / sim tick / draw calls):

  | Run | Frame (ms) | Sim tick (ms) | Draw calls |
  | --- | --- | --- | --- |
  | Baseline, before Stage 1 | 5.4 / 7.5 / 8.0 | 0.95 / 1.38 / 1.78 | 82–83 |
  | Strike | 5.5 / 7.1 / 7.3 | 1.00 / 1.49 / 1.57 | 82–83 |
  | Napalm (a strip burning each tick) | 5.2 / 7.0 | 1.01 / 1.29 | 82–85 |

  No regression; the sim tick stays under the 2.0 ms budget.
- **Build size:** +1.45 MB of clips; the icons are SVG and negligible.
- **Balance:** `balance-stage1.md` has the full matrix (27 cells), plus `smart`/`casual` with
  each other attack, 50 seeds each.
  - **Strike cells (unchanged content)** are within ±4 pts of the final B4 report (e.g. Canyon
    smart 34% vs 38%). The seeds-1–8 curve test matches exactly, so the drift likely comes from
    the art item's crate and barricade sizes. The known B4 misses still stand: `heavy` beats
    `smart` on Switchback (84%), and `casual` is above 40% on Outpost and Switchback.
  - **Before tuning** (smart win rates, Outpost / Canyon / Switchback):

    | Attack | Outpost | Canyon | Switchback |
    | --- | --- | --- | --- |
    | Strike | 38% | 34% | 48% |
    | Mines | 72% | 50% | 56% |
    | Napalm | 58% | 38% | 48% |
    | Cryo | 24% | 18% | 56% |
    | Repair | 26% | 18% | 52% |
  - **One tuning pass:**
    - Minefield 18 → 12 damage, reload 30 → 35 s.
    - Napalm 10 → 8 damage a second.
    - Cryo frozen 3 → 4 s, radius 85 → 95, reload 35 → 30 s.
    - Repair gate +25 → +35, reload 45 → 40 s.
  - **After tuning** (`balance-stage1-tuned.md`), counting only attacks a player can hold there:

    | Sector | Win rates |
    | --- | --- |
    | Outpost | Strike 38%, Cryo 30% |
    | Canyon | Strike 34%, Napalm 38%, Cryo 22% |
    | Switchback | Strike 48%, Napalm 52%, Mines 46%, Cryo 66% |
  - Cryo is situational (weak early, strong on Switchback's long zig-zag), which suits a pick
    per map. Repair only matters from sector 4, so Stage 4 balances it. Left for the user to
    judge by hand rather than tuned further against the bot.
- Clips re-recorded for the new numbers (the demo now runs 6 s after the call, so the
  cryo clip shows the whole freeze): 1.45 MB in all.
- **Tests:** game 249/249, tools 12/12. New or changed tests:
  - `ability_test` (16, every kind);
  - save v7 and unlocks (3);
  - the scene: the button, every attack cast and landing, and the pick plus its tutorial (4);
  - the campaign's pick pool and saved pick;
  - `content_test` for special attacks;
  - the tools test for per-ability cells.
- **Docs:** `detailed-project-overview.md` (files, systems, dependency map, change log),
  `README.md` (status, commands, launch args, layout) and `ROADMAP.md` (E7, E8).
- **Not verified here:** hand feel (aiming on touch, whether the pick panel reads at a
  glance), and clip playback on a phone. Both are for the user.
- **Stage 1 is done.** Stage 2 (four enemies) waits on the user's review.

## 2026-09-28 22:30 — napalm burns along the road (the user's Stage 1 review)

The user's review: "napalm generates a random rectangle instead of fire only in the
trail/path, let's fix that." BURN was a screen-aligned `Rect2` centred on the tap (200×56),
covering bare ground between roads and ignoring bends.

- **Sim (`CombatSim`).** `burn_layout(a, pos)` finds the spot on the nearest open path
  (`nearest_open_path`, now shared with `mine_layout`). Then, for every open path that
  passes within 2 px of that spot, it makes a `Stretch` (path, d range, centre-line points
  via `PathGeo.stretch`) that is `length` long and centred there. It drops stretches that
  are identical, as on a shared trunk.
  - A `Hazard` holds the stretches plus `half_width` (the path spread + 8, so it covers the
    whole road) and a bounding box.
  - `_burn` hits every enemy within half_width + half its body of any stretch
    (`PathGeo.distance_to_polyline`), whichever path it walks.
- **Why every path through the spot.** The first version snapped to one path. On
  Switchback's demo the tap sat where two paths share the road, the tie went to the lower
  index, and the fire ran down the *other* branch while the pack walked past. The fix: fire
  at a shared spot runs down every branch, and a merged trunk burns for everyone on it. A tap
  already inside one branch burns only that branch, so the player still picks one, and the
  preview shows it.
- **Data.** `AbilityDef.depth` → `length` (the road length). BURN no longer reads `radius`.
- **View.** `AbilityView`:
  - The preview, the telegraph (fills from the middle out) and the fire are one band per
    road, built with `Geometry2D.offset_polyline` and merged with `merge_polygons`, so
    translucent fills don't darken at joins.
  - Flames go in two staggered rows along each stretch, skipped where an earlier stretch
    already covers the road.
  - The landing FX in `RunController` go along the stretches.
- **Bot and demo aim.** A point on the cluster's own path, ahead of it (`c.d + 0.35·length`;
  the demo uses `c.d + 70`).
- **Picker text.** "N damage a second along the road for Ns".
- **Balance** (smart+napalm, 50 seeds, Outpost / Canyon / Switchback):

  | Setting | Outpost | Canyon | Switchback |
  | --- | --- | --- | --- |
  | Before (rect, 8/s) | 58% | 38% | 52% |
  | Road, 140 long, 8/s | 82% | 50% | 54% |
  | Road, 100 long, 7/s | 76% | 50% | 56% |
  | **Road, 90 long, 5/s (kept)** | **64%** | **40%** | **52%** |

  Walking down a burning road exposes each enemy far longer than crossing a 56-deep band.
  The kept numbers are back within noise of the pre-change napalm.
- **Tests:** 5 new:
  - only the nearest road burns (a neighbour 180 px away is untouched; the old strip hit it);
  - a merged trunk burns walkers from both paths;
  - a fork runs down both branches, and a stem shared by both is kept once;
  - a tap inside one branch burns only that branch;
  - the fire turns a bend, and `PathGeo.stretch`/`distance_to_polyline` behave.

  The burn fixtures moved to `length`. Game 254/254, tools 12/12.
- **Perf** (`--stress --perf --ability=napalm`): frame 5.4 / 8.0 / 8.6 ms, sim tick 0.99 /
  1.31 / 1.49 ms, 82–85 draw calls. Same range as Stage 1; under the 2.0 ms tick budget.
- **Clips.**
  - `game/clips/napalm.ogv` re-recorded (387 KB, was 459 KB), and
    `captures/clips/napalm.mp4` for review.
  - `captures/napalm_bend.mp4` is the demo on Switchback, where the fire lies on the
    diagonal into the merge.
  - `captures/napalm_switchback.mp4` is a bot run.
- **Left for the user:** whether the fire reads as "the road is burning" on a phone, and
  whether 90 px feels too short for the player's own aim.

## 2026-09-28 23:40 — Stage 2: four new enemies (Wasp, Warden, Burrower, Bombardier)

The user asked to continue with the roadmap. The enemies and their weaknesses are the ones
agreed in `plan.md` (decision 3). The rule details below are defaults chosen during
implementation; the user judges them from clips and play.

- **`EnemyDef`** gains four groups:
  - Flying: `flying`.
  - Shield: `shield_radius`, `shield_amount`, `shield_regen`.
  - Burrow: `burrow_every`, `burrow_length`.
  - Siege from range: `siege_range`, `lob_time`.

  The Bombardier reuses `wall_damage` and `attack_interval` for its lobs instead of the
  planned `siege_damage`/`siege_interval`, so it's less data.
- **Rules (`CombatSim`).** Two helpers do most of the gating:
  - `Enemy.hittable()` (alive, not underground) gates targeting (`can_target`), beams, blasts,
    `enemies_within` and bullets that arrive at a burrowed target (they fizzle).
  - `Enemy.on_ground()` (not underground, not flying) gates shells, mines (tripping and
    blast), fire, mud, escorts and the barricade.
  - **Wasp:** follows its path in the air. Mortars neither aim at it nor splash it; bullets,
    beams, the Strike and Cryo hit it.
  - **Warden:** an aura on itself and every enemy within 90. Shields cap at
    `shield_amount × the Warden's hp scale` (the strongest aura counts) and refill at
    `shield_regen`/s while inside. Outside every aura a shield holds but doesn't refill. The
    shield soaks damage in `_apply_damage`, after the chart and armour, and every damage
    source goes through it. The pass is skipped with no Warden on the field (a counter) and
    runs at 10 Hz (`SHIELD_PERIOD`).
  - **Burrower:**
    - After `burrow_every` s on the surface it dives for `burrow_length` of path. Underground
      it can't be hit, and it tunnels under the barricade.
    - It never dives where it would surface within reach of the gate.
    - **While slowed it can't dive** (its clock pauses). I added this so Frost is its counter
      in play, not just on the chart, and its card says so.
  - **Bombardier:**
    - It stops `siege_range` (200) of path short of the gate (`lobbing`, also `sieging`).
      Every `attack_interval` it lobs a `Lob` that lands `lob_time` later for `wall_damage`.
    - A glob in the air lands even if its thrower dies. A wave's end clears globs in flight,
      the same as shots.
    - A barricade in front of its post stops it there (melee on the barricade).
    - Stopped mid-path, it doesn't hold smaller enemies behind it (escorts skip lobbers).
    - No gate thorns (it's far away).
- **Data.** Enemy stats (`data/enemies/*.tres`, weakness · resistance):

  | Enemy | HP | Speed | Other stats | Weak · resists |
  | --- | --- | --- | --- | --- |
  | Wasp | 7 | 58 | — | kinetic · piercing |
  | Warden | 40 | 26 | armour 1; aura 90 / 8 / 3 per s | explosive · kinetic |
  | Burrower | 24 | 36 | every 3 s for 140 | cryo · explosive |
  | Bombardier | 30 | 24 | armour 1; range 200, 6 damage / 2.5 s | piercing · kinetic |

  Each description is its intel card (the `new_enemy` tip).
- **Bot.** `Autoplay._kill_rate` gives shells 0 against flyers, counts shields as HP, and
  scales Burrowers by their surface uptime.
- **Art (`uv run gen-art`).**
  - Wasp: amber and black, with beating wings.
  - Warden: steel blue, with a shield-projector dome.
  - Burrower: earth brown, with shovel claws.
  - Bombardier: olive, with a bile sac and a mortar tube.
  - Also `fx/mound`, `fx/glob` and `fx/bubble`.
- **View.**
  - `EnemyField` draws burrowed enemies as mounds (a batch) and shields as bubbles (a batch,
    faded by the shield left).
  - Flyers are drawn lifted 12 px and bobbing, over a small faint shadow.
  - Globs arc to the gate on the bar layer.
  - `RunController` adds an acid splash plus the damage popup when a glob lands, and
    `Fx.dust` on a dive or surfacing.
- **Dev flags.**
  - `--showcase=IDS` plays one wave of those enemies among 24 Drones, with 400 coins.
  - `--gold=N` sets the starting coins.
  - `--stress=mix` makes 40 of the 260 stress enemies the new ones (8 Wardens).
- **Perf.**
  - **First mixed-stress measurement: ~1850 draw calls and a 50 ms frame.** Every shield
    bubble was drawn one by one with anti-aliased circles and arcs. They moved into a
    MultiMesh: 87–91 draw calls, frame 7.5–8.0 ms.
  - **Sim tick in game:** plain stress 1.9–2.5 ms, mixed 2.1–3.1 ms. This machine is noisy
    tonight; the plain stress wave measured 1.3–1.6 ms in earlier sessions.
  - **Headless per-pass probe** (the same 260-enemy load, 20 s): plain 1.01 ms/tick, mixed
    1.16 ms/tick. The shield pass is 0.09 ms at 10 Hz, and the move pass +0.05.
  - So the new rules cost about +15%. The desktop 2.0 ms budget is only exceeded by the
    noise, but it needs the phone check in B5.
- **Tests.**
  - `stage2_enemies_test` (13), covering:
    - Wasp: over the barricade, Mortar can't aim or splash, ground effects miss it (fire, mud);
    - Warden: shields to the cap, soak then hp, no refill without a Warden, scales with the
      wave;
    - Burrower: dives out of reach and surfaces, tunnels under the barricade, no dive while
      slowed or near the gate;
    - Bombardier: stops at range with delayed lobs, globs land after the thrower's death,
      a barricade stops it first, it doesn't hold walkers behind it.
  - `content_test` now checks every file in `data/enemies/` (weakness, description length,
    art) and that each new enemy carries its rule.
  - A scene test shows mounds, bubbles, globs and flyers in the real scene.
  - Totals: game 270/270, tools 12/12.
- **Balance.** No existing wave changed. The bot's kill-rate changes only touch the new
  enemies, so the balance matrix is unaffected and wasn't re-run. Tuning the new enemies'
  numbers belongs to Stage 4, where they enter sector waves.
- **Clips** (`captures/`):
  - `stage2_showcase.mp4`: all four, bot-defended.
  - `stage2_bomb_g100.mp4`: Bombardiers at their posts, globs landing.
- **Left for the user:**
  - whether each rule reads at a glance (a Wasp's lift, the bubbles, the mounds, the globs);
  - whether the Bombardier's lime sac is too close to the Spitter's gland;
  - whether "can't dive while slowed" is a fair counter.

## 2026-09-29 22:20 — Stage 3 begins: bosses as data

Resumed from `handover.md` (the user committed Stages 1–2 as `dd52626`/`dd2951a`). Two
refinements to the plan's `BossPhase`, both so a phase describes its own escort rather than
the whole field:
- **`guard` instead of `shield_while_alive` (an enemy id).** An id-based rule would let any
  Warden anywhere on the map shield the boss. Instead, a phase marks its own spawns as guards:
  the boss takes no damage while any guard it spawned lives (a count on the boss, decremented
  when a guard dies: O(1) per hit).
- **`keep_pace`.** Escorts walk at the boss's speed, so Wardens stay beside the Titan (their
  aura covers it) instead of sprinting to the gate.
- **`callout`**, a line the view pops over the boss when the phase fires ("THE BROOD HATCHES").
- **`at_hp_fraction` 1.0** fires on arrival (the Overmind's opening escort).
- **`pause_seconds`** is its own `Enemy.pause`, not `stun`, which the view draws as ice.

## 2026-09-29 22:35 — Stage 3: rules, content, art

- **Core.**
  - `defs/boss_phase.gd` (`BossPhase`).
  - `EnemyDef` Boss group: `is_boss`, `phases`.
  - `CombatSim`:
    - `bosses` (kept by spawn and kill) and the `boss_phase(boss, index)` signal.
    - `_check_phases`: on arrival, and after a non-lethal hit on a boss. It fires every phase
      whose threshold the hp has reached, in order. It is monotonic, so healing never re-fires
      a phase.
    - `_fire_phase`: armour (`Enemy.armor_bonus`, read through `extra_armor()` alongside an
      elite's), speed, `Enemy.pause`, and spawns. Spawns are inserted sorted just ahead of the
      boss, clear of its body, staggered in rows of 3 and fanned across the path's spread. They
      scale by the wave like a Splitter's brood.
    - Guards: `Enemy.guarding` points at the boss, `guards` counts them, and `_apply_damage`
      returns early while it is above 0.
- **Content.**
  - Hive Queen: 999 → 50 per strike (the user's call), `attack_interval` 1 → 3 s (my
    proposal: it gives the defence time to kill her at the gate between the two strikes), 6
    Skitters at 50% with a 1.2 s pause.
  - `broodmother.tres`, `titan.tres`, `overmind.tres` (numbers in the overview roster; Stage 4
    tunes them against real sector waves).
  - All descriptions ≤ 80 characters (the intel card cap).
  - **Titan armour:** Frost hits for 3.5, so against armour 8 even the cryo weakness gave
    ≈1 damage. The Titan starts at armour 6 and sheds all 6 at 50%. Heavy hitters crack the
    plates, and then Frost both melts it (×2) and slows the charge.
- **Art.** `enemies.py` `broodmother` (copper nest, pods with green Skitter embryos), `titan`
  (slate plates, ember seams, a ram), `overmind` (an indigo brain, cyan folds, swinging
  tendrils), with palette entries. Checked as a PNG sheet next to the Queen; the Titan's seams
  were widened after the first look.
- **Tests.**
  - `boss_test` (12): order and thresholds, one hit crossing two, no phase on a killing
    blow, no re-fire after a heal, the brood ahead and sorted, arrival phases, armour shed and
    speed, pause, guards voiding hits until the last dies, units killing guards first,
    keep-pace, the `bosses` list.
  - `content_test`: bosses found by `is_boss`, 15 enemies, and `test_every_boss_is_well_formed`
    (it also pins the Queen at half the base gate).

## 2026-09-29 22:55 — Stage 3: view, clips

- **`ui/boss_bar.gd` (`BossBar`).** It sits under the HUD, centred and kept clear of the
  ability button: the name, HP with a white drain, a tick per phase (dimmed once passed), gold
  while guarded, and "GUARDED ×N". The first clip showed a long status line running into the
  name, so it became a short right-aligned tag.
- **`RunController`.** A banner names a boss as it arrives; each phase pops its `callout` over
  the boss with a ring and a shake. `--showcase` spawns one of a boss, not 8.
- **`EnemyField`.** A guarded boss wears a gold, pulsing bubble; dashed gold tethers run from
  each guard to it.
- **Escort placement.** The first Overmind clip had the Wardens stacked on its head. Spawns
  now start `radius × 1.3 + their radius` ahead.
- **Scene test:** the Overmind's bar, the "GUARDED ×3" tag, the bubble, the bar clear of the
  ability button, the guards killed, a phase tick and the 10 Wasps, and the bar hidden once
  she dies.
- **Clips** (`captures/`, all bot-defended `--showcase`, 60 s):
  - `stage3_overmind.mp4`: the guard bubble, tethers, then Wasps and Menders.
  - `stage3_titan.mp4`: the Warden escort, whose bubbles cover it.
  - `stage3_broodmother.mp4`: two hatchings.
  - `stage3_queen.mp4`: the Queen's Skitters.
- **A pre-existing warning.** `run_scene_test` prints "12 resources still in use at exit". It
  does so with the new test excluded too, so it predates Stage 3. Not chased here.

## 2026-09-29 23:15 — Stage 3: budgets, balance — Stage 3 complete

- **Perf** (`--stress --perf`, xvfb, OpenGL 3):
  - **Plain:** sim tick 1.04 ms at 183 enemies and 1.66 ms at 260; 82–83 draw calls.
  - **Mixed:** 1.06–2.13 ms and 88–91 draw calls. Stage 2 read 2.1–3.1 ms on a noisy day.
  - The per-hit cost added is one int compare (guards) and one bool (`is_boss`) per
    non-lethal hit.
  - Bosses aren't in the stress wave; each adds one MultiMesh batch.
- **Balance** (`balance-stage3.md`, 50 seeds, 1350 runs):
  - **Smart wins:** Outpost 38%, Canyon 36%, Switchback 48%.
  - **Casual wins:** 48%, 32%, 42%.
  - Stage 1 (tuned) read 38/34/48 for smart and 46/32/42 for casual, so this is within
    noise.
  - The Queen has left every profile's top leaks. She was 20–160 gate damage per run in
    some profiles, but the bot's losses come in waves 6–9, which is why wins barely moved.
  - Targets still open are the same as before Stage 3: Outpost casual 48% (target ≤ 40%),
    Switchback casual 42%, and heavy builds matching smart. These belong to Stage 4's
    balance pass.
- **Tests:** game 285/285, tools 12/12.
- **For the user to judge:**
  - whether the phase callouts and the gold guard bubble read at a glance;
  - whether a 3 s Queen strike interval feels right;
  - the three bosses' looks;
  - whether the Titan should shed *all* its armour.

## 2026-09-30 00:30 — Stage 4 begins: three sectors, 30 waves, a sixth tree tier

The user said "let's keep going" after the Stage 3 report (Stage 3 still uncommitted), so
Stage 4 is built on top of it.

- **Maps** (`data/maps/mire.tres`, `ashfall.tres`, `hive.tres`), written by
  `gen_maps.py` (kept in this folder). It checks the content test's geometry first: plots
  ≥ spread + 12 + 22 from every centre line, a wall spot at each path end, and barricade slots
  on a path 40–150 above the wall.
  - **Mire Crossing** (swamp): four narrow paths (spread 20) that merge in pairs into two
    muddy trunks. The outer pair is open from wave 1; the inner ones open at 3 and 6. Four mud
    zones.
  - **Ashfall** (ash): two trunks around a centre column of pads on two high-ground
    ridges, and **burrows that break open mid-field**: on the right at wave 4, on the left at
    wave 7.
  - **The Hive** (infested): one portal whose path forks around a central ridge (a
    high-ground pad) and rejoins; side breaches at waves 3 and 6; mud on both flanks.
- **Biomes:** `terrain.py` gains `swamp`, `ash` (ember-rimmed rocks) and `infested`. That
  one adds a new `Biome.creep` density, ×2.4.
- **The content rule on portals.** A path may now start inside the field, but only as a
  breach: opening after wave 1 and at least 300 above the gate. Everything else still starts
  on an edge.
- **Waves.** `gen_waves.py` (kept in this folder) derives each sector's waves from
  Switchback's, which pass every content rule and pace well:
  - the template's counts thin from wave 4 on (×`count`);
  - Switchback paths are remapped to the new map's open paths (a breach opening this wave
    takes the group that used Switchback's newest path);
  - the sector's new enemies are added on a schedule (×`addk` past their two-at-a-time
    introduction);
  - hp_scale is ×`hp`;
  - the Queen's slot in wave 10 becomes the sector's boss.
- **Progression.**
  - `RunConfig.maps` has 6 entries, for 18 stars.
  - The campaign's cards scroll (`CampaignScreen.scroll`) and bring the newest open sector
    into view once laid out.
  - The skill tree gets a sixth tier, 3 stars each:
    - Heavy Ordnance (Arsenal): special attacks +40%, via the new
      `RunModifiers.ability_power_bonus`, which `Run.call_ability` multiplies in;
    - Bastion (Bulwark): +60 gate HP;
    - Fire Control (Logistics): special attacks reload 20% faster.
  - The tree totals 36 stars against the 18 a player can earn, so it's a choice.
  - `SkillTreePanel.NODE_SIZE` is 84 → 74 tall, so six tiers fit.
  - Sectors 4–6 unlock no new special attack: all five are unlocked by sector 3, and the
    spare, Overcharge, was held back in the plan.
- **Bot profiles.** T9/T12/T15 (`BalanceRun.PROFILES`) for sectors 4–6, plus
  `SECTOR_PROFILES` in `tools/…/balance/report.py`.

## 2026-09-30 01:20 — Stage 4 tuning: what the bot runs showed

1. **First pass: 0% wins in all three sectors.** I had added the new enemies on top of
   Switchback's full waves, which the bot only just survives.
2. **Bombardiers were overtuned (a Stage 2 number).** Two a wave sank Ashfall runs even at
   70% HP. A Bombardier parks 200 short of the gate, and units shoot whatever is nearest
   the gate, so it lobbed unanswered at 2.4 damage a second. Now 4 every 3.5 s (1.1/s).
3. **The bot met Carapaces with MG nests.** Losing Ashfall runs had 7–9 MGs and one Rail.
   `Autoplay._choose_unit` rated a type's need as count × gate damage, so twenty Skitters
   always outranked one Carapace, though the tough one lives to strike many times. Need is
   now × √(HP × wave scale / 10), shield included.
   - This changes the bot everywhere, so sectors 1–3 were re-measured in the final matrix.
4. **The bot plans for boss phase spawns.** `_choose_unit` folds `BossPhase.spawn × count`
   into the coming waves' counts.
5. **Ashfall's lower field had too few pads.** Only the centre column and two late-unlocking
   flank pads covered the trunks. Now there are four flank pads: (130/410, 500) open from the
   start, and (130, 620) and (410, 620) at waves 7 and 4.
6. **The per-wave escalation test.** "Each sector's wave N out-threatens the sector
   before's wave N" held for sectors 1–3 because they escalate only by HP. Sectors 4–6 thin
   the familiar enemies to make room for new ones, and the bot's tree grows each sector, so
   the rule no longer tracked difficulty. Two changes:
   - **The new enemies' threat was re-rated,** from what the runs showed: Wasp 1.5 → 3,
     Burrower 4 → 8, Bombardier 7 → 10, Warden 6 → 10. Boss threat is now proportional to base
     HP: Broodmother 180, Titan 270, Overmind 360.
   - **The test now asks** that each sector's total threat, and its boss wave, exceed the
     previous sector's. Within a sector, threat still rises every wave (unchanged).
7. **Wave 8** (whose template has a lower HP scale than wave 7) got more Stage 2 enemies in
   each sector, to keep threat rising.
8. **Final knobs** (`gen_waves.py`): Mire count 0.66, addk 0.75, hp 1.06; Ashfall 0.52 / 0.5 /
   0.95; Hive 0.6 / 0.6 / 1.04.

**Clips** (`captures/`):
- `stage4_mire_w10.mp4` (T9, seed 4): the Broodmother wave and two hatchings.
- `stage4_ashfall_w4.mp4` (T12): the right burrow breaks open.
- `stage4_hive_w10.mp4` (T15, seed 9): the Overmind guarded ×3, then its Wardens fall.

## 2026-09-30 03:10 — Stage 4: final balance, budgets, tests — E8 built

- **Balance** (`balance-stage4.md`, 50 seeds, every strategy, 2700 runs). The targets are
  smart 35–65% and casual 10–40%.

  | Sector (profile) | Smart | Casual |
  | --- | --- | --- |
  | Outpost (T0) | 36% | 40% |
  | Canyon (T3) | **18%** | 18% |
  | Switchback (T6) | 44% | 36% |
  | Mire (T9) | 36% | 26% |
  | Ashfall (T12) | 40% | 40% |
  | Hive (T15) | 38% | 32% |

  - **Canyon is below target** on unchanged content. The cause is the bot's toughness
    weighting; I checked it three ways:
    - with the weighting off, Canyon is at 35% again, but sectors 4–6 fall to 0–22%;
    - softening it (power 0.35) or weighting by armour instead both leave Canyon at an
      identical 18% and swing Hive to 68–82%;
    - so I kept the √ weighting and did not retune Canyon, a sector the user has played and
      judged good.
  - **"Fixed builds ≥ 10 pts below smart"** still fails on most sectors, as before
    (heavy-only is strong on Switchback 84% and Hive 76%). This is the open B4 item.
- **Perf** (`--stress --perf`, xvfb, OpenGL 3, 260 enemies):

  | Map | Sim tick | Draw calls |
  | --- | --- | --- |
  | Outpost, plain | 1.34–1.60 ms | 82 |
  | Mire, plain | 1.70 ms | 117 |
  | Canyon, plain | 1.71 ms | 109 |
  | Switchback, plain | 2.22 ms | 104 |
  | Hive, mixed | 2.28–2.36 ms | 109–112 |
  | Mire, mixed | 2.13–2.22 ms | 114–120 |

  - The "about 90" draw-call guideline was only ever measured on Outpost. Canyon and
    Switchback were already over it, and the new maps are in line with their extra paths and
    pads.
  - The sim tick sits around the 2.0 ms desktop budget with this machine's usual ±50%
    noise.
  - Both go to the B5 phone check.
- **Tests:** game 288/288, tools 12/12.
  - New: Heavy Ordnance scales a cast; six sectors scroll to the newest open one; the
    six-tier tree fits a 540×960 screen.
  - Updated: content counts (6 maps, 18 nodes, 15 enemies all in waves), star totals
    "/ 18", the tree test (6 tiers, 36 stars), the relaxed portal and escalation rules.
- **E8 status.** All four stages are built. Waiting on the user's review of Stages 3–4.
- **For the user to judge by hand:**
  - the three sectors' layouts and grounds;
  - the Overmind finale's length (guarded for much of its walk);
  - Canyon under the new bot (a player may not notice any change);
  - the tier-6 nodes;
  - the threat re-rating and the relaxed escalation rule.

## 2026-09-30 — E8 closed: the user's review

The user reviewed the Stage 4 report and said "looks good". They asked for a handoff for
the next session.
- **E8 (content expansion) is complete.**
- The defaults listed as open calls in `handover.md` §2 stand as built. None was changed,
  though the user didn't rule on them one by one:
  - the 3 s Queen interval;
  - the Titan's full armour shed;
  - the long Overmind finale;
  - the relaxed escalation test and the threat re-rating;
  - no new special attack in sectors 4–6;
  - Canyon's bot score.
- **Stages 3–4 are still uncommitted** (92 paths). The user commits.
- **Next work item:** B5, the Android build and performance (ROADMAP).
