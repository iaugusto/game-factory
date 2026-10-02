# game-factory

A commercial **2D game** built to ship on **Google Play**, the **Apple App Store** and, where it
fits, **Steam** — and the tooling, research and process around it.

It is built to be **generic, modular, and easy to evolve**: game content (levels, enemies,
upgrades, balance, prices) is data, and platform services (ads, purchases, achievements, cloud
save, analytics) sit behind small interfaces with stub providers, so one codebase serves every
store.

---

## Status

> **Current as of 2026-10-01: prototype in progress, and playable on Android.** B5 built a
> debug APK (37 MB, arm64) that runs on a Galaxy S24 at a steady 60 fps with the
> Compatibility renderer, using about 310 MB of memory
> ([`docs/2026-10-01-b5-android-build/`](./docs/2026-10-01-b5-android-build/)).
> **E9 (same day): the tall-screen layout.** The game is now designed for 540×1170 (19.5:9):
> - every map is 120 units taller (a longer approach), with HP re-tuned per sector;
> - Start Wave, Repair and the special attack sit in a bottom thumb strip;
> - 16:9 screens get extra width
> ([`docs/2026-10-01-e9-tall-screen-layout/`](./docs/2026-10-01-e9-tall-screen-layout/)).
>
> Next: D1 (continue, pivot or stop), after the user plays on the phone.
>
> **2026-09-30:** the content
> expansion (E8) is built: special attacks, four new enemies, bosses as data, and **six
> sectors** (Mire Crossing, Ashfall and The Hive join the first three, each with its own boss),
> an 18-star campaign and a sixth skill-tree tier. The user reviewed it on 2026-09-30.
>
> - **The concept:** "Hold the Gate" (working title). A fixed outpost holds its gate against an
>   alien swarm coming down paths that bend, merge, and break open mid-run.
>   - Every troop and weapon is a **fixed asset on a build spot**, the wall's own spots
>     included. Nothing you own moves.
>   - You **tap loot crates** to break them for **coins**.
>   - Enemies that reach the gate **stop and pound on it** until killed. **When the gate
>     breaks, the run is lost.**
>   - Spitters jam your units from range. **Ravagers destroy units** beside their path (repair
>     them for coins). Splitters burst into Skitters, and Menders heal the swarm. Late waves
>     bring tinted, starred **elites**. Coming with sectors 4–6: **Wasps** fly over the
>     barricade (Mortars can't hit them), **Wardens** shield the pack, **Burrowers** tunnel
>     under your fire, and **Bombardiers** lob acid at the gate from range.
>   - **Know your weapon:**
>     - Every enemy is weak to one damage type and may resist another. Armour blunts light
>       hits.
>     - The build phase previews the next wave, and a tip introduces each new enemy.
>     - Selling refunds 50%, so replacing a unit costs.
>     - Coins also buy masteries for maxed units, one barricade in front of the wall (a kill
>       zone), and gate repairs.
>   - Coins put units on spots and upgrade them, at any time, including mid-wave. The harder a
>     unit hits, the longer it reloads.
>   - A card after each wave.
>   - **Special attacks:** pick one when a map starts: Artillery Strike, Cryo Bomb (freezes
>     a blast solid), Napalm Line (a burning stretch of road), Minefield (mines on a path) or Repair
>     Drones (gate and units, no aim). Strike and Cryo are free; each of the first three
>     sectors unlocks one more. During waves its button arms it (then tap the field); it
>     reloads in 30–45 s. The first time you take one, a tutorial card shows it in a looping
>     clip.
>   - **Unit links:** units built near each other boost each other. Each pair of unit types
>     has its own effect (e.g. Mortar + Rail Cannon = Siege Battery, +15% damage each),
>     shown as lines and on the unit's card.
>   - **A campaign of three sectors.** Each is worth up to 3 stars: win it, and keep the gate
>     above 50% and 90%. Stars buy nodes of a permanent **skill tree** (3 branches × 5, with a
>     free reset), such as Last Stand (a fallen unit explodes) and Scavengers (+10% loot).
>     Progress is saved.
>   - **Tips teach as you go.** The first time something new happens (a new enemy, the first
>     crate, the siege, the card pick, …), time stops. A spotlight and 1–3 short cards
>     explain it. Each tip shows once; the campaign's ⚙ turns tips off or replays them.
> - **Art:** sharp on phones and tablets (4× sprites with mipmaps). Each unit is coloured by
>   its damage type, and each enemy has its own hue. Barricade slots show the barricade's
>   shape. Each sector has its own biome (desert, red-rock canyon, tundra), and the swarm's
>   creep stains the lane edges. See [`docs/2026-09-27-art-readability/`](./docs/2026-09-27-art-readability/).
> - **Look:** one data-driven UI style (`data/styles/hybrid.tres`): Lilita One + Nunito,
>   rounded chunky buttons, navy panels with amber actions. The user picked it from three
>   directions (E6, [`docs/2026-09-27-style-and-tutorials/`](./docs/2026-09-27-style-and-tutorials/)).
> - **The pivots:**
>   - Gates were dropped for build spots and crates, in
>     [`docs/2026-09-25-build-spots-loot-and-art/`](./docs/2026-09-25-build-spots-loot-and-art/).
>   - The aimed squad was removed, in
>     [`docs/2026-09-26-fixed-units-wall-spots/`](./docs/2026-09-26-fixed-units-wall-spots/).
> - **Sectors (maps):**
>   1. **Frontier Outpost:** 3 straight paths.
>   2. **Canyon Pass:** two entrances merge into a muddy trunk; flank breaches open at waves 4
>      and 7; pads unlock as they do.
>   3. **Switchback Ridge:** one path zig-zags across the field twice; a fork opens down the
>      left flank at wave 3, and a tunnel breaks open near the gate at wave 6.
>
>   The game opens on the campaign screen. For a direct run, pass `--map=ID`.
> - **Next:** escalating difficulty.
>   - **Done:** the gate siege (E2), counters and coin sinks (E3), maps from paths (E4), new
>     enemies, destroyable units and elites (E5a), sectors with the skill tree and saves
>     (E5b, [`docs/2026-09-27-sectors-and-skill-tree/`](./docs/2026-09-27-sectors-and-skill-tree/)),
>     the visual style with contextual tips (E6), the artillery strike with unit links (E5c),
>     and the balance bot, tuning and juice pass (B4,
>     [`docs/2026-09-27-b4-balance-and-juice/`](./docs/2026-09-27-b4-balance-and-juice/)).
>   - **Now:** the content expansion to 6 sectors
>     ([`docs/2026-09-27-content-expansion/`](./docs/2026-09-27-content-expansion/)). All four
>     stages are built (special attacks, 4 new enemies, bosses, sectors 4–6).
>   - **Then:** the Android build (B5, done 2026-10-01), then the tall-screen layout.
>
>   See
>   [`docs/2026-09-26-escalating-difficulty/`](./docs/2026-09-26-escalating-difficulty/).
> - **Chosen in**
>   [`docs/2026-09-24-market-research/`](./docs/2026-09-24-market-research/). The prototype plan
>   is [`docs/2026-09-24-hold-the-gate-prototype/plan.md`](./docs/2026-09-24-hold-the-gate-prototype/plan.md).
> - **Engine:** Godot 4.7.2.
> - **Art:** procedural SVG generated by `tools/`.

## Lifecycle

```
market research ─▶ concept ─▶ prototype ─▶ vertical slice ─▶ production ─▶ launch ─▶ live ops
 (docs/…research)  (pick one)  (find the fun, (one polished     (content,     (store      (updates,
                               test the hook) level/loop)       platforms)    listings)   balance, $)
```

Each step is one or more work items under `docs/YYYY-MM-DD-*/` (research → plan →
implementation log). See [`CLAUDE.md`](./CLAUDE.md) §3.

## Layout

| Path | Purpose |
| --- | --- |
| `CLAUDE.md` | Working agreement for AI assistants: context order, work-item flow, standards, guardrails. |
| `ROADMAP.md` | What's next: work grouped into single-session bundles plus user decision gates. |
| `docs/detailed-project-overview.md` | Canonical index of every file and system, with rationale and dependencies. |
| `docs/YYYY-MM-DD-*/` | One folder per work item: `research.md` → `plan.md` → `implementation.md`. |
| `.claude/` | Claude Code skills, agents and (untracked) local permissions. |
| `game/` | Godot 4.7.2 project (designed for 540×1170 portrait): `src/`, `data/`, `scenes/`, `tests/`, `clips/` (generated tutorial clips, `.ogv`), vendored `addons/gdUnit4/`. |
| `scripts/` | `test.sh` (headless game tests), `capture_clip.sh` (record a clip), `android_env.sh` (sourced: the repo-local Android toolchain), `build_android.sh` (debug APK, install), `android_perf.sh` (a measured run on the phone). |
| `.tools/` | Repo-local toolchain (git-ignored; see Quick start): the Godot binary; for Android, `godot-export/` (self-contained, with the templates), `jdk/`, `android-sdk/`, `keystores/debug.keystore`, `android-home/` (adb and SDK state, kept out of `$HOME`). |
| `tools/` | Python (`uv`) tooling, `gf-tools`: the procedural art generator (`uv run gen-art`; it paints each map's ground from `game/data/maps`), the balance report (`uv run balance`) and the tutorial clips (`uv run make-clips`). Content and store tools come later. |
| `prototypes/` | _planned — throwaway experiments; never imported by the game._ |

## Quick start

The toolchain is repo-local: the Godot 4.7.2 Linux editor lives in `.tools/godot/` (git-ignored). On a
fresh checkout, download `Godot_v4.7.2-stable_linux.x86_64.zip` from the
[official releases](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable), verify it
against `SHA512-SUMS.txt`, and unzip it there. Or point `$GODOT_BIN` at any 4.7.x binary.

```bash
scripts/test.sh                                                          # all game tests, headless
(cd tools && uv run python -m unittest discover -s tests)                # tool tests
(cd tools && uv run gen-art)                                             # regenerate game/art/*.svg
(cd tools && uv run balance --seeds 50 --out report.md)                  # bot balance report (~5 min)
(cd tools && uv run make-clips)                                          # re-record game/clips/*.ogv (xvfb-run + $FFMPEG_BIN)
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path game                # the campaign (tap a pad to build; tap crates for coins)
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path game -- --autoplay --seed=3   # watch the bot
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path game -- --map=switchback --tree=all  # a sector directly, full tree
scripts/capture_clip.sh midgame 20 --seed=5 --autoplay --skip-to-wave=5  # record captures/midgame.mp4
scripts/capture_clip.sh tips 60 --seed=3 --autoplay --tips             # the bot reads the first-run tips
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path game --editor       # open the editor (WSLg)
```

**Android** (the setup steps are in `docs/2026-10-01-b5-android-build/plan.md` § Setup).
Pair the phone once over Wireless debugging:

```bash
source scripts/android_env.sh
adb pair IP:PAIR_PORT CODE
adb connect IP:PORT
echo IP:PORT > .tools/android-home/last_device
```

Then:

```bash
scripts/build_android.sh --install --launch                              # build, install, start
scripts/android_perf.sh stress 40 --autoplay --stress --perf             # a measured run → captures/perf/
CLIP=1 scripts/android_perf.sh w10 40 --map=canyon --tree=all --autoplay --skip-to-wave=10 --perf
```

Under WSL, Godot falls back from Vulkan to OpenGL 3 (via D3D12), and audio uses the dummy driver.
Both are expected.

Launch args (after `--`): `--save=PATH` (default `user://save.json`); any of the following
skips the campaign screen for a direct run that records nothing: `--seed=N`, `--map=ID`
(`outpost`, `canyon`, `switchback`), `--tree=all|none|id,id` (skill-tree nodes), `--autoplay`,
`--skip-to-wave=K` (to the build phase of wave K), `--skip=S` (S seconds into it), `--perf`,
`--quit-on-end`, `--ability=ID` (take this special attack; skips the pick); dev-only
`--stress` (`--stress=mix`: with Stage 2 enemies), `--open-plot=N`, `--pick=ID` (answer the
pick), `--demo=ID` (a staged clip of an attack), `--showcase=IDS` (one wave of those enemies,
e.g. `--showcase=wasp,warden,burrower,bombardier`), `--gold=N` (starting coins), and
`--open-tree` (campaign screen).
`--tips` shows tips in a direct run (fresh, nothing saved; with `--autoplay` the bot reads
them). `--style=ID` picks a UI style from `game/data/styles/` (any scene).
`capture_clip.sh` finds ffmpeg via `$FFMPEG_BIN` or PATH.
