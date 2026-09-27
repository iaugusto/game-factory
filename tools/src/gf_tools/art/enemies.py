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
  rust-red with ember eyes.
- Splitter (bursts into Skitters): a bloated, translucent brood sac on short legs, the brood
  visible inside; sickly yellow.
- Mender (heals the swarm): slender, with a glowing green halo organ over its back; soft green.
- Hive Queen (boss): huge; a swollen abdomen of glowing egg sacs, a spiked crown, eight legs.
"""

from __future__ import annotations

from typing import Callable

from . import palette as P
from .svg import Svg, ellipse_points, polar, smooth_path

# Frame-to-frame leg swing, degrees.
SWING = 13.0


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
    for i, ((hx, hy), a, b) in enumerate(zip(hips, angles, bends)):
        group = 1 if i % 2 == 0 else -1
        sw = SWING * group * (1 if frame == 0 else -1)
        _leg(s, (hx, hy), a, sw, l1, l2, b, color, width, highlight)                  # left
        _leg(s, (2 * cx - hx, hy), 180 - a, sw, l1, l2, -b, color, width, highlight)  # right


def _shell(s: Svg, d: str, dark: str, mid: str, light: str, hl: tuple[float, float] = (0.35, 0.3)) -> None:
    """A glossy chitin shape: outlined, lit from the upper left."""
    fill = s.radial([(0, light, 1), (0.45, mid, 1), (1, dark, 1)], cx=hl[0], cy=hl[1], r=0.85,
                    fx=hl[0] - 0.05, fy=hl[1] - 0.05)
    s.outlined(d, fill, P.INK, 1.1)


def _gloss(s: Svg, cx: float, cy: float, rx: float, ry: float, opacity: float = 0.5) -> None:
    """A specular highlight blob on the upper left of a rounded shape."""
    g = s.radial([(0, "#ffffff", opacity), (1, "#ffffff", 0)])
    s.ellipse(cx - rx * 0.35, cy - ry * 0.4, rx * 0.45, ry * 0.3, fill=g)


def _eye(s: Svg, x: float, y: float, r: float, glow: str) -> None:
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


# --- registry ------------------------------------------------------------------------------

# id -> (draw function, frame box size in art units)
ENEMIES: dict[str, tuple[Callable[[Svg, int], None], float]] = {
    "grunt": (drone, 44.0),
    "runner": (skitter, 44.0),
    "brute": (carapace, 64.0),
    "spitter": (spitter, 48.0),
    "ravager": (ravager, 52.0),
    "splitter": (splitter, 52.0),
    "mender": (mender, 44.0),
    "boss": (queen, 128.0),
}


def walk_atlas(enemy_id: str) -> Svg:
    """The two-frame walk atlas for `enemy_id`: frames side by side, each `box` square."""
    draw, box = ENEMIES[enemy_id]
    s = Svg(box * 2, box)
    for frame in (0, 1):
        # Each frame is clipped to its own box so nothing bleeds into its neighbour (texture
        # filtering at the seam would otherwise show it).
        clip = s.clip(f'<rect x="0.5" y="0.5" width="{box - 1}" height="{box - 1}"/>')
        with s.group(f"translate({box * frame},0)"):
            with s.group(None, clip_path=clip):
                draw(s, frame)
    return s
