# Research — "Hold the Gate" playable prototype

**Work item:** build a 2-week playable prototype of the concept chosen in
[`2026-09-24-market-research`](../2026-09-24-market-research/research.md) §4b/§6: a fixed base,
waves in lanes, shootable gate multipliers, build slots, and a base-building meta.

The market case lives in that work item and is not repeated here. This file covers what the
**prototype** needs: the design questions it must answer, prior art for each mechanic, and the
technical choices.

---

## 1. What the prototype must answer

A prototype is an experiment, not an early version of the product. It must answer three
questions, in this order:

1. **Does the hook read?** Does a 10–15 s clip of shooting a gate until it flips from −2 to ×3
   make sense to someone who has never seen the game? That clip is the Steam capsule trailer,
   the TikTok ad and the store screenshot all at once. If it doesn't read, nothing else matters.
2. **Is the loop fun?** Wave → build → card → wave, and after a run ends, do players want
   "one more run"?
3. **Is it feasible?** Can hordes of hundreds of enemies with hundreds of bullets hold 60 fps on
   a mid-range Android phone, from the same codebase as the desktop build?

## 2. Prior art per mechanic

| Mechanic | Where it comes from | What to borrow | What to avoid |
| --- | --- | --- | --- |
| Gates and barrels whose number rises as you shoot them | Last War's ads (§2 of market research), Real War: Not Fake | Big readable numbers; a negative gate you can "rescue" by shooting it; satisfying count-up popups | Pure left/right steering with no decisions (that's all the ad ever is) |
| Squad that grows in size | Mob Control, Count Masters | Seeing many shooters on screen *is* the reward | Unbounded crowds that tank frame rate |
| Fixed base, waves, upgrade between them | The Tower, Dome Keeper, Thronefall | A clear wave/build rhythm; the base is the thing you love and protect | Idle-only play (The Tower works, but it's a live-ops marathon) |
| Fixed build slots | Thronefall | No free placement means no pathfinding and no UI for grid placement; touch-friendly | — |
| Pick 1 of 3 upgrades per wave | Vampire Survivors, Brotato, Ball x Pit | Run-to-run variety for little content cost | More than ~3 choices per pick on a phone screen |
| Persistent base between runs | Ball x Pit, Rogue Legacy | The long-term progression that carries retention and, later, in-app purchases | Grind that is only there to sell skips |

## 3. Design decisions to test

- **Orientation: portrait.** The ads the hook comes from are portrait, phones are held
  portrait, and lanes read best vertically. On desktop/Steam the playfield is a portrait column
  with side panels, like Ball x Pit. *Risk:* Steam players prefer landscape. Revisit after
  playtests.
- **Input: one axis.** Drag horizontally to slide the squad along the wall (choosing which lane
  and gate it fires at), with auto-fire. Alternative to A/B test: tap a lane to focus fire. Both
  are one-thumb.
- **Lose condition:** enemies that reach the wall damage it; a run ends at wall HP 0.

## 4. Technical research

- **Engine:** Godot. The current stable is **4.7.2** (released 2026-08-18). It adds the stable
  Godot Android Build Environment for exporting and publishing directly. GDScript with static
  typing; `.tscn`/`.tres` files are text, so they diff in git and can be edited by Claude.
  [80.lv](https://80.lv/articles/godot-4-7-has-been-released),
  [godot-builds releases](https://github.com/godotengine/godot-builds/releases)
- **Tests:** GdUnit4 has a headless command-line runner and CI support. Its latest listed
  compatibility is Godot 4.5–4.6.3, so 4.7 support must be confirmed at setup. The fallback is
  GUT, the other mainstream Godot test framework.
  [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4)
- **Performance: bullets are data, not nodes.** One node (plus a physics body) per bullet is
  the common frame-rate killer in horde games. Lanes make a cheaper design possible:
  - Bullets live in typed arrays inside a single manager and are drawn in one batch
    (`MultiMeshInstance2D`).
  - Collision is checked only against enemies in the bullet's lane, sorted by distance, so there
    is no physics engine in the hot path.
  - Enemies are pooled and reused, never freed mid-run.
- **Determinism:** a seed must replay a run identically, so gameplay randomness uses named
  `RandomNumberGenerator` streams (spawns, gates, cards). The simulation steps at the fixed
  physics tick rather than per rendered frame.
- **Machine:** Linux under WSL2 with WSLg, an RTX 3070 and 16 cores. Neither Godot nor its
  export templates are installed, and installing them is system configuration (`CLAUDE.md` §5).
  - The Linux editor runs under WSLg. Running the Windows editor against the WSL filesystem is
    slow.
  - An Android export needs JDK 17 and the Android SDK.
  - **An iOS export needs macOS with Xcode.** No iOS build is possible from this machine.

## 5. Open questions (for the user)

1. Which Android phone can we test on (model and year)? That sets the performance budget.
2. Is a Mac available for later iOS builds? This is not needed for the prototype.
3. Portrait on Steam too, or should desktop get a landscape layout later?
