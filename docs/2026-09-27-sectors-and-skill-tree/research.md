# E5b — Sectors, skill tree, save/meta wiring: research

_2026-09-27. Roadmap step E5b (absorbs B3). Follows `docs/2026-09-26-new-enemies-and-destroyable-units/` (E5a)._

## 1. The work item

The user's calls, from `docs/2026-09-26-escalating-difficulty/research.md` §6 and the session memory:

- **Progression is a campaign of maps (sectors)**, each harder than the last (Q2, answer a).
- **A skill tree sits between maps.** The user's own node ideas:
  - "a fallen unit explodes and damages nearby enemies";
  - "+10% loot";
  - others still to be proposed.
- **B3** folds in: save/load wired to the UI, and the flow of run → meta → next run.

## 2. What exists today

| Piece | State |
| --- | --- |
| `SaveData` v4 (`core/save_data.gd`) | Versioned, migrated, written atomically, tested. **Nothing in the game calls it.** |
| `MetaProgress` + 6 `MetaUpgradeDef`s (`data/meta/`) | Bricks buy levels of: Drill (reload), Engineers (−8% prices), Salvage (crate coins), Thick Walls (wall HP), Treasury (kill coins), War Chest (start coins). `to_modifiers()` gives a `RunModifiers`. **No UI, and `Run.new` is never given meta mods in game**; only the bot's "mid-meta profile" uses them. |
| Bricks | `Economy.bricks_for_run(waves_cleared, won, win_bonus)`: shown on the result screen, never banked. |
| Maps | Two, `outpost` and `canyon`, each carrying its own 10 waves. `RunConfig.maps` is the campaign order. The result screen's "PLAY <map>" just toggles between them. |
| Cards | Three picks per run after waves (in-run roguelite layer). Unaffected by this work. |
| Scene flow | `run.tscn` is the main scene. There is no title, map or meta screen; restart reloads the run in place. |
| Balance reference | Tuned against two bot profiles: **zero meta** (loses around waves 6–7) and **mid meta** (+60 wall, +30 coins, −16% prices, +20% crate coins, +10% reload): Outpost 4/12 wins, Canyon 1/12. |

So E5b mostly *connects* what exists, and adds a tree and a campaign screen on top.

## 3. Prior art

- **Kingdom Rush (KR, KR Frontiers, KR Origins).**
  - One upgrade tree per tower type and per spell: six trees of five linear steps, paid in **stars**.
  - Stars come from each level: up to 3 by lives left in the campaign, plus more from Heroic and Iron modes.
  - The tree can be **reset for free at any time**, which invites experimentation.
  - Late on there are more stars than upgrades, so the tree is a ramp, not a permanent choice.
  - Sources: [KR Wiki: Upgrades](https://kingdomrushtd.fandom.com/wiki/Upgrades); [jayisgames review](https://jayisgames.com/review/kingdom-rush.php).
- **Bloons TD 6: Monkey Knowledge.**
  - Six trees by category, bought with points from player levels and achievements.
  - Deeper nodes need earlier nodes, plus a minimum number of points spent in that tree.
  - The effects are small and flavourful: +1 starting cash item, a cheaper first tower, a free item.
  - Sources: [Bloons Wiki](https://bloons.fandom.com/wiki/Monkey_Knowledge_(BTD6)); [bloonswiki](https://www.bloonswiki.com/Monkey_Knowledge_(BTD6)).
- **Roguelite TDs** (Rogue Tower, Tower Cookie).
  - They keep a permanent meta tree, and the run itself is the random layer.
  - Nothing is lost between attempts: "no battle is ever wasted".
  - Sources: [Rogue Tower on Steam](https://store.steampowered.com/app/1843760/Rogue_Tower/); [TowerWard roundup](https://towerward.com/blog/best-roguelite-tower-defense-games).

**Takeaways:**
1. A **campaign of maps with a permanent tree** is the genre standard (KR). It's also mobile-friendly: sessions are short and progress is never lost.
2. **Free respec** turns the tree into a way to try builds, not a trap.
3. **Rewards that measure quality**, like KR's stars by lives left, give a reason to replay a cleared map.
4. **Nodes that change *how* you play** (BTD6's free items, the user's "fallen unit explodes") are remembered. Pure percentage nodes read as filler, so mix the two.

## 4. Design options

### 4.1 What kind of tree

| Option | How it works | For | Against |
| --- | --- | --- | --- |
| **A. Permanent (KR)** ★ | Points are earned per sector and kept forever; the tree is spent and respecced between runs. | Genre standard; never loses progress; fits a campaign and live-ops (a new sector = new points). | Power creep: later sectors must assume a tree. |
| B. Per-attempt (roguelite) | A campaign attempt = sectors 1→N in a row; picks happen between sectors and reset when you lose. | Every attempt differs. | That's what the cards already do inside a run, so there would be two roguelite layers. A loss at sector 4 wipes 30+ minutes: bad on mobile. |
| C. Both | A permanent tree plus per-attempt picks. | Depth. | Too much for a prototype. |

**Recommendation: A.** The run's cards already provide the "every run differs" layer. The tree should be the part that *stays*.

### 4.2 The currency, and the fate of bricks and the 6 meta upgrades

This is the carried-over-default check (memory: *confirm carried-over defaults*). Bricks and the six meta upgrades come from the pre-pivot prototype plan, and the user never confirmed them for the campaign design.

| Option | Currency | Old meta upgrades |
| --- | --- | --- |
| **A. One tree, stars** ★ | **Stars** per sector: 1 for a win, +1 if the gate ends ≥ 50%, +1 if ≥ 90%. | Folded into the tree as nodes (e.g. "War Chest" becomes a node). Bricks are retired. |
| B. Two tracks | Stars for the tree; bricks from every run, win or lose, for the six upgrades. | Kept as a separate "armoury" screen. |
| C. Bricks buy tree nodes | Bricks per wave cleared (win or lose). | Folded in as nodes. |

- **A** gives one screen and one number. A loss grants nothing, but stars are a *quality* measure, so replaying a cleared sector for its 3rd star is the grind valve (as in KR).
- **C** rewards losses (brick per wave), so a stuck player always inches forward. It also removes the "beat it well" goal.
- **B** is both, at the cost of two screens.

**Recommendation: A, plus a softener.** A loss that clears ≥ 5 waves of a sector not yet won grants that sector's **first star** once, so a player is never hard-stuck.

### 4.3 Proposed tree (content = data; numbers are first-pass)

Three branches of five tiers. A tier needs the tier above it in the same branch. Each node has one level, except where a range is shown. Costs rise by tier: 1, 1, 2, 2, 3 stars, so one branch costs **9** and the whole tree **27**.

| Tier | **Arsenal** (offence) | **Bulwark** (defence) | **Logistics** (economy) |
| --- | --- | --- | --- |
| 1 | Drill: units reload 8% faster *(old Drill)* | Thick Walls: +40 gate HP *(old)* | War Chest: +30 starting coins *(old)* |
| 2 | Sharpshooters: +10% unit damage | Reinforced Pads: units have +30% HP | **Scavengers: +10% loot (crate and kill coins)** *(user)* |
| 3 | **Last Stand: a destroyed unit explodes, dealing damage around its pad** *(user)* | Field Barricade: the barricade starts built at level 1 on wave 1 | Engineers: −10% unit prices *(old)* |
| 4 | Veteran Crews: units start at level 2 when built (you pay level 1) | Masons: gate repair heals 50% more | Supply Drop: one free card reroll per offer |
| 5 | Capstone, **Overwatch**: masteries cost 50% less | Capstone, **Iron Gate**: enemies pounding the gate take 5 damage/s | Capstone, **Fourth Card**: offers show 4 cards |

The old Salvage and Treasury are merged into the user's "+10% loot". **Selling (50%) is deliberately not in the tree**: the user wants replacing a unit to be "a costly decision".

**Sector star budget:** 3 sectors × 3 stars = 9, exactly one full branch or a spread. More sectors (and later a "heroic" challenge mode) raise the ceiling, the KR way. The campaign should be designed so that sector *N* is winnable with roughly the stars sectors 1..N−1 give at 2 stars each.

### 4.4 Sectors

- **The order is data.** A new `CampaignDef` resource lists sectors, each a `MapDef` plus star thresholds. This replaces the loose `RunConfig.maps`.
- **Unlocking is linear.** Winning sector *N* opens *N + 1*. Any opened sector can be replayed for better stars.
- **E5b content:** Outpost (sector 1) and Canyon (sector 2) exist. A **third sector** would make the curve and the star budget meaningful.
  - It needs a new map, with authored waves and, ideally, one new map mechanic.
  - That is level design (the user's taste), so it's a question, not an assumption.
- **The difficulty curve against the tree:**
  - Today the Outpost is tuned so zero meta loses around wave 7.
  - Under a campaign, sector 1 must be **winnable at zero tree** by a decent player. Target: the zero-tree bot wins sometimes, and 2–3 stars of tree win often.
  - That means **re-tuning sector 1 easier**, with the Canyon at "tree ≈ 3 stars" and sector 3 at "≈ 6 stars".
  - The bot gets new "tree profiles" in place of the mid-meta profile.

### 4.5 Save and flow (the B3 part)

- **Save v5:** `{version, campaign: {sector_id: best_stars}, tree: {owned node ids}, stats}`.
- **The v4 → v5 migration must not silently reset** (CLAUDE.md §4).
  - v4 holds bricks and meta levels, and no real player save exists, since nothing wrote one.
  - The chain still has to be honest. Move the old bricks and levels into a `legacy` block, and grant the tree nodes that match old meta upgrades the player owned. Covered by a test.
- **Screens:**
  - A new main scene, `campaign.tscn`: a sector list with stars and a lock, plus a "SKILLS ★ n" button.
  - A skill-tree panel: three columns, buy with a tap, "RESET" refunds all.
  - `run.tscn` gains a sector argument. Its result screen shows stars earned, and offers "CAMPAIGN" / "RETRY" / "NEXT SECTOR ▶".
- **Command line:**
  - `--map=` keeps working for direct play and capture.
  - `--tree=all|none|<ids>` sets the tree for bot runs and clips without touching the save.
  - `--save=PATH` points tests at a scratch save.

### 4.6 Implementation notes

- The tree fits `RunModifiers` for the percentage nodes: they are just keys, like the old meta.
- New rule hooks need new `RunModifiers` fields plus a few lines in core:
  - Last Stand: an explosion on `unit_destroyed`, in `CombatSim`.
  - Veteran Crews, Field Barricade, Iron Gate: in `Run` / `CombatSim`.
  - Card reroll, 4-card offers, cheaper masteries: in `Run`.
- **Everything stays in `core/`, and is tested.**
- **Determinism:** the explosion and the reroll use existing RNG streams (`cards` for the reroll).
- **Perf:** Last Stand is event-driven, one splash per unit death, with no per-tick cost. Iron Gate runs inside the existing gate-siege pass. This keeps the sim tick flat (it is at 1.7–1.95 ms; memory says B5 comes before more per-enemy rules).

## 5. Platform/store notes

- The save stays local (`user://`). Cloud save is B13/B17 behind `platform/`.
- No player data leaves the device, so no privacy declaration changes.

## 6. Questions for the user

1. **Tree type:** permanent KR-style tree with free respec (★ recommended), or a per-attempt roguelite tree?
2. **Currency and the old meta:** retire bricks and fold the 6 brick upgrades into the tree, paid in stars per sector (★)? Or keep bricks as a second track?
3. **The tree's contents (§4.3):** do the three branches and 15 nodes look right? This includes your two ideas, placed at Arsenal 3 and Logistics 2. Any to swap?
4. **Sector 3:**
   - Should E5b build a third map (★ recommended, so the curve means something)?
   - Or ship with Outpost and Canyon, and add maps later?
   - If a third map: any wish for its theme or mechanic?
5. **Re-tuning:** sector 1 gets easier (winnable with no tree). OK?

### Answers (user, 2026-09-27)

1. **Tree type:** permanent, KR-style, with a free respec.
2. **Currency:** stars; the six old upgrades are folded into the tree and bricks are retired,
   with the loss softener (5+ waves on an unwon sector gives its first star once).
3. **Sector 3:** yes, build it.
4. **Tree contents and re-tune:** go with §4.3 as proposed; sector 1 gets re-tuned to be
   winnable with no tree.
