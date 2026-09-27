"""`uv run gen-art`: write every procedural SVG into game/art/."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Callable

from .svg import Svg

REPO = Path(__file__).resolve().parents[4]
OUT = REPO / "game" / "art"


def registry() -> dict[str, Callable[[], Svg]]:
    """Every art file, by path relative to game/art/ (without .svg)."""
    from . import enemies
    reg: dict[str, Callable[[], Svg]] = {}
    for eid in enemies.ENEMIES:
        reg[f"enemies/{eid}"] = (lambda e=eid: enemies.walk_atlas(e))
    for mod_name in ("units", "props", "fx", "terrain"):
        try:
            mod = __import__(f"gf_tools.art.{mod_name}", fromlist=["ASSETS"])
        except ModuleNotFoundError:
            continue
        reg.update(mod.ASSETS)
    return reg


def write_all(out: Path = OUT, only: str | None = None) -> list[Path]:
    """Render the registry to `out`; returns the files written."""
    written = []
    for rel, make in sorted(registry().items()):
        if only and not rel.startswith(only):
            continue
        path = out / f"{rel}.svg"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(make().render(), encoding="utf-8")
        written.append(path)
    return written


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--only", help="only paths starting with this prefix (e.g. enemies/)")
    ap.add_argument("--out", type=Path, default=OUT)
    args = ap.parse_args()
    files = write_all(args.out, args.only)
    print(f"wrote {len(files)} SVG files to {args.out}")
