# Roadmap

Work is grouped into **bundles**. Each bundle is sized to be taken from start to verified finish
in **one session by a strong model** (e.g. Fable 5.1), without the user in the loop mid-way.

_Last updated: 2026-09-27. Concept: "Hold the Gate" (see `README.md`). Current work: the
**escalating-difficulty track (E1–E5)** below. It runs ahead of B3/B4, and B4 is re-scoped by
it._

> **Design correction, 2026-09-26 (user).**
> - **Every unit is a fixed asset on a spot, the wall included.** There is no aimed squad.
> - **Crates are tapped.**
> - Done in `docs/2026-09-26-fixed-units-wall-spots/` (E1).
>
> **Escalating difficulty (user request, same day).** The map, the enemy combinations and the
> volume should grow more complex over time. Research and the user's answers are in
> `docs/2026-09-26-escalating-difficulty/research.md`:
> - A campaign of maps.
> - Enemies may hurt units.
> - Maps built from **paths**, not lanes.
> - Losing still needs a definition.
>
> | # | Step | Status |
> | --- | --- | --- |
> | E1 | Fixed units, wall spots, tap crates (squad removed) | ✅ 2026-09-26 |
> | E2 | Losing = the gate siege (the user chose option 2) + Spitters that jam units | ✅ 2026-09-26 (`docs/2026-09-26-gate-siege/`) · 👤 clips |
> | E3 | Counters and coin sinks: the damage chart + armour, sell (50%), masteries, the barricade, gate repair, wave preview + intel cards, escorts, waves from patterns, a counter-picking bot | ✅ 2026-09-26 (`docs/2026-09-26-counters-and-coin-sinks/`) · 👤 play it |
> | E4 | Maps from paths: polylines that bend and merge, portals opening mid-run, pads that unlock, terrain (mud, high ground), maps as levels, Canyon Pass | ✅ 2026-09-26 (`docs/2026-09-26-maps-from-paths/`) · 👤 play the Canyon |
> | E5a | New enemies (the Ravager destroys units, the Splitter, the Mender), destroyable units + repair, elites (Armoured, Swift, Regenerating) | ✅ 2026-09-27 (`docs/2026-09-26-new-enemies-and-destroyable-units/`) · 👤 play |
> | E5b | Sectors: a campaign of 3 maps (Switchback Ridge added) with stars, a **skill tree between maps** (the user's "a fallen unit explodes", "+10% loot", and 13 more nodes), the save/meta wiring (B3), the curve re-tuned against tree profiles | ✅ 2026-09-27 (`docs/2026-09-27-sectors-and-skill-tree/`) · 👤 play the campaign |
> | E6 | Visual style (fonts, palette, type scale as data; the user picked the hybrid direction) + contextual tips that stop time and teach each new thing (pulls parts of B6 and B8 forward) | ✅ 2026-09-27 (`docs/2026-09-27-style-and-tutorials/`) · 👤 play a fresh campaign |
> | E5c | The active ability (an artillery strike) and unit synergies (+ their tips) | ✅ 2026-09-27 (`docs/2026-09-27-artillery-and-synergies/`) · 👤 feel the strike, judge the links |
> | E7 | Art readability and resolution: 4× sprites, readable enemies, damage-type colours, bigger crates and barricade, biome grounds | ✅ 2026-09-27 (`docs/2026-09-27-art-readability/`) · 👤 play it |
> | E8 | Content expansion to ship 6 sectors, in 4 stages: (1) special attacks as data, picked at map start with clip tutorials; (2) Wasp, Warden, Burrower, Bombardier; (3) bosses as data (a 50-damage Queen, Broodmother, Siege Titan, Overmind); (4) Mire Crossing, Ashfall, The Hive + an 18-star tree | Stage 1 ✅ 2026-09-27 (napalm on the road 2026-09-28) · Stage 2 ✅ 2026-09-28 (`docs/2026-09-27-content-expansion/`) · 👤 judge the attacks and the four enemies · Stages 3–4 — |
> | — | Open from E3: make Skitters and Spitters demand their counters (the bot gets by with Snipers and Mortars) | 👤 tune by hand |
> | — | Open from E4/E5a: the sim tick is up to 1.7–1.95 ms in game under stress (it was about 0.65 at E2); measure on the phone (B5) before more per-enemy rules | B5 |

> **Pivot, 2026-09-25 (user request).** Work item `docs/2026-09-25-build-spots-loot-and-art/`,
> done outside the bundle order:
> - **Gates removed.** Troops and weapons now go on **build plots** at any time, bought with
>   coins from **loot crates** the squad breaks. Stronger units reload longer.
> - **A procedural art slice was pulled forward from B6.** The user wanted the game to look
>   stunning now.
> - **Now done:**
>   - The build UI (from B3: radial build menu, card picker, squad panel).
>   - A first-pass balance with a difficulty ramp (from B4: enemies get tougher and faster
>     per wave).
>   - One art direction ("frontier outpost vs alien swarm"; from B6).
> - **The bundles below are annotated with what's left.**

---

## What makes a good bundle

A bundle belongs together when:

1. **It checks itself.** Its "done when" can be proven by the model: tests pass, a headless run
   gives the expected numbers, a build exports. A bundle that can only be judged by taste
   ("does it feel good?") ends at a checkpoint rather than trying to decide it.
2. **Its gates sit at the edges.** Anything on the `CLAUDE.md` §5 ask-first list is approved
   *before* the bundle starts or handed over *after* it ends, never in the middle. Examples:
   downloads, SDKs, accounts, uploads, money.
3. **It shares one mental model.** Splitting it would force the next session to reload the same
   context, e.g. the rules layer and its tests.
4. **Its boundary is an interface.** The next bundle builds on a stable surface (a class API,
   a data format, a scene contract), not on half-finished internals.

## How to run a bundle

1. **Before starting:** clear the bundle's **approvals** (🔒) with the user.
2. **Open a work item** as `CLAUDE.md` §3 describes: `docs/YYYY-MM-DD-<bundle-slug>/` with
   `research.md` → `plan.md` → `implementation.md`. For a bundle already covered by an existing
   plan (B0–B5 use the prototype plan), `research.md` and `plan.md` just link to it and note
   any deviation.
3. **Start the session with a prompt like:**
   > Execute bundle **Bn** from `ROADMAP.md`. Follow `CLAUDE.md`. Work until every "done when"
   > item is proven or you hit a checkpoint; then close out per §3 and report.
4. **Finish at a checkpoint (👤):** the model hands over what the user must judge (a clip, a
   build, options), and the user decides before the next bundle.
5. **Tick the bundle off** in the table below and update "Current bundle".

**Legend:** 🔒 approval needed before starting · 👤 user checkpoint at the end ·
Size: **M** = a focused session, **L** = a long session, **XL** = the most a single session
should attempt.

---

## Overview

| # | Bundle | Phase | Size | Depends on | Status |
| --- | --- | --- | --- | --- | --- |
| B0 | Toolchain & skeleton | Prototype | M | — | ✅ 2026-09-24 |
| B1 | Core rules layer | Prototype | XL | B0 | ✅ 2026-09-24 |
| B2 | Playfield & gates (the hook) | Prototype | XL | B1 | ✅ 2026-09-25 · 👤 answered |
| — | Build spots, loot, reload, art slice (pivot) | Prototype | XL | B2 | ✅ 2026-09-25 · 👤 pending |
| E1 | Fixed units, wall spots, tap crates (squad removed) | Prototype | L | pivot | ✅ 2026-09-26 · 👤 clips |
| E2 | Gate siege loss + Spitter (jams units) | Prototype | L | E1 | ✅ 2026-09-26 · 👤 clips |
| E3 | Counters and coin sinks | Prototype | XL | E2 | ✅ 2026-09-26 · 👤 play it |
| E4 | Maps from paths + Canyon Pass | Prototype | XL | E3 | ✅ 2026-09-26 · 👤 play it |
| E5a | New enemies (Ravager, Splitter, Mender), destroyable units, elites | Prototype | XL | E4 | ✅ 2026-09-27 · 👤 play waves 5–10 |
| E5b | Sectors (campaign of maps) + save/meta wiring (B3) + skill tree | Prototype | XL | E5a | ✅ 2026-09-27 · 👤 play the campaign |
| E6 | Visual style + contextual tips (parts of B6/B8) | Prototype | L | E5b | ✅ 2026-09-27 · 👤 play a fresh campaign |
| E5c | Active ability (e.g. an artillery strike) + unit synergies | Prototype | L | E5a | ✅ 2026-09-27 · 👤 feel the strike |
| B3 | Run loop: meta, save (build/cards done in the pivot) | Prototype | M | pivot | ✅ 2026-09-27 in E5b |
| B4 | Balance bot, tuning & juice | Prototype | L | B3 | ✅ 2026-09-27 · 👤 play; judge Switchback + the Queen |
| E7 | Art readability & resolution | Prototype | L | B4 | ✅ 2026-09-27 · 👤 play it |
| E8 | Content expansion: 6 sectors, 4 enemies, bosses, special attacks (4 stages) | Prototype | XL | E7 | Stages 1–2 ✅ 2026-09-28 · Stages 3–4 — |
| B5 | Android build & performance | Prototype | M | B4 | — |
| **D1** | **Decision: continue, pivot or stop** | Gate | — | B5 | — |
| B6 | Art direction options | Vertical slice | L | D1 | — |
| B7 | Content pipeline & Python tools | Vertical slice | L | D1 | — |
| B8 | First 3 minutes (onboarding) | Vertical slice | L | B6, B7 | — |
| B9 | Steam page kit | Vertical slice | M | B6 | — |
| **D2** | **Decision: publish the Steam page** | Gate | — | B8, B9 | — |
| B10 | Content wave 1 | Production | XL | B7 | — |
| B11 | Audio pass | Production | L | B6 | — |
| B12 | Settings, localization, accessibility | Production | L | B8 | — |
| B13 | Platform services: Steam | Production | L | D2 | — |
| B14 | Demo build & Next Fest prep | Production | L | B10–B13 | — |
| B15 | Mobile F2P economy & monetization | Mobile | XL | D1 | — |
| B16 | Analytics & soft-launch instrumentation | Mobile | L | B15 | — |
| B17 | Mobile platform services & store kit | Mobile | L | B15 | — |
| **D3** | **Decision: Android soft launch** | Gate | — | B16, B17 | — |
| B18 | Live-ops framework | Live ops | L | D3 | — |
| B19 | iOS port | Mobile | M | D3 | — |

---

## Phase 1 — Prototype

Implements [`docs/2026-09-24-hold-the-gate-prototype/plan.md`](./docs/2026-09-24-hold-the-gate-prototype/plan.md).
Its 10 days are regrouped into bundles; day numbers are given for reference.

### B0 — Toolchain & skeleton · M · plan day 0

- **✅ Done 2026-09-24.** See `docs/2026-09-24-b0-toolchain-skeleton/`. The editor and GdUnit4 6.2.1
  are in place; export templates moved to B5.
- **Includes:** `game/project.godot` (portrait 540×960, `canvas_items` stretch), the folder tree
  from plan §3, `scripts/test.sh`, one trivial test, `.gitignore` check.
- **Done when:** `scripts/test.sh` exits 0 headless; the editor opens under WSLg.
- **Why one bundle:** it's all setup with no design, and every later bundle needs it.

### B1 — Core rules layer · XL · plan days 1, 3–8 (logic only)

- **✅ Done 2026-09-24.** See `docs/2026-09-24-b1-core-rules-layer/`. 85 tests; a full headless
  run takes ~1.4 s. Combat and the state machine live in `core/` (see there).

- **Includes:**
  - **All of `src/core/`:** RNG streams, squad stats, gate maths, wave schedule, economy, card
    pool, meta progress, save data with migrations, run state.
  - **All of `src/defs/`.**
  - **Starting content** as `.tres` files in `data/`.
  - **Full unit tests,** and the **determinism test** run against a headless simulation driver
    (no visuals).
  - **The `platform/` interface** plus the stub provider and registry.
- **Done when:** every test in plan §5 exists and passes. A seeded headless run of all 10 waves
  with a scripted policy ends in the same state hash twice.
- **Why one bundle:** this is the whole rulebook, pure and testable. It is the biggest single
  win for a strong model: one consistent mental model, verifiable without eyes, and every later
  bundle only draws and feeds it.

### B2 — Playfield & gates (the hook) · XL · plan days 2–5 (visuals and input)

- **✅ Done 2026-09-25.** See `docs/2026-09-24-b2-playfield-and-gates/`. Clips are in
  `captures/`. Enemies are batched per type (599 → 80 draw calls at budget load).

- **Includes:**
  - **Rendering over core:** since B1, combat rules live in `core/CombatSim`/`Run`. `sim/` only
    renders them: a thin run controller ticking `Run`, the bullet field drawn from its arrays
    into a MultiMesh, pooled enemy and gate nodes keyed by id and driven by its signals.
  - **Input:** the squad with drag input, and the tap-a-lane alternative behind a flag.
  - **Enemies:** all enemy types and the boss.
  - **Gates:** gate visuals with number popups, landing, and negative gates.
  - **Game states:** wall damage, winning and losing.
  - **Capture:** a capture script that records a clip.
- **Done when:** a full 10-wave run is playable. The integration test drives the real scenes
  headless; the frame time on desktop is recorded.
- **👤 Checkpoint:** the 15 s gate clip and the drag-vs-tap comparison. The user judges whether
  the hook reads.
- **Why one bundle:** the hook and the combat it lives in must be tuned together. The gate's
  feel depends on bullet density and enemy speed.

### B3 — Run loop: meta, save · M · plan days 6–8 (UI)

- **✅ Done 2026-09-27 inside E5b** (`docs/2026-09-27-sectors-and-skill-tree/`). The brick meta
  became the campaign's stars and skill tree (user's call). Save v5 is wired through the
  `Session` autoload, and the loop "run → tree → better run" is tested end to end
  (`campaign_flow_test`).

- **Already done by the pivot:** plots and 6 unit types in play, the build menu, the card
  picker, the squad upgrades panel, and the result screen.
- **Includes:** the meta screen (bricks → the 6 meta upgrades), save/load wired to the UI
  (`SaveData` v3 exists and is tested but unused), and the transitions between run, meta and
  next run.
- **Done when:** the loop "run → meta → better run" works end to end in a headless test and by
  hand; progress survives a restart.
- **👤 Checkpoint:** a short clip of two different runs.

### B4 — Balance bot, tuning & juice · L · plan day 9

- **✅ Done 2026-09-27.** See `docs/2026-09-27-b4-balance-and-juice/`.
  - `uv run balance` writes the report.
  - Smart-bot win rates are 38 / 38 / 46% across the three sectors, and the casual bot's
    are 48 / 34 / 42%.
  - Fixed "wrong" builds lose.
  - Big guns still dominate Switchback (an open design call).
  - Juice pass: press squash, star pop-in, count-ups, falling shell, upgrade pop.

> **2026-09-26:** the squad is gone (E1). Items 1, 4 and 6 below are moot, as is the
> "squad-first" strategy. Items 2, 3, 5 and 7 continue in E3 (enemy mixes and volume).

- **👤 User feedback from the B2 checkpoint (2026-09-25). These are the goals of this bundle:**
  1. **Gate speed:** use clip B's feel, ~110 (land ~8 s after spawn), instead of 45.
  2. **Enemies speed up over time** for urgency: across waves, and likely within a wave too.
  3. **Author tricky situations that force genuine mistakes and losses:** competing threats in
     different lanes while a valuable gate is up, negative gates blocking the lane you need,
     runner bursts, brutes behind gates. Not a stroll in the park.
  4. **Less squad fire:** too many shots, too fast. Rein in the fire-rate and shooter growth
     from gates (the multiplicative fire-rate stacking especially).
  5. **Target difficulty:** somewhat hard but not too hard, engaging. Make it measurable with
     the bot, e.g. a zero-meta first run loses mid-game, and meta upgrades make wins
     reachable.
  6. Still open: drag vs tap (ask once this build is playable).
  7. **Enemy roster built on a clear speed ↔ toughness trade-off** (user, 2026-09-25): fast but
     fragile types, and slow types with large health pools. Today there are only grunt (middle),
     runner (fast/fragile) and brute (slow/tanky). Make the trade-off readable at a glance, and
     use the mix to create the tricky situations in item 3. B4 tunes the existing types; new
     types come in B10.

- **Status after the pivot (2026-09-25):**
  - Items 2 (speed-up per wave: `WaveDef.speed_scale`) and 4 (squad fire reined in: gates
    gone; the squad starts at 4 × 2.5/s) have a first pass. Item 1 is moot (no gates).
  - First-pass numbers: the zero-meta bot clears 7–9 waves with 0 wins; a mid meta wins
    ~1 in 4.
  - Still open:
    - The real tuning.
    - The strategy comparison (`Autoplay` knobs: `build_order`, `chase_crates`,
      `squad_first`).
    - Authored tricky situations (item 3).
    - The report.
  - Juice exists now (hit flicker, shards, splats, explosions, coin flyers, shake). B4
    polishes it by eye with the user.
- **Known from B2 (pre-pivot, for the record):**
  - Wave 1 pays 12 gold, but the cheapest turret costs 15, so the first build phase is empty.
  - Gates take ~19 s from spawning to landing (speed 45); too slow for a one-GIF hook. Pending
    the user's call on clip A vs B.
  - Gates charge from −3 to +25 in ~6 s, so the red "rescue" phase barely registers.
- **Known from B1:** the starting numbers are far too easy. Autoplay wins all 10 waves at zero
  meta with ~20,000 shooters, and the wall barely gets touched. Gate values (especially
  multiplicative fire-rate stacking) and wave pressure need the first pass. `Autoplay`'s knobs
  are already there for the strategy comparison.

- **Includes:**
  - **The balance bot:** the headless bot with several strategies (gates-first, enemies-first,
    turret-heavy); 50 seeded runs each; a report.
  - **A tuning pass** on the `.tres` data.
  - **A juice pass:** hit flash, shake, particles, count-ups.
- **Done when:**
  - No single strategy dominates by more than a set margin.
  - The median run at zero meta ends around wave 6–8.
  - The report is saved to the work item.
- **👤 Checkpoint:** the report, plus a clip from after the juice pass.

### B5 — Android build & performance · M · plan day 10

- **🔒 Approvals:** Godot export templates (1.28 GB, into `.tools/`), JDK 17 and the Android
  command-line SDK. The user supplies the phone model
  and plugs it in (or sideloads the APK).
- **Includes:** `scripts/build_android.sh`, a debug APK, an on-device frame-time and memory
  capture at wave 10, a 30 s gameplay clip, and filled-in playtest notes.
- **Done when:** the budgets in plan §3 are measured and recorded (met or not).
- **From B2:**
  - Use `--stress --perf` on the device; it reproduces the budget load.
  - If the phone's display runs above 60 Hz, add physics interpolation for view positions.

### D1 — Decision gate (user)

The user scores the plan §7 criteria. The outcome is one of:

- **Continue:** go to Phase 2.
- **Pivot:** switch to the Thronefall-lean variant and re-plan B6+.
- **Stop:** return to the market research.

---

## Phase 2 — Vertical slice

### B6 — Art direction options · L

- **UI style chosen (E6, 2026-09-27).** Three UI directions (fonts, palette, shape) were
  compared in the game. The user picked "hybrid" (`data/styles/hybrid.tres`). Style is data,
  so later directions only need a new `.tres`.
- **Partly done early (2026-09-25 pivot).**
  - **Built:** one full direction, "frontier outpost vs alien swarm". It is procedural SVG
    from `tools/gf_tools/art`, covering every enemy, unit, crate, the field and the effects.
  - **Left for B6:**
    - The user's verdict on it.
    - 1–2 alternative directions to compare, if the user wants them.
    - The live switch.
    - Capsule mocks.
    - Deciding whether final art stays procedural, or goes to an artist or paid assets (🔒
      money).
- **👤 User direction (2026-09-25): the enemies should make the game visually stunning.**
  - Enemy design is a first-class part of the art direction, not an afterthought.
  - Each option should show the enemy archetypes (fast/fragile vs slow/tanky) with a distinct,
    readable silhouette, animation and death effect.

- **Includes:**
  - **Three distinct in-engine art directions:** palette, shapes, shaders, UI skin and one
    animated enemy each.
  - **A switch** that swaps between them live, for comparison.
  - **Reference boards** with sources.
  - **A capsule-image mock** per direction.
- **Done when:** all three render in the running game and in a side-by-side capture.
- **👤 Checkpoint:** the user picks the direction. That's taste, so the bundle ends there.
- **Note:** paid assets or commissioned art go on the ask-first list (money).

### B7 — Content pipeline & Python tools · L

- **Includes:**
  - **The `tools/` package** (`uv`), with:
    - A CSV ↔ `.tres` round-trip for balance tables.
    - Content validation (dangling references, impossible waves).
    - A balance simulator front end over the B4 bot.
  - **Tests** for all of it.
- **Done when:** a designer can edit a spreadsheet, run one command, and see the change
  validated in the game.

### B8 — First 3 minutes (onboarding) · L

- **Partly done early (E6, 2026-09-27).** The user chose time-stopped tip cards over
  "no text". The tip system and 18 tips exist (`docs/2026-09-27-style-and-tutorials/`).
  - **What's left here:** pacing the first 3 waves, the first meta unlock within the first
    session, and a title screen.
- **Includes:** teaching through play (the first wave teaches gates with no text), pacing of the
  first 3 waves, the first meta unlock arriving within the first session, and a title screen in
  the chosen art direction.
- **Done when:** a scripted "new player" run reaches the first meta unlock within 3–5 minutes.
- **👤 Checkpoint:** a first-session video for the user to watch.

### B9 — Steam page kit · M

- **Includes (drafts only; publishing is 🔒):**
  - Short and long descriptions.
  - Tags researched against comparable games.
  - A capsule brief in all Steam sizes.
  - A screenshot capture script.
  - A trailer shot list with the gate hook in the first 3 s.
  - A wishlist-goal plan.
- **Done when:** everything the Steam page needs exists in `docs/…/steam-page/`, ready to paste.

### D2 — Decision gate (user)

Pay the Steam Direct fee ($100) and publish the page, then start collecting wishlists.

---

## Phase 3 — Production (Steam-first)

### B10 — Content wave 1 · XL

- **User direction:** new enemy types extend the speed ↔ toughness trade-off (see B4 item 7),
  each designed to create a specific tricky situation, not just more HP.

- **Includes:**
  - New content: about 8 enemies, 8 turrets, 30 cards, 10 meta upgrades, 3 biomes/maps, and 2
    new bosses, all as data.
  - The bot's balance report after each addition.
- **Done when:** content validation passes, the balance bot shows no dominant strategy, and
  every new item appears in at least one test run.

### B11 — Audio pass · L

- **Includes:** an audio bus layout, SFX for every event (sourced from CC0/royalty-free with
  licenses logged), adaptive music layers per wave phase, and volume settings.
- **Note:** paid libraries or commissions are 🔒 (money).
- **👤 Checkpoint:** an audio clip for the user to review.

### B12 — Settings, localization, accessibility · L

- **Includes:**
  - A settings menu.
  - Localization: strings extracted to translation files, with EN, PT-BR and ES as the first
    languages.
  - Accessibility: colour-blind-safe gate and enemy colours, reduced screen shake, and
    text-size scaling.
  - Controls: rebindable desktop controls and controller support.
- **Done when:** a test fails on any missing translation key; the game is playable on a
  controller.

### B13 — Platform services: Steam · L

- **🔒 Approvals:** the Steamworks account and app ID, and the GodotSteam integration.
- **Includes:** a Steam provider behind the `platform/` interface (achievements, cloud save,
  rich presence). The stub stays the default in tests.
- **Done when:** achievements unlock in a Steam dev build; tests are green with the stub.

### B14 — Demo build & Next Fest prep · L

- **Includes:** a demo content lock (a flag-controlled subset), a demo-end screen with a
  wishlist call to action, crash logging to local files, a feedback link, and a checklist for
  the fest date.
- **Uploading is 🔒.**
- **Done when:** a demo build exports and can't reach locked content (tested).

---

## Phase 4 — Mobile

### B15 — Mobile F2P economy & monetization · XL

- **🔒 Approvals:** the ad network and IAP SDK choice, and privacy declarations. Both are
  sensitive surfaces.
- **Includes:**
  - **Economy design:** a design doc for what's free, what's rewarded-ad, and what's IAP,
    modelled on the market research (the upgrade tree is the business model).
  - **Remote-config-ready balance.**
  - **Providers:** real ads/IAP providers behind `platform/`.
  - **Privacy:** ATT/consent flows, and drafts of the App Store privacy labels and the Play
    Data safety form.
- **Done when:** purchase and ad flows are tested against the stub and verified in the stores'
  sandbox/test modes.

### B16 — Analytics & soft-launch instrumentation · L

- **Includes:**
  - An event schema.
  - An analytics provider behind `platform/`, declared in the same change (`CLAUDE.md` §4).
  - D1/D7/D30 retention, funnel and ARPDAU (average revenue per daily player) queries in
    `tools/`.
  - A dashboard.
- **Done when:** a local test session produces the full funnel in the dashboard.

### B17 — Mobile platform services & store kit · L

- **Includes:**
  - Play Games Services (achievements, cloud save) behind `platform/`.
  - Adaptive icons and splash screens.
  - Store listing drafts: text, screenshots and feature graphic, with ASO keyword research.
  - Release builds (AAB) with the signing config read from untracked files.
- **🔒** for keystores and console access.

### D3 — Decision gate (user)

Soft-launch on Android in one low-cost market. Measure D1/D7 against the benchmarks before any
ad spend (money, 🔒).

---

## Phase 5 — Launch & live ops

### B18 — Live-ops framework · L

- **Includes:**
  - Timed events and seasons as data.
  - Remote-config switches for them.
  - A content-drop checklist.
  - An update cadence doc.
  - Save migration tests for every schema change.

### B19 — iOS port · M

- **🔒 Needs:** a Mac with Xcode, an Apple developer account ($99/year), and signing.
- **Includes:**
  - The iOS export.
  - A Game Center provider.
  - StoreKit 2 wiring through the existing IAP interface.
  - Safe-area and notch layout.
  - TestFlight build notes.

---

## Not worth bundling

These don't suit a single unattended session. Do them with the user in the loop:

- **Feel tuning by eye:** jump arcs, screen shake strength, "does this hit feel good". The model
  proposes values and makes clips; the user decides.
- **Anything with account creation, payment, uploading or signing.**
- **Naming the game, final art approval, and pricing:** the user's call per `CLAUDE.md` §5.
- **Reacting to live-player data:** interpreting soft-launch numbers is a conversation, not a
  batch job.
