"""Effect sprites. Most are white so the game can tint them (per enemy, per unit) and draw
them additively for light (glow, tracer, muzzle, ring); a few carry their own colour (coin,
shell)."""

from __future__ import annotations

import random
from typing import Callable

from . import palette as P
from .svg import Svg, ellipse_points, polar, smooth_path


def glow() -> Svg:
    s = Svg(64, 64)
    s.circle(32, 32, 32, fill=s.radial([(0, "#ffffff", 1), (0.2, "#ffffff", 0.7), (0.5, "#ffffff", 0.22),
             (1, "#ffffff", 0)]))
    return s


def tracer() -> Svg:
    """A bullet streak pointing up: hot white core, soft edge, fading tail."""
    s = Svg(8, 40)
    s.rect(0, 0, 8, 40, rx=4, fill=s.linear([(0, "#ffffff", 0.9), (0.3, "#ffffff", 0.35), (1, "#ffffff", 0)]))
    s.rect(2.6, 1, 2.8, 26, rx=1.4, fill=s.linear([(0, "#ffffff", 1), (1, "#ffffff", 0)]))
    return s


def bolt() -> Svg:
    """A unit projectile: a bright round slug with a short glow."""
    s = Svg(16, 16)
    s.circle(8, 8, 8, fill=s.radial([(0, "#ffffff", 1), (0.35, "#ffffff", 0.8), (1, "#ffffff", 0)]))
    return s


def shadow() -> Svg:
    s = Svg(64, 32)
    s.ellipse(32, 16, 32, 16, fill=s.radial([(0, "#000000", 0.6), (0.6, "#000000", 0.35), (1, "#000000", 0)]))
    return s


def shard() -> Svg:
    """A chitin shard for death bursts (white; tinted per enemy)."""
    s = Svg(12, 12)
    s.path("M2,9 L6,1.5 L10.5,6 L7,10.5 Z", fill=s.linear([(0, "#ffffff", 1), (1, "#9a9a9a", 1)], 0, 0, 1, 1),
           stroke="#202020", stroke_width=0.7)
    return s


def splat() -> Svg:
    """A goo splat decal (white; tinted per enemy and faded out)."""
    s = Svg(64, 64)
    rng = random.Random(11)
    s.path(smooth_path(ellipse_points(32, 32, 17, 15, 14, [rng.uniform(-0.3, 0.35) for _ in range(14)])),
           fill="#ffffff", opacity=0.9)
    for _ in range(9):
        a = rng.uniform(0, 360)
        x, y = polar(32, 32, rng.uniform(20, 29), a)
        s.circle(x, y, rng.uniform(1.2, 3.4), fill="#ffffff", opacity=0.85)
    return s


def scorch() -> Svg:
    s = Svg(64, 64)
    rng = random.Random(5)
    s.path(smooth_path(ellipse_points(32, 32, 28, 26, 16, [rng.uniform(-0.2, 0.15) for _ in range(16)])),
           fill=s.radial([(0, "#000000", 0.8), (0.6, "#1a0f08", 0.5), (1, "#1a0f08", 0)]))
    return s


def ring() -> Svg:
    s = Svg(64, 64)
    s.circle(32, 32, 28, fill="none", stroke="#ffffff", stroke_width=4, opacity=0.9)
    s.circle(32, 32, 28, fill="none", stroke="#ffffff", stroke_width=8, opacity=0.25)
    return s


def muzzle() -> Svg:
    """A muzzle flash, firing up (the base of the flash sits at the bottom centre)."""
    s = Svg(24, 32)
    s.circle(12, 24, 10, fill=s.radial([(0, "#ffffff", 1), (0.4, "#fff2b0", 0.8), (1, "#ffb347", 0)]))
    s.path("M12,0 L15,18 L22,22 L15,26 L12,32 L9,26 L2,22 L9,18 Z", fill="#fff6d0", opacity=0.9)
    return s


def coin() -> Svg:
    s = Svg(20, 20)
    s.circle(10, 10.8, 8.6, fill="#6a4a08")
    s.circle(10, 10, 8.6, fill=s.radial([(0, "#fff3b0", 1), (0.5, P.GOLD, 1), (1, P.GOLD_DEEP, 1)], cx=0.35, cy=0.3),
             stroke="#5a3e05", stroke_width=1)
    s.circle(10, 10, 5.6, fill="none", stroke=P.GOLD_DEEP, stroke_width=1)
    s.path("M10,5.8 L11.3,8.7 L14.3,8.9 L12,10.9 L12.7,13.9 L10,12.3 L7.3,13.9 L8,10.9 L5.7,8.9 L8.7,8.7 Z",
           fill="#fff6c8", stroke=P.GOLD_DEEP, stroke_width=0.5)
    return s


def shell() -> Svg:
    """A mortar shell in flight, nose up."""
    s = Svg(10, 18)
    s.path("M5,1 Q9,5 8,11 L8,14 L2,14 L2,11 Q1,5 5,1 Z", fill=s.linear([(0, P.OLIVE_LIGHT, 1), (1, P.OLIVE_DARK, 1)], 0, 0, 1, 0),
           stroke=P.INK, stroke_width=0.8)
    s.rect(1.5, 13.5, 7, 4, rx=0.8, fill=P.STEEL, stroke=P.INK, stroke_width=0.6)
    s.path("M3,4 L7,4", stroke=P.HAZARD, stroke_width=1.2)
    return s


def splinter() -> Svg:
    """A wooden/metal splinter for crate breaks (white; tinted)."""
    s = Svg(14, 6)
    s.path("M1,3 L4,1 L13,2.2 L12,4.5 L3,5 Z", fill=s.linear([(0, "#ffffff", 1), (1, "#b0b0b0", 1)]),
           stroke="#2a2a2a", stroke_width=0.6)
    return s


# --- UI icons -----------------------------------------------------------------------------

def icon_wall() -> Svg:
    s = Svg(24, 24)
    s.path("M12,2 L21,5.5 L20,13 Q18.5,19 12,22.5 Q5.5,19 4,13 L3,5.5 Z",
           fill=s.linear([(0, "#9dd6ff", 1), (1, "#3a78b0", 1)]), stroke="#0c1a28", stroke_width=1.4)
    s.path("M12,5 L18,7.5 L17.2,13 Q16,17 12,19.5 Z", fill="#ffffff", opacity=0.25)
    return s


def icon_bolt() -> Svg:
    s = Svg(24, 24)
    s.path("M13,1.5 L5,13.5 L11,13.5 L9,22.5 L19,9.5 L13,9.5 L15,1.5 Z", fill=s.linear([(0, "#ffffff", 1), (1, P.CORE, 1)]),
           stroke="#0a3a36", stroke_width=1.2, stroke_linejoin="round")
    return s


def _dmg_icon(glyph: Callable[[Svg], None], rim: str) -> Svg:
    """A damage-type badge: a dark disc with a coloured rim and a white glyph."""
    s = Svg(24, 24)
    s.circle(12, 12, 10.5, fill="#15181d", stroke=rim, stroke_width=2.2)
    glyph(s)
    return s


def icon_kinetic() -> Svg:
    def g(s: Svg) -> None:  # three bullets
        for x in (7.5, 12, 16.5):
            s.path(f"M{x - 1.6},{17} L{x - 1.6},{10} Q{x},{6} {x + 1.6},{10} L{x + 1.6},{17} Z",
                   fill="#f2ead8")
    return _dmg_icon(g, "#c9a24a")


def icon_explosive() -> Svg:
    def g(s: Svg) -> None:  # a burst
        pts = []
        for i in range(16):
            r = 7.5 if i % 2 == 0 else 3.6
            a = i * 22.5
            pts.append(polar(12, 12, r, a))
        s.path("M" + " L".join(f"{x:.2f},{y:.2f}" for x, y in pts) + " Z", fill="#ffb347")
        s.circle(12, 12, 2.4, fill="#fff4d0")
    return _dmg_icon(g, "#e8742e")


def icon_piercing() -> Svg:
    def g(s: Svg) -> None:  # an arrow through a plate
        s.rect(10.5, 5, 3, 14, fill="#6c7a88")
        s.path("M4,12 L17,12", stroke="#f2ead8", stroke_width=2.2)
        s.path("M15,8.5 L20.5,12 L15,15.5 Z", fill="#f2ead8")
    return _dmg_icon(g, "#b08cff")


def icon_cryo() -> Svg:
    def g(s: Svg) -> None:  # a snowflake
        for a in (0, 60, 120):
            p1 = polar(12, 12, 7, a)
            p2 = polar(12, 12, 7, a + 180)
            s.line(p1, p2, stroke="#dff8ff", stroke_width=1.8, stroke_linecap="round")
        s.circle(12, 12, 1.8, fill="#dff8ff")
    return _dmg_icon(g, "#8fe8ff")


ASSETS = {
    "fx/glow": glow,
    "fx/tracer": tracer,
    "fx/bolt": bolt,
    "fx/shadow": shadow,
    "fx/shard": shard,
    "fx/splat": splat,
    "fx/scorch": scorch,
    "fx/ring": ring,
    "fx/muzzle": muzzle,
    "fx/coin": coin,
    "fx/shell": shell,
    "fx/splinter": splinter,
    "ui/wall": icon_wall,
    "ui/bolt": icon_bolt,
    "ui/dmg_kinetic": icon_kinetic,
    "ui/dmg_explosive": icon_explosive,
    "ui/dmg_piercing": icon_piercing,
    "ui/dmg_cryo": icon_cryo,
}
