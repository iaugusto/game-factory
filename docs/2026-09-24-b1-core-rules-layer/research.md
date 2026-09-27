# Research — B1 core rules layer

The design questions and prior art are in the prototype work item:
[`../2026-09-24-hold-the-gate-prototype/research.md`](../2026-09-24-hold-the-gate-prototype/research.md)
and [`plan.md`](../2026-09-24-hold-the-gate-prototype/plan.md) §2–§5. This note only records the
technical findings that shaped B1.

## Where the combat simulation lives

The prototype plan put the per-tick combat (lanes, bullets, enemies) in `sim/` nodes. But B1's
"done when" asks for a **seeded, headless 10-wave run that reproduces its state hash**, and B4's
balance bot must play 50+ runs per strategy without rendering. Both need combat that runs
**without the scene tree**. So combat belongs in `core/`, and `sim/` shrinks to renderers that
read core state and forward input. It's the same split as a server-authoritative game: core is
the simulation, nodes are the client.

## Why lanes keep collision cheap

Every target in a lane lies on the bullet's path. So a bullet fired up a lane always meets the
target **closest to the wall** first. If each lane keeps its targets sorted by distance to the
wall, collision is one comparison per bullet per tick: O(bullets), with no physics engine and
no spatial hash. The sort is nearly free, because enemies rarely overtake each other (insertion
sort on almost-sorted data is linear).

## Determinism in GDScript

- `RandomNumberGenerator` with an explicit `seed` is deterministic for a given engine build.
  Named streams are seeded from `"<seed>:<name>".hash()` (`String.hash` is a fixed djb2-style
  hash), so adding a new stream later doesn't shift the existing ones.
- Floats: the same binary on the same machine gives identical results. Across platforms, IEEE
  floats can differ in the last bits, so the determinism promise is **per build**. That's enough
  for replaying bugs and for balancing. Lockstep multiplayer would need fixed-point, and it's out
  of scope.
- Fixed tick (60 Hz). Rendering interpolates in B2; rules never read frame delta.

## Content as Resources

Typed `Resource` scripts (`class_name EnemyDef` …) saved as `.tres` are text, diffable, and
editable in the inspector. The initial `.tres` files are produced by `ResourceSaver` from a
throwaway generator (not kept), so their format is exactly what the editor writes. From then on,
the `.tres` files are the source of truth.
