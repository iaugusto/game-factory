# Content expansion: research

**Date:** 2026-09-27.

**The user's ask:** "let's add some levels and new enemies and bosses. I'd want to ship this with
6 levels at least, so 3 more. also, more special attacks would be nice."

## 1. Where the game stands

**Sectors**
- There are 3 sectors (maps), 10 waves each, in `RunConfig.maps`: Outpost, Canyon and
  Switchback. Each has a biome ground.
- Each sector is worth up to 3 stars, 9 in all. Stars buy a 15-node skill tree (3 branches ×
  5 nodes, costs 1–3).

**Enemies:** 8 types, one of them a boss (`data/enemies/`).
- The behaviours are fields on `EnemyDef`: walk, siege the gate, attack units (Ravager),
  split on death (Splitter), heal others (Mender) and spit to jam units (Spitter).
- Every enemy has one weakness in the damage chart (kinetic, explosive, piercing, cryo), may
  resist a type, and may have armour.

**The boss:** the Hive Queen is the only boss. She closes every sector's wave 10.
- 250 HP × the wave's scale; only piercing hurts her.
- `wall_damage` 999: one strike breaks any gate.
- The B4 report flagged that this makes each last wave "all-or-nothing". It's still open.

**Special attacks:** there's one, the artillery strike. It's hard-wired:
- `RunConfig.strike_*`, `Run.call_strike`, `CombatSim.Strike`, a `StrikeButton`, and aim
  mode in `RunController`.
- The Fire Mission card and the bot's `strike_target` both assume it's the only one.

**Balance tooling:** `uv run balance` runs 8+ bot strategies × sectors × 50 seeds against
targets. On sector N the bot plays with a matching tree profile (T0/T3/T6, the stars
earned so far).

**Performance:** the sim tick measured 1.7–1.95 ms in game under stress (E4/E5a). Every new
per-enemy rule adds to it, and it hasn't been measured on a phone yet (B5).

## 2. Prior art

The following comes from how shipped games work, drawn from general knowledge of them; there
are no web citations.

**Kingdom Rush (Ironhide):**
- Two always-on powers (Rain of Fire, Reinforcements) on cooldowns; heroes add a third.
- Each new stage adds one new enemy "twist" (flyers that skip paths, shamans that heal,
  burrowers, enemies that disable towers).
- Every campaign arc ends in a boss stage with phases or special attacks, never an instant
  loss.
- Flyers are the classic reason to diversify towers: artillery can't hit air.

**Bloons TD 6:**
- Many consumable powers in a loadout.
- Boss events: bosses with tiers and skull phases that spawn minions or stun towers at HP
  thresholds.
- Camo and lead properties force specific counters. That's the same role our chart plays.

**Plants vs. Zombies:** one new mechanic per level, introduced alone first and then mixed in.

**Arknights and Iron Marines:** one or two active skills per loadout, chosen before the stage
(a loadout slot). This gives choice without clutter on a phone screen.

**Lessons for us:**
1. **Introduce each new enemy alone,** then mix it in. Our new-enemy tips already stop time
   the first time one appears.
2. **Every new enemy needs a clear counter** in the chart, or a new rule that one unit
   answers (e.g. air vs. mortar).
3. **Bosses should be phased set pieces,** not a one-hit loss. A boss that breaks the gate
   in one strike means a single leak ends 10 waves of play.
4. **Active abilities work best as 2 on screen,** chosen from a growing pool that unlocks
   through the campaign. It's a reward for progress and adds replay choice, while the phone
   UI stays at 2 buttons.

## 3. Options

### 3.1 Special attacks (abilities)

**Architecture:** make abilities data (`AbilityDef`) with a small set of effect kinds, and turn
the strike into one of them. That removes the hard-wired strike and fits the project's
"content is data" rule.

**Candidate abilities** (all tap-targeted, like the strike):

| Ability | Effect | Why it's different |
| --- | --- | --- |
| **Artillery Strike** (exists) | Burst damage in a circle after a delay | Burst, clumps |
| **Cryo Bomb** | Freezes everything in a circle for 3 s (speed 0), then slows | Control; buys time at the gate |
| **Napalm Line** | Lays a burning strip across the field for 6 s; damage over time to walkers | Area denial on a path |
| **Minefield** | Drops 5 mines along the path near the tap; each detonates on contact | Pre-placed; rewards reading the wave |
| **Repair Drones** | Heals the gate by X and every unit by 50% | Defensive; no aiming |
| **Overcharge** | All units fire 2× for 6 s (the Overdrive crate's effect, on demand) | Offensive buff; no aiming |

**Loadout models:**
- **(A) Recommended.** Two slots, filled from unlocked abilities. The Strike and Cryo Bomb
  start unlocked, and each sector cleared unlocks one more. The pick happens before a run, on
  the sector card.
- **(B)** Every unlocked ability on screen at once. Simpler, but 4–6 buttons crowd a phone.
- **(C)** Abilities as cards (a run picks them up). That's random, and loses the player's
  plan.

### 3.2 New enemies

Each one either has one weakness in the chart or introduces one clear rule.

| Enemy | Rule | Counter | Risk |
| --- | --- | --- | --- |
| **Wasp** (flying) | Flies over the barricade and mud; shells (Mortar) can't hit it | Kinetic (MG, Rifleman) | A small sim rule: a `flying` flag skips the barricade stop, mud and SHELL hits |
| **Warden** | Projects a shield on nearby enemies that absorbs N damage, regenerating | Explosive (splash breaks many shields) | A per-tick aura; it costs sim time like the Mender |
| **Burrower** | Dives underground (untargetable) for a stretch of path, then surfaces closer | Cryo (slowed on the surface), Sniper range | Needs a "submerged" state in targeting |
| **Bombardier** | Stops at range and lobs acid at the gate from ~200 away (a siege from range) | Piercing (Sniper/Rail reach) | Changes where the fight happens; strong |
| **Broodling carrier** | Drops a Skitter every few seconds while walking | Explosive | Overlaps with the Splitter |
| **Juggernaut** | Huge armour; each hit strips armour | Heavy piercing | Overlaps with the Carapace |

**Recommendation: the first four** (Wasp, Warden, Burrower, Bombardier). Each is a new *rule*
that changes placement or unit choice, not just stats. The last two overlap with existing
enemies.

### 3.3 Bosses

**The current Queen:** is she kept as a one-strike gate breaker? That's a carried-over default,
so it's an explicit question for the user. I recommend making her **heavy but survivable**
(e.g. 60 gate damage per strike), which removes the B4 "all-or-nothing" finding.

**New bosses**, one per new sector, each phased at HP thresholds (Kingdom Rush / BTD style):

| Boss | Sector | Phases |
| --- | --- | --- |
| **Broodmother** | 4 | At 66% and 33% she stops and births a Skitter swarm; weak to explosive |
| **Siege Titan** | 5 | Armoured. At 50% she sheds her armour and speeds up; spawns Wardens around her; weak to cryo |
| **The Overmind** (finale) | 6 | Shielded while any Warden lives; phase 2 calls Wasps; phase 3 heals from Menders; weak to piercing |

**Boss rules** become data (`BossPhase`: an HP threshold → spawn X, set armour, speed or
shield), so future bosses are content, not code.

### 3.4 Levels (sectors 4–6)

Each new sector introduces 1–2 new enemies, a new map shape, and a new biome:

| # | Sector | Biome | Layout idea | Introduces | Boss |
| --- | --- | --- | --- | --- | --- |
| 4 | **Mire Crossing** | Swamp (dark green, lots of mud) | Four narrow paths through mud, merging in pairs | Wasp, Warden | Broodmother |
| 5 | **Ashfall** | Volcanic (black ash, ember glow) | A burrow that opens **mid-field** at wave 4; high-ground pads | Burrower, Bombardier | Siege Titan |
| 6 | **The Hive** | Infested (full creep) | Paths that loop around a central high ground; every mechanic mixed | All | The Overmind |

- Waves are 10 per sector, authored with the existing `WaveDef` format.
- New mechanics need no new map rules, beyond an optional mid-field portal (a path whose
  first point is inside the field; the sim already supports it).

### 3.5 Progression

- **Stars:** 9 → 18.
- **The skill tree:** grow it from 15 to 21 nodes, or add a tier.
  - Recommended: add a row of 3 nodes (cost 3–4) and three "ability" nodes (shorter
    cooldowns, a third ability slot).
- **The bot's tree profiles** extend to T9/T12/T15.
- **Ability unlocks:** clearing sector N unlocks ability N+2 (the Strike and Cryo Bomb are
  free).

## 4. Risks

- **Scope.** This is 3 maps, 30 waves, 4 enemies, 3 bosses, 4 abilities, and their art, tips,
  bot logic and balance. It's the biggest work item yet, so staging matters.
- **Sim cost.** Warden auras, flying checks and boss phases each add per-tick work. They get
  measured with the stress probe after each stage.
- **Bot competence.** The balance tool is only as good as the bot. The bot must learn to use
  each new ability and to counter the new enemies, or the win-rate targets mislead.
- **Readability.** The on-screen enemy count is 12 types. Each needs its own silhouette and
  hue. The art pipeline from the last work item handles that.

## 5. Questions for the user

1. **Loadout:** two slots from a growing pool (recommended), or everything on screen?
2. **The Hive Queen:** keep her one-strike gate break, or make her heavy but survivable
   (recommended)?
3. **The enemy roster:** Wasp, Warden, Burrower, Bombardier (recommended), or swap any?
4. **Themes and names** (the user's taste): Mire / Ashfall / The Hive; Broodmother / Siege
   Titan / The Overmind. Keep, or rename?
5. **Staging:** build in 4 stages, each ending with clips to judge (recommended), or all at
   once?

## 6. The user's answers (2026-09-27)

1. **Loadout:** "the player selecting a special attack to use in the start of the map, with a
   quick tutorial for what it does, reload time, etc the first time around."
   - That means **one** attack per map, chosen when the map starts.
   - The first time each attack is offered, a short tutorial explains what it does and its
     reload time. This uses the existing tips system.
   - Unlocking (the pool growing through the campaign) stays as proposed. The user didn't
     object to it.
2. **Hive Queen:** "make her deal 50 damage instead (2 hits with no upgrades, 3 with any
   upgrades)."
   - `wall_damage` 999 → 50. The base gate is 100 HP, so two strikes break it.
   - Any gate HP upgrade (the tree or cards) makes it three.
3. **Enemies:** Wasp, Warden, Burrower, Bombardier. Accepted.
4. **Names and themes:** Mire Crossing / Ashfall / The Hive; Broodmother / Siege Titan /
   The Overmind. Accepted.
5. **Staging:** the user asked what staging and clips mean here. Answered in chat; waiting
   on their choice.
   - **Decided:** stages (1 → 4), each ending with clips for the user's review.
6. **Clips in tutorials** (the user's new idea): "we can use some for the tutorials / infos as
   well … only when beneficial, of course - like special atacks' effects". The technical notes
   and a recommendation are in `handover.md` §6. Decide in Stage 1.
