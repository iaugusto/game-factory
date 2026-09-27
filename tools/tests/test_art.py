"""The art generator: deterministic, well-formed SVG, 2x raster size, and every asset the game
references exists. Run: `uv run python -m unittest discover -s tests` (from tools/)."""

from __future__ import annotations

import re
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from gf_tools.art import cli
from gf_tools.art.svg import Svg, smooth_path

GAME = cli.REPO / "game"


class ArtTest(unittest.TestCase):
    def test_every_asset_renders_well_formed_svg_at_2x(self) -> None:
        for rel, make in cli.registry().items():
            with self.subTest(rel):
                root = ET.fromstring(make().render())
                vb = [float(v) for v in root.attrib["viewBox"].split()]
                self.assertAlmostEqual(float(root.attrib["width"]), vb[2] * 2, places=1)
                self.assertAlmostEqual(float(root.attrib["height"]), vb[3] * 2, places=1)

    def test_generation_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            fa = cli.write_all(Path(a))
            fb = cli.write_all(Path(b))
            self.assertEqual(len(fa), len(fb))
            for pa, pb in zip(fa, fb):
                self.assertEqual(pa.read_bytes(), pb.read_bytes(), pa.name)

    def test_committed_art_matches_the_generator(self) -> None:
        """game/art is generated; a hand edit or a stale regeneration shows up here."""
        for rel, make in cli.registry().items():
            with self.subTest(rel):
                path = GAME / "art" / f"{rel}.svg"
                self.assertTrue(path.exists(), f"{path} missing: run `uv run gen-art`")
                self.assertEqual(path.read_text(encoding="utf-8"), make().render())

    def test_every_art_key_the_game_uses_exists(self) -> None:
        keys = set(cli.registry())
        used: set[str] = set()
        for gd in (GAME / "src").rglob("*.gd"):
            used |= set(re.findall(r'"((?:fx|ui|units|crates|field|enemies)/[a-z_]+)"', gd.read_text()))
        # Keys built from data ids: every enemy, unit and crate id in game/data needs its art.
        for folder, prefix in (("enemies", "enemies/"), ("units", "units/"), ("crates", "crates/"),
                               ("maps", "field/ground_")):
            for tres in (GAME / "data" / folder).glob("*.tres"):
                used.add(f"{prefix}{tres.stem}")
        self.assertFalse(used - keys, f"art referenced but not generated: {sorted(used - keys)}")

    def test_smooth_path_closes_and_group_nests(self) -> None:
        d = smooth_path([(0, 0), (10, 0), (10, 10), (0, 10)])
        self.assertTrue(d.startswith("M0,0") and d.endswith("Z"))
        s = Svg(10, 10)
        with s.group("translate(1,2)"):
            s.circle(1, 1, 1)
        self.assertEqual(len(s.body), 1)
        self.assertIn('<g transform="translate(1,2)"><circle', s.body[0])


if __name__ == "__main__":
    unittest.main()
