"""``uv run make-clips``: record the special attacks' tutorial clips from the game itself.

Each attack is staged by the game's ``--demo=ID`` mode (RunController: a stream of enemies down
the middle path, the attack called when they're in place, its spot and frame printed). The
scene is recorded with Godot's Movie Maker at twice the view (1080×1920, near a phone's
resolution and quick enough to render in software), then cropped around the attack, trimmed around its call and encoded:

- ``game/clips/ID.ogv`` (Ogg Theora, the one video format Godot plays): shown looping in the
  attack's first-time tutorial (TipLayer). Generated but tracked, since it ships.
- ``captures/clips/ID.mp4`` (H.264, git-ignored): the same clip for review.

    uv run make-clips                      # every attack
    uv run make-clips strike napalm        # some

Needs ``xvfb-run`` and an ffmpeg with libtheora and libx264 (``$FFMPEG_BIN``, else PATH).
Movie Maker's ``--resolution`` doesn't change the rendered size, so the game is copied to a
temporary folder with an ``override.cfg`` that sets the bigger window (never written into the
real game/).
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
GODOT = REPO / ".tools" / "godot" / "Godot_v4.7.2-stable_linux.x86_64"
GAME = REPO / "game"
CLIPS = GAME / "clips"
REVIEW = REPO / "captures" / "clips"

#: The capture: the 540×1170 view (E9) at ×2 (a 300-unit crop is 600 px, sampled down to OUT_SIZE).
SCALE = 2.0
WIDTH, HEIGHT = 1080, 2340
#: The HUD's height above the field (Hud.HEIGHT), in view units.
FIELD_TOP = 50.0
FPS = 60


@dataclass(frozen=True)
class Shot:
    """How to frame one attack: seconds of lead-in before the call and of play after it, the
    square's side in field units, and a nudge of the square's centre (field units, +y down)."""

    lead: float
    after: float
    side: float = 300.0
    nudge: tuple[float, float] = (0.0, 0.0)


SHOTS: dict[str, Shot] = {
    "strike": Shot(0.7, 2.4),
    "cryo_bomb": Shot(0.7, 5.0),
    "napalm": Shot(0.7, 4.8, 320.0, (0.0, -30.0)),
    "minefield": Shot(0.6, 4.2, 320.0, (0.0, -40.0)),
    "repair": Shot(0.6, 2.2, 300.0, (0.0, 45.0)),
}
#: Encoded size (px, square), rate and Theora quality of the in-game clip: 400 px at q5 is
#: ~70 KB a second and clean on a phone (2026-09-27 comparison of q4–6 at 400/480 px).
OUT_SIZE = 400
OUT_FPS = 30

_DEMO = re.compile(r"DEMO (\w+) field ([\d.]+) ([\d.]+) frame (\d+)")


def ffmpeg_bin() -> str:
    found = os.environ.get("FFMPEG_BIN") or shutil.which("ffmpeg")
    if not found:
        raise SystemExit("no ffmpeg: set FFMPEG_BIN (it needs libtheora and libx264)")
    return found


def big_copy(dest: Path) -> Path:
    """A copy of game/ that renders at WIDTH×HEIGHT (an override.cfg in the copy only)."""
    copy = dest / "game"
    shutil.copytree(GAME, copy, ignore=shutil.ignore_patterns("clips"))
    (copy / "override.cfg").write_text(
        "[display]\n\n"
        f"window/size/viewport_width={WIDTH}\nwindow/size/viewport_height={HEIGHT}\n"
        f"window/stretch/scale={SCALE:.4f}\n")
    return copy


def record(game: Path, ability: str, avi: Path, seed: int) -> tuple[float, float, int]:
    """Play the demo of `ability` into `avi`; return where (field units) and on which frame
    the attack was called."""
    cmd = ["xvfb-run", "-a", "-s", f"-screen 0 {WIDTH + 100}x{HEIGHT + 100}x24", str(GODOT),
           "--path", str(game), "--display-driver", "x11", "--rendering-driver", "opengl3",
           "--write-movie", str(avi), "--fixed-fps", str(FPS), "--resolution",
           f"{WIDTH}x{HEIGHT}", "--", f"--demo={ability}", f"--seed={seed}"]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=900).stdout
    m = _DEMO.search(out)
    if not m or m.group(1) != ability:
        raise RuntimeError(f"{ability}: the demo never called it:\n{out[-2000:]}")
    return float(m.group(2)), float(m.group(3)), int(m.group(4))


def crop_box(x: float, y: float, shot: Shot) -> tuple[int, int, int, int]:
    """The square (w, h, left, top) in capture pixels around field point (x, y), kept on
    screen."""
    side = round(shot.side * SCALE)
    cx = (x + shot.nudge[0]) * SCALE
    cy = (y + shot.nudge[1] + FIELD_TOP) * SCALE
    left = int(min(max(0, cx - side / 2), WIDTH - side))
    top = int(min(max(0, cy - side / 2), HEIGHT - side))
    return side, side, left, top


def encode(ffmpeg: str, avi: Path, ability: str, x: float, y: float, frame: int) -> list[Path]:
    """Crop, trim and encode the clip (Theora for the game, H.264 for review)."""
    shot = SHOTS[ability]
    w, h, left, top = crop_box(x, y, shot)
    start = max(0.0, frame / FPS - shot.lead)
    vf = f"crop={w}:{h}:{left}:{top},scale={OUT_SIZE}:{OUT_SIZE}:flags=lanczos,fps={OUT_FPS}"
    CLIPS.mkdir(exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    ogv = CLIPS / f"{ability}.ogv"
    mp4 = REVIEW / f"{ability}.mp4"
    base = [ffmpeg, "-loglevel", "error", "-y", "-ss", f"{start:.3f}", "-t",
            f"{shot.lead + shot.after:.3f}", "-i", str(avi), "-vf", vf, "-an"]
    subprocess.run(base + ["-c:v", "libtheora", "-q:v", "5", str(ogv)], check=True)
    subprocess.run(base + ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", str(mp4)],
                   check=True)
    return [ogv, mp4]


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("abilities", nargs="*", default=list(SHOTS))
    p.add_argument("--seed", type=int, default=7)
    a = p.parse_args(argv)
    ffmpeg = ffmpeg_bin()
    unknown = [ab for ab in a.abilities if ab not in SHOTS]
    if unknown:
        raise SystemExit(f"no framing for {unknown}; add them to SHOTS")
    with tempfile.TemporaryDirectory(prefix="clips-") as tmp:
        work = Path(tmp)
        game = big_copy(work)
        for ab in a.abilities:
            avi = work / f"{ab}.avi"
            x, y, frame = record(game, ab, avi, a.seed)
            for f in encode(ffmpeg, avi, ab, x, y, frame):
                print(f"{f.relative_to(REPO)}  {f.stat().st_size / 1024:.0f} KB")
            avi.unlink()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
