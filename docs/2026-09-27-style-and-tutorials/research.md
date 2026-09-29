# E6 — Visual style and contextual tutorials: research

_2026-09-27. Asked by the user before the first phone test:_

> "can we improve the overall style of the game before testing? the fonts, color palletes, we
> should ideally have a tutorial every time something new is introduced, where we stop time and
> show cards teaching the user how to use or plan for anything new, it should read seamlessly
> and we shouldn't have, ideally, text blocks too big."

The user's order is: this pass, then keep building the game (E5c is planned and approved but not
started), then a phone test once the experience is complete. Until then, anything that runs on
the desktop is assumed to run on Android.

This pulls parts of **B6** (art direction) and **B8** (onboarding) forward. **B8 said "teach
through play, no text"; the user now wants time-stopped cards.** The user's words replace that
line of the roadmap.

## 1. Where the game stands (captures from 2026-09-27)

Stills are in `captures/style-before-*.mp4`.

**Typography**
- Every label uses Godot's built-in default font. There's no display face, so the title,
  buttons, numbers and body text all look the same and generic.
- Sizes are set per call, anywhere from 10 to 26 px. Some are below phone-readable size at
  540×960:
  - the HUD's "100 / 100" (~10 px);
  - "Tap to continue" (13 px);
  - the build hint line (~13 px).

**Colour**
- `UiTheme` has 9 constants (amber accent, teal, red, green, cream text). Several screens
  still inline their own colours.
- The UI panels are near-black brown, and so is the field around the paths. The HUD and build
  bar sink into the field, and panels don't read as a separate layer.
- Too many accents compete. Amber means *primary button*, *affordable* and *coins* at once;
  teal means both *owned* and *empty pad*.

**Text blocks**
- Enemy descriptions run 100–143 characters, which is 3 lines on the intel card (Ravager,
  Splitter). The card also carries a title, a name, two icon rows and a hint.
- Skill and card descriptions are shorter (60–100 characters) but written as sentences.

**Layering bugs seen in the captures**
- "WAVE … INCOMING" and "MARKSMEN" popups draw on top of each other.
- The NEW THREAT card opens over an open build ring (`style-before-menu`).

**Teaching today**
- There is a one-line hint ("Tap a pad to build · tap crates for coins").
- The `IntelCard` (NEW THREAT) appears before an enemy's first wave, and "NEW BREACH!" when a
  portal opens.
- Nothing teaches any of these:
  - crates and Overdrive;
  - upgrading, selling and masteries;
  - repairing the gate;
  - the barricade;
  - locked pads and high ground;
  - jams;
  - the gate siege;
  - card picks and rerolls;
  - stars and the skill tree;
  - (E5c) the strike and synergies.

## 2. Prior art

| Game | How it teaches something new | Take |
|---|---|---|
| **Kingdom Rush** (Ironhide) | A pause pop-up with a portrait card for every new enemy or tower ("NEW ENEMY"): a name, one line, and an encyclopedia entry for the details. Only the first map uses guided taps. | Pause and one card per new thing, with the details kept elsewhere. This is closest to what the user asked for. |
| **Plants vs. Zombies** | One new element per level. A card for each new plant or zombie, with a one-sentence joke. Time pauses. | Pace new things one at a time. Keep the text to a single line. |
| **Bloons TD 6** | The first game is a short guided build ("place a Dart Monkey here" with an arrow). Later it teaches almost nothing and trusts the upgrade UI. | Guide the player's hand for the first action, then get out of the way. |
| **Clash Royale** | Forced tutorial battles with a pointing hand, and text pinned to the hand. | The pointing hand plus a highlighted target teaches faster than prose. |
| **Rush Royale / Arknights** | Tip cards anchored to the UI element (a spotlight, the rest dimmed), with 1–3 cards and page dots. | Spotlight plus short cards is the mobile standard. |

**What the sources agree on**
- **One idea per card, shown at the moment it becomes relevant (just-in-time).** Front-loaded
  tutorials are skipped and forgotten.
- **Show, then say.** Point at the thing (a spotlight or hand) and pair it with a short line.
  Put the details somewhere the player can look them up later.
- **Stop the clock.** A card must never cost the player a life. Pause while it's shown and
  ease back in.
- **Let players dismiss cards quickly, and never show the same card twice.**
  - Offer "reset tips" for players who want them again.
  - Offer "skip tips" for veterans who reinstall.

Sources:
- Game Developer, "Tutorials: learning to play" (Hollow Ponds / Rosa Carbo-Mascarell) and
  "The Ideal Tutorial" talks;
- Game Accessibility Guidelines (gameaccessibilityguidelines.com): text size, contrast, "avoid
  walls of text", "allow tips to be replayed";
- Apple HIG, Typography: 17 pt body and 11 pt minimum;
- Material 3, Type scale.

## 3. Readability numbers

- The canvas is 540 logical px wide, and phones are 360–430 pt wide, so 1 logical px ≈
  0.7–0.8 pt.
  - A **17 pt body ≈ 20–22 px**.
  - The **11 pt floor ≈ 14–15 px**.
- **Proposed scale:**
  - caption 15;
  - body 19;
  - label 22;
  - heading 28;
  - display 44.
  - Nothing below 15 px ever.
- **Text budget per tutorial card:** a title of ≤ 3 words and a body of **≤ 80 characters**
  (≈ 2 short lines at 19 px in a 420 px card). 1–3 cards per tip. A content test enforces it.
- **Contrast:** WCAG AA says 4.5:1 for body text on panels and 3:1 for large text. The current
  cream on panel passes; the dim grey (#a8a090 on #12141a) is borderline at small sizes.

## 4. Fonts (all SIL Open Font License: free for commercial use, embeddable, from Google Fonts)

| Font | Role | Why |
|---|---|---|
| **Chakra Petch** | Display and headings | Squared, sci-fi military, still readable in caps. Fits "defenders' HUD". |
| **Oxanium** | Display (alternative) | A more techno and angular option. |
| **Barlow / Barlow Semi Condensed** | Body and numbers | Very legible at small sizes. The condensed cut fits the 540 px width, and the digits suit counters. |
| **Lilita One** | Display (the casual direction) | A chunky rounded font, the look of top-grossing mobile TD (Rush Royale-like). |
| **Nunito** | Body (the casual direction) | Rounded and friendly, highly legible. |

- **Size:** about 60–150 KB per font file, 2–3 files per direction. That's a negligible share
  of the build.
- **Rendering:** Godot 4 renders them as dynamic fonts with MSDF off. Hinting "light" and
  oversampling keep them crisp at phone DPI.
- **Coverage:** all include Latin Extended, so they're ready for localization into e.g. pt-BR
  and es.

## 5. Style options (the taste call belongs to the user, so show all three)

Each direction is one set of tokens: fonts, a UI palette, panel shape, and a field colour
grade. The first two keep the current art. Only the UI and a ground tint change.

**A. Field Command (refined current: sci-fi military)**
- Fonts: Chakra Petch + Barlow Semi Condensed.
- Panels: gunmetal navy (#141a24), with cut-corner and bevel strokes.
- Colours:
  - one warm accent: amber, used **only** for actions;
  - cyan for owned and tech;
  - coin gold kept separate from amber;
  - red for threat.
- Field: cooler, slightly desaturated ground, so enemies (warm) pop.

**B. Arcade Siege (bold casual mobile)**
- Fonts: Lilita One + Nunito.
- Panels: saturated plum-navy, with chunky rounded buttons that have a darker bottom lip.
- Colours: thick dark outlines on all text, bright green primary buttons, gold coins.
- Field: warmer and brighter.
- The Rush Royale / Kingdom Rush feel, which is the most "mobile store" of the three.

**C. Frontier Grit (muted, tactical)**
- Fonts: Oxanium + Barlow.
- Palette: sand and olive, with orange-red as the one accent.
- Panels: flat, sharp corners, hairline borders.
- Field: desaturated, dusty.
- Reads more "premium PC/Steam".

**Recommendation: A.** It fixes the real problems (contrast, one meaning per colour, a
readable type scale) without fighting the existing generated art, and it suits both Steam and
mobile. B is the stronger store-conversion look on mobile, though, so it's worth seeing side by
side.

## 6. Tutorial system options

| Option | What it is | Verdict |
|---|---|---|
| 1. Guided first run (scripted) | A fixed level-0 script: tap here, build this, start. | Brittle against balance changes, and it only covers the first minutes. |
| 2. Just-in-time tips from events | A small director listens to run events. The first time something new happens, it pauses and shows 1–3 cards with a spotlight on the thing. | Covers everything the user listed, including future content, and is data-driven. **Chosen.** |
| 3. Encyclopedia only | Tap an enemy or unit for info. | Useful as a complement (later), but doesn't teach at the moment it's needed. |

**Option 2, in detail:**
- **Triggers come from existing core signals.** Examples: first build phase, first crate
  spawned, first time an upgrade is affordable, first jam, first siege, new enemy type, new
  portal, first card pick, campaign skill tree unlocked, and later strike and synergy.
- **The first build keeps one "do" step.** The card says "Tap a pad" and waits for the tap.
  This is the Bloons/Clash guided hand, used only once.
- **The NEW THREAT card joins the same system.** It becomes a tip with the enemy portrait,
  one line, and the weak/strong icon rows, so every new thing looks the same.
- **"Seen" tips are saved in the save file** (save v6, migrated from v5). There's a "Reset
  tips" option on the campaign screen.
- **Headless and tests:** tips must never block `--autoplay`, probes or tests. The director is
  a pure core class, and the view is the only part that pauses.

## 7. Open questions for the user

1. **Which style direction:** A, B or C? Stills side by side, once the token system renders
   them.
2. **Keep the one guided "tap here" step for the first build**, or cards only?
   Recommendation: keep it; it's the fastest way to teach the core verb.
3. **Can the IntelCard become a tutorial card** (same look, shorter text)? Recommendation:
   yes.
4. **Rewrite all descriptions to ≤ 80 characters?** Enemies, units, cards, skills.
   Recommendation: yes, and put icons where words were.
