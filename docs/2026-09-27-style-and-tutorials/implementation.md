# E6 — Visual style and contextual tutorials: implementation log

## 2026-09-27 — user approved the plan ("let's do it")

- Their three decisions were answered by "let's do it", which takes the recommended defaults:
  - keep the one guided "tap a pad" step;
  - fold the IntelCard into tips;
  - rewrite descriptions to ≤ 80 characters.
- Stage 1 started.

## 2026-09-27 — stage 1: style tokens and three directions

**Fonts** (`game/art/fonts/`, each with its `OFL-*.txt`), downloaded from `google/fonts`:
- ChakraPetch Bold/SemiBold;
- BarlowSemiCondensed Medium/SemiBold/Bold;
- LilitaOne;
- Nunito (variable);
- Oxanium (variable);
- Barlow Medium/SemiBold.

The variable fonts are renamed without brackets. They total about 1 MB. The directions not
picked lose theirs after the pick.

**`StyleDef` (`src/defs/style_def.gd`):**
- fonts;
- the type scale (caption 15, body 19, label 22, heading 28, display 44);
- a palette where each colour has one meaning:
  - `action` is for primary buttons only;
  - `coin` is for coins and prices;
  - `title`, `owned`, `threat`, `good` and `gate` each have their own colour;
- panel shape: radius, `corner_detail` (1 gives chamfered corners), button lip;
- `field_tint`.

It has two helpers: `size_of(role)` and `font_of(role)`. The display face covers
label/heading/display, and the body face covers body/caption.

**Content:** `data/styles/command.tres` (A), `arcade.tres` (B), `grit.tres` (C).

**The `UiTheme` rewrite:**
- `static var look: StyleDef` is set in `_static_init` from `--style=ID` or `DEFAULT_STYLE`
  (`command`). Loading a style also sets `ThemeDB.fallback_font` and its size.
- `label(text, role, color)`, `restyle()`, `style_button(b, primary, role)` (with the lip),
  `panel()` (the style's radius, chamfer and hairline by default), and `dim()`.
- The old colour constants are gone.

**The sweep** (mechanical, by script, then hand-fixed):
- Every `UiTheme.label` and `style_button` call now passes a role, not a px size. The mapping
  was ≥ 38 → display, ≥ 27 → heading, ≥ 20 → label, ≥ 16 → body, otherwise caption. Nothing
  is below 15 px now; it was 11–13 in places.
- `ACCENT` was split by meaning:
  - titles → `look.title`;
  - coins and prices → `look.coin`;
  - buttons and borders → `look.action`.
- Every modal dim now uses `UiTheme.dim`. The skill tree uses the opaque backdrop, because at
  0.94 the campaign title showed through.
- `Fx.popup` takes a role. Its labels are styled by `UiTheme.restyle`.
- In-world text (the plot's W-lock, sealed portals, the crate tag) uses the caption size and
  the style's font.
- `FieldView` tints the ground with `field_tint`.

**Layering fixes:**
- **Banners share one lane** (`RunController._banner` → a queue, `BANNER_GAP` 0.9 s). The
  captures had shown a card-pick banner ("MARKSMEN") on top of "WAVE N INCOMING". The map name
  and "NEW BREACH!" go through the lane too. The map name is queued before the first phase's
  banner.
- `_after_skip` clears queued banners. Otherwise a `--skip-to-wave` run showed a stale "WAVE 1
  INCOMING".
- `open_plot` closes the intel card first. The captures had a NEW THREAT card over an open
  menu. That only happened through the dev `--open-plot` path, because phase changes already
  close menus.

**Build ring:** `RING_RADIUS` 84 → 100, and the label width 90 → 100. At 15 px the unit names
overlapped each other.

**`--style=ID`** is documented in the `RunController` header. It isn't a run argument, so the
campaign screen honours it too.

**Tests:** the popup calls in `run_scene_test` now pass roles. 197/197 green.

**Captures:**
- `captures/style-{command,arcade,grit}-{campaign,tree,threat,ring,upg,wave}.png`;
- per-style sheets `captures/style-*-sheet.png`;
- the combined `captures/style-compare.png`.

**👤 Checkpoint:** the user picks A, B or C.

## 2026-09-27 — the user asked for "arcade but with command like colors"

- **Added `data/styles/hybrid.tres`**, built by script:
  - from B: Lilita One + Nunito 850, radius 16, a 5 px button lip, outline 5, no forced caps;
  - from A: the whole palette and the field tint, copied over.
- **Captures:** `captures/style-hybrid-*.png`, the sheet, and `captures/style-compare-hybrid.png`
  (rows A / hybrid / B).
- Waiting on the user's verdict.

## 2026-09-27 — the user picked hybrid ("hybrid looks good, let's use it. good to go.")

- **Style cleanup:**
  - `DEFAULT_STYLE` = `hybrid`.
  - `data/styles/{command,arcade,grit}.tres` deleted, along with the unused fonts
    (ChakraPetch, BarlowSemiCondensed, Barlow, Oxanium) and their licences.
  - Kept: Lilita One, Nunito (variable), `OFL-lilitaone.txt`, `OFL-nunito.txt`. About 300 KB.

## 2026-09-27 — stage 2: tips

- **Defs:**
  - `TipCard`: title ≤ 24, body ≤ 80, icon, focus, `wait_for`.
  - `TipDef`: id, trigger, `per_arg`, priority, cards.
  - `RunConfig.tips`.
- **Core:** `TipDirector`. It keeps a priority queue of unseen tips, with per-argument keys
  (`new_enemy:grunt`), and lists `EVENTS`, `WAIT_EVENTS` and `FOCUSES` for the content test.
  Its seen set is the save's dictionary.
- **Save v6:** `tips: {seen, off}`. v5 → v6 starts with none seen.
- **View:** `TipLayer` plus `shaders/spotlight.gdshader`.
  - The card goes on the half of the screen away from the spotlight, and slides in.
  - It has page dots and "GOT IT ▸" / "TAP THE GLOW". A read guard ignores taps in the first
    0.35 s.
  - A "do" card only accepts a tap inside the spotlight, passes it through to the game, and
    shows a bobbing chevron.
- **`RunController`:**
  - Events come from core signals and the build phase:
    - new enemies and portals;
    - the first build;
    - locked pads, high ground, barricade ready, gate damaged;
    - `can_upgrade` (checked each frame in BUILD);
    - `mastery_ready`;
    - crates (normal / boost);
    - gate struck, jams, unit destroyed;
    - the card offer.
  - `pump_tips` waits for menus and the result screen to close. `focus_rect` resolves each
    spotlight, and the layer re-measures it every frame, so the offered cards are spotlit
    after their slide-in.
- **The `IntelCard` is retired:** its file and tests are deleted. New-enemy tips show the
  portrait, the one line, and the WEAK TO / SHRUGS OFF rows (`TipLayer.unit_row`).
- **Stopping time:**
  - In a WAVE, `freeze` eases `Engine.time_scale` down to `TIP_TIME_FLOOR` (0.001), and
    `_physics_process` skips ticks while a tip is up.
  - Between waves nothing is slowed. The first version slowed time everywhere, which froze
    the card picker's slide-in under its own tip; captured and fixed.
  - The layer animates on `delta / time_scale`, not the wall clock. A wall-clock version
    animated wrongly in fixed-fps captures.
- **Banner lane, second fix:**
  - Each banner now waits for the previous one's full life plus 0.1 s. A 0.9 s gap still let
    "MARKSMEN" overlap "WAVE 2 INCOMING", because the popup lives 1.6 s.
  - The lane counts game time, so it freezes with the popups under a tip. Counting wall-clock
    time let it run on during the tip, which reproduced the same overlap.
- **When tips are on:**
  - In campaign runs, unless the save has them off. The save is written each time a tip is
    read.
  - In direct runs, only with `--tips`.
  - Never in autoplay, except `--autoplay --tips` (the demo: the bot reads each card for
    1.8 s and does the "do" card by tapping its spotlight).
- **Campaign screen:** its own director and layer, with the `campaign_open` and
  `stars_to_spend` tips. The ⚙ settings card has TIPS: ON/OFF and REPLAY ALL TIPS (both
  saved).
- **Content:** 18 tips in `data/tips/`. All descriptions are ≤ 80 characters: 7 enemy
  descriptions plus the boss and Last Stand were rewritten, and weak/strong moved to the icon
  rows.
- **Build bar:** the hint line ("Tap a pad to build · tap crates for coins") is removed, since
  tips teach it now, and `BuildBar.HEIGHT` goes 150 → 128.

**Tests** (211 game, all green):
- `tip_director_test` (6);
- `save_data_test` (v5 → v6, tips round trip);
- `content_test` (tips well formed, no description over 80);
- `run_scene_test`: 4 tip cases replace the intel-card test. They cover:
  - off in direct runs;
  - the enemy → do-build → start order;
  - no tip over a menu, and none twice;
  - a crate tip stopping time;
- `campaign_flow_test`: shown once, saved, replay, off.

**Exercised:**
- `captures/tips-first-session.mp4` (`--seed=3 --autoplay --tips`, 60 s). It shows the Drone
  card, then "Build a defense" with the glow and chevron, the loot-crate card mid-wave
  (frozen), the Reinforcements card spotlighting all three offered cards, then the Skitter
  card.
- `captures/tips-campaign.png`: a fresh save, with the Campaign tip spotlighting PLAY.

**Budgets:**
- Stress at 260 enemies: frame avg 8.1–8.8 ms, sim tick 1.27–1.60 ms, 75 draw calls. That's
  within the earlier logs (74–127 draw calls, 6.6–13 ms).
- There's no cost when no tip is up. The tip layer is hidden, and the spotlight draws only
  while it's visible.
- Fonts add about 300 KB.

**Not covered / open:**
- Not shown in the demo clip: the siege, jam, unit-lost, repair, upgrade, mastery, portal,
  locked-pad, high-ground and barricade tips. The bot builds through `Run` directly, so it
  never sends `unit_built`, and the start-wave tip only fires for real player builds. They
  are covered by the content test and the same code path, but they need a hand-play pass.
- **Taste calls for the user:** the tip wording, the dim strength, and the card position.

## 2026-09-27 — E6 complete

- **Style:** stage 1 plus the hybrid pick.
- **Tips:** stage 2 as above.
- **Docs updated:** overview (header, repo map, core/defs/presentation, dependency map, change
  log), README (status, commands, args), ROADMAP (E6 row; notes on B6 and B8).
- **Next:** E5c (strike and synergies, with their tips), then B4, then B5.
