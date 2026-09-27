# CLAUDE.md

Working agreement for AI assistants (Claude Code and other LLMs) contributing to this
repository. Read this **before** touching anything. Follow it unless the user overrides.

## 1. What this project is

A **game factory** — the home of a commercial 2D game built to ship on **Google Play**, the
**Apple App Store** and, where it fits, **Steam**. It owns the whole lifecycle: market research
and concept selection → prototype → vertical slice → production → store listings and builds →
launch → live operations (updates, balancing, monetization tuning). As of 2026-09-26 the project
is in the **prototype** phase of "Hold the Gate" (Godot 4.7.2): a lane defense where every unit
is a fixed asset on a build spot (the wall included) and loot crates are tapped for coins. See
[`README.md`](./README.md) for status and [`docs/detailed-project-overview.md`](./docs/detailed-project-overview.md) for the canonical map
of files, systems, rationale, and dependencies.

**Design north star:** generic, modular, easy to adapt and evolve. Content (levels, enemies,
weapons, upgrades, balance numbers, localized text) is *data*, not code. Platform services (ads,
in-app purchases, achievements, cloud saves, analytics) sit behind small interfaces with a
**stub provider**, so the game runs, tests and ships to a store that lacks a service without
touching gameplay code. Adding a level, an enemy, a platform or a monetization provider must not
touch unrelated systems.

## 2. Where to fetch context (read in this order)

1. **`docs/detailed-project-overview.md`** — start here. It is the index of every file, system
   and function with its rationale and dependencies. Load the sections relevant to your task
   before reading code.
2. **`README.md`** — high-level purpose, status, layout, and how to build and run.
3. **The relevant `docs/YYYY-MM-DD-*/` folder** — if your task continues or relates to a prior
   work item, read its `research.md`, `plan.md`, and `implementation.md`.
4. **The code itself** in the game project and `tools/`, and prototypes in `prototypes/`.
5. **Game data** (levels, balance tables, content definitions) when you need to understand real
   content shape.

If you change the codebase structure, **update `docs/detailed-project-overview.md` in the same
change.** A stale overview is a bug.

## 3. Ways of working — the per-project flow

Whenever we start a work item (feature, fix, experiment, refactor, balancing pass, store
submission), create a folder:

```
docs/YYYY-MM-DD-project-name/
```

Use today's date and a short kebab-case name (e.g. `docs/2026-09-24-market-research`). Inside,
produce three documents **in order** — do not skip ahead:

1. **`research.md`** — first assess the work item and research the topic thoroughly. Capture
   the problem, constraints, prior art (how shipped games solve it), options considered,
   trade-offs, platform/store-policy notes, and open questions. Cite sources.
2. **`plan.md`** — leverage the research to structure a concrete plan: scope, chosen approach
   and why, file-level changes, interfaces, testing strategy, performance budget impact, risks,
   and rollout. Keep it reviewable before implementation begins.
3. **`implementation.md`** — a **running, timestamped log** of every modification made during
   implementation. Append as you go (`## YYYY-MM-DD HH:MM — what & why`). This is the audit
   trail, not a summary written at the end.

Research and plan should generally be reviewed with the user before large implementation. Small,
obvious fixes may collapse these into a lightweight single note, but still create the folder and
log what changed.

### Definition of done — project closeout

A work item is not finished when the code runs. Before closing it out, always:

1. **Test everything.** Run the unit and integration tests locally and make them pass. Where
   the change adds testable behavior and no test covers it yet, add one — unit tests for pure
   logic (damage/upgrade math, spawn schedules, save-data migration, economy formulas) and
   integration tests for system-to-system flow (using the stub platform providers so no real
   ad, purchase or store service is hit). If a change genuinely has no testable surface, say so
   explicitly in `implementation.md` rather than skipping silently.
2. **Exercise the real change** — run the game (the `verify`/`run` skills, a headless run, or a
   desktop build) and reach the changed behavior. For feel-sensitive changes (controls, camera,
   juice), capture a short clip or screenshots for the user; tests do not prove game feel.
3. **Check the budgets** when the change touches runtime: frame time on the target low-end
   device profile, memory, build size, and load time. Record the before/after numbers.
4. **Update the reference docs** so they reflect reality:
   - `docs/detailed-project-overview.md` — add/adjust file and system entries, flip `planned` →
     `existing`, update the dependency map and change log.
   - `README.md` — update anything now stale (layout, commands, status, capabilities).
   - Mark the work item's `implementation.md` as complete with a final summary.
5. **Report honestly.** State what was tested and the result; if tests failed or a step was
   skipped, say so plainly.

Keeping the reference files current is part of the work item, not optional follow-up — a stale
`README.md` or overview is treated as a bug in that project.

## 4. Engineering standards

- **Engine / language:** **Godot 4.7.x**, with **statically typed GDScript**. The pinned binary
  is `.tools/godot/`, and `tests/core/toolchain_test.gd` fails on a different minor version.
  Upgrading the engine is its own work item. One codebase must build for Android, iOS and
  desktop (Steam).
- **Game code layout:** `game/src/core/` is plain `RefCounted` logic with no nodes (unit
  tested); it holds **all** rules, including the per-tick combat and the run state machine, so
  a run plays headless. `defs/` are `Resource` classes; `sim/` and `ui/` are thin nodes that tick
  `Run`, render its state and forward input, and must not hold rules;
  `platform/` holds the service interfaces and stubs. Content goes in `game/data/` as `.tres`
  files. Track `*.uid` files. Art in `game/art/` is SVG **generated** by `tools/` (`uv run
  gen-art`): change the generator, not the files (a tools test fails on hand edits).
- **Tests:** GdUnit4 (vendored in `game/addons/gdUnit4/`); suites are `game/tests/**/*_test.gd`.
- **Tooling scripts:** anything outside the engine (balancing simulators, asset pipelines, store
  metadata, analytics analysis, market research crawls) is **Python managed with `uv`** (`uv
  sync`, `uv run …`, `uv add …`) in `tools/`, as an importable package. Do not use bare
  `pip`/global installs. Scripts import from the package; they don't reimplement it.
- **Modularity:** gameplay systems stay decoupled (signals/events over direct references).
  Platform services — ads, IAP, achievements, leaderboards, cloud save, analytics, haptics — are
  each one interface plus per-platform providers and a stub, selected by a registry/config, never
  by `if platform ==` branches spread through gameplay code.
- **Data-driven content:** balance numbers, enemy/weapon/upgrade definitions, spawn waves,
  prices and reward tables live in data files (resources/JSON/CSV), never in source constants, so
  they can be tuned — and remotely configured after launch — without a code change.
- **Config over hard-coding:** platform IDs, ad unit IDs, product SKUs, feature flags and build
  settings belong in configuration (and `.env`/untracked files for secrets).
- **Secrets:** API keys, signing keystores, provisioning profiles, App Store Connect / Play
  Console / Steamworks credentials via environment or untracked files. Never commit them or
  print them in logs. `*.example` files record the *shape*.
- **Data hygiene:** source art/audio that is authored here is tracked (large binaries through Git
  LFS once they appear). Builds, exports, imported-asset caches and generated artifacts are
  git-ignored. Builds must be reproducible from source + config.
- **Performance:** mobile first. Keep a stated budget (target FPS, memory, build size) for a
  named low-end Android device profile, and treat a regression past it as a bug.
- **Typing & docs:** type everything the language allows (static typing in GDScript/C#, type
  hints in Python); write docstrings that state rationale, inputs, outputs, and side effects.
  Match the style of surrounding code.
- **Testing:** add tests for pure logic. Mock platform services — never hit real ad networks,
  purchases or store APIs in tests. Gameplay simulations used for balancing must run headless.
- **Determinism:** gameplay randomness goes through seeded RNG streams, so a run (and a bug) is
  reproducible from its seed and a balancing simulation gives stable numbers.
- **Player data & privacy:** save data is versioned and migrated, never silently reset. Anything
  that collects player data (analytics, ads SDKs, attribution) must be declared (App Store
  privacy labels, Play Data safety, consent/ATT prompts) in the same change that adds it.

## 5. Guardrails

**Run the work; don't ask to run it.** Everything inside this repository is yours to do without
asking: read and edit any file under the repo root, run tests, run the game, make local debug
builds, run balancing simulations, install tooling extras via `uv`, delete and regenerate
anything that is git-ignored build output. Local work costs time, not money, so it needs no
confirmation. Stopping to ask before a normal step is the failure mode, not the safe choice; a
one-line "running X now" in the reply is enough.

Ask first — every time, no matter how convenient it would be — only for these:

- **Committing, pushing, or anything that leaves this machine** (`git commit`, `git push`,
  remotes, PRs, releases, uploads to TestFlight / Play Console / Steamworks, store listing edits,
  publishing anything). If asked to commit, branch off `main` first.
- **Writing outside the repository root** — the one exception is your own scratchpad under
  `/tmp/claude-*`, which is free.
- **System configuration** — package managers outside `uv`, installing engines/SDKs/export
  templates system-wide, `sudo`, services, shell profiles, anything under `/etc` or `~/.config`.
- **Sensitive components** — `.env` and secrets, signing keys and certificates, store and
  developer-account credentials, the game's published identity (bundle ID, package name, store
  name), and anything that would alter or introduce a security- or privacy-relevant surface
  (ad/analytics/attribution SDKs, network code, purchase validation).
- **Money** — paid third-party APIs in bulk, paid assets, ad spend / user-acquisition tests,
  developer-program fees, publisher or platform agreements. Estimate cost and scope first.

Also:

- Prefer the dedicated file/search tools over shell `cat`/`sed`/`echo`.
- Keep changes scoped to the work item; surface unrelated issues rather than silently fixing
  them.
- When something is ambiguous and the answer changes what you build, ask. Otherwise pick the
  sensible default, state it, and proceed. Creative taste (art direction, game feel, level
  design, names) is the user's call — but *show* them the result (a playable build, a clip, a
  mock-up) rather than asking in advance.

The per-command permission rules that implement this live in `.claude/settings.local.json`
(untracked, machine-local). This section is the intent; that file is the mechanism.

## 6. Quick reference

| I want to… | Go to |
| --- | --- |
| Understand the whole codebase | `docs/detailed-project-overview.md` |
| Understand purpose, status & layout | `README.md` |
| See what's next / pick up a bundle | `ROADMAP.md` |
| Start a new work item | Create `docs/YYYY-MM-DD-name/` → `research.md` → `plan.md` → `implementation.md` |
| See why this game was chosen | `docs/2026-09-24-market-research/` |
| Run the game | `.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path game` (add `-- --map=canyon` for map 2) |
| Open the editor | `… --path game --editor` (don't smoke-test with `--quit`: it crashes on teardown; use `--quit-after N`) |
| Run tests | `scripts/test.sh` (game); `cd tools && uv run python -m unittest discover -s tests` (tools) |
| Regenerate the art | `cd tools && uv run gen-art` → `game/art/*.svg` |
| Record a clip for the user | `scripts/capture_clip.sh NAME SECONDS [--seed=N --autoplay --skip=S …]` → `captures/` |
| Measure frame time | `… --path game -- --autoplay --stress --perf` |
