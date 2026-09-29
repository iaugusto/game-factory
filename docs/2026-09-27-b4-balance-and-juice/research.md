# B4 — Balance bot, tuning and juice: research

_2026-09-27. Continues straight after E5c. The user said "let's keep going, just stop when
everything is done": B4, then B5 (Android build), then stop at the D1 decision gate._

## 1. What B4 has to answer now

The roadmap's B4 predates the campaign, the counter chart, the strike and links. Its intent
still stands:
- a headless balance bot with several strategies;
- a report;
- a tuning pass;
- a juice pass.

Its done-criteria need restating for today's game:

| Original criterion | What it means now |
|---|---|
| "No single strategy dominates by more than a set margin" | **Reading the counter chart must matter.** The counter-picking bot should beat fixed build orders clearly, and no fixed order should beat the others by a wide margin. Otherwise counters are decoration (the open E3 issue: Skitters and Spitters don't force their counters). |
| "The median run at zero meta ends around wave 6–8" | That was a roguelite target. Sector 1 is now meant to be winnable with no tree (E5b), so this applies to a **human-like** player on sector 1 with no tree. The bot is a stronger player than a newcomer, so it needs a "casual" profile: slower tapping, a late and sloppy strike. |
| The report | Kept, and made a reusable tool: `uv run balance` writes a Markdown report. |

**Open issues carried in:**
- **E3:** counters for Skitters and Spitters aren't forced.
- **E5b:** maxed runs pile up unspent coins (no late sink).
- **E5c:** Outpost is generous for the bot (6/8 with no tree).

## 2. Prior art

- **Bloons TD 6 / Kingdom Rush:** the designers balance with win rates per map and difficulty
  against scripted or recorded strategies, and watch for dominant towers. KR's
  "encyclopedia + counters" design relies on armoured and magic-resistant enemies making the
  wrong tower visibly bad.
- **Slay the Spire (Mega Crit's metrics talks):** it tracks per-card pick and win rates from
  runs. The equivalent here is per-strategy win rates and gate damage by enemy type, which
  shows which enemies get through a given build.
- **Juice** ("Juice it or lose it", Jonasson & Purho, 2012; Vlambeer's "Art of screenshake"):
  - small, frequent feedback on every player verb (press, build, upgrade, reward);
  - count-ups for rewards;
  - anticipation plus impact on big events;
  - not more particles on the playfield, which is already busy.

## 3. Strategies to compare (Autoplay presets)

| Id | Knobs | Stands for |
|---|---|---|
| `smart` | the defaults: counter-pick, synergy placement, strikes (checked every 12 ticks, ≥ 5 threat), 3 taps/s | an expert |
| `casual` | 1.5 taps/s, strikes checked every 90 ticks at ≥ 10 threat, no synergy placement, repairs the gate below 50% | a new player |
| `no_strike` | smart, never strikes | ignoring the new verb |
| `no_links` | smart, no synergy placement | ignoring links |
| `cycle` | no counter-pick; cycles through all six units | not reading the preview |
| `heavy` | no counter-pick; Mortar, Sniper, Rail only | "big guns win" |
| `light` | no counter-pick; MG, Rifleman, Cryo only | "fast guns win" |
| `mixed` | no counter-pick; a fixed build covering every damage type (added during tuning) | a player who read the chart once |
| `no_loot` | smart, never taps crates | sanity floor |

**Per run, recorded:**
- won, waves cleared, gate fraction;
- strikes called, links at the end, unspent coins at the end;
- **gate damage per enemy type** (what leaks).

## 4. Targets (the defaults; the user can move them)

Each sector is played at its intended tree profile: **Outpost T0, Canyon T3, Switchback T6**.

- **`smart`:** wins 35–65% on every sector.
- **`casual`:** wins 10–40% on every sector, with the median wave ≥ 6 on Outpost T0. The
  newcomer loses sometimes but gets deep.
- **Counters matter:** `cycle`, `heavy` and `light` are each ≥ 10 points below `smart`.
  - _(Revised during tuning. The draft also asked for the fixed builds to be within 25
    points of each other. A build with no answer to armour (`light`) *should* lose badly,
    so a wide spread between fixed builds is the chart working, not a flaw. The real guard
    is that none of them comes near `smart`.)_
- **Sanity:** `no_loot` < `casual`.

## 5. Juice candidates (cheap, UI-side, no playfield clutter)

- **Button press feedback:** a quick squash on every UI button press.
- **The result screen:** stars pop in one by one (scale overshoot), and the waves and gate
  numbers count up.
- **Wave cleared:** a brief "WAVE N CLEARED" beat, a gate glow, and coin count-ups (these
  exist).
- **The strike:** a short camera kick toward the blast (shake exists), and a falling-shell
  streak during the delay (anticipation).
- **Upgrades:** the unit pops (exists on build; add on upgrade).
- **Stars on the campaign screen:** a count-up when returning with new stars (skipped if it
  gets complex).
