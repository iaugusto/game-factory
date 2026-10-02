"""E9 one-off: move every map down by DY field units for the taller field (plan.md § Changes 3).

Shifts plots, barricade slots, zone centres and path points by +DY on y. A path that enters at
the top edge (first point y <= 0) keeps entering there: it gets a new first point (x, -10)
straight above its shifted start, so its approach grows by DY. Side-entry and mid-field
(breach) paths only move. Every distance between plots, paths and zones is unchanged.

    python3 shift_maps.py            # dry run: prints what would change
    python3 shift_maps.py --write    # rewrites game/data/maps/*.tres in place

Run once: it refuses if the maps already end at the new wall (y = 860 + DY).
"""
import re
import sys
from pathlib import Path

DY = 120.0
OLD_WALL = 860.0
TOP = -10.0
MAPS = Path(__file__).resolve().parents[2] / "game" / "data" / "maps"


def fmt(v: float) -> str:
    return str(int(v)) if v == int(v) else repr(v)


def pairs(body: str) -> list[tuple[float, float]]:
    nums = [float(n) for n in body.split(",") if n.strip()]
    return list(zip(nums[0::2], nums[1::2]))


def join(pts: list[tuple[float, float]]) -> str:
    return ", ".join(f"{fmt(x)}, {fmt(y)}" for x, y in pts)


def shift_path(m: re.Match) -> str:
    pts = pairs(m.group(1))
    assert pts[-1][1] == OLD_WALL, f"path doesn't end at the old wall: {pts}"
    moved = [(x, y + DY) for x, y in pts]
    if pts[0][1] <= 0.0:
        assert pts[1][0] == pts[0][0], f"top entry isn't vertical: {pts[:2]}"
        moved = [(pts[0][0], TOP)] + moved
    return f"points = PackedVector2Array({join(moved)})"


def shift_list(m: re.Match) -> str:
    return f"{m.group(1)} = PackedVector2Array({join([(x, y + DY) for x, y in pairs(m.group(2))])})"


def shift_center(m: re.Match) -> str:
    x, y = float(m.group(1)), float(m.group(2))
    return f"center = Vector2({fmt(x)}, {fmt(y + DY)})"


def main(write: bool) -> None:
    for f in sorted(MAPS.glob("*.tres")):
        text = f.read_text()
        if f"{fmt(OLD_WALL + DY)})" in text and f"{fmt(OLD_WALL)})" not in text:
            sys.exit(f"{f.name}: already shifted")
        out = re.sub(r"points = PackedVector2Array\(([^)]*)\)", shift_path, text)
        out = re.sub(r"(plots|barricade_slots) = PackedVector2Array\(([^)]*)\)", shift_list, out)
        out = re.sub(r"center = Vector2\(([-\d.]+), ([-\d.]+)\)", shift_center, out)
        changed = sum(a != b for a, b in zip(text.splitlines(), out.splitlines()))
        print(f"{f.name}: {changed} lines")
        if write:
            f.write_text(out)


if __name__ == "__main__":
    main("--write" in sys.argv)
