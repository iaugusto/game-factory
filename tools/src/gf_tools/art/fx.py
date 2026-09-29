"""Effect sprites. Most are white so the game can tint them (per enemy, per unit) and draw
them additively for light (glow, tracer, muzzle, ring); a few carry their own colour (coin,
shell)."""

from __future__ import annotations

import random
from typing import Callable

from . import palette as P
from .svg import Svg, ellipse_points, path_from, polar, smooth_path


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


def _star_points(cx: float, cy: float, r_out: float, r_in: float) -> list[tuple[float, float]]:
    pts = []
    for k in range(10):
        r = r_out if k % 2 == 0 else r_in
        pts.append(polar(cx, cy, r, -90 + k * 36))
    return pts


def icon_star() -> Svg:
    """A campaign star, earned: gold, lit from the top."""
    s = Svg(24, 24)
    s.path(path_from(_star_points(12, 12.8, 11, 4.9)),
           fill=s.linear([(0, "#fff3b0", 1), (0.55, "#ffc24a", 1), (1, "#c7801a", 1)]),
           stroke="#4a2c06", stroke_width=1.3, stroke_linejoin="round")
    return s


def icon_star_empty() -> Svg:
    """A campaign star not yet earned: a dark socket with a dim rim."""
    s = Svg(24, 24)
    s.path(path_from(_star_points(12, 12.8, 11, 4.9)), fill="#1c1a18", fill_opacity=0.85,
           stroke="#7a6a50", stroke_width=1.3, stroke_linejoin="round")
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


# --- special attacks (docs/2026-09-27-content-expansion/) ---------------------------------

def flame() -> Svg:
    """One tongue of fire for burning strips: a hot core in a teardrop, pointing up."""
    s = Svg(20, 30)
    s.path("M10,1 Q15,9 17,16 Q19,26 10,29 Q1,26 3,16 Q5,9 10,1 Z",
           fill=s.linear([(0, "#ffe07a", 0.0), (0.25, "#ffb347", 0.85), (0.7, "#ff5a1f", 0.95),
                          (1, "#b8260c", 0.9)]))
    s.path("M10,10 Q13,16 13,21 Q13,26 10,27 Q7,26 7,21 Q7,16 10,10 Z",
           fill=s.linear([(0, "#fff6d0", 0.2), (1, "#fff2b0", 1)]))
    return s


def mine() -> Svg:
    """A landmine seen from above: a squat olive disc, a pressure plate and a red light."""
    s = Svg(24, 24)
    s.soft_shadow(12.5, 13.5, 11, 9, 0.5)
    for a in range(0, 360, 60):
        x, y = polar(12, 12, 9.6, a)
        s.circle(x, y, 1.7, fill=P.STEEL_DARK, stroke=P.STEEL_INK, stroke_width=0.6)
    s.circle(12, 12, 8.6, fill=s.radial([(0, P.OLIVE_LIGHT, 1), (1, P.OLIVE_DARK, 1)], cx=0.4, cy=0.35),
             stroke=P.STEEL_INK, stroke_width=1.1)
    s.circle(12, 12, 4.4, fill=P.STEEL, stroke=P.STEEL_INK, stroke_width=0.8)
    s.circle(12, 12, 1.7, fill="#ff3b2e")
    s.glow(12, 12, 4, "#ff3b2e", 0.6)
    return s


def mound() -> Svg:
    """A Burrower underground: a heap of churned earth with clods and a crack of light where it
    is about to break through. Carries its own colour."""
    s = Svg(48, 36)
    s.soft_shadow(24.5, 22, 21, 11, 0.45)
    heap = ellipse_points(24, 19, 19, 11, 18, jitter=[0, 0.06, -0.04, 0.05, -0.03])
    s.outlined(smooth_path(heap), s.radial([(0, "#b08050", 1), (0.6, "#7a5230", 1), (1, "#4a3018", 1)],
                                           cx=0.4, cy=0.35), "#241408", 1.1)
    rng = random.Random(7)
    for _ in range(9):
        x, y = 24 + rng.uniform(-14, 14), 19 + rng.uniform(-7, 7)
        s.circle(x, y, rng.uniform(1.2, 2.6), fill="#5a3a1e", stroke="#241408", stroke_width=0.5)
    s.path("M17,17 L22,21 L26,16 L31,20", fill="none", stroke="#ffb04a", stroke_width=1.2,
           stroke_linecap="round", opacity=0.9)
    return s


def bubble() -> Svg:
    """A Warden's shield around one enemy: a faint white fill, a brighter rim and a glint (white,
    tinted and faded by the game per instance, so one batch draws them all)."""
    s = Svg(64, 64)
    s.circle(32, 32, 30, fill=s.radial([(0, "#ffffff", 0.05), (0.75, "#ffffff", 0.18), (1, "#ffffff", 0.45)]))
    s.circle(32, 32, 30, fill="none", stroke="#ffffff", stroke_width=2.2, opacity=0.9)
    s.path("M14,22 A21,21 0 0 1 26,12", fill="none", stroke="#ffffff", stroke_width=2.6,
           stroke_linecap="round", opacity=0.8)
    return s


def glob() -> Svg:
    """A Bombardier's glob of bile in flight: a glowing lime drop with a darker rim."""
    s = Svg(24, 24)
    s.glow(12, 12, 12, "#c8ff3a", 0.6)
    s.circle(12, 12, 6.5, fill=s.radial([(0, "#f8ffd0", 1), (0.5, "#c8ff3a", 1), (1, "#4a7a08", 1)],
                                        cx=0.38, cy=0.32), stroke="#1e3004", stroke_width=1)
    s.circle(9.8, 9.6, 1.7, fill="#ffffff", opacity=0.8)
    return s


def _ability_icon(glyph: Callable[[Svg], None], rim: str, core: str) -> Svg:
    """A special attack's badge: a dark disc lit in its colour, a coloured rim, and a glyph."""
    s = Svg(48, 48)
    s.circle(24, 24, 22.5, fill=s.radial([(0, core, 0.55), (0.7, "#15181d", 1), (1, "#0d0f12", 1)]),
             stroke=rim, stroke_width=3)
    glyph(s)
    return s


def icon_ability_strike() -> Svg:
    def g(s: Svg) -> None:  # a shell diving into a burst
        pts = []
        for i in range(14):
            r = 11 if i % 2 == 0 else 5.5
            pts.append(polar(24, 31, r, i * 360 / 14))
        s.path(path_from(pts), fill="#ffb347", stroke="#5a2308", stroke_width=1)
        s.circle(24, 31, 3.6, fill="#fff4d0")
        with s.group(transform="rotate(20 24 18)"):
            s.path("M24,6 Q29,11 28,19 L28,24 L20,24 L20,19 Q19,11 24,6 Z",
                   fill=s.linear([(0, P.OLIVE_LIGHT, 1), (1, P.OLIVE_DARK, 1)], 0, 0, 1, 0),
                   stroke=P.INK, stroke_width=1.2)
            s.path("M20.5,11 L27.5,11", stroke=P.HAZARD, stroke_width=1.8)
    return _ability_icon(g, "#e8742e", "#e8742e")


def icon_ability_cryo_bomb() -> Svg:
    def g(s: Svg) -> None:  # a round bomb with a frost star
        s.circle(24, 26, 12, fill=s.radial([(0, "#dff8ff", 1), (0.6, "#6cc8ea", 1), (1, "#2a6a90", 1)], cx=0.35, cy=0.3),
                 stroke="#0c2230", stroke_width=1.4)
        s.rect(21, 10, 6, 5, rx=1, fill=P.STEEL, stroke=P.STEEL_INK, stroke_width=0.9)
        for a in (0, 60, 120):
            s.line(polar(24, 26, 7.5, a), polar(24, 26, 7.5, a + 180), stroke="#ffffff",
                   stroke_width=2, stroke_linecap="round")
        s.circle(24, 26, 2, fill="#ffffff")
    return _ability_icon(g, "#8fe8ff", "#8fe8ff")


def icon_ability_napalm() -> Svg:
    def g(s: Svg) -> None:  # three flames over a burning line
        s.rect(8, 33, 32, 5, rx=2.5, fill="#ff5a1f", stroke="#4a1204", stroke_width=1)
        for x, h in ((15, 13), (24, 19), (33, 13)):
            top = 34 - h
            s.path(f"M{x},{top} Q{x + 6},{top + h * 0.5} {x + 4},{34} L{x - 4},{34} Q{x - 6},{top + h * 0.5} {x},{top} Z",
                   fill=s.linear([(0, "#ffe07a", 1), (0.6, "#ff9a2e", 1), (1, "#e2461a", 1)]),
                   stroke="#4a1204", stroke_width=0.9)
    return _ability_icon(g, "#ff8a2e", "#ff5a1f")


def icon_ability_minefield() -> Svg:
    def g(s: Svg) -> None:  # a mine and two more behind it
        for cx, cy, r in ((13, 17, 5.5), (35, 17, 5.5), (24, 29, 10)):
            for a in range(0, 360, 60):
                x, y = polar(cx, cy, r * 1.1, a)
                s.circle(x, y, r * 0.2, fill=P.STEEL_DARK, stroke=P.STEEL_INK, stroke_width=0.6)
            s.circle(cx, cy, r, fill=s.radial([(0, P.OLIVE_LIGHT, 1), (1, P.OLIVE_DARK, 1)], cx=0.4, cy=0.35),
                     stroke=P.STEEL_INK, stroke_width=1.1)
            s.circle(cx, cy, r * 0.45, fill=P.STEEL, stroke=P.STEEL_INK, stroke_width=0.7)
            s.circle(cx, cy, r * 0.18, fill="#ff3b2e")
    return _ability_icon(g, "#c9b04a", "#86985a")


def icon_ability_repair() -> Svg:
    def g(s: Svg) -> None:  # a drone (rotors and body) carrying a green cross
        for x in (12, 36):
            s.ellipse(x, 13, 8, 2.4, fill="#dfe8ee", opacity=0.7, stroke=P.STEEL_INK, stroke_width=0.7)
            s.line((x, 13), (x + (6 if x < 24 else -6), 19), stroke=P.STEEL_DARK, stroke_width=2)
        s.rect(16, 16, 16, 9, rx=3, fill=s.linear([(0, P.STEEL_LIGHT, 1), (1, P.STEEL_DARK, 1)]),
               stroke=P.STEEL_INK, stroke_width=1.1)
        s.circle(24, 20.5, 2, fill="#7dffb0")
        s.path("M21,27 L27,27 L27,31 L31,31 L31,37 L27,37 L27,41 L21,41 L21,37 L17,37 L17,31 L21,31 Z",
               fill="#58e08a", stroke="#0e3a1e", stroke_width=1.2, stroke_linejoin="round")
    return _ability_icon(g, "#58e08a", "#2fae5c")


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
    "ui/star": icon_star,
    "ui/star_empty": icon_star_empty,
    "ui/dmg_kinetic": icon_kinetic,
    "ui/dmg_explosive": icon_explosive,
    "ui/dmg_piercing": icon_piercing,
    "ui/dmg_cryo": icon_cryo,
    "fx/flame": flame,
    "fx/mine": mine,
    "fx/mound": mound,
    "fx/glob": glob,
    "fx/bubble": bubble,
    "ui/ability_strike": icon_ability_strike,
    "ui/ability_cryo_bomb": icon_ability_cryo_bomb,
    "ui/ability_napalm": icon_ability_napalm,
    "ui/ability_minefield": icon_ability_minefield,
    "ui/ability_repair": icon_ability_repair,
}
