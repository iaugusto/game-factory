# Art readability and resolution: research

**Date:** 2026-09-27.

**Ask:** improve the resolution and design of the enemies and the units. The user picked
**A + B** below and asked for a comparison sheet before any change to the game.

## Findings

**Resolution**
- The game is laid out on a 540×960 screen and scaled to fit the real one (`canvas_items`
  stretch, `expand` aspect).
- Art SVGs are rasterized at **2×** their field size, with no mipmaps, and drawn at
  `Art.SCALE` 0.5.
- On a 1080-wide phone the scale is about 2×, which is exactly right.
- On bigger screens the scale goes past 2×, so sprites are stretched and look soft:
  - 1440p phones: 2.67×
  - tablets: about 2.85×
- On the desktop the window is 540×960 (1×). There the 2× textures are shrunk with no
  mipmaps, so thin lines alias.

**Design**
- Enemies are drawn about 30–40 px wide on the 540 field, and the thin legs, eyes and
  outlines get lost.
- Two pairs of enemies share a hue family:
  - Skitter (acid green) and Mender (soft green)
  - Drone (ember orange) and Ravager (rust red)
- Every unit's head is olive and steel, small inside its base. Nothing on a unit says its
  damage type, although the counter chart is the core decision.

## Options considered

- **A. Sharpness.** Rasterize sprites at 4× and turn on mipmaps. Grounds and the wall stay
  at 2×, because a 4× ground is about 30 MB of video memory.
- **B. Readability, in the same style.** Changes to the generator only:
  - bigger enemies
  - thicker ink, legs and eyes
  - separate hues for the colour clashes
  - bigger unit heads
  - a damage-type accent on each unit and its base
- **C. Richer procedural art.** Walk and idle animations, upgrade looks. Deferred.
- **D. Hand-made or bought art.** Revisit at the vertical slice; the paid routes need the
  user's OK on cost.

**Chosen:** A + B.

## Comparison sheet

The sheet is `captures/art-compare-ab.png`. It was rendered by Godot's own SVG rasterizer
(ThorVG) with a throwaway probe script, at two sizes:
- the 540×960 desktop window at 1×, pixel-zoomed
- a 1440p phone at 2.67×

The proposal shown there:

**Enemies**
- First proposal: zoomed 1.35× for Skitter, Drone and Mender; 1.3× for Spitter, Ravager and
  Splitter; 1.25× for Carapace; 1.1× for the Hive Queen. The user judged that too big, so
  now: 1.1× for Skitter, Drone and Mender, 1.0× for the rest.
- Shell ink 1.1 → 1.4, legs at least 1.6 wide, eyes ×1.3.
- Mender recoloured bone white (its halo stays green). Ravager recoloured crimson.

**Units**
- Heads ×1.1 (first proposal 1.35, judged too big).
- Accents in the colours of the `ui/dmg_*` icons:
  - kinetic brass: Rifleman and MG
  - explosive orange: Mortar
  - piercing violet: Sniper and Rail
  - cryo cyan: Cryo
- Each unit gets its own base: emplacement corners painted in the accent, troop sandbags
  at the back dyed in it.

**Known weaknesses of the proposal**
- The Rifleman's brass sandbags barely stand out, since brass is close to sand.
- The prone Sniper now hangs past its sandbag ring.
