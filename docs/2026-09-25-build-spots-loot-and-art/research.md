# Research — build spots, loot crates, reload trade-off, and a "stunning" look

Work item opened 2026-09-25 from a user request. It changes the core loop the prototype is
built on, and it pulls art forward from B6, so it gets its own research before any code.

## 1. The request (user, 2026-09-25)

1. **Build spots.** The player positions **troops or weapons** on spots. Each costs a given
   amount of resources.
2. **Loot crates.** While fighting, there are **resource boxes/loot** the player breaks to
   gather resources, which then buy the units and upgrades.
3. **Enemy health bars.** Enemies have health bars, as discussed before. They don't
   necessarily die to a single shot from any weapon.
4. **Reload trade-off.** The stronger the weapon or troop, the longer it takes to reload and
   shoot again.
5. **Look.** Enemies, troops, weapons and every other object should be modelled "super
   professionally", and the game should look stunning.

## 2. Where the code is today (B2 done)

| Request | Today | Gap |
| --- | --- | --- |
| Build spots | `Run.turrets`: 4 slots (5 with meta) in a row **on the wall**. Turrets aim at the lane whose front enemy is nearest the wall, whichever lane that is. You can build only in the BUILD phase between waves. | There's no position, no range and no choice of *where*. You can't build mid-wave. There's no "troop" kind. |
| Currency | `gold` comes only from **kills** (`Economy.kill_reward`). | Nothing on the field pays out when you break it. |
| Loot crates | Nothing. But **gates** are the same shape: an object in a lane that drifts down and is hit only by squad bullets (`CombatSim.Gate`, `_hit_gate`). | A crate is a new field object that reuses the gate plumbing (lanes sorted front-first, squad-only hits, signals for the views). |
| Health bars | `EnemyField` already draws an HP bar per enemy in one batched pass. HPs are grunt 3, runner 1.5, brute 30, boss 900. Squad damage is 1 per bullet. | Bars exist but are placeholder-looking. The one-shot problem is the squad's **volume** of fire (B2 feedback: "too many shots, too fast"), not the per-bullet damage. |
| Reload | `TurretDef.fire_rate` and `damage` are independent numbers. They happen to be inversely related today (MG 5/s × 1, Cannon 0.8/s × 5, Rail 0.4/s × 8), but nothing enforces it and nothing shows it. | Make "reload time" a first-class, visible stat, and make "stronger means slower" a checked content rule. |
| Look | Coloured circles and rectangles (see the B2 clips). Art direction is **B6**, after the **D1** continue/pivot/stop decision. | This is the biggest item by far (§6). |

## 3. Prior art

### Build spots

- **Kingdom Rush** uses fixed, pre-marked build plots alongside the path. The design value is
  in *which* plot: chokepoints and bends give towers more time on target. Players place
  cheap, fast towers early on the path to strip weak enemies and slow, heavy towers later for
  the tanks that survive ("sequence strategy"). The map, not free placement, carries the
  strategy, and it reads instantly on a small screen.
  [Kingdom Rush Wiki — Sequence strategy](https://kingdomrushtd.fandom.com/wiki/Sequence_strategy),
  [BlueStacks tips](https://www.bluestacks.com/blog/game-guides/kingdom-rush/kr-tips-tricks-en.html),
  [Steam guide — Origins tower placements](https://steamcommunity.com/sharedfiles/filedetails/?id=3587039934).
- **Fixed plots suit portrait mobile.** Free placement needs precise drags and invites
  overlapping, unreadable towers. Plots are one tap each.

### Breakable loot in lanes

- **Last War: Survival** (the ad-famous shooter, since made real) puts **barrels in the lane
  that show how many bullets they need**. Breaking one gives units, weapons or strength. It
  sits next to +N/×N gates as a *third* choice: spend fire on the barrel, or on the enemies.
  This is the closest reference to our concept.
  [Wikipedia](https://en.wikipedia.org/wiki/Last_War:_Survival_Game),
  [Pocket Gamer guide](https://www.pocketgamer.com/last-war-survival/guide/),
  [ad footage: barrels and boss](https://www.youtube.com/watch?v=FCQHtD1S_Xw).
- **Plants vs. Zombies** (sun) is the classic case of a resource you *collect during the
  fight* and spend on placements in the same fight. The tension is attention: collecting is
  time not spent elsewhere. Earning mid-wave only matters if you can spend mid-wave.

**Takeaway.** Crates are the same verb as gates (shoot an object in a lane) with a different
payoff. Gates make the *squad* stronger; crates buy *units on spots*. That extends the core
decision in the prototype plan ("every second spent on a gate is a second not spent on
enemies") instead of competing with it. The risk is **clutter**: 3 lanes × 180 px on a 540 px
portrait screen already carry enemies, gates and bullets. Crates need a silhouette nothing
else has, and waves must ration them.

### "Stronger means slower"

- It's the standard tower defense axis (Kingdom Rush: archers fast and light, artillery and
  mage slow and heavy). It pairs with the enemy roster the user asked for in B2 (fast and
  fragile vs slow and tanky, `ROADMAP.md` B4 item 7):
  - A heavy gun **wastes** damage on runners (overkill) and can be out-timed by a burst of
    them between reloads.
  - A light gun barely scratches a brute.
  - So the roster and the reload axis make each other matter. Neither works alone.
- For this to be a trade-off and not a ranking, **damage per second must stay in a band**
  across units of the same cost. The heavy shot buys splash, pierce, range or burst, not raw
  DPS. That can be checked as a content test.
- **Readability:** a visible reload ring or bar under each unit tells the player *why* the
  cannon isn't firing, and turns the reload into a moment of anticipation ("charging →
  BOOM"). That's a big part of the game feel.

## 4. Design options

### 4.1 Where the spots are

| Option | Pros | Cons |
| --- | --- | --- |
| **A. On the wall only** (today's 4 slots, each with a lane or range) | Smallest change. Nothing new on the field. | "Position" means little: every slot is at the same distance. |
| **B. Plots on the field**, on the lane dividers and edges at 2–3 depths, each with a range circle covering one or two lanes | Real placement choices (forward plots engage early and cover two lanes; rear plots guard the wall). It's what Kingdom Rush does, and it creates the "sequence" strategy. | Needs a map definition (plot positions as data). More on screen. Targeting becomes range-based. |
| C. Free placement anywhere | Maximum freedom. | Poor on mobile, unreadable, hard to balance. Rejected. |

**Recommendation: B.** Plots are data (a `MapDef` listing positions), which also gives the B10
"3 biomes/maps" a home. Wall slots stay as the rear row of plots.

### 4.2 When you can build

- **Between waves only** (today): simple, but crate loot sits idle until the wave ends.
- **Any time, including mid-wave:** tap a plot, pick a unit from a small radial menu, and it
  builds instantly or after a short build time. Loot you break is spent where it's needed
  *now*. That's the PvZ loop, and it makes breaking crates matter.
- **Input conflict (portrait, one thumb):** drag moves the squad. Tapping a plot must not also
  move it. Taps that start on a plot open the menu; everything else drives the squad. It's
  solvable, but it needs testing in the scene tests.

**Recommendation: any time**, with the between-wave BUILD phase kept for upgrades and cards.

### 4.3 Troops vs weapons

- Both use one data type (`UnitDef`, generalizing `TurretDef`): cost, damage, **reload time**,
  range, projectile, splash/pierce/slow, and a "troop" or "emplacement" look. The rules don't
  care which it is. The distinction is visual and in flavour, and it may later carry a rule
  (e.g. troops can be healed, emplacements can't).
- A starting roster that fits the speed ↔ toughness axis:
  - Rifle squad (fast, light)
  - MG nest (fast, light, short range)
  - Sniper (slow, very heavy, long range, single target)
  - Mortar/cannon (slow, heavy, splash)
  - Frost/tesla (control)
  - Rail (slowest, pierces the lane)

### 4.4 Currency sources

- **Crates only:** the purest version of the request. Every resource is a decision to take
  fire off the enemies.
- **Crates plus a small kill trickle:** softer, and it guarantees some income in a bad run.
- **Recommendation:** crates are the main income, and kills pay a small amount. The split is
  one number in data, tuned by the B4 bot.

### 4.5 Do the gates stay?

The gates are the **hook the concept was chosen for** (market research §4b; D1 judges it). The
crates add a second shootable object. Options:

1. **Keep both.** Gates grow the squad; crates fund the plots. It's the richest option, and
   the one with the most clutter risk.
2. **Crates replace gates.** Simpler, but it throws away the tested hook and turns this into a
   different game (lane tower defense with loot). It would effectively be a pivot.
3. **Crates are one kind of gate.** A "supply" gate pays resources when it lands instead of
   buffing the squad. It's the least new code and the lowest clutter, but "break it" becomes
   "charge it".

This changes what's built, so it's a **question for the user** (§7).

## 5. Rules and architecture impact (any option)

- **Core stays the rulebook** (`CLAUDE.md` §4):
  - `CombatSim` gains crates as a lane object like gates, plus plot-based units with range
    targeting.
  - Units get a `reload` countdown instead of the fire-rate loop.
  - `Run.build()` works during WAVE.
  - It all stays deterministic and headless-testable.
- **New data:**
  - `UnitDef` (replaces `TurretDef`; the four turret `.tres` files migrate).
  - `CrateDef` (HP, reward, speed, look).
  - `MapDef` (plots: position, range, allowed unit tags).
  - Crate spawns in `WaveDef`.
- **Content tests:**
  - Reload is monotonic in damage per shot.
  - DPS per cost stays in a band.
  - Every plot is reachable, and every crate is breakable in time at base fire.
- **Save data:** unaffected. Plots and units live within a run and nothing about them is
  saved. Meta upgrades that reference `turret_*` modifier keys get renamed through a v3
  migration only if saved data refers to them (it doesn't today: saves hold meta levels by id).
- **Performance:**
  - Crates are few, so they can be pooled nodes like gates.
  - Units are ≤ ~12, so they can be nodes.
  - Enemies and bullets **must stay MultiMesh-batched** (B2 finding: 599 → 80 draw calls). The
    art pipeline has to respect that (§6).

## 6. "Modelled super professionally, stunning": the options

Being honest about what can be produced here: I can write code, shaders, procedural geometry
and VFX, and I can drive tools like Blender through scripts. I can't hand-paint illustration
at the level of a commercial artist. "Stunning" comes from three things:

1. **Coherent art direction:** palette, lighting, shape language.
2. **Motion and VFX:** anticipation, impact, particles, death effects, screen feel.
3. **Asset craft:** silhouettes and detail.

The first two I can do very well in engine. The third is where the routes below differ.

| Route | Quality ceiling | Cost / approvals | Fits batching? | Notes |
| --- | --- | --- | --- | --- |
| **A. Procedural "illustrated vector" in engine:** layered polygons with outlines, gradients, soft shadows, rim light; baked to textures at load; shader hit flash, dissolve deaths, GPU particles | Good to very good: a clean, stylized look, like polished vector mobile games | Free, no approvals | Yes: shapes bake to textures, then MultiMesh | Fastest to iterate. Every look is code, so it can be changed and tested. |
| **B. 3D models → pre-rendered 2D sprites** (Blender, scripted: modelled, lit, rendered to sprite sheets at 8 angles/frames) | Very good: the "Kingdom Rush / Clash" rendered look, real lighting and depth | **Blender download (~300 MB into `.tools/`, repo-local) needs approval** (download / system tooling) | Yes: sprite sheets into MultiMesh | Procedural/scripted modelling has limits for organic creatures; mechanical units (turrets, crates, drones, robots) come out best. |
| **C. CC0 packs as a base** (Kenney *Tower Defense (Top-Down)*, 300 assets, CC0, commercial use OK) plus custom VFX and palette | Consistent and professional but generic; recognisable as Kenney | Free. **Download needs approval.** | Yes | A good placeholder standard, weak for store differentiation. [Kenney TD Top-Down](https://kenney.nl/assets/tower-defense-top-down), [Kenney license/support](https://kenney.nl/support) |
| **D. AI-generated sprites** (image model API) | High detail; consistency across a set is the hard part | **Paid API (money, ask first).** Steam requires disclosing AI-generated shipped art (rules revised Jan 2026). | Yes | [Steam AI disclosure changes, 2026](https://www.generationamiga.com/2026/01/17/valve-rewrites-steams-ai-disclosure-rules-for-developers/) |
| **E. Commissioned artist / paid packs** | Highest, and distinctive | **Money** | Yes | The realistic route for final store art, normally at D2/production. |

**Mobile rendering notes:**

- Godot's 2D normal-mapped lights are expensive on phones: reports of 60 → 42 fps from a
  single `PointLight2D` on Android, and ~50 fps with 2 lights on mid-range phones
  ([godot#81152](https://github.com/godotengine/godot/issues/81152),
  [forum](https://forum.godotengine.org/t/perfomance-issues-using-light2d-with-normal-maps/7096)).
- So lighting should be **baked into the art** (routes A/B) or faked with additive sprites,
  not done with real-time 2D lights.

**Sequencing concern (to raise, not to block):**

- The roadmap deliberately puts art (B6) after **D1**, the "is it fun?" decision, so polish
  isn't spent on a loop that gets pivoted.
- This request changes the loop *and* asks for final-quality looks at the same time.
- A middle path: build the loop changes first (cheap to change), then make **one fully
  art-directed slice** (one enemy of each archetype, one crate, two units, the field, VFX) in
  1–2 directions for the user to judge. Only then roll the direction out to all content.
- That's B6's "options, then the user picks" structure, pulled forward and focused.

## 7. Open questions for the user

1. **Gates:** keep them alongside crates, replace them with crates, or make crates a kind of
   gate? (§4.5)
2. **Build timing:** any time including mid-wave (recommended), or between waves only? (§4.2)
3. **Spots:** plots on the field with range (recommended), or wall slots only? (§4.1)
4. **Art route:** A (procedural, free, now), B (Blender pre-render, needs a download), C (CC0
   base, needs a download), or D/E (paid)? And should it be one art-directed slice first, or a
   full pass? (§6)

### Answers (user, 2026-09-25)

- **Build timing:** any time, mid-wave included.
- **Spots:** plots on the field, with range.
- **Art route:** procedural in engine, one art-directed slice first.
- **Gates:** the user questions keeping them. Spots, crates and coins now carry the
  progression, so why keep the multipliers? See §8.

## 8. Do the gates still earn their place? (asked by the user)

**Why they were in the concept:**

1. **The ad-proven hook.** "+5 / ×2" gates are the most-seen mobile ad format and read in 3 s
   (market research §4b).
2. **A moment-to-moment aim decision:** gate or enemies.
3. **Visible exponential growth,** which is satisfying to watch.

**What the new design does to each:**

1. **The hook** is partly replaced. A crate with a hit counter that bursts into coins is the
   same Last War ad beat (the barrels), and just as readable.
2. **The aim decision** is fully replaced. "Crate or enemies" is the same trade, and its payoff
   (coins → a unit on a plot) is *more* strategic than "+5 shooters".
3. **Exponential growth** is the part that hurts:
   - The multipliers caused the B1 balance blow-up (~20,000 shooters, a trivial win) and the
     B2 feedback ("too many shots, too fast").
   - With plots, the squad and the units are two parallel power curves fighting for the same
     job, so the stronger one makes the other pointless.
   - Keeping both means balancing two economies and cluttering three 180 px lanes with a
     third kind of object.

**Conclusion: drop the gates.**

- The squad stays as the player's aimed weapon (drag). It's the active verb during a wave, and
  it's what breaks crates.
- It grows through coin upgrades and cards instead of gates.
- Occasional **special crates** can grant a short, temporary boost (e.g. 10 s of double fire
  rate). That keeps a bit of the gate thrill with no permanent snowball.

**Consequences:**

- This is effectively the D1 "pivot" branch. The game becomes a **lane tower defense with an
  aimed hero squad and loot**, closer to the research's Thronefall-lean runner-up than to the
  gate runner.
- The market research's hook argument should be re-read with that in mind.
- `GateMath`, `GateDef`, the 5 gate `.tres`, `GateView`, `GateFormat` and the gate cards
  (`lucky_gates`, `soft_gates`) and meta (`gate_lore`) are removed or repurposed.

**Defaults if unanswered** (all tunable data):

- Kills pay a small trickle and crates are the main income.
- The squad keeps its drag control.
- The currency keeps the internal name `gold`; the display name is the user's call.
