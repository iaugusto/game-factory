# E5c — Artillery strike and unit synergies: research

_2026-09-27. Roadmap step E5c. The user's calls: "artillery strike is ok, so is synergies (each
combination gets a different effect)". B4 follows in its own work item._

## 1. Why these two

- **The artillery strike: a second verb during a wave.**
  - Today the only live action is tapping crates. Spending is live too, but it's menu-driven.
  - An aimed strike on a cooldown gives the player a way to *save* a bad moment: a Brute
    pounding the gate, or a Splitter brood bunched up.
  - It's also the spectacle beat for clips and store screenshots.
- **Synergies: placement starts to matter.**
  - Today a unit's value depends only on what it is (the counter chart), not on where it
    stands next to others.
  - With a pair effect, "what goes next to what" becomes a puzzle on every map, and every map
    reshuffles it.

## 2. Prior art

- **Aimed abilities on a cooldown:**
  - Kingdom Rush's Rain of Fire and Reinforcements: tap the icon, then tap the field. The
    meteor lands after a short delay. Cooldowns run about 60–80 s, and there's one or two
    uses per wave.
  - Plants vs. Zombies' Cherry Bomb is a seed with a recharge.
  - Bloons TD 6's powers (the MOAB Mine, etc.) are consumables.
  - **The common grammar:** an icon with a radial cooldown, arm, target, a short telegraph,
    then impact.
  - The telegraph matters: fast enemies can walk out of it, like our Mortar shells, so aiming
    ahead is a skill.
- **Adjacency synergies:**
  - *Dungeon Warfare 2* and *Legion TD 2*'s auras.
  - *Bad North*'s formation bonuses.
  - *Rogue Tower*'s adjacent buildings.
  - *Kingdom Rush*: the Barracks + Mage combo (units hold, mages fry) is a *tactical*
    synergy, not a numeric one.
  - **What works:** synergies must be **visible**. Link lines, and a name on formation, as
    Legion TD shows aura icons. The player should be able to **preview** them before building.
    Hidden number soup doesn't change behaviour.

## 3. Design

### 3.1 Artillery strike

**The loop:**
1. Tap the **STRIKE** button (top right, under the HUD; only during waves).
2. This arms it: time slows (like the build menu) and a crosshair shows.
3. Tap the field to call the strike there. Tapping the button again cancels.
4. A telegraph ring appears. The shell lands after **0.9 s**, hitting everything within
   **radius 70**.

**Numbers (in config):**
- **Damage** is 30 × the wave's `hp_scale`, so it stays relevant as enemy HP ramps. It kills a
  crowd of Skitters or Drones, and chunks a Carapace.
- **It ignores the chart and armour.** It's the answer that is never wrong, and it's paid for
  with the cooldown.
- **Cooldown** is 25 s. It runs during waves only, and the strike is **ready at each wave's
  start**: about 2 uses per wave.

**Rules:**
- **Determinism:** the strike is an input, like a tap, and it lands on a tick count. The bot
  uses it too.
- **Card:** "Fire Mission" gives −30% strike cooldown, so runs can build around it.

### 3.2 Synergies

**The rule:**
- Two built units whose pads are within **200** of each other form a **link**.
- Each unordered pair of unit types, same-type pairs included, has its **own named effect**:
  21 in all (6 unit types).
- A unit gets each distinct synergy once, however many partners of that type it has, so
  stacking stays sane.
- **Links are recomputed on build, sell and destruction,** never per tick. Stats stay flat,
  and the per-tick cost is one extra add in each stat.

**The effect vocabulary** (per unit, like masteries):
- damage %, reload %, reach %, splash %;
- slow strength and duration;
- armour pierce, crit chance, extra beam targets;
- **chill**: a non-Cryo unit's hits slow briefly.

The table below assigns one to each pair, favouring effects that make thematic sense:

| Pair | Name | Effect |
| --- | --- | --- |
| Rifleman + Rifleman | Fire Team | both +15% damage |
| Rifleman + MG | Suppressing Fire | both reload 15% faster |
| Rifleman + Cryo | Cold Rounds | Rifleman hits chill (×0.8 speed, 1 s) |
| Rifleman + Mortar | Spotter | Mortar +20% reach |
| Rifleman + Sniper | Marked Targets | Sniper +25% damage |
| Rifleman + Rail | Loader Team | Rail reloads 20% faster |
| MG + MG | Interlocking Fire | both +10% reach |
| MG + Cryo | Shatter | MG +15% crit chance |
| MG + Mortar | Crossfire | Mortar reloads 20% faster, MG +10% damage |
| MG + Sniper | Tracer Rounds | Sniper +20% reach |
| MG + Rail | Capacitor Link | Rail beam +2 targets |
| Cryo + Cryo | Deep Cold | both slow 15% harder, +1 s |
| Cryo + Mortar | Brittle Ground | Mortar +30% splash |
| Cryo + Sniper | Frozen Aim | Sniper pierces 50% of armour |
| Cryo + Rail | Superconductor | Rail +30% damage |
| Mortar + Mortar | Barrage | both +20% splash |
| Mortar + Sniper | Rangefinding | Mortar +25% reach, Sniper +10% damage |
| Mortar + Rail | Siege Battery | both +15% damage |
| Sniper + Sniper | Twin Scopes | both +10% crit chance |
| Sniper + Rail | Kill Chain | both reload 15% faster |
| Rail + Rail | Grid Resonance | both +1 beam target and +10% damage |

**Visibility (from the prior art):**
- **Link lines:** a thin glowing line between linked pads, tinted by the synergy.
- **On formation:** a name popup ("SIEGE BATTERY").
- **In the build menu:** each unit button **previews** the synergies it would form on that
  pad, and a built unit's card lists its active links.

### 3.3 Risks

- **Balance:**
  - Every existing layout gains links, so runs get easier.
  - The balance bot must place for synergies (a "prefer linking" heuristic) to measure it.
  - B4 re-tunes against it.
- **Perf:** no per-tick lookup (links are cached per plot). The link lines are one draw pass.
- **Readability on a 540 px screen:** lines must stay subtle; names show on formation only.

## 4. Taste calls (shown in clips; the user judges)

1. The strike's feel: delay, radius, screen shake.
2. The synergy list: names and effects. Swapping any row is one `.tres` edit.
