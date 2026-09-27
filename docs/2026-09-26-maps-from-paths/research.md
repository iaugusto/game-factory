# Maps from paths (E4): research

_Work item opened 2026-09-26. It is step **E4** of the escalating-difficulty track
(`ROADMAP.md`). The user played E3 ("the game feels ok, we're good to continue")._

## 1. The request

The user, earlier the same day:

> we also don't need to be stuck in 3 lanes, even though that looks ok.

And in reply to the escalating-difficulty questions:

> yes, lanes is stale in this new design.

Research §4.2 of `2026-09-26-escalating-difficulty` listed the options:
- bent paths;
- portals that open mid-run;
- spawn depth (shorter paths);
- spots that unlock;
- terrain zones;
- merging and forking.

## 2. Why lanes existed, and what depends on them now

Straight vertical lanes served the aimed squad: one bullet list per lane, hitting the front
object. The squad is gone. What still leans on lanes:

- **`CombatSim`** keeps per-lane arrays sorted nearest the wall first. Targeting
  (`first_in_reach`) binary-searches a y window per lane. It was the fix for a 5 ms-per-tick
  full scan (`2026-09-25-build-spots-loot-and-art`).
- **Enemy x** is the lane centre plus a deterministic spread. Crates sit on the lane centre.
- **The barricade** blocks one lane. **Escorts** are per lane. **The Rail's beam** hits its
  target's lane.
- **`SpawnEntry.lane` and `CrateSpawn.lane`**, with random lanes resolved in `WaveSchedule`.
- **The ground art** paints three straight dirt strips (`tools/gf_tools/art/props.ground`).
- **Content tests:** plots must keep clear of lane centres, and barricade slots sit on lane
  centres.

## 3. Prior art

- **Kingdom Rush:** each map is a set of paths. They wind, and two entrances merge into a shared
  choke before the exit. Some maps open new entrances in later waves, announced by a skull
  icon at the path start, so the player's layout must adapt mid-level.
  <https://kingdomrushtd.fandom.com/wiki/Kingdom_Rush>
- **Bloons TD 6:** maps are graded by path length and number of entrances (Beginner → Expert).
  More entrances and shorter paths are the main difficulty lever, not HP.
  <https://www.bloonswiki.com/Maps_(BTD6)>
- **Plants vs. Zombies:** new environments change placement rules. In the Pool, only some rows
  take plants; on the Roof, straight shots can't reach. PvZ's lesson is that terrain changes
  *which spot is good*, not just numbers.

### Takeaways

1. **Merges make chokes.** A shared segment is where a barricade and splash shine. It's an easy
   early game, and it gets harder when a second entrance opens.
2. **Portals opening mid-run** are the cleanest escalation over a run. Every existing unit's
   value changes, and the player must re-plan. It must be announced in the build phase before
   it happens.
3. **Shorter paths** (a portal low on the field) mean less time to kill. That's a strong but
   readable pressure.
4. **Terrain:**
   - Mud (enemies slowed) makes a natural kill zone.
   - High ground (+reach for a pad) makes one pad worth more.
   - Both are data, and both are visible.

## 4. Design

**A path** (`PathDef`) is a polyline from its portal to the gate.
- Its **y strictly increases** along it: it may bend sideways but never turns back up the
  field. That keeps enemy order along a path consistent with y, so targeting stays a binary
  search (on distance along the path).
- It ends on the gate line (`wall_y`).
- It has a `spread` (how far enemies stray from its centre line) and `opens_at_wave`.

**Enemies and crates** carry `d`, the distance along their path. Position is the centre line
at `d` plus a lateral offset. "Nearest the gate" means the least distance remaining, which
compares correctly across paths of different lengths.

**Merges and forks** are data: two paths that share a stretch of centre line. The escort and
beam rules stay per path.

**The barricade** blocks every path whose centre line passes within 40 of its slot, so a slot
on a merged choke blocks both entrances.

**A map is a level:** its paths, plots (with `unlock_waves`), barricade slots, terrain zones
and **its own waves**. `RunConfig.maps` lists them. `RunConfig.for_map()` gives the run config
for one.

| Zone | Effect |
| --- | --- |
| **Mud** | Enemies inside move at `value` × speed (0.6) |
| **High ground** | Plots inside get +`value` reach (0.25) |

**Ground art:**
- The generator paints a lane-less ground (`field/ground_bare`).
- `FieldView` draws each path at runtime as a textured `Line2D` (a tiling dirt strip,
  `field/dirt`, over a darker worn edge), with a portal sprite at its start.
- Zones draw from generated `field/mud` and `field/ridge` sprites.
- Paths that aren't open yet draw dimmed, with a sealed portal and "W4".
- Their opening is announced with a "NEW BREACH" banner and a pulsing portal in the build phase
  before.

### Maps

- **Frontier Outpost** (sector 1): the existing 3 straight paths, as before.
- **Canyon Pass** (sector 2, harder and more complex):
  - Two portals top-left and top-right bend inward and **merge** into a central choke through
    a mud patch.
  - A **left flank breach** opens at **wave 4**, and a **right flank breach** at **wave 7**.
    Both portals are low on the field (short paths).
  - Pads around the bends; a high-ground pad over the choke; some pads unlock at waves 4 and
    7, covering the flanks.
  - Barricade slots on the choke and both flanks.
  - Its own 10 waves, heavier than the Outpost's.

**Choosing a map:** there's no campaign until E5. For now: `--map=<id>`, and a "PLAY <next
map>" button on the result screen. E5 turns this into sectors with unlocks.

## 5. Risks

- **Targeting cost** with bent paths. It's kept a binary search by the y-monotonic rule and
  measured under `--stress`.
- **Readability** of merged paths on a 540 px portrait screen. It's checked in stills.
- **The bot:** it needs path-aware barricade placement. Its counter-picking is unchanged.
