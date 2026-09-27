"""Procedural art for the game, written as SVG.

Why SVG: it is readable, diffable source art that Godot rasterizes on import (at the
document's width/height, which we set to 2x the viewBox so sprites stay crisp on high-DPI
phones), and a future artist can open and refine any of it in Inkscape. Everything here is
deterministic: the same code always produces the same files, so regenerated art only changes
when the code does.

Run `uv run gen-art` from tools/ to (re)write game/art/.
"""
