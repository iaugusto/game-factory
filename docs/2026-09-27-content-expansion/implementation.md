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
