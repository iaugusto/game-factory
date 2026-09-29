"""Balance reports: many headless bot runs of the real game, aggregated into a Markdown report.

The Godot side (game/tools/balance_sim.gd, core BalanceRun) plays and records; this package
fans the runs out in parallel (runner), aggregates and checks the targets (report), and wires
both into the ``balance`` console script (cli). See docs/2026-09-27-b4-balance-and-juice/.
"""
