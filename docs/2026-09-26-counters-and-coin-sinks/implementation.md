# Counters and coin sinks (E3): implementation log

## 2026-09-26 — decisions taken in the conversation

- **Units can be destroyed**, by specific enemies (E5, together with the enemy that does it).
- **Selling refunds 50%, always** (the user: "refund has to be a costly decision"). This
  replaces the proposed 100% between waves.
- **The barricade** is placed by the player on a slot and moves between waves, as proposed.
- **In E3:** the type chart, sell/replace, the wave preview and intel cards, the barricade,
  masteries, gate repair, and the waves re-authored.
- **Later:**
  - maps from paths (E4);
  - the skill tree, sectors, destroyable units, elites, the active ability and synergies
    (E5).

## 2026-09-26 — core

- **Defs:**
  - `UnitDef` gains the `DamageType` enum (KINETIC, EXPLOSIVE, PIERCING, CRYO),
    `damage_type`, `masteries`, `mastery_cost`, and `beam_max_targets`.
  - `EnemyDef` gains `description`, `weak_to` and `resists` (flags), `armor`, and `threat`.
  - New `MasteryDef`: bonuses for damage, reach, reload, splash, slow and slow time, plus
    armour pierce.
  - New `BarricadeDef`: HP per level, costs, and repair cost per HP.
  - `MapDef.barricade_slots`.
  - `RunConfig` gains `weak_multiplier` 2, `resist_multiplier` 0.5, `armor_floor` 0.15,
    `sell_refund` 0.5, `build_setup_time` 1.0, `gate_repair_hp` 25, `gate_repair_cost` 20,
    and `barricade`.
- **`CombatSim`:**
  - `effective_damage` (static): armour first (reduced by pierce, floored), then the chart
    multiplier. **Every hit goes through it.**
  - `enemy_hit(enemy, amount, effect)`, emitted only when the chart changed the hit.
  - Per-plot stats `plot_damage/reload/reach` and the `*_for(def, level, mastery)` functions
    fold in modifiers, mastery and boost. Shots carry the damage type and armour pierce.
  - `Barricade` (owned by the sim, driven by Run):
    - An enemy in its lane that crosses the stop line stops (`sieging` + `at_barricade`) and
      strikes it through the same `_strike` as the gate.
    - When it breaks (`barricade_broken`), the attackers resume walking.
    - The signal `barricade_struck`.
  - **Escorts:** a small enemy can't pass a much bigger one directly ahead in its lane
    (`_big_one_ahead`: radius gap ≥ 5, looking up to 4 enemies ahead). Without this, the
    "Carapaces lead, Skitters behind" pattern couldn't exist: Skitters (speed 105) overtook
    Carapaces (speed 20) within a second.
  - Beams stop at `beam_max_targets`.
- **`Run`:**
  - `sell_value` and `sell` (50% of `Plot.spent`, which tracks build, upgrades and mastery).
  - `mastery_cost` and `buy_mastery` (max level, once).
  - `build` sets the 1 s setup cooldown mid-wave.
  - `repair_gate` (BUILD only).
  - The barricade: `barricade_cost`, `build_barricade` (a free move when one stands, BUILD
    only), `upgrade_barricade` (HP grows by the level difference), `barricade_repair_cost`,
    `repair_barricade`.
  - `state_hash` covers all of it.
- **`WaveSchedule`:** `enemy_counts`, `new_enemies`, `threat`. **`Counters`** (new, pure): the
  chart queries used by the UI.
- **`Autoplay`:**
  - It counter-picks by "filling the biggest gap". For each enemy type in the wave at hand, it
    weighs count × threat against the kills per second the built units deal to it, then picks
    the most cost-effective unit against the worst-covered type.
  - It saves for that unit, unless enemies are already at the gate; then it builds the best
    affordable one next to them.
  - It raises the barricade after 3 units, in the most threatened lane, and moves it there
    each build phase.
  - It repairs the gate below 70% and the barricade when broken.
  - It buys masteries (Overcharge) and barricade levels among its "cheapest upgrades".

## 2026-09-26 — content

- **The chart:**

  | Enemy | Weak to | Resists | Armour | Threat |
  | --- | --- | --- | --- | --- |
  | Skitter | kinetic | piercing | 0 | 0.6 |
  | Drone | explosive | piercing | 0 | 1 |
  | Spitter | cryo | kinetic | 0 | 2.5 |
  | Carapace | piercing | explosive | 3 | 20 |
  | Queen | piercing | cryo | 4 | 150 |

  Each enemy also has an intel line.
- **Unit types:** MG and Rifleman are kinetic; Mortar explosive; Sniper and Rail piercing;
  Cryo cryo.
- **Masteries** (7 `.tres`): Overcharge (+25% damage) for every unit, plus AP Rounds (MG),
  Marksman (Rifleman), Deep Freeze (Cryo), Heavy Shells (Mortar), Bolt Action (Sniper) and
  Capacitors (Rail). Mastery costs are 50–140.
- **Barricade:** HP 60/140/260, costs 30/40/60, repairs at 0.25 coins per HP. Slots at
  (90/270/450, 770).
- **Waves 1–10 re-authored** from named patterns in chosen lanes: Drone lines, Skitter bursts,
  the Carapace intro, Spitters behind a Drone screen, escorts, split pressure, swarm, siege,
  and the Queen with an escort. Crates are unchanged.
- **Rail:** beam capped at 3 targets, cost 85, reload 4.6 s.

## 2026-09-26 — art

- `props/barricade_1..3` (sandbags; + a timber and steel frame; + spikes) and
  `props/barricade_rubble`.
- The damage-type badges `ui/dmg_kinetic|explosive|piercing|cryo`.
- 41 SVGs; they were checked on a preview sheet.

## 2026-09-26 — UI

- **`BuildMenu`:**
  - The ring shows a damage badge on every unit.
  - The unit card shows its stats, its type and "strong vs" (from `Counters`), UPGRADE (or
    two mastery buttons with prices and descriptions at max level), and "SELL +N".
- **`BarricadeField`:** faint hazard outlines on empty slots (between waves, or until one is
  built); the level sprite or rubble; an HP bar; a shake on strikes; the selection.
- **`BarricadeMenu`:** build, move here (between waves), upgrade, repair.
- **`BuildBar`** (now 150 tall):
  - "NEXT": the coming wave's enemy pictures × counts;
  - "REPAIR GATE +25 ● 20";
  - START.
- **`IntelCard`:** "NEW THREAT" for each type new that wave, with its picture, name,
  description, and "weak to" / "shrugs off" as unit icons. A tap closes it.
- **`EnemyIcon`:** frame 0 of an enemy's atlas.
- **Fx:** `weak_hit` (a gold spark) and `resisted_hit` (a grey ping), throttled to 14 per
  second each in `RunController`. A barricade strike uses a gate-strike spark; a break gives an
  explosion and "BARRICADE DOWN".
- **`RunController`:** input priority is crate > plot > barricade slot. It wires sell,
  mastery, repair, the barricade, the intel card and hit feedback.

## 2026-09-26 — tests

- **New `counters_test` (10 cases):**
  - weak ×2 / resist ×0.5;
  - the armour floor and AP pierce;
  - hits go through the chart and report it;
  - the `Counters` queries;
  - masteries only at max level and once;
  - a mastery's reload effect;
  - selling refunds 50% and empties the plot;
  - the setup time mid-wave;
  - gate repair only between waves;
  - `WaveSchedule` counts, new types and threat.
- **New `barricade_test` (6 cases):**
  - one barricade, built, upgraded and priced;
  - moves only between waves, keeping level and HP;
  - blocks its lane only and takes the strikes;
  - breaks, enemies walk on, and repair restores it;
  - small enemies bunch behind a big one;
  - beam target cap.
- **`content_test` (+5):**
  - one weakness per enemy, never also resisted;
  - every damage type has an enemy weak to it and a unit;
  - wave threat strictly rises;
  - every unit offers Overcharge plus its own trait;
  - barricade slots sit on each lane in front of the wall.
- **`run_scene_test` (+4):**
  - the unit card sells and offers masteries at max level;
  - barricade slots open the card (build, upgrade, move);
  - the build bar previews the wave and repairs the gate;
  - intel cards on first sight only.
- **Fixture:** barricade slots and a `BarricadeDef` in `Fixtures.config`.
- **Fix:** the build bar and intel card `queue_free`'d replaced children, which GdUnit counted
  as 236 orphans (exit 101). They now `remove_child` + `free()`.
- **Result:** `scripts/test.sh` → **148/148 passed, 0 orphans**. Tools → **5/5 OK**.

## 2026-09-26 — balance (bot probes, 12 seeds; mid meta as in E1/E2)

1. **First run after the chart:** zero meta cleared 0–3 waves. The bot's build order put a
   single Mortar out and then saved for a second while a leaked Drone besieged the gate. Two
   fixes: build next to siegers, and pick among affordable units when under siege.
2. **Next, most runs died at wave 3.** Riflemen against the first Carapace deal 0.2 per hit,
   which is the chart working. The bot was ignoring the Carapace because 16 Drones dominated
   its per-wave score. It now fills the biggest gap. Carapace threat 8 → 20, Queen 60 → 150.
3. **Then it went bimodal.** Zero meta either died at waves 3–4 or won (6/12), and mid meta
   won 12/12, with **Rails dominating** (a piercing beam through the whole lane).
   - Rail: beam capped at 3 targets, cost 85, reload 4.6 s.
   - HP schedule: 1, 1.35, 1.8, 2.4, 3.4, 4.8, 6.8, 9.4, 12.4, 15.5. That's gentler early
     than E2's, and steeper late, because masteries, the barricade and counter-picking make
     late waves easier.
4. **Rails still made up most of the mid-meta rosters.** Drones now **resist piercing**, so
   the Sniper and Rail are the armour answer, not the answer to everything. The bot also
   assumed a beam hits 2 enemies; 1.3 is realistic for armoured targets.
5. **Final, on the real data:**
   - **Zero meta:** waves [2, 7, 7, 7, 7, 8, 8, 8, 8, 8, 8, 8], **median 8, 0 wins**.
   - **Mid meta:** median 10, **6/12 wins**.
   - The integration guard (8 seeds): [7, 8, 8, 2, 8, 7, 8, 8], 0 wins.
6. **Finding, not fixed here:**
   - The bot now gets by with **Snipers and Mortars** alone (zero meta: 83 Snipers, 32
     Mortars, 7 Riflemen and 3 MGs over 12 runs). Skitters and Spitters don't threaten
     enough to *demand* their counters (MG/Rifleman, Cryo).
   - One experiment (Skitter strike 3 → 6, Spitters every 3 s and jamming for 5 s) changed
     neither the rosters nor the results, so it was not applied.
   - Making each enemy demand its own counter is a wave-design job for the next tuning pass.
     Candidates:
     - Skitter swarms that outrun splash;
     - Spitters that target the most expensive unit in range;
     - fewer Drones and more mixed packs.
   - It needs the user's hands on it; bot rosters are only a proxy for player choices.

## 2026-09-26 — running the game

- **Frame time** (`--stress --perf`, WSLg): about 120 fps, frame average 8.2–8.4 ms, max
  about 13 ms, 75–85 draw calls.
  - The first measurement showed a **sim tick of 1.2 ms** (E2: about 0.65). The escort check
    ran for every enemy.
  - Lanes with nothing big enough to block now skip it: **0.87–0.99 ms**. The rest is the
    chart per hit and the hit signals.
  - Within the desktop budget. Worth watching on the phone (B5).
- **Clips** (`captures/`):
  - `e3-intel.mp4`: the build phase of wave 3. The preview shows Drone ×16, Carapace ×1,
    Skitter ×6, the REPAIR GATE button, and the Carapace intel card (weak to Sniper and Rail;
    shrugs off MG, Rifleman, Cryo and Mortar).
  - `e3-card.mp4`: the Mortar's card: "Explosive · strong vs Drone", UPGRADE ● 45 greyed
    (32 coins), SELL +22.
  - `e3-midgame.mp4`: seed 2, wave 6, autoplay. A Drone swarm in lane 0, a Carapace pair and
    Spitters in lane 2, and the bot's barricade in lane 2.
- **Still open from earlier (not bugs):** the "WAVE N INCOMING" banner shows behind open cards
  and overlaps "WAVE N".

**Status: complete.**

**👤 For the user:** play it by hand. Do the intel cards, preview and "strong vs" make the
right weapon readable? Does 50% selling feel costly but usable? Does the barricade create a
kill zone?
