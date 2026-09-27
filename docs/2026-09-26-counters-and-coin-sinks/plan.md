# Counters and coin sinks (E3): plan

## Core

- **`UnitDef`:**
  - `enum DamageType { KINETIC, EXPLOSIVE, PIERCING, CRYO }`;
  - `damage_type`, `masteries: Array[MasteryDef]`, `mastery_cost`.
- **`EnemyDef`:**
  - `weak_to` and `resists` (`@export_flags` over the damage types);
  - `armor`, `threat`, `description`.
- **`MasteryDef` (new):** `id`, `title`, `description`, and multipliers/bonuses for damage,
  reach, reload, splash, slow and armour pierce.
- **`BarricadeDef` (new):** `hp_per_level`, `costs`, `repair_cost_per_hp`.
- **`MapDef.barricade_slots`:** a `PackedVector2Array`.
- **`RunConfig`:**
  - `weak_multiplier` (2), `resist_multiplier` (0.5), `armor_floor` (0.15);
  - `sell_refund` (0.5), `build_setup_time` (1.0);
  - `gate_repair_hp` (25), `gate_repair_cost` (20);
  - `barricade: BarricadeDef`.
- **`CombatSim`:**
  - `effective_damage(e, raw, type, armor_pierce)`, a pure static helper that applies the
    chart and armour. Every hit goes through it.
  - A new signal `enemy_hit(enemy, amount, effect)`, with effect +1 for weak and −1 for
    resisted, emitted only when the effect isn't neutral. The views use it for the spark or
    ping.
  - Per-plot stats: `plot_damage(plot)`, `plot_reach(plot)`, `plot_reload(plot)`,
    `plot_splash`, `plot_slow`. These fold in modifiers, the mastery and the boost.
  - **The barricade** (`Barricade` class: `slot`, `lane`, `y`, `level`, `hp`,
    `max_hp()`):
    - An enemy in its lane that reaches `y − radius` while it stands stops and sieges it
      (`Enemy.siege_barricade`).
    - A strike hits the barricade instead of the gate.
    - When it breaks, the signal `barricade_broken` goes out, the besiegers resume walking,
      and `hp` stays 0 until repaired.
    - Signals: `barricade_struck`, `barricade_broken`.
  - Spitters don't spit while attacking anything.
- **`Run`:**
  - `sell(plot) -> int` (50% of `plot.spent`, in BUILD and WAVE);
  - `buy_mastery(plot, index)` (max level only);
  - `build` sets the setup cooldown mid-wave and tracks `plot.spent`;
  - `repair_gate()` (BUILD only);
  - the barricade: `barricade_cost()`, `build_barricade(slot)` (it moves the barricade when
    one already stands, in BUILD only), `upgrade_barricade()`, `repair_barricade_cost()`,
    `repair_barricade()`;
  - `state_hash` covers all of it.
- **`WaveSchedule`:** `enemy_counts(wave)` (id → count) and `new_enemies(waves, index)` (types
  first seen in wave `index`).
- **`Autoplay`:**
  - It picks units that counter the next wave's weaknesses, weighted by count × threat.
  - It builds and upgrades the barricade in the busiest lane.
  - It buys masteries (Overcharge) and repairs the gate when low.
  - It never sells (a knob).

## Data

- Unit types and masteries: 7 `.tres` files (Overcharge, plus 6 traits).
- Enemy weaknesses, resistances, armour, threat and descriptions.
- `barricade.tres`; barricade slots on `outpost`.
- Waves 1–10 re-authored in patterns and lanes.

## Art (`tools/`)

- `props`: a `barricade_1..3` series (sandbags → steel), plus rubble.
- `fx`: 4 small damage-type icons (`ui/dmg_kinetic` …).

## UI

- **`BuildMenu`:**
  - On an empty plot, each unit's ring label shows its type icon, and the card shows
    "Strong vs".
  - On a built plot, the card gains a SELL button (+N) and, at max level, 2 mastery buttons.
- **`BarricadeMenu`**, a card opened on a barricade slot: build, move here, upgrade, repair.
- **`BuildBar`:** the next wave's preview (enemy icons × count) and a REPAIR GATE button.
- **`IntelCard`** (new): shown in BUILD for enemy types new this wave. It gives the name, the
  description, and "Weak to" / "Resists" as unit icons. A tap closes it.
- **`EnemyIcon`** (new): frame 0 of an enemy's atlas.
- **`BarricadeField`:** its view shows the level sprite, an HP bar and rubble; empty slots show
  faintly during BUILD only.
- **Fx:** `weak_hit` (a bright yellow spark) and `resisted_hit` (a grey ping), both capped.

## Tests

- **Core:**
  - the chart math (weak, resist, armour floor, armour pierce);
  - a mastery's effect on damage and reload;
  - sell refunds 50% and empties the plot;
  - the setup time mid-wave;
  - buying a mastery only at max level, only once;
  - the barricade: it blocks its lane only, takes strikes, breaks and enemies continue,
    repair costs coins, it can move in BUILD but not mid-wave, and there's only one;
  - gate repair;
  - `WaveSchedule` counts and new types.
- **Content:**
  - every enemy has exactly one weakness, and it's not also a resistance;
  - every damage type counters some enemy;
  - the waves' threat rises;
  - every unit has Overcharge plus one trait;
  - barricade slots sit on lane centres in front of the wall.
- **Scene:**
  - sell from the card;
  - buy a mastery;
  - barricade build, move and upgrade from its menu;
  - the intel card shows on first sight;
  - the preview lists the next wave;
  - gate repair.
- **Integration:** the guards, re-tuned (zero meta: median 6–8, 0 wins; mid meta: some wins).
