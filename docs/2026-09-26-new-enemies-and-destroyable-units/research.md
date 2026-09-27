# New enemies, destroyable units and elites (E5a): research

_Work item opened 2026-09-26. It is the first part of step **E5** (`ROADMAP.md`); the user said
"let's press forward"._

E5 is split so each part can be proven on its own:

| Part | Scope |
| --- | --- |
| **E5a (this)** | Units that can be destroyed, the enemies that do it, new enemy types, elites |
| E5b | Sectors (a campaign of maps), save/meta wiring (B3), the skill tree between maps |
| E5c | The active ability and unit synergies |

## 1. The user's decisions this builds on

- "units can be destroyed as you suggested": **by specific enemies only**, so a loss is readable
  (`2026-09-26-counters-and-coin-sinks`).
- New enemy types "each designed to create a specific tricky situation, not just more HP"
  (ROADMAP B10, and `2026-09-26-escalating-difficulty` §4.1).
- The "Doom Eternal" counter chart: every new enemy gets one weakness and at most one
  resistance, plus a tell.
- Elites: "elite versions of enemies later in the campaign [...] multiplies the which-weapon
  puzzle without drawing new enemies" (accepted with the E3 suggestions).

## 2. Prior art

- **Units that can be lost:**
  - **Plants vs. Zombies:** zombies eat the first plant in their row. Losing a plant is the
    everyday cost of a leak, and the Wall-nut exists to absorb it.
  - **Kingdom Rush:** barracks soldiers die and respawn; towers never die. A **few specific**
    enemies (e.g. the Juggernaut's missiles, Sarelgaz) attack towers directly, which makes them
    priority targets.
  - The lesson from both: destruction is best as the signature of specific enemies, so the
    player learns "kill that one first".
- **Enemies that split** (Bloons' layers; PvZ's Gargantuar throwing an Imp): killing it late
  is worse than killing it early, because the children spawn nearer the goal.
- **Healers** (Kingdom Rush's Shaman heals nearby enemies): they turn focus fire into the
  answer, and long-reach single-target units (Snipers) earn their place.
- **Elites** (Bloons' Fortified, Camo and Regrow properties; Diablo's champion packs): a known
  shape with a changed property. The tell is a colour tint plus a marker. A property changes
  *which weapon* rather than adding a new enemy to learn.

## 3. Design

### 3.1 Destroyable units

- **HP:** every `UnitDef` gets `hp` (troops less, emplacements more), +30% per level.
- **Destruction:** a plot whose unit reaches 0 HP is **destroyed**. The plot empties with no
  refund (the rubble is shown), and it can be rebuilt.
- **Repair:** a damaged unit's card offers REPAIR, at a coin cost per HP. That's another coin
  sink.
- **Who damages units: only the Ravager** (for now). E5b's skill tree adds "a fallen unit
  explodes".

### 3.2 New enemies

| Enemy | Role / the habit it punishes | Mechanic | Weak to | Resists | Stats |
| --- | --- | --- | --- | --- | --- |
| **Ravager** | Pads placed hugging the path | While walking, it stops at the first built pad within 90 of it and mauls it (8 per 0.8 s) until the unit falls, then walks on | Kinetic (the MG shreds it) | Cryo | HP 30, speed 40, armour 1, gate strike 8 |
| **Splitter** | Killing late | When it dies it bursts into 3 Skitters at its spot. Killed near the gate, they're at the gate | Explosive (the splash kills the brood too) | Kinetic | HP 22, speed 32, gate strike 6 |
| **Mender** | Chip damage | Heals enemies within 80 by 6% of their max HP per second (not itself) | Piercing (a Sniper picks it off) | Explosive | HP 18, speed 34, gate strike 3 |

### 3.3 Elites

`EliteDef` is data: HP ×, speed ×, extra armour, regeneration (fraction of max HP per second),
and a tint. A `SpawnEntry` can mark its group elite.

| Elite | Effect | Tint | Answer |
| --- | --- | --- | --- |
| **Armoured** | +3 armour, ×1.3 HP | Gold | Piercing, or AP rounds |
| **Swift** | ×1.45 speed | Cyan | Cryo |
| **Regenerating** | +4% max HP per second | Green | Burst |

- Elites are tinted, with a small "★" over their HP bar.
- The build preview marks an elite group with a tinted icon and a ★.
- They appear in late waves (from about 7 on the Outpost, earlier on the Canyon).

## 4. Risks

- **Balance:** unit loss compounds; a destroyed Sniper is 50–150 coins gone. The Ravager is
  introduced alone (at most two), and its weakness (the MG) is cheap.
- **Splitter children mid-iteration:** they spawn while hits are being resolved. They are
  inserted in sorted position, so targeting's binary search stays valid within the same tick.
- **Performance:** the Mender scans its neighbours (there are few Menders), and Ravagers check
  the few plots near them. Both are measured under `--stress`.
