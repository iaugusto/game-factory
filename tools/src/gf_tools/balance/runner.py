"""Run the balance matrix as parallel headless Godot processes (one per cell)."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[4]
GODOT = REPO / ".tools" / "godot" / "Godot_v4.7.2-stable_linux.x86_64"
GAME = REPO / "game"


def run_cell(map_id: str, profile: str, strategy: str, seeds: int, workdir: Path,
             hp: float | None = None) -> list[dict[str, Any]]:
    """Play `seeds` runs of one cell headless and return their records.

    `strategy` may name the bot's special attack after a "+" ("smart+napalm"); without one the
    bot takes the game's default (the strike).

    Raises CalledProcessError if Godot fails, so a broken script can't produce an empty report.
    """
    out = workdir / f"{map_id}-{profile}-{strategy}.jsonl"
    preset, _, ability = strategy.partition("+")
    args = [str(GODOT), "--headless", "--path", str(GAME), "--script",
            "res://tools/balance_sim.gd", "--", f"map={map_id}", f"profile={profile}",
            f"strategy={preset}", f"seeds=1-{seeds}", f"out={out}"]
    if ability:
        args.append(f"ability={ability}")
    if hp is not None:
        args.append(f"hp={hp}")
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return [json.loads(line) for line in out.read_text().splitlines() if line.strip()]


def run_matrix(cells: list[tuple[str, str, str]], seeds: int, jobs: int | None = None,
               hp: dict[str, float] | None = None) -> list[dict[str, Any]]:
    """Run every (map, profile, strategy) cell in parallel; return all records."""
    jobs = jobs or max(1, (os.cpu_count() or 2) - 1)
    with tempfile.TemporaryDirectory(prefix="balance-") as tmp:
        work = Path(tmp)
        with ThreadPoolExecutor(max_workers=jobs) as pool:
            futures = [pool.submit(run_cell, m, p, s, seeds, work, (hp or {}).get(m))
                       for m, p, s in cells]
            records: list[dict[str, Any]] = []
            for f in futures:
                records.extend(f.result())
    return records
