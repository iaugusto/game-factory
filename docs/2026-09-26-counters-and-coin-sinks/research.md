# Counters and coin sinks (E3): research

_Work item opened 2026-09-26. It is step **E3** of the escalating-difficulty track
(`ROADMAP.md`)._

## 1. The request (user, 2026-09-26)

> on what to spend money, they can build barricades before the wall, 1 only that can be
> upgraded to level 3. each maxed spot can also get a boost status, which increase their damage
> by 25%. we can also have skill trees between maps [...] we also don't need to be stuck in 3
> lanes [...] we should have certain units that are particularly efficient for certain enemy
> types, so there's that doom eternal feeling of having to know which weapon to use for each
> enemy [...] the player can replace a spot's unit.

After the proposal ("I like all of these, for 1 I take your suggestion on it. let's build
this"), the user added:

> refund has to be a costly decision, perhaps 50% back only

> units can be destroyed as you suggested

### Decisions

| Topic | Decision |
| --- | --- |
| Units | They can be destroyed, **by specific enemies only**. That comes with E5's new enemies. |
| Barricade | **One**, placed by the player on a slot in front of the wall (one per lane), and **movable between waves**. Levels 1–3, with HP; enemies stop and attack it; repairs cost coins. |
| Selling | Refunds **50%** of everything spent on the unit, always. Replacing is a costly decision. |
| Maxed unit | Buys **one mastery**: a choice between the user's **+25% damage** "Overcharge" and a unit-specific trait. |
| Suggestions accepted | A wave preview and intel cards; gate repair between waves; the active ability, synergies and elites (these three land later). |

### How the work splits

| Step | Scope |
| --- | --- |
| **E3 (this)** | The type chart, selling/replacing, wave preview and intel cards, the barricade, masteries, gate repair, and waves re-authored around counters. |
| E4 | Maps from paths: not stuck in 3 lanes. |
| E5 | Destroyable units and their enemy, new enemies, the campaign and the skill tree (plus the save wiring), elites, the active ability, synergies. |

## 2. The "Doom Eternal" loop: what makes it work

In Doom Eternal (id Software, 2020), each demon has a *designated answer*. Examples: the
Precision Bolt pops a Revenant's cannons, and the Ice Bomb freezes a Marauder's window. The
game makes it work in three ways:

1. **It telegraphs the weak point** with glowing parts, audio and a codex entry on first
   sight.
2. **It makes the right answer much better, not slightly better.** The weak point is often a
   ×2–×3 multiplier, or a whole mechanic like staggering or disarming.
3. **It makes the wrong answer feel bad but not useless.** Resisted is not immune.

Hugo Martin's talks on "combat chess" describe the goal: the player reads the arena and picks
the tool. Refs:
<https://doom.fandom.com/wiki/Weak_point>;
<https://www.gamedeveloper.com/design/doom-eternal-s-combat-chess> (interview coverage).

**The tower-defense counterpart** is Bloons TD 6's bloon properties:
- lead is immune to sharp;
- camo needs detection;
- ceramic shells need burst.

They force diversity without a big matrix, since each property has *one* clear answer.
<https://www.bloonswiki.com/Bloon_properties>

### Takeaways for a phone-sized design

1. **A small chart.** 4 damage types. Each enemy has **one weakness** (×2) and **at most one
   resistance** (×0.5).
2. **Armour as a separate lever.** A flat reduction per hit punishes rapid, light weapons (MG,
   Rifleman) and rewards heavy single shots. It works without a table, and it is exactly what
   the Carapace's look promises.
3. **A tell for every relationship:**
   - An **intel card** the first time an enemy appears: its name, what it does, and "weak to"
     and "resists" shown with the units' icons.
   - A **wave preview** in the build phase: which enemies come next.
   - **Hit feedback:** weak hits spark bright, resisted hits "ping" grey.
   - **"Strong vs"** on every unit in the build menu.
4. **Swapping must cost something.** At a 50% refund (the user's call), the right answer is
   worth building ahead of time, and a wrong build hurts. That matches "knowing which weapon
   to use".

## 3. The chart

**Damage types:**

| Type | Units |
| --- | --- |
| Kinetic | MG Nest, Rifleman |
| Explosive | Mortar |
| Piercing | Sniper, Rail Cannon |
| Cryo | Cryo Projector |

**Enemies:**

| Enemy | Weak to (×2) | Resists (×0.5) | Armour (per hit) | The tell |
| --- | --- | --- | --- | --- |
| Skitter | Kinetic | Piercing (overkill wasted) | 0 | Fast and fragile: spray it |
| Drone | Explosive | — | 0 | Comes in packs: splash it |
| Spitter | Cryo (the gland freezes) | Kinetic | 0 | Glowing gland |
| Carapace | Piercing (the vent) | Explosive | 3 | Armoured shell, glowing vent |
| Hive Queen | Piercing | Cryo | 4 | Boss |

- **Armour:** damage is reduced by the armour value, down to a floor of 15% of the hit.
  Examples:
  - MG (1 damage per bullet) into a Carapace: 0.15 per bullet. Its fire rate makes up only a
    little of that.
  - A Sniper (18) into a Carapace: 15 left after armour, ×2 = 30.
- **Numbers:** they're tuned with the bot. The chart itself is data (`UnitDef.damage_type`,
  `EnemyDef.weak_to` / `resists` / `armor`), so it can be tuned without code changes.

## 4. Coin sinks

**The barricade:**
- **Slots:** one in front of the wall in each lane (y ≈ 770). The player builds **one**
  barricade on a slot.
- **Moving it:** in BUILD, tapping another slot moves it there for free, keeping its level and
  HP.
- **Levels:** 1–3 (HP 60 / 140 / 260; costs 30 / 40 / 60).
- **Enemies at a barricade:** those in its lane stop in front of it and strike it with their
  `wall_damage` on their `attack_interval`. It's the same code path as the gate siege.
- **When it breaks:** they walk on. Rubble stays, and **repair** refills HP at a coin cost per
  HP, any time coins can be spent.
- **Why it's good:** enemies bunch in front of it, which makes a kill zone for Mortar splash
  and Cryo. The Queen's 999 strike smashes it instantly, and that's intended.

**Masteries:**
- At max level, a unit can buy one mastery: **Overcharge** (+25% damage, the user's) or its
  own trait.
- A `MasteryDef` is data with generic fields: damage, reach, reload, splash, slow, and armour
  pierce. Each trait is a combination of those:

  | Unit | Trait |
  | --- | --- |
  | MG | AP Rounds: ignores armour |
  | Rifleman | Marksman: +25% reach |
  | Cryo | Deep Freeze: slows 25% harder |
  | Mortar | Heavy Shells: +40% splash |
  | Sniper | Bolt Action: −25% reload |
  | Rail | Capacitors: −20% reload |

**Selling:**
- A 50% refund of everything spent on the plot (build + upgrades + mastery), always.
- A unit built mid-wave takes `build_setup_time` (1 s) before its first shot, so a swap during
  a wave is never instant.

**Gate repair:**
- BUILD only.
- +25 HP for 20 coins, up to max.

## 5. Waves re-authored around counters

The same 10 waves, each built from named patterns in chosen lanes, not random ones. Each wave
teaches or tests one relationship:

| Waves | Pattern |
| --- | --- |
| 1–2 | Drone lines (the basics) |
| 3 | The Carapace appears with its intel: "weak to piercing" |
| 4 | Spitters appear behind a Drone screen |
| 5 | Escort: Carapaces leading Skitter packs in one lane |
| 6 | Split pressure: a swarm in one lane, a Carapace pair in another |
| 7–9 | The mixes combined |
| 10 | The Queen with escorts |

Volume and composition carry the ramp. `hp_scale` stays the gentle E2 curve for now. The full
threat-budget director is still future work (E5 or live ops). A light version comes now:
`EnemyDef.threat` and a content test that wave threat grows each wave.

## 6. Risks

- **Too much UI on a phone:** the build menu gains "strong vs", sell and mastery. It needs a
  still review.
- **Balance:** the bot needs to know counters, or its numbers stop meaning anything. It will
  build toward the next wave's weaknesses. That's a fair model of a player who reads the
  preview.
