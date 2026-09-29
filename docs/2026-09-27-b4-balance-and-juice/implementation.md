# B4 — Balance bot, tuning and juice: implementation log

## 2026-09-27 — scope

- The user said "let's keep going, just stop when everything is done", then, mid-B4, "you can
  let me play before the android work". So **B4 ends with a hand-play checkpoint, and B5
  waits**.
- The research and plan restate B4's done-criteria for the campaign era (research §1, §4).

## 2026-09-27 — the balance bot

- **`Autoplay.preset(name)` and `Autoplay.PRESETS`:** the 8 strategies are smart, casual,
  no_strike, no_links, cycle, heavy, light and no_loot.
- **`core/balance_run.gd` (`BalanceRun`):**
  - `PROFILES` (T0/T3/T6, moved here from the integration test, which now uses
    `profile_mods`);
  - `play(cfg, mods, seed, strategy)` returns a flat record: won, waves, gate, ticks,
    strikes, links, unspent, crates, kills, and leaks (gate damage per enemy type).
- **`game/tools/balance_sim.gd`:** a headless SceneTree script, one cell per process, writing
  JSON lines. It takes an optional `hp=` for sweeps.
- **`tools/src/gf_tools/balance/`:**
  - `runner`: parallel processes, one per cell;
  - `report`: aggregation, the research §4 target checks, and Markdown rendering;
  - `cli`: `uv run balance --seeds N --maps … --strategies … --hp map=x --out …`.
  - Tests: `tests/test_balance.py` (4). Tool tests: 10/10 green.
- **Speed:** about 2 s per run, so 1,200 runs take a few minutes on 15 jobs.

## 2026-09-27 — juice

- **Buttons:** every `UiTheme.style_button` button squashes on press (0.94 then a spring back,
  on real time, so it works in slow motion and under tips).
- **The result screen:** earned stars pop in one by one after the fade (`StarRow.pop_in`), and
  "Gate held" counts up from 0.
- **The strike:** a shell falls into the blast along a trail while the telegraph ring closes.
- **Upgrades:** a unit pops like on build (`PlotView` tracks the level).

## 2026-09-27 — baseline (`report-baseline.md`, 1,200 runs, 50 seeds)

Targets met: 6/16. The big finding was that **`heavy` (Mortar, Sniper and Rail only) won
84–92% on every sector**, beating the counter-picking `smart` (34–74%). `light` (MG, Rifleman,
Cryo) won 0% and died around wave 5. Reading the chart didn't pay. That's the open E3 issue,
at full strength.

**Why:**
- Pads are scarce (11 on Outpost) and coins aren't, so **damage per pad** decides. The light
  units did 2.5–6 damage per second per pad against 10–17 for Mortar and Rail. Late enemy HP
  (×7–12) makes 1-damage bullets useless against armour.
- **Mortar splash covered Skitters.** They only resisted piercing, so kinetic units were never
  needed.
- **The smart bot's own logic was weak:**
  - It filled pads with Snipers.
  - It scored needs by `threat`, where Skitters rate 0.6 and Carapaces 20.
  - It measured coverage in DPS, ignoring overkill: a 9-damage round on a 3-HP Skitter still
    kills only one.

## 2026-09-27 — tuning iterations (20 seeds unless noted; win % smart / heavy)

| # | Change | Outpost | Canyon | Switchback | Verdict |
|---|---|---|---|---|---|
| A | MG dmg 1→1.5, Rifleman 1.5→2.5, Cryo 2.5→3.5; Rail beam targets 3→2; Mortar splash 55→45; the bot scores per √cost | 65/70 | 45/70 | 65/75 | heavy −20, still on top |
| B | + Skitter counts ×1.6 from wave 5 | 60/60 | 35/55 | 40/75 | Skitter leaks rise |
| C | + **Skitters also resist explosive** (shells miss them) | 50/55 | 20/25 | 20/50 | heavy leaks Skitters 100+/run; so does the bot |
| D | the bot counts kills per second (with overkill) | 40/55 | 10/25 | 20/50 | still Sniper-heavy |
| E | the bot's need = count × gate damage (not `threat`) | 60/55 | 25/25 | 15/50 | smart ≥ heavy on 2 sectors |
| F | the bot scores marginal coverage over the whole mix | 10/55 | 20/25 | 0/50 | rejected: undervalues tanks |
| G | the same, normalised per type | 0/55 | 0/25 | 0/50 | rejected: MG spam fills every pad |
| H | E's bot + a 2-wave look-ahead; Skitter gate damage 3→4 | 40/55 | 40/35 | 15/35 | kept |
| I | a `mixed` build (every damage type) for comparison, 30 seeds | 43/57 (mixed 50) | 47/40 (43) | 13/43 (13) | Switchback favours reach |

**Switchback HP**, `smart` / `heavy` / `casual`, 30–40 seeds:
- ×0.85: 3% / 87% / 13%;
- ×0.75: 77% / 90% / 90%;
- ×0.8: 72% / 88% / 62%;
- **×0.82: 45% / 88% / 42%.** Kept.

It's a cliff, not a curve, because runs are decided by whether the build kills the Hive
Queen: one strike from her breaks the gate, and her HP scales with the wave (×10 on the last
Switchback wave).

**Rejected on purpose:** more smart-bot planning (a sell-and-replace policy, a portfolio
choice). It measures my bot's cleverness more than the game's design. Iterations F and G
showed that simple greedy variants swing wildly.

## 2026-09-27 — final state (`report.md`, 1,200 runs, 50 seeds, 8 strategies; `mixed` was measured in iteration I and is now in the CLI's default list)

**Data changes kept:**

| What | Change |
|---|---|
| MG | damage 1.5 |
| Rifleman | damage 2.5 |
| Cryo Projector | damage 3.5 |
| Rail Cannon | beam targets 2 |
| Mortar | splash 45 |
| Skitter | resists piercing **and explosive**; gate damage 4; counts ×1.6 from wave 5 on every map |
| Switchback | `hp_scale` ×0.82 |

**Bot changes kept:**
- kill-rate coverage;
- need = count × gate damage;
- a 2-wave look-ahead;
- √cost scoring;
- the `mixed` preset.

**Targets, 8/13 met:**
- `smart` wins 38 / 38 / 46% (Outpost / Canyon / Switchback): all in band.
- `casual` wins 48 / 34 / 42%. Outpost and Switchback are a little over the 40% ceiling.
  That's reasonable for sector 1, and I reported it rather than move the target.
- The casual median wave on Outpost is 8.
- `no_loot` is far below `casual` on every sector.
- **"Fixed builds ≥ 10 points below smart" is missed on all three sectors:**
  - `heavy` wins 50 / 34 / 86%. It's roughly even with `smart` on Outpost and Canyon, and
    dominant on Switchback, whose long zig-zag path rewards long reach (Sniper 430, Rail 320,
    Mortar 290) over the short-range kinetic and cryo units.
  - `cycle` (6 / 4 / 2%) and `light` (0%) trail badly, so a random or wrong build loses.
- **Counters now show in the leaks:** `heavy` leaks Skitters 2–3× more than any other build
  (60–120 gate damage per run).

**The integration test's curve:** outpost T0 3/8 | canyon [1, 3, 5] | switchback T0/T6 [1, 3].
Green.

**Open for the user** (taste and design calls, shown in the report):
1. **Is "big guns win on Switchback" acceptable as that sector's identity?** Or should
   short-range units gain reach there (e.g. MG 160→190), or Switchback get Skitter-heavy
   waves on its crossing?
2. **The Hive Queen makes each sector's last wave all-or-nothing.** Options: give her fixed
   HP instead of scaling with the wave, or let her strike take a large but survivable share
   of the gate instead of breaking it outright.
3. `casual` beats `smart` on Outpost. The only differences are the repair threshold and tap
   rate, so it's within the noise of 50 seeds. The bot is not a perfect player, and that's
   fine for this tool.

## 2026-09-27 — juice, checked in captures

- `captures/juice-pass.mp4` (`--seed=5 --autoplay --skip-to-wave=10`, 60 s): wave 10 through
  VICTORY. The stars pop in one by one and the gate % counts up.
- The first cut showed the earned stars at full size before their pop, because the
  HBoxContainer sort resets child scale. They're now hidden by alpha until their turn;
  re-captured and fixed.
- The falling shell before a strike and the upgrade pop are in the same clip, at wave 10.

## 2026-09-27 — tests

- **GdUnit:** `balance_run_test` (3): the presets, the profiles, and the record fields.
  **232 game tests**, all green.
- **Python:** `test_balance` (4). **10 tool tests** in all, green.

## 2026-09-27 — B4 complete, stopped for hand play

The user asked to play before any Android work, so B5 hasn't started.
