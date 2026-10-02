"""The swarm: eight alien bugs, top-down, facing down the lane (+y, toward the wall).

Each enemy is a two-frame walk atlas (frame 0 on the left half, frame 1 on the right). The
frames differ only in the legs (an alternating tripod gait), so the game's shader can flip
between them by distance walked and the body never jitters.

The archetypes read by silhouette as much as by colour:
- Skitter (fast, fragile): a small body on long, thin, splayed legs; antennae; acid green.
- Drone (the line): a compact classic bug; ember orange; glowing eyes.
- Carapace (slow, armoured): a wide beetle shell with plates, rim spikes and a horned shield;
  stubby legs; violet, with a glowing vent on its back (its "weak point").
- Spitter (ranged, disables units): a squat body under a swollen, glowing acid gland with a
  spout at the front; teal, with a lime glow. Its glob shuts a unit down for a few seconds.
- Ravager (hunts units): hunched and broad-shouldered with two huge scything claws forward;
  crimson with ember eyes (deeper than the Drone's orange, so the two never blur).
- Splitter (bursts into Skitters): a bloated, translucent brood sac on short legs, the brood
  visible inside; sickly yellow.
- Mender (heals the swarm): slender and pale bone-white, with a glowing green halo organ over
  its back (bone, not green, so it never reads as a Skitter).
- Hive Queen (boss): huge; a swollen abdomen of glowing egg sacs, a spiked crown, eight legs.

Stage 2 of the content expansion (docs/2026-09-27-content-expansion/):
- Wasp (flies): a slim, amber-and-black striped body with a stinger and two pairs of glassy
  wings that beat between the frames (the only enemy whose frames move wings, not legs).
- Warden (shields its pack): a broad, plated steel-blue body carrying a glowing shield
  projector dome on its back; the bubble itself is drawn by the game.
- Burrower (dives): an earth-brown mole-cricket, low and segmented, with two huge shovel claws
  forward.
- Bombardier (sieges from range): an olive body under a tall bile-green sac feeding a stubby
  mortar tube pointed forward.

Stage 3, the bosses (each as big as the Queen, in its own hue):
- Broodmother (hatches swarms): a bloated copper nest of translucent pods, a green Skitter
  embryo curled in each, on eight stubby legs.
- Siege Titan (plated, sheds at half health): overlapping slate plates split by glowing ember
  seams, a battering ram forward, six pillar legs.
- The Overmind (the finale): a giant indigo brain, its folds lit by cyan neural light, on
  writhing tendrils (the frames swing the tendrils), with a crown of eyes forward.
"""

from __future__ import annotations

from typing import Callable

from . import palette as P
from .svg import Svg, ellipse_points, path_from, polar, smooth_path

# Frame-to-frame leg swing, degrees.
SWING = 13.0
# Readability floors (art units, before the per-enemy zoom): thinner legs and smaller eyes
# vanish at phone size.
LEG_MIN = 1.6
EYE_BOOST = 1.3


def _leg(s: Svg, hip: tuple[float, float], deg: float, swing: float, l1: float, l2: float,
         bend: float, color: str, width: float, highlight: str | None) -> None:
    knee = polar(hip[0], hip[1], l1, deg + swing)
    foot = polar(knee[0], knee[1], l2, deg + swing + bend)
    s.limb([hip, knee, foot], color, P.INK, width, highlight)
    s.circle(knee[0], knee[1], width * 0.62, fill=color, stroke=P.INK, stroke_width=0.6)
    s.circle(foot[0], foot[1], width * 0.45, fill=P.INK)


def _legs(s: Svg, cx: float, hips: list[tuple[float, float]], angles: list[float],
          l1: float, l2: float, bends: list[float], color: str, width: float, frame: int,
          highlight: str | None = None) -> None:
    """Pairs of legs, mirrored across x = cx, with a tripod gait: legs alternate groups and
    the right side swings opposite to the left."""
    width = max(width, LEG_MIN)
    for i, ((hx, hy), a, b) in enumerate(zip(hips, angles, bends)):
        group = 1 if i % 2 == 0 else -1
        sw = SWING * group * (1 if frame == 0 else -1)
        _leg(s, (hx, hy), a, sw, l1, l2, b, color, width, highlight)                  # left
        _leg(s, (2 * cx - hx, hy), 180 - a, sw, l1, l2, -b, color, width, highlight)  # right


def _shell(s: Svg, d: str, dark: str, mid: str, light: str, hl: tuple[float, float] = (0.35, 0.3)) -> None:
    """A glossy chitin shape: outlined, lit from the upper left."""
    fill = s.radial([(0, light, 1), (0.45, mid, 1), (1, dark, 1)], cx=hl[0], cy=hl[1], r=0.85,
                    fx=hl[0] - 0.05, fy=hl[1] - 0.05)
    s.outlined(d, fill, P.INK, 1.4)


def _gloss(s: Svg, cx: float, cy: float, rx: float, ry: float, opacity: float = 0.5) -> None:
    """A specular highlight blob on the upper left of a rounded shape."""
    g = s.radial([(0, "#ffffff", opacity), (1, "#ffffff", 0)])
    s.ellipse(cx - rx * 0.35, cy - ry * 0.4, rx * 0.45, ry * 0.3, fill=g)


def _eye(s: Svg, x: float, y: float, r: float, glow: str) -> None:
    r *= EYE_BOOST
    s.glow(x, y, r * 3.2, glow, 0.55)
    s.circle(x, y, r, fill=glow, stroke=P.INK, stroke_width=0.5)
    s.circle(x - r * 0.3, y - r * 0.3, r * 0.35, fill="#ffffff", opacity=0.9)


# --- Drone --------------------------------------------------------------------------------

def drone(s: Svg, frame: int) -> None:
    dark, mid, light, glow = P.DRONE
    cx = 22.0
    _legs(s, cx, [(17.5, 22.5), (17, 25), (17.5, 27.5)], [205, 180, 150], 6.5, 7.0,
          [-30, 10, 35], mid, 1.7, frame, light)
    # abdomen (back, up) with segment bands
    _shell(s, smooth_path(ellipse_points(cx, 14.5, 8.5, 10, 14)), dark, mid, light)
    for k, y in enumerate((10.5, 14.5, 18.5)):
        w = 7.5 - abs(k - 1) * 1.6
        s.path(f"M{cx - w},{y} Q{cx},{y + 2.4} {cx + w},{y}", fill="none", stroke=dark,
               stroke_width=0.9, opacity=0.8)
    _gloss(s, cx, 14.5, 8.5, 10)
    # thorax and head
    _shell(s, smooth_path(ellipse_points(cx, 25, 6.8, 4.6, 12)), dark, mid, light)
    _shell(s, smooth_path(ellipse_points(cx, 30.5, 5.2, 4.2, 12)), dark, dark, mid)
    # mandibles
    for sgn in (-1, 1):
        s.path(f"M{cx + sgn * 2.2},{33.5} Q{cx + sgn * 4.8},{36.5} {cx + sgn * 1.6},{38.8}",
               fill="none", stroke=P.INK, stroke_width=2.2, stroke_linecap="round")
        s.path(f"M{cx + sgn * 2.2},{33.5} Q{cx + sgn * 4.8},{36.5} {cx + sgn * 1.6},{38.8}",
               fill="none", stroke=light, stroke_width=0.9, stroke_linecap="round")
    _eye(s, cx - 2.3, 31.6, 1.2, glow)
    _eye(s, cx + 2.3, 31.6, 1.2, glow)


# --- Skitter ------------------------------------------------------------------------------

def skitter(s: Svg, frame: int) -> None:
    dark, mid, light, glow = P.SKITTER
    cx = 22.0
    _legs(s, cx, [(19.8, 21), (19.5, 23.5), (19.8, 26)], [215, 185, 145], 8.2, 8.8,
          [-40, 12, 45], mid, 1.1, frame, light)
    # antennae, swept forward
    for sgn in (-1, 1):
        sw = 4 * (1 if frame == 0 else -1) * sgn
        s.limb([(cx + sgn * 1.2, 32), (cx + sgn * 4 + sw * 0.3, 37), (cx + sgn * 7 + sw, 42)],
               light, P.INK, 0.7)
    _shell(s, smooth_path(ellipse_points(cx, 13.5, 4.8, 8.5, 12)), dark, mid, light)
    # bioluminescent dots down the back
    for y in (9.5, 13, 16.5):
        s.glow(cx, y, 2.6, glow, 0.5)
        s.circle(cx, y, 0.9, fill=glow)
    _shell(s, smooth_path(ellipse_points(cx, 23.5, 3.8, 4.4, 10)), dark, mid, light)
    _shell(s, smooth_path(ellipse_points(cx, 29.5, 3.2, 3.6, 10)), dark, mid, light)
    _eye(s, cx - 1.5, 30.8, 0.9, "#ffffff")
    _eye(s, cx + 1.5, 30.8, 0.9, "#ffffff")


# --- Carapace -----------------------------------------------------------------------------

def carapace(s: Svg, frame: int) -> None:
    dark, mid, light, glow = P.CARAPACE
    cx = 32.0
    _legs(s, cx, [(17, 26), (16, 32), (17, 38)], [215, 180, 145], 7, 6.5, [-25, 5, 30], mid,
          3.2, frame, light)
    # rim spikes behind the shell
    for i in range(11):
        a = 200 + i * 14
        base_l = polar(cx, 30, 20.5, a - 5)
        base_r = polar(cx, 30, 20.5, a + 5)
        tip = polar(cx, 30, 26, a)
        s.outlined(f"M{base_l[0]},{base_l[1]} L{tip[0]},{tip[1]} L{base_r[0]},{base_r[1]} Z",
                   dark, P.INK, 0.8)
    # the shell: two elytra halves split by a seam
    shell = ellipse_points(cx, 30, 21, 22, 20, jitter=[0, 0.02, 0, -0.02])
    _shell(s, smooth_path(shell), dark, mid, light)
    s.path(f"M{cx},{9} L{cx},{50}", stroke=P.INK, stroke_width=1.4)
    s.path(f"M{cx - 0.6},{10} L{cx - 0.6},{49}", stroke=light, stroke_width=0.5, opacity=0.5)
    # plate ridges
    for sgn in (-1, 1):
        for k, (y, w) in enumerate(((17, 15), (27, 18), (37, 16))):
            s.path(f"M{cx + sgn * 2},{y} Q{cx + sgn * w * 0.6},{y - 3} {cx + sgn * w},{y + 2}",
                   fill="none", stroke=dark, stroke_width=1.3, opacity=0.9)
            s.path(f"M{cx + sgn * 2},{y - 1} Q{cx + sgn * w * 0.6},{y - 4} {cx + sgn * w},{y + 1}",
                   fill="none", stroke=light, stroke_width=0.6, opacity=0.45)
    _gloss(s, cx - 6, 26, 12, 16, 0.4)
    _gloss(s, cx + 8, 26, 8, 14, 0.18)
    # glowing vent on the back: the weak point
    s.glow(cx, 13, 9, glow, 0.8)
    s.ellipse(cx, 13, 3.5, 2.4, fill=glow, stroke=P.INK, stroke_width=0.8)
    s.ellipse(cx, 13, 1.6, 1, fill="#ffffff")
    # horned head shield
    shield = f"M{cx - 13},{47} Q{cx},{58} {cx + 13},{47} Q{cx},{52} {cx - 13},{47} Z"
    s.outlined(shield, s.linear([(0, light, 1), (1, dark, 1)]), P.INK, 1.0)
    for sgn in (-1, 1):
        s.outlined(f"M{cx + sgn * 7},{51} Q{cx + sgn * 11},{57} {cx + sgn * 6},{61} "
                   f"Q{cx + sgn * 8},{56} {cx + sgn * 4},{52.5} Z", light, P.INK, 0.8)
    _eye(s, cx - 3.5, 51.5, 1.1, glow)
    _eye(s, cx + 3.5, 51.5, 1.1, glow)


# --- Spitter -------------------------------------------------------------------------------

def spitter(s: Svg, frame: int) -> None:
    dark, mid, light, glow = P.SPITTER
    cx = 24.0
    _legs(s, cx, [(18.5, 25), (18, 28), (18.5, 31)], [210, 182, 150], 6.0, 6.5,
          [-28, 8, 32], mid, 2.0, frame, light)
    # squat abdomen
    _shell(s, smooth_path(ellipse_points(cx, 17, 10, 10.5, 14)), dark, mid, light)
    # the acid gland: a swollen, translucent sac on the back, glowing lime
    s.glow(cx, 15, 13, glow, 0.55)
    gland = s.radial([(0, "#f4ffc0", 1), (0.45, glow, 1), (1, "#5a8a10", 1)], cx=0.38, cy=0.32)
    s.outlined(smooth_path(ellipse_points(cx, 15, 7, 7.5, 12, jitter=[0, 0.04, -0.03])), gland,
               P.INK, 0.9)
    for (x, y, r) in ((cx - 2.5, 12.5, 1.3), (cx + 2.2, 16.5, 1.0), (cx - 0.5, 18.5, 0.8)):
        s.circle(x, y, r, fill="#ffffff", opacity=0.7)  # bubbles
    # thorax and head
    _shell(s, smooth_path(ellipse_points(cx, 28, 6.8, 4.8, 12)), dark, mid, light)
    _shell(s, smooth_path(ellipse_points(cx, 33.5, 5, 4, 12)), dark, dark, mid)
    # the spout, dripping
    s.outlined(f"M{cx - 2.2},{36} L{cx - 1.4},{41.5} L{cx + 1.4},{41.5} L{cx + 2.2},{36} Z",
               s.linear([(0, mid, 1), (1, dark, 1)]), P.INK, 0.8)
    s.glow(cx, 42, 3.2, glow, 0.8)
    s.circle(cx, 42.3, 1.2, fill=glow)
    _eye(s, cx - 2.6, 32.8, 1.1, glow)
    _eye(s, cx + 2.6, 32.8, 1.1, glow)


# --- Ravager -------------------------------------------------------------------------------

def ravager(s: Svg, frame: int) -> None:
    dark, mid, light, glow = P.RAVAGER
    cx = 26.0
    _legs(s, cx, [(19, 22), (18.5, 26), (19, 30)], [215, 185, 150], 7.0, 7.5, [-25, 8, 30], mid,
          2.6, frame, light)
    # hunched back with spines
    _shell(s, smooth_path(ellipse_points(cx, 18, 11, 11.5, 16)), dark, mid, light)
    for i, (x, y) in enumerate(((cx - 6, 10), (cx, 8), (cx + 6, 10), (cx - 3, 14), (cx + 3, 14))):
        s.outlined(f"M{x - 2},{y + 2} L{x},{y - 4} L{x + 2},{y + 2} Z", light, P.INK, 0.6)
    _gloss(s, cx, 18, 11, 11.5, 0.35)
    # scything claws forward, swinging with the gait
    sw = 5 * (1 if frame == 0 else -1)
    for sgn in (-1, 1):
        base = (cx + sgn * 7, 31)
        tip = (cx + sgn * (15 + sw * sgn * 0.3), 46)
        s.limb([base, (cx + sgn * 13, 37), tip], mid, P.INK, 3.2, light)
        s.outlined(f"M{tip[0]},{tip[1]} L{tip[0] - sgn * 7},{tip[1] - 2} L{tip[0] - sgn * 2},{tip[1] - 5} Z",
                   "#f2e6d0", P.INK, 0.7)
    _shell(s, smooth_path(ellipse_points(cx, 32, 7, 5.5, 12)), dark, dark, mid)
    _eye(s, cx - 2.8, 33.5, 1.2, glow)
    _eye(s, cx + 2.8, 33.5, 1.2, glow)


# --- Splitter ------------------------------------------------------------------------------

def splitter(s: Svg, frame: int) -> None:
    dark, mid, light, glow = P.SPLITTER
    cx = 26.0
    _legs(s, cx, [(19.5, 30), (19.5, 34), (20, 38)], [210, 180, 150], 5.0, 5.5, [-25, 8, 30], mid,
          1.8, frame, light)
    # the bloated brood sac: translucent, with Skitter young curled inside
    sac = s.radial([(0, "#fffbe0", 0.95), (0.55, light, 0.9), (1, mid, 1)], cx=0.4, cy=0.35)
    s.outlined(smooth_path(ellipse_points(cx, 22, 15, 15, 18, jitter=[0, 0.04, -0.03, 0.02])), sac,
               P.INK, 1.1)
    for (x, y, a) in ((cx - 5, 17, 20), (cx + 5, 19, -30), (cx, 27, 80)):
        with s.group(f"translate({x},{y}) rotate({a})"):
            s.ellipse(0, 0, 4.5, 2.6, fill=P.SKITTER[1], stroke=P.INK, stroke_width=0.5, opacity=0.85)
            s.circle(2.8, 0, 1.1, fill=P.SKITTER[0], opacity=0.9)
    for (x, y) in ((cx - 9, 14), (cx + 9, 26), (cx - 7, 29)):  # veins
        s.path(f"M{cx},{22} Q{(cx + x) / 2 + 2},{(22 + y) / 2 - 2} {x},{y}", fill="none", stroke=dark,
               stroke_width=0.8, opacity=0.6)
    _gloss(s, cx, 22, 15, 15, 0.5)
    _shell(s, smooth_path(ellipse_points(cx, 38, 5.5, 4.2, 12)), dark, mid, light)
    _eye(s, cx - 2.2, 39.5, 1.0, glow)
    _eye(s, cx + 2.2, 39.5, 1.0, glow)


# --- Mender --------------------------------------------------------------------------------

def mender(s: Svg, frame: int) -> None:
    dark, mid, light, glow = P.MENDER
    cx = 22.0
    _legs(s, cx, [(19.5, 20), (19.5, 23), (19.5, 26)], [210, 182, 150], 8.0, 8.5, [-35, 10, 40], mid,
          1.2, frame, light)
    # the halo organ: a glowing ring over its back
    s.glow(cx, 14, 16, glow, 0.6)
    s.circle(cx, 14, 8.5, fill="none", stroke=glow, stroke_width=2.4, opacity=0.9)
    s.circle(cx, 14, 8.5, fill="none", stroke="#ffffff", stroke_width=0.8, opacity=0.7)
    _shell(s, smooth_path(ellipse_points(cx, 15, 4.5, 8, 12)), dark, mid, light)
    for y in (11, 15, 19):
        s.circle(cx, y, 1.2, fill=glow)
    _shell(s, smooth_path(ellipse_points(cx, 25.5, 3.6, 3.8, 10)), dark, mid, light)
    _shell(s, smooth_path(ellipse_points(cx, 31, 3.0, 3.3, 10)), dark, mid, light)
    for sgn in (-1, 1):  # feelers
        sw = 3 * (1 if frame == 0 else -1) * sgn
        s.limb([(cx + sgn * 1.2, 33), (cx + sgn * 3.5 + sw * 0.3, 38), (cx + sgn * 5 + sw, 42)],
               light, P.INK, 0.7)
    _eye(s, cx - 1.4, 31.5, 0.9, "#ffffff")
    _eye(s, cx + 1.4, 31.5, 0.9, "#ffffff")


# --- Hive Queen ---------------------------------------------------------------------------

def queen(s: Svg, frame: int) -> None:
    dark, mid, light, glow = P.QUEEN
    cx = 64.0
    # eight legs
    _legs(s, cx, [(46, 72), (44, 78), (44, 84), (46, 90)], [215, 195, 170, 145], 16, 18,
          [-30, -10, 15, 35], mid, 5.0, frame, light)
    # abdomen: a swollen, banded egg sac
    ab = ellipse_points(cx, 42, 31, 36, 22, jitter=[0, 0.03, -0.02, 0.02])
    _shell(s, smooth_path(ab), dark, mid, light, hl=(0.3, 0.25))
    for k, y in enumerate((20, 32, 44, 56, 66)):
        w = 26 - abs(k - 2) * 5
        s.path(f"M{cx - w},{y} Q{cx},{y + 5} {cx + w},{y}", fill="none", stroke=dark,
               stroke_width=1.6, opacity=0.85)
    # glowing egg sacs
    for (x, y, r) in ((50, 26, 5), (76, 30, 6), (60, 46, 6.5), (80, 50, 4.5), (46, 52, 5),
                      (66, 64, 4.5), (56, 16, 3.5), (72, 14, 3.5)):
        s.glow(x, y, r * 2.4, "#ff9a5c", 0.55)
        s.circle(x, y, r, fill=s.radial([(0, "#fff0c0", 1), (0.5, "#ffb070", 1), (1, "#c04030", 1)],
                                          cx=0.4, cy=0.35), stroke=P.INK, stroke_width=1)
        s.circle(x - r * 0.3, y - r * 0.35, r * 0.28, fill="#ffffff", opacity=0.8)
    _gloss(s, cx - 4, 36, 26, 30, 0.35)
    # thorax: armoured, spiked
    th = ellipse_points(cx, 82, 21, 13, 16)
    _shell(s, smooth_path(th), dark, mid, light)
    for sgn in (-1, 1):
        for k in range(3):
            x = cx + sgn * (7 + k * 6)
            s.outlined(f"M{x - 2.5},{76 - k} L{x + sgn * 2},{67 - k * 2} L{x + 2.5},{76 - k} Z",
                       light, P.INK, 0.9)
    # head with a crown of spikes
    for i, a in enumerate((230, 250, 270, 290, 310)):
        base_l = polar(cx, 99, 11, a - 7)
        base_r = polar(cx, 99, 11, a + 7)
        tip = polar(cx, 99, 21 if i == 2 else 18, a)
        s.outlined(f"M{base_l[0]},{base_l[1]} L{tip[0]},{tip[1]} L{base_r[0]},{base_r[1]} Z",
                   mid, P.INK, 1.0)
    _shell(s, smooth_path(ellipse_points(cx, 100, 14, 11, 16)), dark, mid, light)
    # mandibles
    for sgn in (-1, 1):
        d = (f"M{cx + sgn * 6},{107} Q{cx + sgn * 16},{114} {cx + sgn * 8},{124} "
             f"Q{cx + sgn * 10},{115} {cx + sgn * 3},{110} Z")
        s.outlined(d, light, P.INK, 1.0)
    for (x, y, r) in ((cx - 5.5, 101, 1.8), (cx + 5.5, 101, 1.8), (cx - 2.5, 105, 1.3),
                      (cx + 2.5, 105, 1.3), (cx - 8, 97.5, 1.1), (cx + 8, 97.5, 1.1)):
        _eye(s, x, y, r, P.QUEEN[3])


# --- Wasp ----------------------------------------------------------------------------------

def wasp(s: Svg, frame: int) -> None:
    dark, mid, light, _ = P.WASP
    cx = 22.0
    # two pairs of glassy wings; frames beat them (forward/back)
    beat = 14 if frame == 0 else -10
    for sgn in (-1, 1):
        for k, (length, width, base) in enumerate(((15.0, 5.2, 205), (11.5, 4.0, 170))):
            a = base + beat * (1 if k == 0 else 0.6)
            deg = a if sgn < 0 else 180 - a
            tip = polar(cx + sgn * 2.5, 21, length, deg)
            mid_pt = ((cx + sgn * 2.5 + tip[0]) / 2, (21 + tip[1]) / 2)
            with s.group(f"rotate({deg} {mid_pt[0]} {mid_pt[1]})"):
                s.ellipse(mid_pt[0], mid_pt[1], length / 2, width, fill="#e8f6ff", opacity=0.55,
                          stroke=P.INK, stroke_width=0.6)
                s.path(f"M{mid_pt[0] - length / 2 + 1},{mid_pt[1]} L{mid_pt[0] + length / 2 - 2},{mid_pt[1]}",
                       stroke="#9ab8c8", stroke_width=0.5, opacity=0.8)
    # tucked legs
    _legs(s, cx, [(20, 22), (20, 24.5)], [200, 160], 3.5, 3.0, [-20, 20], dark, 1.0, frame)
    # striped abdomen with a stinger at the back (up)
    s.outlined(f"M{cx - 1.2},{3.5} L{cx},{0.8} L{cx + 1.2},{3.5} Z", P.INK, P.INK, 0.6)
    _shell(s, smooth_path(ellipse_points(cx, 12.5, 5.2, 8.8, 14)), dark, mid, light)
    for y in (8.0, 12.0, 16.0):
        s.path(f"M{cx - 4.6},{y} Q{cx},{y + 1.8} {cx + 4.6},{y} L{cx + 4.2},{y + 1.8} "
               f"Q{cx},{y + 3.4} {cx - 4.2},{y + 1.8} Z", fill=P.WASP_STRIPE, opacity=0.9)
    _gloss(s, cx, 12.5, 5.2, 8.8, 0.45)
    # thorax (a narrow waist) and head
    _shell(s, smooth_path(ellipse_points(cx, 23.5, 4.2, 3.8, 12)), P.WASP_STRIPE, dark, mid)
    _shell(s, smooth_path(ellipse_points(cx, 29.5, 4.4, 3.6, 12)), dark, mid, light)
    for sgn in (-1, 1):  # antennae
        s.limb([(cx + sgn * 1.2, 32), (cx + sgn * 3.5, 36), (cx + sgn * 5.5, 38.5)], P.WASP_STRIPE,
               P.INK, 0.7)
    _eye(s, cx - 2.3, 30.2, 1.2, "#2a1a08")
    _eye(s, cx + 2.3, 30.2, 1.2, "#2a1a08")


# --- Warden --------------------------------------------------------------------------------

def warden(s: Svg, frame: int) -> None:
    dark, mid, light, glow = P.WARDEN
    cx = 26.0
    _legs(s, cx, [(18, 24), (17.5, 28), (18, 32)], [212, 182, 150], 7.0, 7.0, [-25, 8, 30], mid,
          2.4, frame, light)
    # broad plated body
    _shell(s, smooth_path(ellipse_points(cx, 22, 13, 13.5, 18)), dark, mid, light)
    for sgn in (-1, 1):  # side plates
        s.path(f"M{cx + sgn * 4},{11} Q{cx + sgn * 12},{15} {cx + sgn * 11},{30}", fill="none",
               stroke=dark, stroke_width=1.3, opacity=0.9)
        s.path(f"M{cx + sgn * 4.6},{12} Q{cx + sgn * 11.4},{16} {cx + sgn * 10.4},{29}", fill="none",
               stroke=light, stroke_width=0.6, opacity=0.5)
    # the shield projector: a glowing dome with a ring around it
    s.glow(cx, 19, 14, glow, 0.7)
    s.circle(cx, 19, 7.5, fill="none", stroke=glow, stroke_width=1.6, opacity=0.9)
    s.circle(cx, 19, 5, fill=s.radial([(0, "#ffffff", 1), (0.45, glow, 1), (1, "#1a5a9a", 1)],
                                      cx=0.4, cy=0.35), stroke=P.INK, stroke_width=0.9)
    for a in (30, 150, 270):  # emitter studs
        x, y = polar(cx, 19, 7.5, a)
        s.circle(x, y, 1.2, fill=light, stroke=P.INK, stroke_width=0.5)
    # armoured head
    _shell(s, smooth_path(ellipse_points(cx, 37, 7, 5, 12)), dark, dark, mid)
    s.outlined(f"M{cx - 7},{38} Q{cx},{44} {cx + 7},{38} Q{cx},{41} {cx - 7},{38} Z", light, P.INK, 0.7)
    _eye(s, cx - 3, 37.5, 1.1, glow)
    _eye(s, cx + 3, 37.5, 1.1, glow)


# --- Burrower ------------------------------------------------------------------------------

def burrower(s: Svg, frame: int) -> None:
    dark, mid, light, glow = P.BURROWER
    cx = 24.0
    _legs(s, cx, [(19, 18), (19, 22)], [205, 170], 6.0, 6.0, [-20, 25], mid, 1.9, frame, light)
    # long segmented body, low to the ground
    for k, (y, rx, ry) in enumerate(((8, 6.2, 4.4), (14, 7.6, 4.6), (20, 8.2, 4.6), (26, 8.0, 4.4))):
        _shell(s, smooth_path(ellipse_points(cx, y, rx, ry, 14)), dark, mid, light)
        s.path(f"M{cx - rx + 1.5},{y + 1} Q{cx},{y + 3} {cx + rx - 1.5},{y + 1}", fill="none",
               stroke=dark, stroke_width=0.8, opacity=0.8)
    # bristles along the back
    for y in (6, 12, 18, 24):
        for sgn in (-1, 1):
            s.line((cx + sgn * 2, y), (cx + sgn * 3.2, y - 2), stroke=light, stroke_width=0.6, opacity=0.7)
    # two huge shovel claws forward, digging with the gait
    sw = 4 * (1 if frame == 0 else -1)
    for sgn in (-1, 1):
        base = (cx + sgn * 5, 31)
        elbow = (cx + sgn * 11, 35 + sw * sgn * 0.25)
        s.limb([base, elbow], mid, P.INK, 3.0, light)
        blade = (f"M{elbow[0] - sgn * 1},{elbow[1] - 2} L{elbow[0] + sgn * 5},{elbow[1] + 3} "
                 f"L{elbow[0] + sgn * 2},{elbow[1] + 8} L{elbow[0] - sgn * 3},{elbow[1] + 6} Z")
        s.outlined(blade, s.linear([(0, light, 1), (1, dark, 1)]), P.INK, 0.8)
        for t in range(3):  # claw teeth
            x0 = elbow[0] + sgn * (2 - t * 1.8)
            y0 = elbow[1] + 6.5 + t * 0.4
            s.outlined(f"M{x0 - 0.8},{y0} L{x0},{y0 + 2.4} L{x0 + 0.8},{y0} Z", "#f2e6d0", P.INK, 0.4)
    # blunt head
    _shell(s, smooth_path(ellipse_points(cx, 33, 6.2, 4.6, 12)), dark, dark, mid)
    _eye(s, cx - 2.4, 34.5, 0.9, glow)
    _eye(s, cx + 2.4, 34.5, 0.9, glow)


# --- Bombardier ----------------------------------------------------------------------------

def bombardier(s: Svg, frame: int) -> None:
    dark, mid, light, glow = P.BOMBARDIER
    cx = 26.0
    _legs(s, cx, [(18, 28), (17.5, 32), (18, 36)], [212, 182, 150], 6.5, 6.5, [-25, 8, 30], mid,
          2.4, frame, light)
    # squat body
    _shell(s, smooth_path(ellipse_points(cx, 32, 10, 8, 16)), dark, mid, light)
    # the bile sac: tall, glowing, veined, feeding the tube
    s.glow(cx, 16, 16, glow, 0.5)
    sac = s.radial([(0, "#f8ffd0", 1), (0.45, glow, 1), (1, "#4a7a08", 1)], cx=0.38, cy=0.3)
    s.outlined(smooth_path(ellipse_points(cx, 16, 10, 12, 16, jitter=[0, 0.03, -0.02])), sac, P.INK, 1.1)
    for (x, y) in ((cx - 6, 10), (cx + 7, 14), (cx - 4, 22)):
        s.path(f"M{cx},{24} Q{(cx + x) / 2 + 1.5},{(24 + y) / 2} {x},{y}", fill="none", stroke="#4a7a08",
               stroke_width=0.8, opacity=0.7)
    for (x, y, r) in ((cx - 3, 12, 1.6), (cx + 3.5, 17, 1.1), (cx + 0.5, 8, 0.9)):
        s.circle(x, y, r, fill="#ffffff", opacity=0.7)
    # the mortar tube, forward
    s.outlined(f"M{cx - 3.5},{36} L{cx - 3},{46} L{cx + 3},{46} L{cx + 3.5},{36} Z",
               s.linear([(0, light, 1), (1, dark, 1)]), P.INK, 0.9)
    s.ellipse(cx, 46, 3.4, 1.4, fill=P.INK)
    s.glow(cx, 46, 3.5, glow, 0.8)
    for sgn in (-1, 1):
        _eye(s, cx + sgn * 6.5, 37, 1.0, glow)


# --- Broodmother ---------------------------------------------------------------------------

def broodmother(s: Svg, frame: int) -> None:
    dark, mid, light, glow = P.BROODMOTHER
    cx = 64.0
    # eight stubby legs, low under the nest
    _legs(s, cx, [(40, 70), (38, 78), (38, 86), (41, 94)], [210, 190, 168, 148], 12, 13,
          [-25, -8, 12, 30], mid, 5.2, frame, light)
    # the nest: a lumpy, bloated abdomen
    ab = ellipse_points(cx, 48, 38, 40, 24, jitter=[0, 0.04, -0.03, 0.05, -0.02])
    _shell(s, smooth_path(ab), dark, mid, light, hl=(0.3, 0.25))
    # translucent pods, each with a curled green embryo
    pods = ((44, 26, 8), (66, 18, 7), (86, 30, 8.5), (52, 46, 9), (78, 52, 8.5), (40, 64, 7),
            (64, 68, 7.5), (88, 70, 6.5), (60, 34, 5.5))
    for (x, y, r) in pods:
        s.circle(x, y, r + 1.4, fill=dark, opacity=0.7)
        s.circle(x, y, r, fill=s.radial([(0, "#fff2dc", 0.95), (0.6, light, 0.75), (1, mid, 0.9)],
                                         cx=0.4, cy=0.35), stroke=P.INK, stroke_width=0.9)
        s.glow(x, y + r * 0.1, r * 1.3, glow, 0.35)
        s.ellipse(x, y + r * 0.1, r * 0.42, r * 0.55, fill="#6a9a1a", stroke="#2c4a08",
                  stroke_width=0.5)
        s.circle(x, y - r * 0.28, r * 0.2, fill=glow)
        s.circle(x - r * 0.35, y - r * 0.4, r * 0.25, fill="#ffffff", opacity=0.75)
    _gloss(s, cx - 6, 40, 30, 32, 0.3)
    # thorax and head
    _shell(s, smooth_path(ellipse_points(cx, 90, 17, 10, 16)), dark, mid, light)
    _shell(s, smooth_path(ellipse_points(cx, 104, 12, 9, 16)), dark, dark, mid)
    for sgn in (-1, 1):  # mandibles
        d = (f"M{cx + sgn * 5},{109} Q{cx + sgn * 13},{115} {cx + sgn * 6},{122} "
             f"Q{cx + sgn * 8},{114} {cx + sgn * 2},{111} Z")
        s.outlined(d, light, P.INK, 1.0)
    for (x, y, r) in ((cx - 4.5, 104, 1.7), (cx + 4.5, 104, 1.7), (cx - 7.5, 100.5, 1.1),
                      (cx + 7.5, 100.5, 1.1)):
        _eye(s, x, y, r, glow)


# --- Siege Titan ---------------------------------------------------------------------------

def titan(s: Svg, frame: int) -> None:
    dark, mid, light, glow = P.TITAN
    cx = 64.0
    # six pillar legs
    _legs(s, cx, [(38, 44), (36, 64), (38, 84)], [205, 180, 155], 17, 15, [-15, 5, 20],
          mid, 7.0, frame, light)
    # the body under the plates, glowing through the seams
    s.glow(cx, 62, 46, glow, 0.35)
    body = ellipse_points(cx, 60, 34, 44, 20)
    s.outlined(smooth_path(body), s.radial([(0, "#ffd08a", 1), (0.5, glow, 1), (1, "#7a2a08", 1)]),
               P.INK, 1.4)
    # overlapping plates, back to front (each a rounded slab), rivets along their edges
    for k, (y, w, h) in enumerate(((20, 26, 10), (36, 32, 10), (53, 34, 10), (70, 32, 10),
                                   (86, 26, 9))):
        slab = [(cx - w, y + h * 0.3), (cx - w * 0.8, y - h * 0.6), (cx, y - h * 0.85),
                (cx + w * 0.8, y - h * 0.6), (cx + w, y + h * 0.3), (cx + w * 0.7, y + h * 0.75),
                (cx, y + h * 0.9), (cx - w * 0.7, y + h * 0.75)]
        _shell(s, smooth_path(slab, tension=0.35), dark, mid, light, hl=(0.3, 0.2))
        for sgn in (-1, 1):
            for f in (0.45, 0.8):
                s.circle(cx + sgn * w * f, y + h * 0.15, 1.2, fill=light, stroke=P.INK,
                         stroke_width=0.4)
        if k in (1, 2, 3):  # shoulder spikes
            for sgn in (-1, 1):
                bx = cx + sgn * w
                s.outlined(f"M{bx},{y - 4} L{bx + sgn * 9},{y + 1} L{bx},{y + 5} Z", light,
                           P.INK, 0.9)
    _gloss(s, cx - 4, 50, 28, 36, 0.25)
    # the battering ram, forward
    ram = [(cx - 12, 94), (cx + 12, 94), (cx + 9, 112), (cx, 122), (cx - 9, 112)]
    _shell(s, path_from(ram), dark, mid, light, hl=(0.35, 0.2))
    s.path(f"M{cx},{96} L{cx},{119}", fill="none", stroke=dark, stroke_width=1.2, opacity=0.8)
    for (x, y) in ((cx - 6, 100), (cx + 6, 100)):
        _eye(s, x, y, 1.6, glow)


# --- The Overmind --------------------------------------------------------------------------

def overmind(s: Svg, frame: int) -> None:
    dark, mid, light, glow = P.OVERMIND
    cx = 64.0
    # writhing tendrils (they swing between frames instead of walking)
    for i, (deg, ln) in enumerate(((200, 34), (178, 38), (156, 36), (134, 30))):
        sw = 10 * (1 if (i + frame) % 2 == 0 else -1)
        for sgn in (-1, 1):
            a = deg if sgn < 0 else 180 - deg
            base = polar(cx, 66, 30, a)
            mid_pt = polar(base[0], base[1], ln * 0.55, a + sw * sgn)
            tip = polar(mid_pt[0], mid_pt[1], ln * 0.5, a - sw * 1.6 * sgn)
            s.limb([base, mid_pt, tip], mid, P.INK, 5.0, light)
            s.circle(tip[0], tip[1], 2.0, fill=glow, stroke=P.INK, stroke_width=0.5)
    # the brain: two hemispheres, folds traced in neural light
    s.glow(cx, 56, 56, glow, 0.3)
    for sgn in (-1, 1):
        hemi = ellipse_points(cx + sgn * 17, 54, 22, 42, 20, jitter=[0, 0.03, -0.02])
        _shell(s, smooth_path(hemi), dark, mid, light, hl=(0.35 if sgn < 0 else 0.5, 0.25))
        for k, y in enumerate((26, 40, 54, 68, 82)):
            x0 = cx + sgn * 5
            x1 = cx + sgn * (30 - abs(k - 2) * 4)
            wob = 5 if k % 2 == 0 else -5
            d = (f"M{x0},{y} Q{(x0 + x1) / 2},{y + wob} {x1},{y - 2} "
                 f"Q{x1 + sgn * 3},{y + 5} {x1 - sgn * 4},{y + 8}")
            s.path(d, fill="none", stroke=dark, stroke_width=2.2, opacity=0.9)
            s.path(d, fill="none", stroke=glow, stroke_width=0.8, opacity=0.8)
    s.path(f"M{cx},{14} L{cx},{94}", fill="none", stroke=P.INK, stroke_width=2.0)
    _gloss(s, cx - 8, 44, 34, 36, 0.3)
    # the face, forward: a crown of eyes over a small maw
    _shell(s, smooth_path(ellipse_points(cx, 102, 16, 11, 16)), dark, dark, mid)
    for (x, y, r) in ((cx, 99, 3.0), (cx - 7.5, 101, 2.0), (cx + 7.5, 101, 2.0),
                      (cx - 12, 105.5, 1.3), (cx + 12, 105.5, 1.3), (cx - 3.5, 106, 1.2),
                      (cx + 3.5, 106, 1.2)):
        _eye(s, x, y, r, glow)
    s.path(f"M{cx - 5},{110} Q{cx},{115} {cx + 5},{110}", fill="none", stroke=P.INK,
           stroke_width=1.6)


# --- registry ------------------------------------------------------------------------------

# id -> (draw function, frame box size in art units, zoom). Each enemy is drawn in its box and
# then scaled by `zoom` into a box `zoom` times bigger. Only the three smallest grow (10%), so
# they read on a phone; the user judged bigger zooms (1.25-1.35) too big for the lanes.
ENEMIES: dict[str, tuple[Callable[[Svg, int], None], float, float]] = {
    "grunt": (drone, 44.0, 1.1),
    "runner": (skitter, 44.0, 1.1),
    "brute": (carapace, 64.0, 1.0),
    "spitter": (spitter, 48.0, 1.0),
    "ravager": (ravager, 52.0, 1.0),
    "splitter": (splitter, 52.0, 1.0),
    "mender": (mender, 44.0, 1.1),
    "boss": (queen, 128.0, 1.0),
    "wasp": (wasp, 44.0, 1.1),
    "warden": (warden, 52.0, 1.0),
    "burrower": (burrower, 48.0, 1.0),
    "bombardier": (bombardier, 52.0, 1.0),
    "broodmother": (broodmother, 128.0, 1.0),
    "titan": (titan, 128.0, 1.0),
    "overmind": (overmind, 128.0, 1.0),
}


def walk_atlas(enemy_id: str) -> Svg:
    """The two-frame walk atlas for `enemy_id`: frames side by side, each `box` square."""
    draw, box, zoom = ENEMIES[enemy_id]
    out = round(box * zoom)
    s = Svg(out * 2, out)
    for frame in (0, 1):
        # Each frame is clipped to its own box so nothing bleeds into its neighbour (texture
        # filtering at the seam would otherwise show it).
        clip = s.clip(f'<rect x="0.5" y="0.5" width="{box - 1}" height="{box - 1}"/>')
        with s.group(f"translate({out * frame},0) scale({out / box})"):
            with s.group(None, clip_path=clip):
                draw(s, frame)
    return s
