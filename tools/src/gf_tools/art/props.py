"""The wall, the loot crates and the barricade, plus the ground's decoration helpers (rocks,
scrub, crystals) that terrain.py paints each map's ground with.
"""

from __future__ import annotations

import random
from math import pi, sin

from . import palette as P
from .svg import Svg, ellipse_points, polar, smooth_path

FIELD_W = 540.0
FIELD_H = 860.0
def _rock(s: Svg, rng: random.Random, x: float, y: float, r: float) -> None:
    jit = [rng.uniform(-0.18, 0.18) for _ in range(9)]
    pts = ellipse_points(x, y, r, r * rng.uniform(0.65, 0.9), 9, jit, rng.uniform(0, pi))
    s.soft_shadow(x + r * 0.35, y + r * 0.45, r * 1.25, r * 0.9, 0.55)
    fill = s.radial([(0, P.ROCK_LIGHT, 1), (0.55, P.ROCK, 1), (1, "#2a2724", 1)], cx=0.35, cy=0.3)
    s.outlined(smooth_path(pts, tension=0.35), fill, "#141210", 0.7)
    s.path(smooth_path(pts[5:9] + pts[0:1], closed=False, tension=0.35), fill="none",
           stroke="#8a8378", stroke_width=0.7, opacity=0.5)


def _tuft(s: Svg, rng: random.Random, x: float, y: float, color: str) -> None:
    for _ in range(rng.randint(4, 7)):
        a = rng.uniform(200, 340)
        l = rng.uniform(4, 9)
        tip = polar(x, y, l, a)
        s.path(f"M{x},{y} Q{(x + tip[0]) / 2 + rng.uniform(-2, 2)},{(y + tip[1]) / 2} {tip[0]},{tip[1]}",
               fill="none", stroke=color, stroke_width=1.1, stroke_linecap="round", opacity=0.85)


def _crystal(s: Svg, rng: random.Random, x: float, y: float, size: float) -> None:
    s.glow(x, y - size * 0.4, size * 2.2, P.CRYSTAL, 0.28)
    for _ in range(rng.randint(2, 4)):
        a = rng.uniform(235, 305)
        h = size * rng.uniform(0.7, 1.3)
        w = size * rng.uniform(0.22, 0.32)
        tip = polar(x, y, h, a)
        l = polar(x, y, w, a - 90)
        r = polar(x, y, w, a + 90)
        mid_l = polar(l[0], l[1], h * 0.75, a)
        mid_r = polar(r[0], r[1], h * 0.75, a)
        d = f"M{l[0]},{l[1]} L{mid_l[0]},{mid_l[1]} L{tip[0]},{tip[1]} L{mid_r[0]},{mid_r[1]} L{r[0]},{r[1]} Z"
        s.outlined(d, s.linear([(0, "#d8fff6", 1), (0.4, P.CRYSTAL, 1), (1, P.CRYSTAL_DEEP, 1)], 0, 0, 1, 1),
                   "#0a2a28", 0.6)
        s.path(f"M{l[0]},{l[1]} L{mid_l[0]},{mid_l[1]} L{tip[0]},{tip[1]}", fill="none",
               stroke="#ffffff", stroke_width=0.6, opacity=0.6)


def wall() -> Svg:
    """The defensive line (540 wide). Its top edge is drawn 16 units above RunConfig.wall_y:
    a concrete-and-steel parapet, a hazard band, then the walkway the wall's build spots sit on."""
    s = Svg(FIELD_W, 112)
    rng = random.Random(3)
    s.rect(0, 20, FIELD_W, 92, fill=s.linear([(0, "#2a2e33", 1), (1, "#15181b", 1)]))
    for y in range(34, 112, 7):  # walkway grating
        s.line((0, y), (FIELD_W, y), stroke="#0d0f11", stroke_width=1.1, opacity=0.8)
        s.line((0, y + 1), (FIELD_W, y + 1), stroke="#3a4046", stroke_width=0.5, opacity=0.5)
    for x in range(0, int(FIELD_W), 18):
        s.line((x, 30), (x, 112), stroke="#0d0f11", stroke_width=0.8, opacity=0.5)
    # parapet blocks
    x = 0.0
    while x < FIELD_W:
        w = rng.uniform(40, 56)
        s.rect(x + 0.6, 0, w - 1.2, 22, rx=2.5,
               fill=s.linear([(0, "#9a958c", 1), (0.35, "#77736c", 1), (1, "#4a4743", 1)]),
               stroke="#141210", stroke_width=1.2)
        s.rect(x + 3, 2, w - 6, 3, rx=1.4, fill="#ffffff", opacity=0.18)
        for _ in range(rng.randint(0, 2)):  # chips and cracks
            cx0 = x + rng.uniform(6, w - 6)
            s.path(f"M{cx0},{rng.uniform(3, 8)} l{rng.uniform(-4, 4)},{rng.uniform(4, 7)} "
                   f"l{rng.uniform(-3, 3)},{rng.uniform(3, 6)}", fill="none", stroke="#2a2724",
                   stroke_width=0.8)
        s.circle(x + 6, 16, 1.2, fill="#3a3632")
        s.circle(x + w - 6, 16, 1.2, fill="#3a3632")
        x += w
    # hazard band
    s.rect(0, 22, FIELD_W, 7, fill=P.HAZARD)
    for i in range(-2, 60):
        x0 = i * 12
        s.path(f"M{x0},{29} L{x0 + 6},{22} L{x0 + 12},{22} L{x0 + 6},{29} Z", fill="#1a1a1a")
    s.line((0, 22), (FIELD_W, 22), stroke="#141210", stroke_width=1)
    s.line((0, 29), (FIELD_W, 29), stroke="#141210", stroke_width=1)
    # floodlights throwing warm light up the field
    for lx in (45, 180, 360, 495):
        s.glow(lx, 0, 30, "#ffd08a", 0.35)
        s.rect(lx - 5, -1, 10, 6, rx=2, fill="#2a2e33", stroke="#0d0f11", stroke_width=0.8)
        s.rect(lx - 3.5, -0.5, 7, 2.4, rx=1, fill="#fff2c8")
    return s


def _crate_boards(s: Svg, x0: float, y0: float, w: float, h: float, n: int) -> None:
    for i in range(n):
        bx = x0 + i * w / n
        s.rect(bx, y0, w / n, h, fill=s.linear([(0, P.WOOD_LIGHT, 1), (1, P.WOOD, 1)], 0, 0, 1, 1),
               stroke=P.WOOD_DARK, stroke_width=0.8)
        s.line((bx + w / n * 0.5, y0 + 3), (bx + w / n * 0.5, y0 + h - 3), stroke=P.WOOD_DARK,
               stroke_width=0.35, opacity=0.6)


def crate_supply() -> Svg:
    """A wooden supply crate with steel corners and a stencilled mark."""
    s = Svg(40, 40)
    s.soft_shadow(22, 24, 19, 17, 0.55)
    s.rect(5, 5, 30, 30, rx=2, fill=P.WOOD_DARK, stroke=P.INK, stroke_width=1.6)
    _crate_boards(s, 6, 6, 28, 28, 4)
    # diagonal brace
    s.path("M8,31 L32,9 L32,12.5 L11.5,31 Z", fill=s.linear([(0, P.WOOD_LIGHT, 1), (1, P.WOOD, 1)]),
           stroke=P.WOOD_DARK, stroke_width=0.8)
    s.rect(5, 5, 30, 30, rx=2, fill="none", stroke=P.WOOD_DARK, stroke_width=2.2)
    for (x, y) in ((5, 5), (29, 5), (5, 29), (29, 29)):
        s.rect(x, y, 6, 6, rx=1, fill=s.linear([(0, P.STEEL_LIGHT, 1), (1, P.STEEL_DARK, 1)]),
               stroke=P.STEEL_INK, stroke_width=0.6)
        s.circle(x + 3, y + 3, 0.9, fill=P.STEEL_DARK)
    # stencil: a supply chevron
    s.path("M14,22 L20,16 L26,22", fill="none", stroke="#f4ead0", stroke_width=2.4,
           stroke_linecap="round", stroke_linejoin="round", opacity=0.8)
    s.path("M14,26 L20,20 L26,26", fill="none", stroke="#f4ead0", stroke_width=2.4,
           stroke_linecap="round", stroke_linejoin="round", opacity=0.8)
    s.rect(6, 6, 28, 5, fill="#ffffff", opacity=0.12)
    return s


def crate_cache() -> Svg:
    """A heavy munitions cache: an olive steel container with handles and a hazard stripe."""
    s = Svg(48, 48)
    s.soft_shadow(26, 28, 23, 20, 0.55)
    s.rect(4, 7, 40, 34, rx=3, fill=s.linear([(0, "#7a8a52", 1), (0.5, P.AMMO, 1), (1, "#2e351f", 1)], 0, 0, 0.6, 1),
           stroke=P.INK, stroke_width=1.6)
    for y in (13, 35):
        s.rect(4, y - 1.2, 40, 2.4, fill="#2e351f")
    s.rect(4, 21, 40, 6, fill=P.HAZARD, stroke=P.INK, stroke_width=0.6)
    for i in range(7):
        x0 = 4 + i * 6.6
        s.path(f"M{x0},27 L{x0 + 3.3},21 L{x0 + 6.6},21 L{x0 + 3.3},27 Z", fill="#1a1a1a")
    for sgn in (-1, 1):  # handles
        x = 24 + sgn * 22
        s.rect(x - 2.5, 16, 5, 16, rx=2, fill=P.STEEL_DARK, stroke=P.INK, stroke_width=0.8)
    for (x, y) in ((8, 10), (40, 10), (8, 38), (40, 38)):
        s.circle(x, y, 1.3, fill=P.STEEL_LIGHT, stroke=P.INK, stroke_width=0.4)
    s.rect(6, 8.5, 36, 3, rx=1.4, fill="#ffffff", opacity=0.2)
    # an ammo symbol
    for dx in (-4, 0, 4):
        s.path(f"M{24 + dx - 1.2},{19} L{24 + dx - 1.2},{15.5} Q{24 + dx},{13.5} {24 + dx + 1.2},{15.5} L{24 + dx + 1.2},{19} Z",
               fill=P.GOLD, stroke=P.INK, stroke_width=0.4)
    return s


def crate_overdrive() -> Svg:
    """An energy core in a steel cage: breaking it overdrives every unit's fire."""
    s = Svg(40, 40)
    s.soft_shadow(22, 24, 18, 16, 0.5)
    s.glow(20, 20, 20, P.CORE, 0.6)
    s.circle(20, 20, 9.5, fill=s.radial([(0, "#ffffff", 1), (0.35, "#b8fff6", 1), (0.8, P.CORE, 1),
             (1, "#157a74", 1)]), stroke="#0a2a28", stroke_width=1)
    s.path("M20,12 L16.5,21 L20.5,21 L18.5,28.5 L24.5,18 L20.5,18 L22.5,12 Z", fill="#ffffff",
           stroke="#0a4a44", stroke_width=0.5)
    for a in (45, 135, 225, 315):  # cage struts
        p = polar(20, 20, 15, a)
        s.line((20, 20), p, stroke=P.STEEL_INK, stroke_width=3.2, opacity=0.0)
    s.rect(6, 6, 28, 28, rx=4, fill="none", stroke=P.STEEL_INK, stroke_width=3.6)
    s.rect(6, 6, 28, 28, rx=4, fill="none", stroke=P.STEEL_LIGHT, stroke_width=1.8)
    for x in (13, 27):
        s.line((x, 6), (x, 34), stroke=P.STEEL_INK, stroke_width=2.6)
        s.line((x, 6), (x, 34), stroke=P.STEEL, stroke_width=1.2)
    for (x, y) in ((6, 6), (34, 6), (6, 34), (34, 34)):
        s.circle(x, y, 2.6, fill=P.STEEL, stroke=P.STEEL_INK, stroke_width=0.7)
    return s


def _bag(s: Svg, x: float, y: float, w: float = 13.0, h: float = 7.0, tint: str = P.SAND) -> None:
    """One sandbag seen from above: a rounded sack with a tied seam."""
    s.rect(x - w / 2, y - h / 2, w, h, rx=h * 0.45, fill=s.linear([(0, P.SAND_LIGHT, 1), (1, tint, 1)]),
           stroke=P.INK, stroke_width=0.9)
    s.line((x - w * 0.3, y - h * 0.15), (x + w * 0.3, y - h * 0.15), stroke=P.SAND_DARK, stroke_width=0.6,
           opacity=0.7)


def barricade(level: int) -> Svg:
    """The barricade across a lane, one per level: 1 is a sandbag line, 2 adds a timber-and-steel
    frame, 3 is a steel wall with spikes. 120 wide (the lane is 180), 40 deep."""
    s = Svg(120, 40)
    s.soft_shadow(62, 24, 58, 13, 0.5)
    if level >= 2:  # timber frame and steel plates behind the bags
        s.rect(6, 6, 108, 12, rx=2, fill=s.linear([(0, P.WOOD_LIGHT, 1), (1, P.WOOD_DARK, 1)]),
               stroke=P.INK, stroke_width=1.2)
        for x in range(12, 112, 16):
            s.rect(x, 5, 8, 14, rx=1, fill=s.linear([(0, P.STEEL_LIGHT, 1), (1, P.STEEL_DARK, 1)]),
                   stroke=P.STEEL_INK, stroke_width=0.7)
            s.circle(x + 4, 9, 0.9, fill=P.STEEL_DARK)
            s.circle(x + 4, 15, 0.9, fill=P.STEEL_DARK)
    if level >= 3:  # spikes toward the enemy (up the lane)
        for x in range(10, 114, 12):
            s.outlined(f"M{x - 3},{7} L{x},{-0.5 + 1} L{x + 3},{7} Z", P.STEEL_LIGHT, P.STEEL_INK, 0.7)
    rows = [(16, 12.5), (24, 13.5)] if level == 1 else [(22, 12.5), (30, 13.5)]
    for k, (y, w) in enumerate(rows):
        off = 0 if k % 2 == 0 else w / 2
        x = 8 + off
        while x < 114:
            _bag(s, x, y, w, 7.2)
            x += w
    s.rect(4, 28 if level > 1 else 20, 112, 3, fill=P.HAZARD, opacity=0.55)
    return s


def barricade_rubble() -> Svg:
    """A broken barricade: split bags and scattered timber (it can be repaired)."""
    s = Svg(120, 40)
    s.soft_shadow(62, 24, 56, 11, 0.35)
    rng = random.Random(11)
    for i in range(14):
        x = 10 + i * 7.5 + rng.uniform(-3, 3)
        y = 22 + rng.uniform(-7, 7)
        _bag(s, x, y, rng.uniform(7, 11), rng.uniform(4, 6), P.SAND_DARK)
    for i in range(4):
        x = 15 + i * 26 + rng.uniform(-4, 4)
        s.rect(x, 12 + rng.uniform(-3, 6), 18, 4, rx=1, fill=P.WOOD_DARK, stroke=P.INK, stroke_width=0.6,
               transform=f"rotate({rng.uniform(-35, 35):.1f} {x + 9} 16)")
    return s


ASSETS = {
    "field/wall": wall,
    "crates/supply": crate_supply,
    "crates/cache": crate_cache,
    "crates/overdrive": crate_overdrive,
    "props/barricade_1": lambda: barricade(1),
    "props/barricade_2": lambda: barricade(2),
    "props/barricade_3": lambda: barricade(3),
    "props/barricade_rubble": barricade_rubble,
}
