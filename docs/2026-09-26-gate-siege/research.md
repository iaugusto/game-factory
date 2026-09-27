# Gate siege and enemies that disable units: research

_Work item opened 2026-09-26. It is step **E2** of the escalating-difficulty track
(`ROADMAP.md`). Its options were laid out in
[`../2026-09-26-escalating-difficulty/research.md`](../2026-09-26-escalating-difficulty/research.md)
§7._

## 1. The request

The user picked loss option 2:

> 2 sounds good

That option: enemies that reach the gate **stop and attack it** instead of vanishing. The
wall's spots fire at them point-blank. **The run is lost when the gate breaks.**

The user had also accepted that enemies may **hurt or disable fixed units** (§6 Q3 there),
which this step builds.

## 2. Today

- `CombatSim._move_enemies`: an enemy that reaches `wall_y` is removed and adds its
  `wall_damage` once (Drone 5, Skitter 3, Carapace 15, Queen 999).
- The loss is abstract: a bar empties and the result says "THE WALL FELL".
- Nothing can affect a unit. `Plot` has no state beyond its cooldown and target.

## 3. Prior art

- **Plants vs. Zombies:** zombies that reach a plant stop and chew it. The *stop-and-attack*
  moment is readable and gives the player a window to react: a crowd at the line is a visible
  emergency. A lawnmower is the last-chance mechanic before the loss.
  <https://plantsvszombies.fandom.com/wiki/Lawn_Mower>
- **Kingdom Rush:** soldiers block and melee at the rally point, and enemies stop to fight
  them. The fight at the line is where tension peaks.
- **Bloons TD 6:** leaks cost lives instantly. That's clear, but invisible, the loss style
  option 2 rejects.
- **Disabling towers:** Kingdom Rush's Frontiers Shamans and Arknights' casters that "stun"
  operators force redundancy. Stun beats destruction for readability and fairness, because
  the player's investment isn't wiped.

## 4. Design

### 4.1 The siege

- An enemy that reaches the gate line **stops** at `wall_y` and **strikes** every
  `EnemyDef.attack_interval` seconds (default 1.0) for `wall_damage` per strike. Its first
  strike lands on arrival.
- It stays **targetable**. Every unit in reach keeps firing, and the wall spots are right
  there.
- A sieging enemy is still "alive": the wave doesn't end until it's killed.
- **The Queen's single strike is 999.** A Queen at the gate breaks it at once. That is
  unchanged, and it stays the boss's threat.
- **Loss:** gate HP ≤ 0. The presentation has three beats:
  1. A **breach moment**: a heavy shake, a flash along the wall, the banner "THE GATE HAS
     FALLEN", and a 1.2 s slow-motion.
  2. The result screen fades in.
  3. The title reads "THE GATE FELL".

  This is option 2. Option 4's "pour-in" sequence is left out.
- **Siege visuals:**
  - A sieging enemy stops its walk cycle and **lunges** toward the gate on each strike (an
    offset in its batch transform).
  - A spark flash marks the strike point.
  - A small "−N" popup shows the damage.
  - The HUD's wall label becomes **GATE**.
- **Balance consequence:** damage is now per strike, over time, so an unkilled enemy is worse
  than before. Wall spots and back-row plots become the answer, which fits "hold the gate".
  Per-strike damage is retuned with the bot.

### 4.2 Enemies that disable units: the Spitter

The first enemy that acts on a fixed unit.

- **Spitter** (mid speed, mid toughness): walks the lane. Every `spit_interval` seconds, it
  **spits acid at the nearest working unit within `spit_range`**.
- The glob flies as a projectile and always lands, since plots don't move.
- **On landing, the unit is disabled for `disable_duration` seconds.** It can't fire, and its
  reload is paused.
- **Disable, not destroy:**
  - It is readable: the unit is gooed, greyed, with a countdown ring.
  - It is fair: the coins aren't lost.
  - It asks for redundancy and for killing Spitters early.
  - "Hurt" (unit HP, destruction) can come later if disabling proves too soft.
- **Counterplay:**
  - `spit_range` (140) is shorter than the Sniper (430), the Rail (320) and the Mortar (290).
  - Long-reach units placed deep kill Spitters before they are in range.
  - This is a content rule: at least one unit must outrange every spitter.
- The data is generic: any `EnemyDef` with `spit_interval > 0` spits. E5's enemies reuse it.

| Stat | Value |
| --- | --- |
| HP | 14 |
| Speed | 30 |
| Wall damage | 4 per strike |
| Gold | 2 |
| Radius | 13 |
| `spit_range` | 140 |
| `spit_interval` | 3.5 s (the first spit comes as soon as a unit is in range) |
| `disable_duration` | 4 s |
| Glob speed | 260 |

- **Where it appears:** waves 4–10, in small groups (2–5), so it is taught first. Wave 4
  brings one Spitter pair and little else in that lane.
- **Art:** a new generated two-frame atlas. It is a squat bug with a swollen, glowing acid
  gland on its back and a spout. It is teal with a lime glow, a silhouette unlike the Drone's
  or the Skitter's.

## 5. Risks

- **Balance:** siege damage over time could make the wall far deadlier. It gets retuned with
  the zero-meta and mid-meta probes (the targets are unchanged: zero meta clears 6–9 waves
  and doesn't win; mid meta wins some).
- **Enemies stacking at the gate draw on top of each other.** The lane jitter spreads them in
  x. That is acceptable for now; E4's paths will add crowding.
