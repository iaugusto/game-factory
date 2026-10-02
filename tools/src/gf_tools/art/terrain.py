"""The ground of every map, painted from the map's own data (game/data/maps/*.tres).

A map is paths from portals to the gate, build plots and terrain zones
(docs/2026-09-26-maps-from-paths/). The painter reads those straight from the map files so the
art can never disagree with the rules: packed-dirt strips follow each path's centre line (merged
paths blend into one trunk), burrows open where paths start, mud and ridges sit where their zones
are, and decoration (rocks, scrub, crystals) keeps clear of paths and plots.

Each map names a biome (MapDef.biome) that picks the palette (BIOMES): a desert outpost, a
red-rock canyon, a frozen ridge, a swamp, black ash with ember-rimmed rocks, the infested
hive (its creep ×2.4), or the neutral dusk look. Lanes are sunken (a lit lip, then the
left wall's shadow across the floor), and the swarm's creep stains the lane edges in sparse,
faint patches that thin out toward the wall, so it tells the story without competing with the
enemies (the user judged a dense creep at the top of the field too much).
"""

from __future__ import annotations

import math
import random
import re
from dataclasses import dataclass, field
from typing import Callable
from pathlib import Path

from . import palette as P
from .props import _crystal, _rock, _tuft
from .svg import FIELD_RASTER, Svg, smooth_path

GAME_DIR = Path(__file__).resolve().parents[4] / "game"


def field_height() -> float:
    """The field's height in field units: RunConfig.wall_y, the gate line, as the game reads it.

    The value in game/data/run_config.tres, else RunConfig's default (game/src/defs/
    run_config.gd), so the painted ground always matches the field the game lays out (E9 made
    it 980 for tall phones; one number, owned by the game's data).
    """
    for path, pattern in ((GAME_DIR / "data" / "run_config.tres", r"^wall_y = ([\d.]+)"),
                          (GAME_DIR / "src" / "defs" / "run_config.gd",
                           r"^@export var wall_y: float = ([\d.]+)")):
        m = re.search(pattern, path.read_text(), re.M) if path.exists() else None
        if m:
            return float(m.group(1))
    raise ValueError("RunConfig.wall_y not found")


FIELD_W = 540.0
FIELD_H = field_height()
# Half-width of a painted dirt strip (the rules' path spread is 30 plus the enemy's radius).
STRIP = 56.0
MAPS_DIR = GAME_DIR / "data" / "maps"

Point = tuple[float, float]


@dataclass
class Zone:
    kind: int  # ZoneDef.Kind: 0 mud, 1 high ground
    center: Point
    radius: float


@dataclass
class MapShape:
    id: str
    biome: str = ""
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
    biome = re.search(r'^biome = &"(\w*)"', text, re.M)
    shape.biome = biome.group(1) if biome else ""
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


@dataclass(frozen=True)
class Biome:
    """A ground palette. Colours stay darker and less saturated than the sprites on top."""

    bg: tuple[str, str, str]          # the base gradient, top to bottom
    mottle: tuple[str, str, str]      # blotches over the base
    strip: tuple[str, str, str]       # lane: edge (dark), floor, centre wear (light)
    edge: str                         # the lane's outline
    pebbles: tuple[str, str, str]
    rock: tuple[str, str, str, str]   # light, mid, dark, rim (props._rock)
    tufts: tuple[str, ...]
    crystals: bool
    haze: str                         # the dusk haze over the swarm's end
    warm: float                       # the floodlight's warmth near the wall
    mud: tuple[str, str]              # mud patch, puddle
    creep: float = 1.0                # how much of the swarm's creep stains the lanes (×)


BIOMES: dict[str, Biome] = {
    "dusk": Biome(("#1a1420", "#26201f", "#2b2520"), (P.VERGE, P.VERGE_LIGHT, "#1c1a18"),
                  (P.DIRT_DARK, P.DIRT, P.DIRT_LIGHT), "#231b15", ("#8a7560", "#7a6650", "#a08a70"),
                  (P.ROCK_LIGHT, P.ROCK, "#2a2724", "#8a8378"),
                  ("#4f6a3a", "#5d7a40", "#3e5f55", "#6a5a7a"), True, P.HAZE, 0.10,
                  ("#2a1f16", "#1b140e")),
    "desert": Biome(("#3a2a22", "#5a4230", "#6a4e36"), ("#4e3a2a", "#6e5238", "#5a4432"),
                    ("#4a3626", "#7a5e40", "#9a7a54"), "#3a2a1c", ("#b09070", "#9a7a5a", "#c8a882"),
                    ("#a08466", "#7a624a", "#4a3a2c", "#c8b090"),
                    ("#7a7a3a", "#8a8448", "#6a6a36", "#5e6a3a"), False, "#3a2030", 0.14,
                    ("#3a2a1c", "#241a10")),
    "canyon": Biome(("#2a1418", "#4a2420", "#5a2e24"), ("#5a2a20", "#6e3626", "#4a221c"),
                    ("#3e2218", "#6a3e2a", "#8a5638"), "#2e1812", ("#a0624a", "#8a5240", "#b87858"),
                    ("#b0664a", "#8a4632", "#4a2218", "#d08a6a"),
                    ("#6a6a3a", "#7a6a3a", "#5a5a30", "#7a5a3a"), False, "#2a1030", 0.12,
                    ("#2e1a12", "#1e100a")),
    "tundra": Biome(("#1a2230", "#2a3440", "#34404c"), ("#2e3a46", "#3e4c58", "#26303a"),
                    ("#2a2e34", "#4a4e54", "#6a6e74"), "#1e2228", ("#9aa6b0", "#8a96a0", "#c0cad2"),
                    ("#8a96a2", "#5a6672", "#2a323a", "#c0ccd6"),
                    ("#5a7a7a", "#6a8a8a", "#4a6a70", "#7a8a9a"), True, "#1a2440", 0.06,
                    ("#1e242c", "#12161c")),
    # Content expansion, Stage 4 (sectors 4-6).
    "swamp": Biome(("#141c16", "#1e2a1e", "#243024"), ("#1a261c", "#26342a", "#16201a"),
                   ("#1e261c", "#34402c", "#4a5638"), "#141a12", ("#6a7a5a", "#5a6a4a", "#8a9a70"),
                   ("#5a6a52", "#3e4c3a", "#1e2618", "#8a9a7a"),
                   ("#4a7a3a", "#5a8a40", "#3a6a4a", "#6a8a5a"), False, "#10241e", 0.08,
                   ("#1a2416", "#0e160c")),
    "ash": Biome(("#141212", "#221e1c", "#2a2420"), ("#2a2624", "#34302c", "#1c1a18"),
                 ("#1e1a18", "#3a3430", "#56504a"), "#141110", ("#7a726a", "#5e5852", "#9a928a"),
                 ("#5e5650", "#3e3834", "#1a1614", "#ff8a3a"),
                 ("#4a4440", "#5a524a", "#3a3430", "#6a5a4a"), False, "#2a1410", 0.18,
                 ("#1e1814", "#120e0c")),
    "infested": Biome(("#1e1020", "#2a1628", "#301a2a"), ("#34182e", "#40203a", "#261222"),
                      ("#2a1424", "#4a2a3a", "#6a3e50"), "#1e0c1a", ("#8a5a78", "#7a4a68", "#a87090"),
                      ("#7a4a6a", "#5a2e4c", "#2a1022", "#b0306a"),
                      ("#6a2a5a", "#7a3a6a", "#5a2a4a", "#8a3a6a"), True, "#3a1030", 0.12,
                      ("#2a1022", "#1a0816"), 2.4),
}
# The swarm's creep: stain, vein, pustule.
CREEP = ("#5a1440", "#b0306a", "#ff7ab0")


def _band(smp: list[tuple[Point, Point]], half: Callable[[int], float]) -> str:
    """A closed band around a sampled path, `half(i)` wide at sample i."""
    left, right = [], []
    for i, ((x, y), (nx, ny)) in enumerate(smp):
        h = half(i)
        left.append((x + nx * h, y + ny * h))
        right.append((x - nx * h, y - ny * h))
    return smooth_path(left + right[::-1], tension=0.4)


def _creep(s: Svg, rng: random.Random, samples: list[list[tuple[Point, Point]]],
           burrows: list[Point], density: float = 1.0) -> None:
    """Sparse, faint creep on the lane edges: most common near the burrows but reaching down
    the field, never within 200 of the wall, never on the lane floor's centre."""
    stain, vein, pus = CREEP
    for cx, cy in burrows:  # a modest stain around each burrow
        s.ellipse(cx, cy + 6, 52, 26, fill=s.radial([(0, stain, 0.6), (0.7, stain, 0.3), (1, stain, 0)]))
    for smp in samples:
        patches: list[Point] = []
        for _ in range(int(max(6, len(smp) // 3) * density)):
            i = int(len(smp) * rng.random() ** 1.6)
            (x, y), (nx, ny) = smp[min(i, len(smp) - 1)]
            if y > FIELD_H - 200:
                continue
            side = rng.choice((-1, 1))
            off = side * (STRIP + rng.uniform(-10, 16))
            px, py = x + nx * off, y + ny * off
            fade = 1.0 - py / (FIELD_H - 200)
            r = rng.uniform(8, 18)
            s.ellipse(px, py, r * 1.3, r * 0.8, fill=s.radial([(0, stain, 0.55 * fade + 0.25),
                      (0.7, stain, 0.3 * fade + 0.1), (1, stain, 0)]))
            patches.append((px, py))
        for px, py in rng.sample(patches, min(4, len(patches))):  # a few thin veins
            pts = [(px, py)]
            for _ in range(rng.randint(2, 4)):
                px += rng.uniform(-10, 10)
                py += rng.uniform(14, 26)
                pts.append((px, py))
            s.path(smooth_path(pts, closed=False), fill="none", stroke=vein,
                   stroke_width=rng.uniform(0.9, 1.5), opacity=0.5, stroke_linecap="round")
        for px, py in rng.sample(patches, min(3, len(patches))):  # the odd pustule
            r = rng.uniform(2.0, 3.4)
            s.glow(px, py, r * 3, pus, 0.3)
            s.circle(px, py, r, fill=s.radial([(0, "#ffd0e8", 1), (0.5, "#e0508a", 1), (1, stain, 1)],
                     cx=0.4, cy=0.35), stroke="#2a0818", stroke_width=0.5, opacity=0.85)


def ground_for(m: MapShape) -> Svg:
    b = BIOMES.get(m.biome, BIOMES["dusk"])
    s = Svg(FIELD_W, FIELD_H, FIELD_RASTER)
    rng = random.Random(sum(ord(c) for c in m.id) * 7)
    s.rect(0, 0, FIELD_W, FIELD_H, fill=s.linear([(0, b.bg[0], 1), (0.22, b.bg[1], 1), (1, b.bg[2], 1)]))
    for _ in range(480):  # mottled ground texture
        x, y = rng.uniform(0, FIELD_W), rng.uniform(0, FIELD_H)
        s.ellipse(x, y, rng.uniform(4, 17), rng.uniform(3, 10.5), fill=rng.choice(b.mottle),
                  opacity=rng.uniform(0.25, 0.6))
    for z in m.zones:  # ridges under everything else (a raised rocky shelf)
        if z.kind == 1:
            cx, cy = z.center
            s.circle(cx, cy + 4, z.radius + 10, fill="#15110e", opacity=0.6)
            s.circle(cx, cy, z.radius + 8, fill=s.radial([(0, b.rock[0], 1), (0.7, b.rock[1], 1),
                     (1, b.rock[2], 1)], cx=0.4, cy=0.35), stroke="#1a1612", stroke_width=2)
            for i in range(14):
                a = i / 14 * math.tau
                _rock(s, rng, cx + math.cos(a) * (z.radius + 6), cy + math.sin(a) * (z.radius + 6),
                      rng.uniform(3.5, 6), b.rock)
    samples = [_sample(pts, 14.0) for pts in m.paths]
    dark, floor, wear = b.strip
    for pi_, smp in enumerate(samples):  # lane beds, edges first so merges blend
        wob = [STRIP + 6 * math.sin(i * 0.45 + pi_ * 2.1) + rng.uniform(-2.5, 2.5) for i in range(len(smp))]
        s.path(_band(smp, lambda i: wob[i] + 7), fill=b.pebbles[2], opacity=0.28)  # the lit lip
        s.path(_band(smp, lambda i: wob[i]), fill=dark, stroke=b.edge, stroke_width=6, opacity=0.95)
    for smp in samples:
        s.path(_band(smp, lambda i: STRIP - 8), fill=floor, opacity=0.95)
        s.path(_band(smp, lambda i: 22), fill=wear, opacity=0.35)
        # the left wall's shadow across the floor (light from the upper left)
        pts = [(x + nx * (STRIP - 8), y + ny * (STRIP - 8)) for (x, y), (nx, ny) in smp]
        pts += [(x + nx * (STRIP - 24), y + ny * (STRIP - 24)) for (x, y), (nx, ny) in reversed(smp)]
        s.path(smooth_path(pts, tension=0.4), fill="#000000", opacity=0.22)
    for smp in samples:  # clods, pebbles and claw tracks along each path
        for _ in range(len(smp) * 3):
            (x, y), (nx, ny) = smp[rng.randrange(len(smp))]
            o = rng.gauss(0, 24)
            x, y = x + nx * o, y + ny * o
            if rng.random() < 0.55:
                s.ellipse(x, y, rng.uniform(1.5, 5), rng.uniform(1, 3.2), fill=rng.choice(b.strip),
                          opacity=rng.uniform(0.35, 0.8))
            else:
                r = rng.uniform(0.8, 1.9)
                s.circle(x + 0.5, y + 0.6, r, fill="#1a140f", opacity=0.6)
                s.circle(x, y, r, fill=rng.choice(b.pebbles))
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
                           stroke=b.edge, stroke_width=0.9, opacity=0.55, stroke_linecap="round")
                i += rng.randint(1, 2)
    for z in m.zones:  # mud: a dark wet patch with glossy puddles
        if z.kind == 0:
            cx, cy = z.center
            s.ellipse(cx, cy, z.radius, z.radius * 0.85, fill=s.radial([(0, b.mud[0], 0.95),
                      (0.75, b.mud[0], 0.85), (1, b.mud[0], 0)]))
            for _ in range(9):
                a, r = rng.uniform(0, math.tau), rng.uniform(0, z.radius * 0.6)
                x, y = cx + math.cos(a) * r, cy + math.sin(a) * r * 0.85
                s.ellipse(x, y, rng.uniform(5, 13), rng.uniform(3, 7), fill=b.mud[1], opacity=0.9)
                s.ellipse(x - 2, y - 1.5, rng.uniform(2, 5), rng.uniform(1, 2), fill="#8fa0a8", opacity=0.35)

    def clear(x: float, y: float, r: float) -> bool:
        if any(_dist_to_path((x, y), pts) < STRIP + r + 4 for pts in m.paths):
            return False
        if any((x - px) ** 2 + (y - py) ** 2 < (r + 32) ** 2 for px, py in m.plots):
            return False
        return not any((x - z.center[0]) ** 2 + (y - z.center[1]) ** 2 < (z.radius + r + 10) ** 2
                       for z in m.zones)

    for _ in range(740):  # verges: rocks, scrub and crystals
        x, y = rng.uniform(4, FIELD_W - 4), rng.uniform(40, FIELD_H - 20)
        kind = rng.random()
        if kind < 0.45:
            r = rng.uniform(3, 9)
            if clear(x, y, r):
                _rock(s, rng, x, y, r, b.rock)
        elif kind < 0.85:
            if clear(x, y, 4):
                _tuft(s, rng, x, y, rng.choice(b.tufts))
        elif kind < 0.93 and b.crystals and clear(x, y, 10):
            _crystal(s, rng, x, y, rng.uniform(6, 11))
    burrows = [(min(max(pts[0][0], 24.0), FIELD_W - 24.0), max(pts[0][1], 4.0)) for pts in m.paths]
    _creep(s, rng, samples, burrows, b.creep)
    for cx, cy in burrows:  # burrows where each path starts, where the swarm emerges
        s.glow(cx, cy, 70, P.HIVE_GLOW, 0.45)
        s.ellipse(cx, cy, 40, 16, fill=s.radial([(0, "#050305", 1), (0.7, "#1a0c16", 1),
                  (1, "#3a1a2a", 0.9)]))
        for i in range(9):  # a lip of torn earth
            a = math.radians(i * 22.5)
            _rock(s, rng, cx + math.cos(a) * 42, cy + math.sin(a) * 14 + 8, rng.uniform(3, 5.5), b.rock)
    s.rect(0, 0, FIELD_W, 300, fill=s.linear([(0, b.haze, 0.92), (0.45, b.haze, 0.45), (1, b.haze, 0)]))
    s.rect(0, FIELD_H - 180, FIELD_W, 180, fill=s.linear([(0, "#ffb060", 0), (1, "#ffb060", b.warm)]))
    # a vignette: darker corners pull the eye to the lanes
    s.rect(0, 0, FIELD_W, FIELD_H, fill=s.radial([(0, "#000000", 0), (0.7, "#000000", 0),
           (1, "#000000", 0.45)], cx=0.5, cy=0.55, r=0.75))
    return s


def portal_sealed() -> Svg:
    """A burrow the swarm hasn't broken open yet: a crusted, pulsing mound (the game adds the
    wave it opens on)."""
    s = Svg(96, 48, FIELD_RASTER)
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
