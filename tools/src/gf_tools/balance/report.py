"""Aggregate balance records and check them against the design targets.

Pure functions over the JSON records written by ``BalanceRun.play`` (one dict per run), so
they are unit tested without Godot. Rationale for the targets:
docs/2026-09-27-b4-balance-and-juice/research.md §4.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from statistics import mean, median
from typing import Any, Iterable

Record = dict[str, Any]

#: The sector order, and the tree profile each is meant to be played at.
SECTOR_PROFILES: dict[str, str] = {"outpost": "T0", "canyon": "T3", "switchback": "T6"}
#: The special attack the targets are checked with (the bot's default); cells with another one
#: are labelled "strategy+ability".
DEFAULT_ABILITY = "strike"
#: Strategies whose build ignores the counter chart (they should trail "smart").
FIXED_BUILDS: tuple[str, ...] = ("cycle", "heavy", "light")


@dataclass
class CellStats:
    """What one (sector, profile, strategy) cell of runs came to."""

    map: str
    profile: str
    strategy: str
    runs: int
    win_rate: float
    median_waves: float
    mean_waves: float
    mean_gate: float
    mean_casts: float
    mean_unspent: float
    leaks: dict[str, float] = field(default_factory=dict)


@dataclass
class Check:
    """One target and whether it holds."""

    name: str
    ok: bool
    detail: str


def label(r: Record) -> str:
    """A record's strategy label: the bot preset, plus "+ability" when it didn't take the
    default special attack."""
    ability = r.get("ability") or DEFAULT_ABILITY
    return r["strategy"] if ability == DEFAULT_ABILITY else f"{r['strategy']}+{ability}"


def aggregate(records: Iterable[Record]) -> list[CellStats]:
    """Group records by (map, profile, strategy label) and summarise each group.

    Leaks are the mean gate damage per run by enemy type, largest first.
    """
    groups: dict[tuple[str, str, str], list[Record]] = {}
    for r in records:
        groups.setdefault((r["map"], r.get("profile", "T0"), label(r)), []).append(r)
    out: list[CellStats] = []
    for (m, p, s), rs in groups.items():
        leak_sum: dict[str, float] = {}
        for r in rs:
            for enemy, dmg in r.get("leaks", {}).items():
                leak_sum[enemy] = leak_sum.get(enemy, 0.0) + float(dmg)
        leaks = {k: v / len(rs) for k, v in sorted(leak_sum.items(), key=lambda kv: -kv[1])}
        out.append(
            CellStats(
                map=m,
                profile=p,
                strategy=s,
                runs=len(rs),
                win_rate=sum(1 for r in rs if r["won"]) / len(rs),
                median_waves=float(median(r["waves"] for r in rs)),
                mean_waves=mean(r["waves"] for r in rs),
                mean_gate=mean(r["gate"] for r in rs),
                mean_casts=mean(r.get("casts", r.get("strikes", 0)) for r in rs),
                mean_unspent=mean(r.get("unspent", 0) for r in rs),
                leaks=leaks,
            )
        )
    return out


def _cell(stats: list[CellStats], m: str, s: str) -> CellStats | None:
    want = SECTOR_PROFILES.get(m)
    for c in stats:
        if c.map == m and c.strategy == s and (want is None or c.profile == want):
            return c
    return None


def check_targets(stats: list[CellStats]) -> list[Check]:
    """The research §4 targets, per sector at its intended profile. Missing cells are skipped."""
    checks: list[Check] = []
    for m in SECTOR_PROFILES:
        smart = _cell(stats, m, "smart")
        casual = _cell(stats, m, "casual")
        if smart:
            checks.append(Check(f"{m}: smart wins 35–65%", 0.35 <= smart.win_rate <= 0.65,
                                f"{smart.win_rate:.0%}"))
        if casual:
            checks.append(Check(f"{m}: casual wins 10–40%", 0.10 <= casual.win_rate <= 0.40,
                                f"{casual.win_rate:.0%}"))
            if m == "outpost":
                checks.append(Check("outpost: casual median wave ≥ 6", casual.median_waves >= 6,
                                    f"{casual.median_waves:g}"))
        fixed = [c for c in (_cell(stats, m, f) for f in FIXED_BUILDS) if c]
        if smart and fixed:
            worst_gap = min(smart.win_rate - c.win_rate for c in fixed)
            checks.append(Check(f"{m}: fixed builds ≥ 10 pts below smart", worst_gap >= 0.10,
                                ", ".join(f"{c.strategy} {c.win_rate:.0%}" for c in fixed)))
        no_loot = _cell(stats, m, "no_loot")
        if no_loot and casual:
            checks.append(Check(f"{m}: no_loot below casual",
                                no_loot.mean_waves < casual.mean_waves,
                                f"{no_loot.mean_waves:.1f} vs {casual.mean_waves:.1f} waves"))
    return checks


def render(stats: list[CellStats], checks: list[Check], title: str, notes: str = "") -> str:
    """The report as Markdown: targets first, then one table per sector, then leaks."""
    lines = [f"# {title}", ""]
    if notes:
        lines += [notes, ""]
    passed = sum(1 for c in checks if c.ok)
    lines += [f"## Targets: {passed}/{len(checks)} met", "", "| Target | Result | Value |",
              "| --- | --- | --- |"]
    lines += [f"| {c.name} | {'✅' if c.ok else '❌'} | {c.detail} |" for c in checks]
    order = list(SECTOR_PROFILES) + sorted({c.map for c in stats} - set(SECTOR_PROFILES))
    for m in order:
        rows = sorted((c for c in stats if c.map == m), key=lambda c: (c.profile, -c.win_rate))
        if not rows:
            continue
        lines += ["", f"## {m}", "",
                  "| Profile | Strategy | Runs | Win | Median wave | Mean wave | Gate | Casts | Unspent | Top leaks (gate dmg/run) |",
                  "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
        for c in rows:
            top = ", ".join(f"{k} {v:.0f}" for k, v in list(c.leaks.items())[:3]) or "—"
            lines.append(f"| {c.profile} | {c.strategy} | {c.runs} | {c.win_rate:.0%} | "
                         f"{c.median_waves:g} | {c.mean_waves:.1f} | {c.mean_gate:.0%} | "
                         f"{c.mean_casts:.1f} | {c.mean_unspent:.0f} | {top} |")
    return "\n".join(lines) + "\n"
