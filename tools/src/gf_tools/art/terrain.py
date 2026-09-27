"""The ground of every map, painted from the map's own data (game/data/maps/*.tres).

A map is paths from portals to the gate, build plots and terrain zones
(docs/2026-09-26-maps-from-paths/). The painter reads those straight from the map files so the
art can never disagree with the rules: packed-dirt strips follow each path's centre line (merged
paths blend into one trunk), burrows open where paths start, mud and ridges sit where their zones
are, and decoration (rocks, scrub, crystals) keeps clear of paths and plots.
"""

from __future__ import annotations

import math
import random
import re
from dataclasses import dataclass, field
from pathlib import Path

from . import palette as P
from .props import _crystal, _rock, _tuft
from .svg import Svg, smooth_path

FIELD_W = 540.0
FIELD_H = 860.0
# Half-width of a painted dirt strip (the rules' path spread is 30 plus the enemy's radius).
STRIP = 56.0
MAPS_DIR = Path(__file__).resolve().parents[4] / "game" / "data" / "maps"

Point = tuple[float, float]


@dataclass
class Zone:
    kind: int  # ZoneDef.Kind: 0 mud, 1 high ground
    center: Point
    radius: float


@dataclass
class MapShape:
    id: str
    paths: list[list[Point]] = field(default_factory=list)
    plots: list[Point] = field(default_factory=list)
    zones: list[Zone] = field(default_factory=list)


def _vec2s(text: str) -> list[Point]:
    nums = [float(v) for v in text.replace(" ", "").split(",") if v]
    return list(zip(nums[0::2], nums[1::2]))


def load_map(path: Path) -> MapShape:
    """Parse the parts of a MapDef .tres the painter needs (paths, plots, zones)."""
    text = path.read_text(encoding="utf-8")
    shape = MapShape(re.search(r'^id = &"(\w+)"', text, re.M).group(1))
    for block in re.split(r"\n(?=\[)", text):
        if 'script = ExtResource("path_s")' in block:
            shape.paths.append(_vec2s(re.search(r"points = PackedVector2Array\((.*)\)", block).group(1)))
        elif 'script = ExtResource("zone_s")' in block:
            kind = int(re.search(r"kind = (\d+)", block).group(1))
            c = re.search(r"center = Vector2\(([-\d.]+), ([-\d.]+)\)", block)
            r = float(re.search(r"radius = ([\d.]+)", block).group(1))
            shape.zones.append(Zone(kind, (float(c.group(1)), float(c.group(2))), r))
        elif block.startswith("[resource]"):
            m = re.search(r"^plots = PackedVector2Array\((.*)\)", block, re.M)
            shape.plots = _vec2s(m.group(1)) if m else []
    return shape


def load_maps() -> list[MapShape]:
    return [load_map(p) for p in sorted(MAPS_DIR.glob("*.tres"))]


def _dist_to_path(p: Point, pts: list[Point]) -> float:
    best = math.inf
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        dx, dy = bx - ax, by - ay
        l2 = dx * dx + dy * dy
        t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / l2)) if l2 else 0.0
        best = min(best, math.hypot(ax + t * dx - p[0], ay + t * dy - p[1]))
    return best


def _sample(pts: list[Point], step: float) -> list[tuple[Point, Point]]:
    """Points every `step` along a polyline, each with its unit normal (smoothed at corners)."""
    out: list[tuple[Point, Point]] = []
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        seg = math.hypot(bx - ax, by - ay)
        n = max(1, int(seg // step))
        tx, ty = (bx - ax) / seg, (by - ay) / seg
        for i in range(n):
            k = i / n
            out.append(((ax + (bx - ax) * k, ay + (by - ay) * k), (-ty, tx)))
    last = pts[-1]
    out.append(((last[0], last[1] + 20), out[-1][1]))  # run on under the wall
    # average neighbouring normals so strip edges bend smoothly
    smooth = []
    for i, (p, _) in enumerate(out):
        nx = sum(out[j][1][0] for j in range(max(0, i - 2), min(len(out), i + 3)))
        ny = sum(out[j][1][1] for j in range(max(0, i - 2), min(len(out), i + 3)))
        ln = math.hypot(nx, ny) or 1.0
        smooth.append((p, (nx / ln, ny / ln)))
    return smooth


def ground_for(m: MapShape) -> Svg:
    s = Svg(FIELD_W, FIELD_H)
    rng = random.Random(sum(ord(c) for c in m.id) * 7)
    s.rect(0, 0, FIELD_W, FIELD_H, fill=s.linear([(0, "#1a1420", 1), (0.22, "#26201f", 1),
           (1, "#2b2520", 1)]))
    for _ in range(420):  # mottled ground texture
        x, y = rng.uniform(0, FIELD_W), rng.uniform(0, FIELD_H)
        s.ellipse(x, y, rng.uniform(4, 16), rng.uniform(3, 10),
                  fill=rng.choice([P.VERGE, P.VERGE_LIGHT, "#1c1a18"]), opacity=rng.uniform(0.25, 0.6))
    for z in m.zones:  # ridges under everything else (a raised rocky shelf)
        if z.kind == 1:
            cx, cy = z.center
            s.circle(cx, cy + 4, z.radius + 10, fill="#15110e", opacity=0.6)
            s.circle(cx, cy, z.radius + 8, fill=s.radial([(0, P.ROCK_LIGHT, 1), (0.7, P.ROCK, 1),
                     (1, "#2e2a26", 1)], cx=0.4, cy=0.35), stroke="#1a1612", stroke_width=2)
            for i in range(14):
                a = i / 14 * math.tau
                _rock(s, rng, cx + math.cos(a) * (z.radius + 6), cy + math.sin(a) * (z.radius + 6),
                      rng.uniform(3.5, 6))
    samples = [_sample(pts, 14.0) for pts in m.paths]
    for pi_, smp in enumerate(samples):  # dirt strips, edges first so merges blend
        left, right = [], []
        for i, ((x, y), (nx, ny)) in enumerate(smp):
            half = STRIP + 6 * math.sin(i * 0.45 + pi_ * 2.1) + rng.uniform(-2.5, 2.5)
            left.append((x + nx * half, y + ny * half))
            right.append((x - nx * half, y - ny * half))
        s.path(smooth_path(left + right[::-1], tension=0.4), fill=P.DIRT_DARK, stroke="#231b15",
               stroke_width=6, opacity=0.9)
    for smp in samples:
        left, right = [], []
        for (x, y), (nx, ny) in smp:
            left.append((x + nx * (STRIP - 8), y + ny * (STRIP - 8)))
            right.append((x - nx * (STRIP - 8), y - ny * (STRIP - 8)))
        s.path(smooth_path(left + right[::-1], tension=0.4), fill=P.DIRT, opacity=0.95)
        left, right = [], []
        for (x, y), (nx, ny) in smp:
            left.append((x + nx * 22, y + ny * 22))
            right.append((x - nx * 22, y - ny * 22))
        s.path(smooth_path(left + right[::-1], tension=0.4), fill=P.DIRT_LIGHT, opacity=0.35)
    for smp in samples:  # clods, pebbles and claw tracks along each path
        for _ in range(len(smp) * 3):
            (x, y), (nx, ny) = smp[rng.randrange(len(smp))]
            o = rng.gauss(0, 24)
            x, y = x + nx * o, y + ny * o
            if rng.random() < 0.55:
                s.ellipse(x, y, rng.uniform(1.5, 5), rng.uniform(1, 3.2),
                          fill=rng.choice([P.DIRT_DARK, "#5c4834", P.DIRT_LIGHT]), opacity=rng.uniform(0.35, 0.8))
            else:
                r = rng.uniform(0.8, 1.9)
                s.circle(x + 0.5, y + 0.6, r, fill="#1a140f", opacity=0.6)
                s.circle(x, y, r, fill=rng.choice(["#8a7560", "#7a6650", "#a08a70"]))
        for track in (-22, 0, 20):
            i = rng.randrange(2)
            while i < len(smp) - 1:
                (x, y), (nx, ny) = smp[i]
                (x2, y2), _ = smp[i + 1]
                tx, ty = x2 - x, y2 - y
                ln = math.hypot(tx, ty) or 1.0
                tx, ty = tx / ln, ty / ln
                x, y = x + nx * (track + rng.uniform(-5, 5)), y + ny * (track + rng.uniform(-5, 5))
                for k in (-2.2, 0, 2.2):
                    s.line((x + nx * k, y + ny * k), (x + nx * k * 1.4 + tx * 5, y + ny * k * 1.4 + ty * 5),
                           stroke="#2a2018", stroke_width=0.9, opacity=0.55, stroke_linecap="round")
                i += rng.randint(1, 2)
    for z in m.zones:  # mud: a dark wet patch with glossy puddles
        if z.kind == 0:
            cx, cy = z.center
            s.ellipse(cx, cy, z.radius, z.radius * 0.85, fill=s.radial([(0, "#2a1f16", 0.95),
                      (0.75, "#33271c", 0.85), (1, "#33271c", 0)]))
            for _ in range(9):
                a, r = rng.uniform(0, math.tau), rng.uniform(0, z.radius * 0.6)
                x, y = cx + math.cos(a) * r, cy + math.sin(a) * r * 0.85
                s.ellipse(x, y, rng.uniform(5, 13), rng.uniform(3, 7), fill="#1b140e", opacity=0.9)
                s.ellipse(x - 2, y - 1.5, rng.uniform(2, 5), rng.uniform(1, 2), fill="#8fa0a8", opacity=0.35)

    def clear(x: float, y: float, r: float) -> bool:
        if any(_dist_to_path((x, y), pts) < STRIP + r + 4 for pts in m.paths):
            return False
        if any((x - px) ** 2 + (y - py) ** 2 < (r + 32) ** 2 for px, py in m.plots):
            return False
        return not any((x - z.center[0]) ** 2 + (y - z.center[1]) ** 2 < (z.radius + r + 10) ** 2
                       for z in m.zones)

    for _ in range(700):  # verges: rocks, scrub and crystals
        x, y = rng.uniform(4, FIELD_W - 4), rng.uniform(40, FIELD_H - 20)
        kind = rng.random()
        if kind < 0.45:
            r = rng.uniform(3, 8.5)
            if clear(x, y, r):
                _rock(s, rng, x, y, r)
        elif kind < 0.85:
            if clear(x, y, 4):
                _tuft(s, rng, x, y, rng.choice(["#4f6a3a", "#5d7a40", "#3e5f55", "#6a5a7a"]))
        elif kind < 0.93 and clear(x, y, 10):
            _crystal(s, rng, x, y, rng.uniform(6, 11))
    for pts in m.paths:  # burrows where each path starts, where the swarm emerges
        cx = min(max(pts[0][0], 24.0), FIELD_W - 24.0)
        cy = max(pts[0][1], 4.0)
        s.glow(cx, cy, 70, P.HIVE_GLOW, 0.45)
        s.ellipse(cx, cy, 40, 16, fill=s.radial([(0, "#050305", 1), (0.7, "#1a0c16", 1),
                  (1, "#3a1a2a", 0.9)]))
        for i in range(9):  # a lip of torn earth
            a = math.radians(i * 22.5)
            _rock(s, rng, cx + math.cos(a) * 42, cy + math.sin(a) * 14 + 8, rng.uniform(3, 5.5))
    s.rect(0, 0, FIELD_W, 300, fill=s.linear([(0, P.HAZE, 0.92), (0.45, P.HAZE, 0.45), (1, P.HAZE, 0)]))
    s.rect(0, FIELD_H - 180, FIELD_W, 180, fill=s.linear([(0, "#ffb060", 0), (1, "#ffb060", 0.10)]))
    return s


def portal_sealed() -> Svg:
    """A burrow the swarm hasn't broken open yet: a crusted, pulsing mound (the game adds the
    wave it opens on)."""
    s = Svg(96, 48)
    rng = random.Random(5)
    s.soft_shadow(48, 28, 42, 16, 0.5)
    s.ellipse(48, 24, 40, 16, fill=s.radial([(0, "#4a2238", 1), (0.6, "#2a1420", 1), (1, "#1a0c14", 1)]))
    for _ in range(18):  # crust
        x, y = 48 + rng.uniform(-32, 32), 24 + rng.uniform(-10, 10)
        s.ellipse(x, y, rng.uniform(3, 7), rng.uniform(2, 4), fill=rng.choice(["#5a3048", "#3a1a2a", "#6a3a55"]))
    for i in range(5):  # glowing cracks
        a = i * 1.25 + 0.3
        s.path(f"M48,24 L{48 + math.cos(a) * 30:.1f},{24 + math.sin(a) * 12:.1f}", stroke=P.HIVE_GLOW,
               stroke_width=1.6, opacity=0.8, stroke_linecap="round")
    return s


ASSETS = {f"field/ground_{m.id}": (lambda mm=m: ground_for(mm)) for m in load_maps()}
ASSETS["field/portal_sealed"] = portal_sealed
