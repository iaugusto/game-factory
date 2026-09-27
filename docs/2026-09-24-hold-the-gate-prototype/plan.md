# Plan — "Hold the Gate" playable prototype

Built on [`research.md`](./research.md). **Timebox: 10 working days.** At the end we decide
whether to continue, pivot or stop, based on the success criteria in §7, not on sunk cost.

---

## 1. Scope

### In

- **One run** of 10 waves (~8–12 min):
  - 3 lanes, a wall at the bottom with the squad on it.
  - 3 enemy types plus a boss at wave 10.
  - 5 gate types.
  - 4 fixed turret slots with 4 turret types.
  - A pick-1-of-3 card after every wave.
- **Meta loop:** a run earns *bricks* to spend on 6 permanent base upgrades, saved to disk
  (versioned).
- **Juice**, enough for the clip test (§7): hit flash, number popups on gates, screen shake on
  wall damage, death particles, a count-up when a gate lands.
- **Builds:** a Linux desktop build, and an Android debug APK (day 10, pending the approval in
  §6).
- **Platform services:** the interface plus a stub provider only.
- **Tests:** unit tests for all core logic, one headless seeded-run integration test, and one
  determinism test.

### Out (deliberately)

- Ads, IAP, analytics and Steam SDKs. These are a security/privacy surface and on the ask-first
  list.
- iOS: needs a Mac.
- Final art and audio: coloured shapes plus free placeholder sounds.
- Localization, settings menus, tutorials.
- Landscape layout.

## 2. The loop, concretely

```
┌───────────── RUN (10 waves) ──────────────────────────────────────────┐
│ WAVE  ─ enemies walk down 3 lanes; gates drift down among them        │
│         squad auto-fires up the lane it stands in (drag to slide)     │
│         shooting a gate raises its value; it applies when it reaches  │
│         the wall. Enemies that reach the wall deal damage.            │
│ BUILD ─ spend gold (from kills) on turrets in 4 fixed slots or on     │
│         upgrades (3 levels each)                                      │
│ CARD  ─ pick 1 of 3 run upgrades                                      │
└──── wall HP 0 → run over ─── wave 10 boss down → win ─────────────────┘
        ▼
META ─ bricks earned (by waves cleared) → 6 permanent upgrades → next run
```

**The core decision:** every second of fire spent charging a gate is a second not spent on the
enemies in another lane. The gate pays off later, the enemies hurt now. If that trade isn't
interesting, the concept fails the fun test.

### Starting content (all data, tuned in `.tres` files)

| Kind | Items |
| --- | --- |
| Squad | Starts with 5 shooters, 1 damage, 4 shots/s each; max 60 shooters shown (extra ones add damage instead, to protect frame rate) |
| Enemies | **Grunt** (HP 3, slow); **Runner** (HP 1, fast); **Brute** (HP 25, very slow, 5 wall damage); **Boss** (HP 600, wave 10) |
| Gates | **+N shooters**; **×N shooters** (rare); **+fire rate %**; **+damage**; **rocket trooper** (adds a splash shooter). Every gate starts at a value (possibly negative) and rises by 1 step every K hits |
| Turrets | **MG** (fast, single target); **Cannon** (slow, splash); **Frost** (slows a lane); **Rail** (pierces the whole lane) |
| Cards | 12, e.g. "gates start +2", "runners drop double gold", "wall regenerates 1/s", "crits" |
| Meta | Starting shooters, wall HP, gold gain, turret discount, gate step size, 5th turret slot |

Numbers are starting guesses. Tuning them is day 9's job.

## 3. Architecture

Godot **4.7.2**, statically typed GDScript. The rule that makes everything testable: **the
`core/` layer is plain `RefCounted` classes with no nodes and no scene tree**. Nodes only draw
the state and forward input.

```
game/                              Godot project root (project.godot)
  project.godot                    portrait 540×960 base resolution, stretch mode canvas_items
  src/
    core/                          pure logic — unit tested, no Node dependencies
      rng_streams.gd               named seeded RNG streams (spawn, gates, cards)
      gate_math.gd                 gate value progression and application to SquadStats
      squad_stats.gd               shooters, damage, fire rate, visible-cap rule
      wave_schedule.gd             WaveDef → timed spawn events (enemies + gates)
      economy.gd                   gold income and costs, turret upgrade prices
      card_pool.gd                 weighted 1-of-3 draw without duplicates
      meta_progress.gd             bricks, meta upgrades, their effects on a new run
      save_data.gd                 versioned JSON save to user://, with a migration chain
      run_state.gd                 the whole run as data: wave, wall HP, gold, squad, turrets
    defs/                          typed Resource classes the data files instantiate
      enemy_def.gd  gate_def.gd  turret_def.gd  wave_def.gd  card_def.gd  meta_upgrade_def.gd
    sim/                           runtime managers (nodes), thin over core/
      run_controller.gd            state machine: WAVE → BUILD → CARD → … → WIN/LOSE
      lane_field.gd                per-lane enemy lists sorted by distance to the wall
      bullet_field.gd              bullets as packed arrays + one MultiMeshInstance2D
      enemy_pool.gd                pooled enemy nodes, never freed mid-run
      gate_field.gd                gates in lanes, hit counting, landing
      turret_slot.gd               a slot on the wall, fires via bullet_field
    platform/
      platform_services.gd         interface: ads, purchases, achievements, analytics
      stub_services.gd             logs calls, grants rewards instantly — the only provider now
      services_registry.gd         autoload; picks the provider from config
    ui/                            hud, build_panel, card_picker, meta_screen, popups
  data/                            .tres content: enemies/ gates/ turrets/ waves/ cards/ meta/
  scenes/                          main.tscn, run.tscn, meta.tscn
  tests/
    core/                          one suite per core/ file
    integration/                   seeded headless run; determinism check
  addons/gdUnit4/                  vendored test framework (or GUT, see §6)
scripts/
  test.sh                          runs the whole test suite headless; nonzero exit on failure
  build_desktop.sh / build_android.sh
```

**Frame-rate budget** (checked on day 10):

- **Load at wave 10:** ≤250 enemies, ≤600 bullets, 60 visible shooters.
- **Desktop:** 60 fps with plenty of headroom.
- **Android:** 60 fps on the test phone. The floor is 50 fps on the heaviest wave.
- **APK size:** ≤60 MB.

## 4. Milestones

| Day | Deliverable | Done when |
| --- | --- | --- |
| 0 | **Setup** (needs approval, §6): Godot 4.7.2 + export templates, test framework, empty project, `scripts/test.sh` | The editor opens under WSLg; `scripts/test.sh` runs one passing test headless |
| 1 | `core/` foundations (RNG streams, squad stats, run state, defs) and their tests | Tests pass |
| 2 | The playfield: lanes, the wall, the squad on it with drag input, auto-fire, `bullet_field`, grunts walking down and dying | Playable: slide and shoot grunts |
| 3–4 | **Gates** (the hook): spawn, charge by hits, number popups, landing and applying, negative gates | A 15 s capture of a gate flipping from −2 to +4 and the squad growing |
| 5 | Wave schedule from data; runner, brute and boss; wall damage and lose/win | A full 10-wave run is possible |
| 6 | Build phase: 4 slots, 4 turret types, gold, upgrades | Turrets change the outcome of a run |
| 7 | Card picks; the 12 cards | Two runs play noticeably differently |
| 8 | Meta screen, bricks, 6 upgrades, save/load with a version field | Progress survives a restart; the migration test passes |
| 9 | Juice pass; **headless balance bot** (a scripted policy plays 50 seeded runs and prints the wave reached); first tuning | The bot's median run ends around wave 6–8 at zero meta (a first run should lose) |
| 10 | Android debug APK, performance capture, a 30 s gameplay clip, playtest notes | §7 criteria assessed in `implementation.md` |

The A/B test between drag input and tap-a-lane input happens on day 2 or 3, behind a flag.

## 5. Testing strategy

- **Unit tests (per `core/` file):**
  - Gate value steps and caps; negative → positive crossover.
  - Multiplier application order (additive before multiplicative).
  - The visible-shooter cap converting extra shooters into damage.
  - Economy prices.
  - Card draws with no duplicates, respecting weights.
  - Meta effects applied to a fresh run.
  - Save round trip, and a v1 save migrating to v2.
- **Integration test:** run the full simulation headless for one wave with a fixed seed and
  the stub provider; assert wave cleared, wall HP and gold.
- **Determinism test:** the same seed and the same scripted inputs give the same end-state hash,
  twice.
- **Manual:** each milestone ends with a short clip or screenshot for the user, since tests don't
  prove feel (`CLAUDE.md` §3).
- `scripts/test.sh` is the one command; it must pass before any milestone is called done.

## 6. Needs your approval before day 0

These fall under `CLAUDE.md` §5 (system configuration / network):

1. **Download Godot 4.7.2** (Linux x86_64) **and its export templates** into a repo-local,
   git-ignored `.tools/godot/`. Nothing is installed system-wide. _(Correction, B0: the editor is
   78 MB, but the templates are 1.28 GB, so they were deferred to B5.)_
2. **Vendor the test framework** into `game/addons/`. GdUnit4 if its current release supports
   4.7; otherwise GUT. I'll report which.
3. **Day 10 only:** install JDK 17 and the Android command-line SDK (system-level or under
   `~/`). This can wait; I'll ask again then.

## 7. Success and kill criteria

Recorded honestly in `implementation.md` on day 10.

| Question | Pass | Fail → action |
| --- | --- | --- |
| Does the hook read? | Most of 3–5 people who watch the 15 s gate clip without explanation can say what happened and want to try it | Rework how gates look and behave before anything else; if still unreadable, the gate layer isn't the hook |
| Is it fun? | You play 3+ runs voluntarily; playtesters ask for "one more" | If the gates feel like noise next to the turrets: pivot to a Thronefall-lean version (the research's runner-up). If nothing is fun: stop and revisit the research |
| Is it feasible? | Budgets in §3 met on desktop and the test phone | Profile, then fall back to a lower enemy cap or simpler rendering |
| Is the tech sound? | `scripts/test.sh` green; the determinism test passes | Fix before moving on |

**If it passes, the next work item is the vertical slice plus a Steam page:** final art
direction, the first 3 minutes polished, and the store page up to start collecting wishlists.

## 8. Risks

- **The gate trade-off may be trivially solved** (e.g. "always shoot gates"). The balance bot on
  day 9 exists to catch this.
- **WSLg performance** may make the editor sluggish. Fallback: keep the repo in WSL and run the
  editor on Windows against a synced copy. That needs a decision, so I'd ask.
- **GdUnit4 support for 4.7 is unconfirmed.** Mitigated by the GUT fallback.
- **Scope creep:** anything not in §1 goes into a list in `implementation.md` for after the
  decision, not into the prototype.

## 9. Doc updates at closeout

- `docs/detailed-project-overview.md`: the `game/` tree, systems and dependency map, flipped to
  `existing`.
- `README.md`: status, quick start (run, test, build).
- `CLAUDE.md` §4 engine line and §6 quick reference: the engine is now decided, plus the real
  commands.
