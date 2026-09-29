"""Balance report aggregation and target checks, on synthetic records (no Godot)."""

import unittest

from gf_tools.balance import report


def rec(m: str, s: str, won: bool, waves: int, profile: str = "T0", leaks=None) -> dict:
    return {"map": m, "profile": profile, "strategy": s, "won": won, "waves": waves,
            "gate": 0.5 if won else 0.0, "casts": 2, "unspent": 10, "leaks": leaks or {}}


class AggregateTest(unittest.TestCase):
    def test_groups_and_summarises(self) -> None:
        rs = [rec("outpost", "smart", True, 10, leaks={"grunt": 10}),
              rec("outpost", "smart", False, 6, leaks={"grunt": 30, "runner": 5}),
              rec("outpost", "casual", False, 4)]
        stats = {c.strategy: c for c in report.aggregate(rs)}
        self.assertEqual(stats["smart"].runs, 2)
        self.assertAlmostEqual(stats["smart"].win_rate, 0.5)
        self.assertEqual(stats["smart"].median_waves, 8)
        self.assertEqual(list(stats["smart"].leaks), ["grunt", "runner"])
        self.assertAlmostEqual(stats["smart"].leaks["grunt"], 20)

    def test_other_abilities_get_their_own_cells(self) -> None:
        rs = [rec("outpost", "smart", True, 10), rec("outpost", "smart", False, 5)]
        rs[1]["ability"] = "napalm"
        rs.append({**rec("outpost", "smart", True, 10), "ability": "strike"})
        stats = {c.strategy: c for c in report.aggregate(rs)}
        self.assertEqual(sorted(stats), ["smart", "smart+napalm"])
        self.assertEqual(stats["smart"].runs, 2)
        self.assertEqual(stats["smart+napalm"].win_rate, 0.0)


class TargetsTest(unittest.TestCase):
    def _stats(self, smart: float, casual: float, fixed: tuple[float, float, float]):
        rs = []
        for name, rate in [("smart", smart), ("casual", casual), ("cycle", fixed[0]),
                           ("heavy", fixed[1]), ("light", fixed[2])]:
            wins = round(rate * 20)
            rs += [rec("outpost", name, i < wins, 10 if i < wins else 7) for i in range(20)]
        return report.aggregate(rs)

    def test_a_healthy_spread_meets_every_target(self) -> None:
        checks = report.check_targets(self._stats(0.5, 0.25, (0.3, 0.2, 0.25)))
        self.assertTrue(all(c.ok for c in checks), [c for c in checks if not c.ok])

    def test_a_dominant_fixed_build_is_flagged(self) -> None:
        checks = {c.name: c for c in report.check_targets(self._stats(0.5, 0.25, (0.5, 0.1, 0.2)))}
        self.assertFalse(checks["outpost: fixed builds ≥ 10 pts below smart"].ok)

    def test_sectors_are_checked_at_their_own_profile(self) -> None:
        rs = [rec("canyon", "smart", True, 10, profile="T0") for _ in range(4)]
        rs += [rec("canyon", "smart", False, 5, profile="T3") for _ in range(4)]
        checks = {c.name: c for c in report.check_targets(report.aggregate(rs))}
        self.assertEqual(checks["canyon: smart wins 35–65%"].detail, "0%")

    def test_render_lists_targets_and_tables(self) -> None:
        stats = self._stats(0.5, 0.25, (0.3, 0.2, 0.25))
        md = report.render(stats, report.check_targets(stats), "Balance report")
        self.assertIn("## Targets:", md)
        self.assertIn("## outpost", md)
        self.assertIn("| T0 | smart |", md)


if __name__ == "__main__":
    unittest.main()
