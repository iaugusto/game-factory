# E6 — Visual style and contextual tutorials: plan

_2026-09-27. Built on `research.md`. The work runs in two stages. There's a user checkpoint
after stage 1, because picking the style direction is the user's taste call._

## Stage 1: style tokens and three directions (checkpoint: the user picks one)

1. **Fonts** go into `game/art/fonts/` (all OFL, from Google Fonts, each with its `OFL.txt`
   licence):
   - Chakra Petch (SemiBold and Bold);
   - Barlow Semi Condensed (Medium and SemiBold);
   - Lilita One;
   - Nunito (SemiBold and ExtraBold);
   - Oxanium (SemiBold and Bold);
   - Barlow (Medium).

   Fonts are tracked source assets, and the directions that lose get deleted after the pick.
2. **`StyleDef` (`defs/style_def.gd`, a Resource):**
   - fonts: display, body, number;
   - the type scale: caption 15, body 19, label 22, heading 28, display 44;
   - the palette, with one meaning per colour:
     - `panel`, `panel_raised`, `line`;
     - `text`, `text_dim`;
     - `action` (primary buttons only);
     - `coin`;
     - `owned`;
     - `threat`;
     - `good`, `bad`;
   - panel shape: radius, bevel, cut corner;
   - `field_grade` (a Color multiply plus saturation, for the ground).

   Content lives in `data/styles/{command,arcade,grit}.tres`.
3. **`UiTheme` reads the active `StyleDef`:**
   - It builds a real Godot `Theme` (default font, sizes, Label, Button and Panel styles) and
     sets it on the root windows, so most labels restyle without per-call overrides.
   - The `label()`, `style_button()` and `panel()` helpers take a *role* (`&"body"`,
     `&"heading"`, …), not raw sizes.
   - A sweep replaces every inline colour and font size in `ui/` and `sim/` with roles, and
     raises every size under 15 px.
4. **The field grade:** `FieldView` applies `field_grade` to the ground through the existing
   shader path, or a modulate. No art regeneration is needed for the comparison.
5. **The switch:**
   - `--style=command|arcade|grit` works for direct launches and captures.
   - The chosen style is a `RunConfig`/project setting, not a save field. The player never
     picks it.
6. **Fix the layering bugs:**
   - Popups queue through one `Announcer` lane, so no two banners draw on top of each other.
   - Modal cards close any open build ring first.
7. **Capture:** the same four screens (campaign, build phase with the ring, NEW THREAT, a
   mid-wave shot) in each style, as `captures/style-{a,b,c}-*.png`, plus a side-by-side sheet.

**👤 Checkpoint:** the user picks A, B or C, or asks for a mix. The losing fonts and styles are
deleted.

## Stage 2: the tutorial system (built after the pick; the look follows the chosen style)

### Core (pure, unit tested)

- **`TipDef` (`defs/tip_def.gd`):**
  - `id`;
  - `trigger` (a StringName event), with an optional `trigger_arg` (e.g. an enemy id);
  - `priority`;
  - `cards: Array[TipCard]`.
- **`TipCard`:**
  - `title` (≤ 24 characters), `body` (≤ 80 characters);
  - `icon` (an art key), or `enemy`/`unit` for a portrait;
  - `focus` (the anchor to spotlight: a UI node name such as `&"start_wave"` or
    `&"strike_button"`, or a world target such as `&"first_empty_pad"`, `&"crate"` or
    `&"gate"`);
  - `wait_for` (optional. An event that closes the card instead of a tap. This is the
    "do" step, e.g. `&"unit_built"`).
- **`TipDirector` (`core/tip_director.gd`, RefCounted):**
  - Its input is `notify(event, arg)` and the `seen` set; its output is
    `pending() -> TipDef`, the highest-priority unseen tip.
  - `mark_seen(id)`.
  - It holds no nodes and no timing. It's a queue, so two tips never overlap: the second
    waits for the first to close.
- **Events `Run` emits** (on top of the existing signals, with no new rules):

| Event | When |
|---|---|
| `run_started` | The first BUILD phase of the first run |
| `crate_spawned` | The first crate appears |
| `boost_crate` | The first Overdrive crate |
| `wave_started` | The first wave begins |
| `can_upgrade` | The first time coins ≥ the cheapest upgrade in BUILD |
| `gate_hit` | The gate is damaged for the first time |
| `siege` | Enemies reach the gate for the first time |
| `unit_jammed` | A unit is jammed for the first time |
| `unit_destroyed` | A unit is destroyed for the first time |
| `new_enemy` (arg id) | Replaces the IntelCard trigger |
| `new_portal` | A portal opens for the first time |
| `locked_pad` | A locked pad is first visible |
| `high_ground` | A high-ground pad is first visible |
| `barricade_ready` | The first time the barricade can be placed |
| `card_pick` | The first card pick |
| `mastery_ready` | A unit reaches max level for the first time |
| `strike` / `synergy` | (E5c) |
| `campaign_first` | The campaign screen, first time |
| `stars_earned` | Stars earned for the first time |
| `tree_open` | The skill tree opens for the first time |

- **Save v6:** adds `tips: {seen: [ids], off: bool}`, with a v5 → v6 migration that starts
  empty. Existing players see the tips once, which is intended.

### View

- **`TipLayer` (`ui/tip_layer.gd`):**
  - It dims the screen with a cut-out spotlight on the `focus` rect (a shader: a rounded rect
    with a soft edge and a slow pulse ring). A pointing hand appears on "do" steps.
  - One compact card sits at the top or bottom, whichever half the spotlight isn't in. It has
    a portrait or icon on the left, the title and body, page dots, and "TAP ▸".
  - It slides in over 0.18 s.
- **Time:**
  - On show, `Engine.time_scale` eases to 0 over 0.15 s.
  - The layer runs with `PROCESS_MODE_ALWAYS`.
  - On close it eases back to the prior scale.
  - "Do" steps pause the waves but let the one needed input through, e.g. taps on the
    spotlit pad only.
- **`focus` anchors:**
  - UI nodes register by name with the layer (`TipLayer.anchor(&"start_wave", node)`).
  - World anchors are resolved by `RunController`: pad and crate positions.
- **Skipping:**
  - A long-press on the card offers "Skip all tips".
  - The campaign screen gets a small ⚙ with "Reset tips" and "Tips on/off".
- **Never in automation:** `--autoplay`, `--quit-on-end`, probes and tests start with tips
  off (a `--tips` flag forces them on for captures).
- **`IntelCard` is retired.** New-enemy tips render its portrait and weak/strong icon rows
  inside the tip card.

### Content (`data/tips/*.tres`, about 20 tips, 1–3 cards each)

Example texts, all ≤ 80 characters:
- **first_build** (do): "Build a defense": "Tap a glowing pad to place a unit." → waits for
  `unit_built`.
- **start_wave:** "Ready?": "Start the wave when your line is set. Enemies march on the gate."
- **crates:** "Loot crate": "Tap crates fast to crack them for coins before they vanish."
- **siege:** "Gate under siege": "Enemies at the gate pound it. Kill them before it breaks."
- **new_enemy:** its title is the enemy name, and the body is the one-line description plus
  the icon rows.

**Text pass:** every enemy, unit, card, skill and mastery description is rewritten to ≤ 80
characters. The details move to icons already on screen: damage-type badges and weak/strong
rows.

### Tests

- **Unit:**
  - `TipDirector`: trigger matching, the priority queue, no repeats, and args.
  - The save v5 → v6 migration.
- **Content:** every tip's cards are within the text limits, every `focus` names a known
  anchor, every trigger is a known event, and no description anywhere in `data/` exceeds 80
  characters.
- **Integration (`run_scene_test`):**
  - A first-run flow with tips on: the first-build tip shows, time is 0, and a pad tap
    completes it.
  - The start-wave tip, then a crate tip on the first crate.
  - Autoplay with tips off never shows the layer.
- **Captures:** a first-session clip (`--tips`, a fresh save) and stills of 4 tips.

### Budgets

- Fonts: about 300–400 KB in the build.
- The spotlight shader adds one full-screen draw, only while a tip is up.
- There's no per-frame cost when no tip is shown.

## Order after this

E6 (this) → **E5c** (strike and synergies, with their tips) → B4 (balance and juice) → B5
(Android build). The phone test happens when the user calls the experience complete.

## Risks

- **A global `Theme` can shift existing layouts** (min sizes grow with larger fonts). The
  stage 1 capture is the check, and the tests assert no control overflows the 540 px width.
- **Pausing with `time_scale = 0`** must not stall tweens that the tip itself uses. Those run
  on `Tween.set_ignore_time_scale(true)`.
- **Tip spam in the first run.** Priorities plus the rule of one tip per BUILD phase (the rest
  queue to the next phase) keep the first 3 waves to about 5 tips.
