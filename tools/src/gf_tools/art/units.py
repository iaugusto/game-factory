"""The defenders: two bases and six rotating heads, top-down.

A unit is drawn as a static base plus a head that turns toward its target, so every head
points up (-y) with its pivot at the centre of its box, and the game rotates it. Troops
(Rifleman, Sniper) sit in a sandbag ring; emplacements (MG, Cryo, Mortar, Rail) on a steel
hex platform. Cool steel and olive with one accent colour each, so the defenders never blend
into the warm swarm. The accent is the unit's damage type (palette KINETIC/EXPLOSIVE/PIERCING/
CRYO_TYPE, the same as the ui/dmg_* icons), so a unit's colour says what it counters.

Heads are drawn in a HEAD box and scaled by HEAD_ZOOM, so they read at phone size over a base
that stays the size of its build spot.
"""

from __future__ import annotations

from math import cos, sin, pi

from . import palette as P
from .svg import Svg, ellipse_points, polar, smooth_path

BASE = 56.0
HEAD = 64.0
HEAD_ZOOM = 1.1


def _metal(s: Svg, light: str = P.STEEL_LIGHT, mid: str = P.STEEL, dark: str = P.STEEL_DARK) -> str:
    return s.linear([(0, light, 1), (0.5, mid, 1), (1, dark, 1)], 0, 0, 0.8, 1)


def _bolt(s: Svg, x: float, y: float, r: float = 1.1) -> None:
    s.circle(x, y, r, fill=P.STEEL_DARK, stroke=P.STEEL_INK, stroke_width=0.4)
    s.circle(x - r * 0.3, y - r * 0.3, r * 0.4, fill=P.STEEL_LIGHT)


def _sandbag(s: Svg, x: float, y: float, deg: float, w: float = 9.0, h: float = 5.2,
             dye: str | None = None) -> None:
    """One sandbag; `dye` colours its cloth (the unit's damage-type accent)."""
    fill = (s.radial([(0, "#ffffff", 1), (0.35, dye, 1), (1, P.INK, 1)], cx=0.4, cy=0.35, r=0.9)
            if dye else
            s.radial([(0, P.SAND_LIGHT, 1), (0.6, P.SAND, 1), (1, P.SAND_DARK, 1)], cx=0.4, cy=0.35))
    with s.group(f"translate({x},{y}) rotate({deg})"):
        s.outlined(smooth_path(ellipse_points(0, 0, w / 2, h / 2, 10, jitter=[0, 0.05, -0.03])),
                   fill, P.INK, 0.6)
        s.path(f"M{-w * 0.3},{-h * 0.1} L{w * 0.3},{-h * 0.1}", stroke=P.SAND_DARK,
               stroke_width=0.5, opacity=0.7)


# --- bases ------------------------------------------------------------------------------

def base_troop(accent: str | None = None) -> Svg:
    """A dug-in position: a dirt floor ringed by sandbags; with an `accent`, the bags at the
    back are dyed in it."""
    s = Svg(BASE, BASE)
    c = BASE / 2
    s.soft_shadow(c + 2, c + 3, 26, 25, 0.5)
    s.circle(c, c, 19, fill=s.radial([(0, "#5a4834", 1), (1, "#35291e", 1)]), stroke=P.INK,
             stroke_width=0.8)
    for i in range(14):
        a = i * 360 / 14
        x, y = polar(c, c, 21.5, a)
        _sandbag(s, x, y, a + 90, dye=accent if accent and 2 <= i <= 5 else None)
    for i in range(7):  # an inner staggered row on the front arc
        a = 200 + i * 20
        x, y = polar(c, c, 17, a)
        _sandbag(s, x, y, a + 90, 7.5, 4.4)
    return s


def base_emplacement(accent: str = P.HAZARD) -> Svg:
    """A bolted steel hex platform with its corners painted in `accent`."""
    s = Svg(BASE, BASE)
    c = BASE / 2
    s.soft_shadow(c + 2, c + 3, 27, 25, 0.5)
    hexa = [polar(c, c, 25, 30 + i * 60) for i in range(6)]
    s.outlined("M" + " L".join(f"{x},{y}" for x, y in hexa) + " Z", _metal(s), P.STEEL_INK, 1.0)
    inner = [polar(c, c, 19, 30 + i * 60) for i in range(6)]
    s.path("M" + " L".join(f"{x},{y}" for x, y in inner) + " Z",
           fill=s.linear([(0, P.STEEL_DARK, 1), (1, P.GUNMETAL, 1)]), stroke=P.STEEL_INK,
           stroke_width=0.8)
    # painted corners
    for i in range(6):
        a = 30 + i * 60
        p1 = polar(c, c, 24.2, a - 9)
        p2 = polar(c, c, 24.2, a + 9)
        p3 = polar(c, c, 20, a + 7)
        p4 = polar(c, c, 20, a - 7)
        s.path(f"M{p1[0]},{p1[1]} L{p2[0]},{p2[1]} L{p3[0]},{p3[1]} L{p4[0]},{p4[1]} Z",
               fill=accent, stroke=P.STEEL_INK, stroke_width=0.5)
    for i in range(6):
        x, y = polar(c, c, 22, i * 60)
        _bolt(s, x, y)
    # a highlight along the top-left edges
    s.path(f"M{hexa[3][0]},{hexa[3][1]} L{hexa[4][0]},{hexa[4][1]} L{hexa[5][0]},{hexa[5][1]}",
           fill="none", stroke="#ffffff", stroke_width=0.8, opacity=0.35)
    return s


# --- heads -------------------------------------------------------------------------------

def _soldier(s: Svg, cx: float, cy: float, uniform: tuple[str, str, str]) -> None:
    """A soldier seen from above: shoulders, pack, helmet (the rifle is drawn by the caller)."""
    light, mid, dark = uniform
    s.outlined(smooth_path(ellipse_points(cx, cy + 5.5, 5, 3.6, 10)),
               s.linear([(0, mid, 1), (1, dark, 1)]), P.INK, 0.6)  # pack
    s.outlined(smooth_path(ellipse_points(cx, cy + 1.5, 9.5, 5.2, 14)),
               s.radial([(0, light, 1), (1, dark, 1)], cx=0.35, cy=0.3), P.INK, 0.7)  # shoulders
    s.circle(cx, cy, 5.6, fill=s.radial([(0, light, 1), (0.6, mid, 1), (1, dark, 1)], cx=0.35,
             cy=0.3), stroke=P.INK, stroke_width=0.9)  # helmet
    s.path(f"M{cx - 4.2},{cy - 1} Q{cx},{cy - 4.8} {cx + 4.2},{cy - 1}", fill="none",
           stroke=dark, stroke_width=0.6)
    s.circle(cx - 1.8, cy - 1.8, 1.4, fill="#ffffff", opacity=0.35)


def _gun(s: Svg, x: float, y0: float, y1: float, w: float, color: str = P.GUNMETAL) -> None:
    s.rect(x - w / 2 - 0.6, y1 - 0.6, w + 1.2, y0 - y1 + 1.2, rx=0.8, fill=P.STEEL_INK)
    s.rect(x - w / 2, y1, w, y0 - y1, rx=0.6, fill=color)
    s.rect(x - w / 2, y1, w * 0.35, y0 - y1, fill="#ffffff", opacity=0.18)


def head_rifleman() -> Svg:
    s = Svg(HEAD, HEAD)
    c = HEAD / 2
    # arms reaching to the rifle
    s.limb([(c - 7, c + 2), (c - 2.5, c - 4), (c + 1.5, c - 9)], P.OLIVE, P.INK, 2.6)
    s.limb([(c + 7, c + 2), (c + 3.5, c - 2)], P.OLIVE, P.INK, 2.6)
    _gun(s, c + 1.5, c + 1, c - 17, 2.2)
    s.rect(c + 0.7, c - 19, 1.6, 3, fill=P.STEEL_LIGHT)  # muzzle
    for sgn in (-1, 1):  # brass ammo pouches on the shoulders
        s.rect(c + sgn * 7 - 2, c + 1.5, 4, 3.4, rx=0.8, fill=P.KINETIC, stroke=P.INK,
               stroke_width=0.6)
    _soldier(s, c, c + 1.5, (P.OLIVE_LIGHT, P.OLIVE, P.OLIVE_DARK))
    s.path(f"M{c - 5.2},{c + 2.4} Q{c},{c + 5.6} {c + 5.2},{c + 2.4}", fill="none",
           stroke=P.KINETIC, stroke_width=1.6)  # helmet band
    return s.zoomed(HEAD_ZOOM)


def head_sniper() -> Svg:
    s = Svg(HEAD, HEAD)
    c = HEAD / 2
    # prone: legs trailing back, ghillie scraps
    for sgn in (-1, 1):
        s.limb([(c + sgn * 2.5, c + 8), (c + sgn * 4.5, c + 17), (c + sgn * 5, c + 24)],
               P.OLIVE_DARK, P.INK, 3.2)
    s.outlined(smooth_path(ellipse_points(c, c + 6, 6, 9, 12)),
               s.linear([(0, P.OLIVE, 1), (1, P.OLIVE_DARK, 1)]), P.INK, 0.6)
    for (dx, dy, r) in ((-4, 3, 2.2), (3.5, 6, 2.5), (-2, 10, 2), (4, 12, 1.8), (0, 1, 1.6)):
        s.circle(c + dx, c + dy, r, fill="#4a5a2a", opacity=0.9)
    # the long rifle with scope and bipod
    _gun(s, c, c + 2, c - 29, 2.0)
    s.rect(c - 1.9, c - 13, 3.8, 7, rx=1.6, fill=P.STEEL_DARK, stroke=P.STEEL_INK, stroke_width=0.5)
    s.glow(c, c - 13.2, 4, P.PIERCING, 0.7)
    s.circle(c, c - 13.2, 1.5, fill=P.PIERCING)
    s.limb([(c, c - 22), (c - 4, c - 19)], P.GUNMETAL, P.INK, 0.9)
    s.limb([(c, c - 22), (c + 4, c - 19)], P.GUNMETAL, P.INK, 0.9)
    s.limb([(c - 5, c + 1), (c - 1.5, c - 5)], P.OLIVE, P.INK, 2.4)
    s.limb([(c + 5, c + 1), (c + 1.5, c - 3)], P.OLIVE, P.INK, 2.4)
    s.circle(c, c - 1, 5, fill=s.radial([(0, P.OLIVE_LIGHT, 1), (0.6, P.OLIVE, 1),
             (1, P.OLIVE_DARK, 1)], cx=0.35, cy=0.3), stroke=P.INK, stroke_width=0.9)
    s.path(f"M{c - 4.6},{c + 0.6} Q{c},{c + 3.8} {c + 4.6},{c + 0.6}", fill="none",
           stroke=P.PIERCING, stroke_width=1.6)  # helmet band
    s.circle(c - 1.6, c - 2.6, 1.2, fill="#ffffff", opacity=0.35)
    return s.zoomed(HEAD_ZOOM)


def head_mg() -> Svg:
    s = Svg(HEAD, HEAD)
    c = HEAD / 2
    s.soft_shadow(c + 1.5, c + 2, 14, 14, 0.35)
    for dx in (-2.6, 2.6):  # twin barrels with cooling jackets
        _gun(s, c + dx, c - 2, c - 22, 2.4)
        for y in (c - 18, c - 14, c - 10):
            s.rect(c + dx - 1.8, y, 3.6, 1.6, rx=0.5, fill=P.STEEL, stroke=P.STEEL_INK,
                   stroke_width=0.4)
        s.rect(c + dx - 1.5, c - 24, 3, 2.6, rx=0.6, fill=P.STEEL_LIGHT, stroke=P.STEEL_INK,
               stroke_width=0.4)
    # curved gun shield
    s.outlined(f"M{c - 12},{c - 4} Q{c},{c - 11} {c + 12},{c - 4} L{c + 11},{c - 1} "
               f"Q{c},{c - 7} {c - 11},{c - 1} Z", _metal(s), P.STEEL_INK, 0.8)
    s.path(f"M{c - 11.2},{c - 3.2} Q{c},{c - 9.8} {c + 11.2},{c - 3.2}", fill="none",
           stroke=P.KINETIC, stroke_width=1.5)
    # housing
    s.outlined(f"M{c - 8},{c - 3} L{c + 8},{c - 3} L{c + 9},{c + 9} Q{c},{c + 13} {c - 9},{c + 9} Z",
               _metal(s), P.STEEL_INK, 1.0)
    _bolt(s, c - 5.5, c + 6)
    _bolt(s, c + 5.5, c + 6)
    # ammo box and belt
    s.outlined(f"M{c + 9},{c - 1} L{c + 16},{c - 1} L{c + 16},{c + 8} L{c + 9},{c + 8} Z",
               s.linear([(0, P.OLIVE_LIGHT, 1), (1, P.OLIVE_DARK, 1)]), P.INK, 0.6)
    s.path(f"M{c + 9},{c + 1} Q{c + 5},{c - 1} {c + 2.6},{c - 3}", fill="none", stroke=P.HAZARD,
           stroke_width=1.6, stroke_dasharray="1 0.6")
    s.rect(c - 3, c + 1, 6, 4, rx=1, fill=P.STEEL_DARK)
    s.circle(c, c + 3, 1.2, fill=P.KINETIC)
    return s.zoomed(HEAD_ZOOM)


def head_frost() -> Svg:
    s = Svg(HEAD, HEAD)
    c = HEAD / 2
    s.glow(c, c - 17, 9, P.CRYO, 0.7)
    s.soft_shadow(c + 1.5, c + 2, 14, 14, 0.35)
    # emitter nozzle
    s.outlined(f"M{c - 3.5},{c - 6} L{c - 2.2},{c - 17} L{c + 2.2},{c - 17} L{c + 3.5},{c - 6} Z",
               _metal(s), P.STEEL_INK, 0.7)
    s.ellipse(c, c - 17.5, 3.2, 1.6, fill=P.CRYO, stroke=P.STEEL_INK, stroke_width=0.6)
    s.ellipse(c, c - 17.6, 1.6, 0.8, fill="#ffffff")
    # coolant tanks
    for sgn in (-1, 1):
        x = c + sgn * 11
        s.outlined(f"M{x - 3.2},{c - 5} Q{x},{c - 9} {x + 3.2},{c - 5} L{x + 3.2},{c + 8} "
                   f"Q{x},{c + 12} {x - 3.2},{c + 8} Z",
                   s.linear([(0, "#e8fbff", 1), (0.5, P.CRYO, 1), (1, P.CRYO_DEEP, 1)], 0, 0, 1, 0),
                   P.STEEL_INK, 0.6)
        s.rect(x - 3.4, c + 1, 6.8, 1.4, fill=P.STEEL_DARK)
        s.line((x, c + 2), (c + sgn * 6, c + 2), stroke=P.STEEL, stroke_width=1.4)
    # dome housing
    s.circle(c, c + 1, 9.5, fill=s.radial([(0, "#ffffff", 1), (0.35, "#cfe9f2", 1),
             (1, "#5a7f92", 1)], cx=0.35, cy=0.3), stroke=P.STEEL_INK, stroke_width=1.1)
    s.circle(c, c + 1, 4.5, fill=s.radial([(0, "#ffffff", 1), (0.5, P.CRYO, 1), (1, P.CRYO_DEEP, 1)]),
             stroke=P.STEEL_INK, stroke_width=0.6)
    s.circle(c - 3.2, c - 2.4, 2.2, fill="#ffffff", opacity=0.6)
    return s.zoomed(HEAD_ZOOM)


def head_mortar() -> Svg:
    s = Svg(HEAD, HEAD)
    c = HEAD / 2
    # baseplate
    s.circle(c, c + 6, 10, fill=_metal(s), stroke=P.STEEL_INK, stroke_width=0.9)
    for i in range(8):
        x, y = polar(c, c + 6, 8, i * 45)
        _bolt(s, x, y, 0.8)
    # bipod
    s.limb([(c, c - 8), (c - 8, c - 2)], P.STEEL_DARK, P.STEEL_INK, 1.4)
    s.limb([(c, c - 8), (c + 8, c - 2)], P.STEEL_DARK, P.STEEL_INK, 1.4)
    # the tube, tilted up toward the target (its mouth at the top)
    s.outlined(f"M{c - 4},{c + 6} L{c - 3.6},{c - 15} L{c + 3.6},{c - 15} L{c + 4},{c + 6} Z",
               s.linear([(0, P.OLIVE_DARK, 1), (0.35, P.OLIVE_LIGHT, 1), (1, P.OLIVE_DARK, 1)], 0, 0, 1, 0),
               P.INK, 0.8)
    s.rect(c - 4.5, c - 7, 9, 2.6, fill=P.EXPLOSIVE, stroke=P.INK, stroke_width=0.5)
    s.rect(c - 4.4, c - 12, 8.8, 1.8, fill=P.EXPLOSIVE, stroke=P.INK, stroke_width=0.5)
    s.ellipse(c, c - 15, 4.4, 2.2, fill=P.OLIVE_DARK, stroke=P.INK, stroke_width=0.8)
    s.ellipse(c, c - 15, 2.8, 1.3, fill="#0a0a0a")
    # shells ready at the side
    for dx in (12, 15.5):
        s.outlined(f"M{c + dx - 1.4},{c + 12} L{c + dx - 1.4},{c + 5} Q{c + dx},{c + 2} "
                   f"{c + dx + 1.4},{c + 5} L{c + dx + 1.4},{c + 12} Z",
                   s.linear([(0, P.SAND_LIGHT, 1), (1, P.SAND_DARK, 1)], 0, 0, 1, 0), P.INK, 0.4)
        s.path(f"M{c + dx - 1.4},{c + 5.4} Q{c + dx},{c + 2} {c + dx + 1.4},{c + 5.4} Z",
               fill=P.EXPLOSIVE)  # warhead tip
    return s.zoomed(HEAD_ZOOM)


def head_rail() -> Svg:
    s = Svg(HEAD, HEAD)
    c = HEAD / 2
    s.glow(c, c - 10, 14, P.RAIL, 0.35)
    s.soft_shadow(c + 1.5, c + 3, 13, 16, 0.35)
    # twin rails
    for sgn in (-1, 1):
        x = c + sgn * 4.2
        s.outlined(f"M{x - 1.8},{c + 6} L{x - 1.8},{c - 27} L{x + 1.8},{c - 25} L{x + 1.8},{c + 6} Z",
                   _metal(s), P.STEEL_INK, 0.7)
    # the charge channel between them
    s.rect(c - 2.2, c - 25, 4.4, 28, fill=s.linear([(0, "#ffffff", 0.9), (0.5, P.RAIL, 0.9),
           (1, P.RAIL_DEEP, 0.2)], 0, 0, 0, 1))
    # magnetic coils
    for y in (c - 21, c - 15, c - 9, c - 3):
        s.rect(c - 8, y, 16, 3, rx=1.2, fill=s.linear([(0, P.RAIL_DEEP, 1), (0.5, P.RAIL, 1),
               (1, P.RAIL_DEEP, 1)], 0, 0, 1, 0), stroke=P.STEEL_INK, stroke_width=0.6)
        s.rect(c - 7, y + 0.5, 14, 0.8, fill="#ffffff", opacity=0.35)
    # breech housing with a capacitor
    s.outlined(f"M{c - 10},{c + 2} L{c + 10},{c + 2} L{c + 11},{c + 13} Q{c},{c + 17} "
               f"{c - 11},{c + 13} Z", _metal(s), P.STEEL_INK, 1.0)
    s.glow(c, c + 9, 7, P.RAIL, 0.8)
    s.circle(c, c + 9, 3.4, fill=s.radial([(0, "#ffffff", 1), (0.5, P.RAIL, 1), (1, P.RAIL_DEEP, 1)]),
             stroke=P.STEEL_INK, stroke_width=0.6)
    for sgn in (-1, 1):
        _bolt(s, c + sgn * 7.5, c + 5)
    return s.zoomed(HEAD_ZOOM)


def plot_pad() -> Svg:
    """An empty build plot: a concrete hex pad with a teal ring and a "+" build glyph."""
    s = Svg(BASE, BASE)
    c = BASE / 2
    s.soft_shadow(c + 1, c + 2, 25, 23, 0.4)
    hexa = [polar(c, c, 23, 30 + i * 60) for i in range(6)]
    s.outlined("M" + " L".join(f"{x},{y}" for x, y in hexa) + " Z",
               s.linear([(0, "#5d5a55", 1), (1, "#35332f", 1)], 0, 0, 0.7, 1), P.STEEL_INK, 0.9)
    for i in range(6):  # worn edges
        a = 30 + i * 60
        p1 = polar(c, c, 21, a)
        p2 = polar(c, c, 21, a + 60)
        s.line(p1, p2, stroke="#77736b", stroke_width=0.7, opacity=0.6)
    s.glow(c, c, 20, P.TEAL, 0.25)
    s.circle(c, c, 15, fill="none", stroke=P.TEAL, stroke_width=1.6, stroke_dasharray="4.2 2.6",
             opacity=0.9)
    s.path(f"M{c - 5},{c} L{c + 5},{c} M{c},{c - 5} L{c},{c + 5}", stroke=P.TEAL,
           stroke_width=2.2, stroke_linecap="round")
    return s


# unit id -> (base, damage-type accent): each unit gets its own base, painted in its accent.
BASES = {
    "rifleman": (base_troop, P.KINETIC),
    "sniper": (base_troop, P.PIERCING),
    "mg": (base_emplacement, P.KINETIC),
    "frost": (base_emplacement, P.CRYO_TYPE),
    "mortar": (base_emplacement, P.EXPLOSIVE),
    "rail": (base_emplacement, P.PIERCING),
}

ASSETS = {
    **{f"units/base_{uid}": (lambda f=f, a=a: f(a)) for uid, (f, a) in BASES.items()},
    "units/plot": plot_pad,
    "units/rifleman": head_rifleman,
    "units/sniper": head_sniper,
    "units/mg": head_mg,
    "units/frost": head_frost,
    "units/mortar": head_mortar,
    "units/rail": head_rail,
}
