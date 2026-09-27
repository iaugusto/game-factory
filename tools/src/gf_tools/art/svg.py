"""A tiny SVG builder: defs (gradients, clip paths), a flat list of elements, and helpers for
the few shapes the art uses a lot (outlined paths, soft shadows, highlights).

Only features Godot's ThorVG rasterizer handles are used: paths, basic shapes, groups,
transforms, opacity, linear and radial gradients, clip paths. No filters (blur/drop shadow);
softness comes from radial gradients that fade to transparent.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from math import cos, sin, pi
from typing import Iterable, Sequence

Point = tuple[float, float]


def _fmt(v: float) -> str:
    """Compact, stable number formatting (keeps diffs of regenerated art small)."""
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def attrs(**kw: object) -> str:
    """Render keyword attributes; underscores become dashes, None values are skipped."""
    out = []
    for k, v in kw.items():
        if v is None:
            continue
        name = k.rstrip("_").replace("_", "-")
        if isinstance(v, float):
            v = _fmt(v)
        out.append(f'{name}="{v}"')
    return " ".join(out)


def pts(points: Iterable[Point]) -> str:
    return " ".join(f"{_fmt(x)},{_fmt(y)}" for x, y in points)


def path_from(points: Sequence[Point], closed: bool = True) -> str:
    """A polygon/polyline as path data."""
    d = "M" + " L".join(f"{_fmt(x)},{_fmt(y)}" for x, y in points)
    return d + (" Z" if closed else "")


def smooth_path(points: Sequence[Point], closed: bool = True, tension: float = 0.5) -> str:
    """A Catmull-Rom spline through `points`, as cubic Béziers: organic outlines (carapace
    plates, splats, rocks) from a handful of control points."""
    n = len(points)
    if n < 3:
        return path_from(points, closed)
    p = list(points)
    d = f"M{_fmt(p[0][0])},{_fmt(p[0][1])}"
    count = n if closed else n - 1
    for i in range(count):
        p0 = p[(i - 1) % n] if closed or i > 0 else p[i]
        p1 = p[i]
        p2 = p[(i + 1) % n]
        p3 = p[(i + 2) % n] if closed or i + 2 < n else p2
        c1 = (p1[0] + (p2[0] - p0[0]) * tension / 3, p1[1] + (p2[1] - p0[1]) * tension / 3)
        c2 = (p2[0] - (p3[0] - p1[0]) * tension / 3, p2[1] - (p3[1] - p1[1]) * tension / 3)
        d += f" C{_fmt(c1[0])},{_fmt(c1[1])} {_fmt(c2[0])},{_fmt(c2[1])} {_fmt(p2[0])},{_fmt(p2[1])}"
    return d + (" Z" if closed else "")


def ellipse_points(cx: float, cy: float, rx: float, ry: float, n: int = 16,
                   jitter: Sequence[float] | None = None, rot: float = 0.0) -> list[Point]:
    """Points around an ellipse, optionally with per-point radial jitter (organic shapes)."""
    out = []
    for i in range(n):
        a = 2 * pi * i / n + rot
        k = 1.0 + (jitter[i % len(jitter)] if jitter else 0.0)
        out.append((cx + cos(a) * rx * k, cy + sin(a) * ry * k))
    return out


@dataclass
class Svg:
    """One SVG document. `w`/`h` are the viewBox (art units = game units); the document is
    rasterized at `scale` × that size."""

    w: float
    h: float
    scale: float = 2.0
    defs: list[str] = field(default_factory=list)
    body: list[str] = field(default_factory=list)
    _ids: int = 0

    def uid(self, prefix: str) -> str:
        self._ids += 1
        return f"{prefix}{self._ids}"

    # --- paint servers -----------------------------------------------------------------

    def linear(self, stops: Sequence[tuple[float, str, float]], x1: float = 0, y1: float = 0,
               x2: float = 0, y2: float = 1, user: bool = False) -> str:
        """A linear gradient; stops are (offset, color, opacity). Returns `url(#id)`.
        Coordinates are fractions of the shape's box unless `user` (then art units)."""
        gid = self.uid("lg")
        units = "userSpaceOnUse" if user else "objectBoundingBox"
        s = "".join(f'<stop {attrs(offset=float(o), stop_color=c, stop_opacity=float(a))}/>'
                    for o, c, a in stops)
        self.defs.append(f'<linearGradient id="{gid}" {attrs(gradientUnits=units, x1=float(x1), y1=float(y1), x2=float(x2), y2=float(y2))}>{s}</linearGradient>')
        return f"url(#{gid})"

    def radial(self, stops: Sequence[tuple[float, str, float]], cx: float = 0.5,
               cy: float = 0.5, r: float = 0.5, fx: float | None = None,
               fy: float | None = None, user: bool = False) -> str:
        """A radial gradient (fractions of the shape's box unless `user`). Returns `url(#id)`."""
        gid = self.uid("rg")
        units = "userSpaceOnUse" if user else "objectBoundingBox"
        s = "".join(f'<stop {attrs(offset=float(o), stop_color=c, stop_opacity=float(a))}/>'
                    for o, c, a in stops)
        self.defs.append(f'<radialGradient id="{gid}" {attrs(gradientUnits=units, cx=float(cx), cy=float(cy), r=float(r), fx=None if fx is None else float(fx), fy=None if fy is None else float(fy))}>{s}</radialGradient>')
        return f"url(#{gid})"

    def clip(self, inner: str) -> str:
        """A clip path from raw element markup. Returns `url(#id)`."""
        cid = self.uid("cp")
        self.defs.append(f'<clipPath id="{cid}">{inner}</clipPath>')
        return f"url(#{cid})"

    # --- elements ----------------------------------------------------------------------

    def add(self, markup: str) -> None:
        self.body.append(markup)

    def path(self, d: str, **kw: object) -> str:
        m = f'<path {attrs(d=d, **kw)}/>'
        self.add(m)
        return m

    def circle(self, cx: float, cy: float, r: float, **kw: object) -> str:
        m = f'<circle {attrs(cx=float(cx), cy=float(cy), r=float(r), **kw)}/>'
        self.add(m)
        return m

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, **kw: object) -> str:
        m = f'<ellipse {attrs(cx=float(cx), cy=float(cy), rx=float(rx), ry=float(ry), **kw)}/>'
        self.add(m)
        return m

    def rect(self, x: float, y: float, w: float, h: float, rx: float = 0, **kw: object) -> str:
        m = f'<rect {attrs(x=float(x), y=float(y), width=float(w), height=float(h), rx=float(rx) if rx else None, **kw)}/>'
        self.add(m)
        return m

    def line(self, a: Point, b: Point, **kw: object) -> str:
        m = f'<line {attrs(x1=float(a[0]), y1=float(a[1]), x2=float(b[0]), y2=float(b[1]), **kw)}/>'
        self.add(m)
        return m

    def polyline(self, points: Sequence[Point], **kw: object) -> str:
        m = f'<polyline {attrs(points=pts(points), **kw)}/>'
        self.add(m)
        return m

    def group(self, transform: str | None = None, **kw: object) -> "_Group":
        return _Group(self, transform, kw)

    # --- compound helpers --------------------------------------------------------------

    def outlined(self, d: str, fill: str, outline: str, width: float = 1.6, **kw: object) -> None:
        """A filled shape with a dark outline drawn *behind* it, so the outline reads as a
        crisp ink line around the silhouette without eating into the fill."""
        self.path(d, fill=outline, stroke=outline, stroke_width=width * 2, stroke_linejoin="round")
        self.path(d, fill=fill, **kw)

    def soft_shadow(self, cx: float, cy: float, rx: float, ry: float, opacity: float = 0.45) -> None:
        """A blurred-looking drop shadow: an ellipse whose radial gradient fades to nothing."""
        g = self.radial([(0, "#000000", opacity), (0.55, "#000000", opacity * 0.6), (1, "#000000", 0)])
        self.ellipse(cx, cy, rx, ry, fill=g)

    def glow(self, cx: float, cy: float, r: float, color: str, opacity: float = 0.8) -> None:
        """A soft light blob (baked glow, since 2D lights are too costly on phones)."""
        g = self.radial([(0, color, opacity), (0.35, color, opacity * 0.5), (1, color, 0)])
        self.circle(cx, cy, r, fill=g)

    def limb(self, points: Sequence[Point], color: str, outline: str, width: float,
             highlight: str | None = None) -> None:
        """A jointed limb (leg, antenna): an outlined round-capped polyline, with an optional
        thin highlight along its upper-left edge so it reads against dark ground."""
        self.polyline(points, fill="none", stroke=outline, stroke_width=width + 2.2,
                      stroke_linecap="round", stroke_linejoin="round")
        self.polyline(points, fill="none", stroke=color, stroke_width=width,
                      stroke_linecap="round", stroke_linejoin="round")
        if highlight:
            off = width * 0.22
            self.polyline([(x - off, y - off) for x, y in points], fill="none", stroke=highlight,
                          stroke_width=max(0.4, width * 0.3), stroke_linecap="round",
                          stroke_linejoin="round", opacity=0.7)

    def render(self) -> str:
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{_fmt(self.w * self.scale)}" '
                f'height="{_fmt(self.h * self.scale)}" viewBox="0 0 {_fmt(self.w)} {_fmt(self.h)}">\n'
                f'<defs>{"".join(self.defs)}</defs>\n' + "\n".join(self.body) + "\n</svg>\n")


class _Group:
    """`with svg.group("translate(…)") as g:` — elements added inside land in the group."""

    def __init__(self, svg: Svg, transform: str | None, kw: dict[str, object]) -> None:
        self.svg = svg
        self.open = f'<g {attrs(transform=transform, **kw)}>'
        self.mark = 0

    def __enter__(self) -> Svg:
        self.mark = len(self.svg.body)
        return self.svg

    def __exit__(self, *exc: object) -> None:
        inner = self.svg.body[self.mark:]
        del self.svg.body[self.mark:]
        self.svg.body.append(self.open + "".join(inner) + "</g>")


def mirror_x(points: Sequence[Point], cx: float) -> list[Point]:
    return [(2 * cx - x, y) for x, y in points]


def polar(cx: float, cy: float, r: float, deg: float) -> Point:
    """Point at `r` from (cx, cy), angle in degrees (0 = +x, 90 = +y/down)."""
    a = deg * pi / 180
    return (cx + cos(a) * r, cy + sin(a) * r)
