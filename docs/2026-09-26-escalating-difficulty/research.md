# Escalating difficulty: map, enemy combinations, volume — research

_Work item opened 2026-09-26 at the user's request:_

> the troops don't move also, they are a fixed asset, just like a gun/tank/tourete placed at a
> given spot. we should make the map and the enemy combinations, as well as volume, more
> complex / difficult over time.

## 1. The problem

Difficulty today grows **only in magnitude, never in kind**. Measured from `game/data/waves/`:

| Wave | Enemies | Mix (Drone / Skitter / Carapace / Queen) | `hp_scale` | `speed_scale` | Total HP | Spawn window |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 10 | 10 / 0 / 0 / 0 | 1.00 | 1.00 | 60 | 22 s |
| 2 | 18 | 14 / 4 / 0 / 0 | 1.85 | 1.03 | 178 | 22 s |
| 3 | 27 | 18 / 8 / 1 / 0 | 3.02 | 1.06 | 565 | 23 s |
| 4 | 32 | 20 / 10 / 2 / 0 | 4.36 | 1.09 | 1,134 | 22 s |
| 5 | 35 | 24 / 8 / 3 / 0 | 5.81 | 1.12 | 1,935 | 24 s |
| 6 | 44 | 26 / 14 / 4 / 0 | 7.36 | 1.15 | 3,076 | 24 s |
| 7 | 51 | 30 / 16 / 5 / 0 | 8.98 | 1.18 | 4,517 | 25 s |
| 8 | 58 | 34 / 18 / 6 / 0 | 10.68 | 1.21 | 6,280 | 27 s |
| 9 | 66 | 38 / 20 / 8 / 0 | 12.44 | 1.24 | 9,056 | 28 s |
| 10 | 53 | 30 / 16 / 6 / 1 | 14.25 | 1.27 | 11,514 | 31 s |

- **Three types in a near-constant ratio** (about 60% Drone, 30% Skitter, 10% Carapace from
  wave 3 on). Wave 9 asks the same question as wave 3, only louder.
- **Most spawns use `lane = -1`** (random). Pressure is spread evenly rather than *shaped*: no
  authored "left lane is on fire while the crate is on the right" moments. That was B4 feedback
  item 3, and it's still open.
- **HP ×14 is doing the work.** Health sponges are the classic failure of pure stat scaling.
  Nothing new has to be learned, and the player's answer (build more, upgrade more) never
  changes.
- **One map, forever.** It has 3 straight lanes and 8 plots, and it never changes within a run
  or between runs. The prototype research picked "straight-line enemies, fixed build slots" on
  purpose, as the smallest scope for finding the fun. That choice has done its job; complexity
  can now be added deliberately.
- **Spawn windows barely grow** (22 → 31 s), so volume rises as density only. That's fine for
  the hook, but there is no pacing inside a wave: no lull, surge or release.

## 2. Design correction: every unit is fixed, and there is no mobile squad

**User, 2026-09-26:**

> there's no wall squad... the wall is also composed of fixed spots the player can place troops
> or weapons on. where was the movement defined as a part of the new design?

**Where the movement came from.** It was never the user's design:

- It started in the original gate-runner concept, "one-thumb drag"
  (`2026-09-24-market-research/research.md`, the gate/horde row).
- The prototype adopted it: `2026-09-24-hold-the-gate-prototype/research.md` §"Input: one
  axis" and `plan.md` day 2 ("the squad on it with drag input").
- When gates were dropped, `2026-09-25-build-spots-loot-and-art/research.md` §8 *kept* the
  squad on its own authority. "The squad keeps its drag control" was listed under "Defaults if
  unanswered". The user was never asked about it directly, and it went into the build.
- The same research had said "wall slots stay as the rear row of plots" (§4.1), but the
  implementation put no plots on the wall.

**The corrected design rule:**

- Troops and weapons are fixed assets on spots, **the wall included**.
- The player's power is *where* and *what* they place, and when they spend. It is never
  manoeuvre or aiming.
- So escalation must attack **placement**:
  - threats a fixed position can't cover;
  - paths that change what a spot reaches;
  - enemies that punish one unit type;
  - moments when the right spot is on the wrong side.

**What this changes in the current build.** It is a prerequisite work item, not part of the
difficulty work:

| Today | Consequence |
| --- | --- |
| `SquadStats`, squad bullets (`BulletField`), `SquadView`, the drag/tap input modes, the SQUAD panel and 3 squad upgrades | Removed |
| The Overdrive crate (×2 squad fire), and the cards and meta tied to the squad (`rapid`, `crits`, `recruits`, …) | Repurposed for units, or removed |
| **Crates are broken by squad fire only** (the income loop) | Needs a new rule: **Q1** |
| The wall has no plots | A row of wall spots becomes part of every `MapDef` |
| `Autoplay` aims the squad | It only builds and upgrades (and breaks crates, per Q1) |
| The balance numbers | All assume squad DPS; they need a re-tune |

## 3. Prior art: how shipped games escalate

### Lane defense with fixed units

**Plants vs. Zombies** (PopCap, 2009) is the closest relative: fixed units on a grid, enemies
walking lanes. It escalates on three separate axes:

1. **New enemy per level or two, each a question with a specific answer:**
   - Buckethead: armour, answered by high damage.
   - Pole Vaulter: jumps the first blocker.
   - Newspaper: enrages when its shield breaks.
   - Balloon: ignores ground defence.
   - Digger: attacks from behind.
2. **New environment every 10 levels**, each changing placement:
   - Night: no free income.
   - Pool: two lanes need special plots.
   - Fog: limited vision.
   - Roof: sloped lanes break straight shots.
3. **Volume inside a level:** small trickles, then a "huge wave" flag. Pacing is authored.

Ref: <https://plantsvszombies.fandom.com/wiki/Plants_vs._Zombies> (level and zombie lists).

**Kingdom Rush** (Ironhide): every map has its own path topology (forks, merges, multiple
entrances). New enemies are introduced one at a time with a "new enemy" card, and later maps
mix them. Difficulty comes from **composition and topology** far more than from HP.
Ref: <https://kingdomrushtd.fandom.com/wiki/Kingdom_Rush>.

**Arknights** (Hypergryph): fixed operators on fixed tiles, like our plots. Stages escalate
with map mechanics:

- Tiles that damage or buff.
- Drones that fly over blockers.
- Enemies that path around.

Ref: <https://arknights.wiki.gg/wiki/Terrain>.

### Volume and pacing systems

**Bloons TD 6** (Ninja Kiwi): rounds are authored, but their difficulty is budgeted by **RBE**
(red bloon equivalent: total "health" of a round). Late rounds switch *property* (camo, lead,
regrow, fortified), each needing a specific tower answer, rather than only adding more bloons.
Ref: <https://www.bloonswiki.com/Rounds_(BTD6)>.

**Risk of Rain 2** (Hopoo): a **director** earns credits over time and spends them on
spawn cards, each with a cost. Difficulty then rises smoothly from a single curve, and the
composition emerges from what the director can afford.
Ref: <https://riskofrain2.fandom.com/wiki/Directors>.

**Left 4 Dead** (Valve): the AI Director alternates **build-up → peak → relax**, tracking
player intensity. Relentless pressure feels worse than waves with valleys.
Ref: Michael Booth, "The AI Systems of Left 4 Dead", AIIDE 2009,
<https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf>.

### Takeaways

1. **Escalate one new idea at a time,** then combine ideas. Introduce an enemy or map mechanic
   alone first (the teach), then mix it with known ones (the test).
2. **A threat budget beats hand-scaled HP.** Author *what* comes (composition, lanes, timing).
   Let a single curve set *how much*, so the ramp stays smooth and measurable.
3. **Topology is difficulty.** Paths that bend, split or appear make the same plots worth
   different amounts, which is the strongest lever for a fixed-unit game.
4. **Pacing matters as much as totals:** a trickle, then a surge, then a breather to spend
   crate coins in.

## 4. Options

### 4.1 Enemy combinations

Units today target "first in reach" (the enemy nearest the wall). A Carapace walking ahead of
Skitters therefore soaks every shot while the pack behind it closes in. Only splash, the Rail
beam, or a unit whose reach starts behind the Carapace gets past it. That is exactly the kind
of situation to author on purpose.

**Combination patterns** (data, built from existing types):

| Pattern | What it is | What it tests |
| --- | --- | --- |
| Escort | Carapace in front, a Skitter pack tight behind | Units with reach past the front (Sniper, Rail beam) |
| Split pressure | Two lanes spike at once, far apart | Placement coverage: no spot covers both |
| Crate bait | A valuable crate arrives while a surge hits | Greed vs safety (its exact form depends on Q1) |
| Swarm | Many Drones packed in one lane | Splash (Mortar) over single-target |
| Sprint burst | Skitters at 0.3 s intervals | Fast hitters; Mortar shells miss them |
| Siege | Carapaces spaced along all lanes, slow | Sustained DPS, economy |
| Surge / lull | A dense 6 s spike, then 8 s of quiet | Pacing; a window to spend coins |

**New enemy types** (B10 already plans ~8). Each should answer "which placement does this
punish?". Candidates, ordered by how much they stress *fixed* units:

| Enemy | Mechanic | Punishes | Counter | Core cost |
| --- | --- | --- | --- | --- |
| **Plated** (armour) | Flat damage reduction per hit | MG/Rifle spam | Sniper, Rail, Mortar | Tiny: one field, one subtraction |
| **Splitter** | Dies into 3 Skitters | Late kills near the wall | Kill it early (front plots) | Small: a spawn-on-death list |
| **Lane-hopper** | Switches lane once, at a y threshold | Committing the squad and plots to one lane | Plots on dividers (they cover two lanes) | Medium: moves between lane arrays |
| **Burrower** | Untargetable between two y marks | Plots covering that stretch | Plots near the wall | Small: a targetable flag |
| **Mender** | Heals nearby enemies | Chip damage | Focus fire, Sniper | Small–medium |
| **Spitter** | Stops and fires at the nearest plot, disabling it for N s | Turtling behind one strong unit | Spread and redundancy | Medium: a new interaction (enemy → unit) |
| **Broodmother** | Mini-boss that spawns Drones while walking | Everything | Burst | Small |

Spitter is the one that makes "fixed assets" into **targets**. It is a big design step (units
can be disabled; the UI needs a disabled state), so it's a user decision (Q4).

### 4.2 Map complexity

The core already abstracts lanes well:

- Unit targeting distance-checks `x, y`.
- Enemy `x` lives in core.
- With the squad gone, nothing depends on lanes being straight.

So most map features are cheap. Options, cheapest first:

| Feature | Description | Rules cost | Notes |
| --- | --- | --- | --- |
| **Plot unlocks** | The map starts with some plots locked; they open at wave N, or for coins | Tiny | Gradual build complexity |
| **Spawn depth per lane** | A lane's portal sits lower (shorter lane = less reaction time) | Tiny | A portal can "advance" mid-run |
| **Portals that open mid-run** | A lane is inactive until wave N | Small | "A new front opened"; forces a re-plan |
| **Bent lanes** | A lane is a polyline; enemy `x = path(y)` | Small in core, medium in visuals | Same plot, different reach per lane; content test checks plots stay off paths |
| **Terrain zones** | Mud (slows), ridge plots (+reach), fog (−reach near the top) | Small | Pure data plus a lookup |
| **4 lanes** | `lane_count` per map | Small in core (already a config value) | 540 px portrait gives 135 px per lane; 5 lanes is too tight on phones |
| **Merging / forking lanes** | Two portals feed one lane, or one lane splits | Medium | Lane membership changes at a y. Shares code with the Lane-hopper |
| **Destructible or blocked plots** | An event destroys the unit on a plot | Medium | Only if Q4 says fixed assets can be hurt |

### 4.3 Volume and pacing

**Threat budget.** Give each `EnemyDef` a `threat` cost (≈ its effective HP × speed ×
wall damage, calibrated by the bot). A wave's budget follows one curve,
`budget(w) = B₀ · g^w` (per sector). Then:

- Authored waves are checked against the curve.
- Procedural waves (endless mode) are generated from it.
- `hp_scale` can shrink back to a gentle modifier (e.g. ≤ ×3), because count and composition
  carry the ramp.

**In-wave pacing.** Waves become a sequence of **beats**, each a pattern from §4.1 with a
budget share. Examples: trickle → surge → lull → escort → peak. The existing `SpawnEntry` list
already encodes a timeline; a beat is a named group of entries.

**Director (later).** A seeded `WaveDirector` in core picks patterns and lanes from the
budget. It's needed for endless mode and live-ops remixes; it's not needed for the campaign.
It must use the `spawn` RNG stream (determinism rule).

### 4.4 Progression structure: "over time" at three timescales

| Timescale | What escalates | Mechanism |
| --- | --- | --- |
| Within a wave | Density and surges | Beats (§4.3) |
| Within a run (10 waves) | Composition, and new lanes/plots opening | Patterns + map events keyed by wave |
| Across runs | New maps, each adding one mechanic and 1–2 enemies | **Sectors**: a campaign of maps, unlocked by clearing the previous one |

The sector structure follows PvZ's chapters and Kingdom Rush's maps. It also gives the
mobile/F2P side a natural content axis (B15, B18: a new sector is a content drop). Sectors
need save wiring, which is B3 (`SaveData` v3 exists but is unused).

## 5. Constraints

- **Performance:** batching rules stand: no node per enemy (`detailed-project-overview.md`
  §3.5). New enemy types add one MultiMesh batch each (+1 draw call). Bent lanes change only
  `x`. Splitters and Broodmothers raise peak enemy count, so `--stress` must include them.
- **Determinism:** every new random choice (director, Splitter offsets, hop timing) goes through
  `RngStreams`.
- **Data-driven:** patterns, beats, map events, terrain and sector lists are `.tres` data, not
  code.
- **Content tests** must extend. Plots must stay off *bent* paths; every enemy used in a sector
  must be introduced there or earlier; each wave's budget must stay within ±X% of the curve.
- **Portrait phone:** at most 4 lanes. Bends must keep lanes visually separable at 540 px.
- **Art:** new enemies need generator code in `tools/gf_tools/art/enemies.py`; bent lanes need
  `FieldView` to draw paths instead of three straight strips.

## 6. Open questions for the user

1. **Q1: Who breaks the crates now?** Squad fire was the only way. Options:
   - (a) **The player taps a crate** to break it (a few taps each). That's the PvZ "tap the
     sun" verb, and it keeps an active choice during a wave: tap loot, or tap a spot to build.
   - (b) **Units shoot crates** in reach when no enemy is closer.
   - (c) **Crates are collected** when they reach the wall.

   The recommendation is (a). It keeps the greed-vs-safety decision without an aimed weapon.
2. **Q2: Progression shape.** One of:
   - (a) A campaign of sectors (maps), each a 10-wave run that is harder and more complex than
     the last.
   - (b) One long run whose map evolves.
   - (c) Endless.

   The recommendation is (a), with map events inside each run and endless later.
3. **Q3: Bent lanes.** Accept the move away from the prototype's "straight lanes only" scope?
4. **Q4: Can enemies hurt or disable fixed units** (Spitter, plot-destroying events)? It turns
   "fixed" into "fixed and vulnerable", a bigger design step.
5. **Q5: Order vs B3/B4.** Sectors need saves (B3). The budget model reshapes B4's tuning.
   Should this work replace B4's "tricky situations" item and precede B10's enemy list?

### Answers (user, 2026-09-26)

1. **Crates:** "what would give better gameplay?" The answer given is **tap to break**. With
   every unit fixed, a tap is the player's only moment-to-moment action during a wave. It also
   keeps the core choice: tap loot now, or tap a spot and build. Units that auto-shoot crates
   would turn income into a passive targeting rule. Collect-at-the-wall would drop the decision
   entirely. Implemented in `2026-09-26-fixed-units-wall-spots`.
2. **Progression:** (a), a **campaign of maps (sectors)**, each harder than the last.
3. **Enemies can hurt or disable fixed units:** yes. The user adds: "we also have to define
   what losing looks like". That needs its own design pass (see §7).
4. **Bent lanes:** yes. "Lanes is stale in this new design." Straight lanes existed for the
   squad's per-lane bullets. With the squad gone, the map should be built from **paths**
   (polylines from spawn portals to the gate, which may bend, fork and merge), Kingdom Rush
   style. Straight lanes become just one kind of path.

## 7. What does losing look like? (open, for the next design pass)

Today a run is lost when the wall's HP reaches 0. Enemies that reach it chip it and vanish.
Now that units can be hurt, and the game is called *Hold the Gate*, the options are:

| Option | Loss condition | Feel | Notes |
| --- | --- | --- | --- |
| A. The wall (today) | Wall HP 0 | Abstract: a bar empties | Cheapest; weak drama |
| B. **The gate** | Enemies that reach the gate *attack it* (they stop and hit, rather than vanishing); gate HP 0 = the base is overrun | You see the breach build: a crowd pounding the gate while your wall spots fire point-blank | It fits the title; the last line of defence becomes a real fight |
| C. Lives (Kingdom Rush) | N leaks = loss | Clear, forgiving | Loses the "last stand" feel |
| D. The base core behind the gate | Gate breaks → enemies pour in → the core falls | The most dramatic; a two-stage loss (a warning, then the end) | More art and rules |

The recommendation is **B**, optionally with D's two-stage warning: "gate breached!" slow-mo,
then defeat. It turns the loss into something the player *sees coming* and can fight at the
last moment, with the wall spots as the final line.
