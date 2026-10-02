"""E9 one-off: bake per-sector HP multipliers into the wave files' hp_scale (implementation.md).

The taller field (shift_maps.py) gave the defence a longer approach to shoot at, so every
sector but Outpost got easier. The multipliers were found with `uv run balance --hp` sweeps;
this writes them into game/data/waves/<map>_NN.tres (Outpost's are wave_NN.tres), so the data
alone carries the tuning.

    python3 bake_hp.py canyon=1.16 mire=1.085 ...           # dry run
    python3 bake_hp.py --write canyon=1.16 mire=1.085 ...   # rewrite in place
"""
import re
import sys
from pathlib import Path

WAVES = Path(__file__).resolve().parents[2] / "game" / "data" / "waves"
PREFIX = {"outpost": "wave"}


def main(argv: list[str]) -> None:
    write = "--write" in argv
    for arg in (a for a in argv if "=" in a):
        name, mult = arg.split("=")
        files = sorted(WAVES.glob(f"{PREFIX.get(name, name)}_[0-9][0-9].tres"))
        assert len(files) == 10, f"{name}: {len(files)} wave files"
        for f in files:
            text = f.read_text()
            m = re.search(r"^hp_scale = ([\d.]+)$", text, re.M)
            old = float(m.group(1)) if m else 1.0
            new = round(old * float(mult), 3)
            out = (text[:m.start()] + f"hp_scale = {new}" + text[m.end():]) if m else \
                text.replace("[resource]\n", f"[resource]\nhp_scale = {new}\n", 1)
            print(f"{f.name}: {old} -> {new}")
            if write:
                f.write_text(out)


if __name__ == "__main__":
    main(sys.argv[1:])
