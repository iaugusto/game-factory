# Implementation log — repository bootstrap

Lightweight work item (CLAUDE.md §3: small and obvious, so research/plan collapse into this
note). Newest at the bottom.

## 2026-09-24 — repository created

- **Why:** the user wants a repo like `content-creation-factory` for the game, with the same
  development rules and good practices.
- `git init -b main`. Nothing committed; committing is the user's call (§5).
- `CLAUDE.md` — adapted from `content-creation-factory/CLAUDE.md`, keeping the same structure
  and rules: context order, the per-work-item `research → plan → implementation` flow,
  definition of done, "run the work, don't ask", the ask-first list, and "a stale overview is a
  bug". Game-specific additions: a performance-budget check in the definition of done; platform
  services behind interfaces with stub providers (the TTS-provider-registry pattern applied to
  ads/IAP/achievements); data-driven balance; seeded RNG for determinism; player-data/privacy
  declarations; store uploads, signing keys, bundle IDs and ad spend on the ask-first list.
- **Engine not chosen yet.** `CLAUDE.md` §4 says so explicitly and forbids scaffolding engine
  code until the concept work item decides it. Python/`uv` is kept for out-of-engine tooling,
  same as the source project.
- `README.md`, `docs/detailed-project-overview.md` — written in the same format as the source
  project (status block, layout table, `existing`/`planned` markers, change log).
- `.gitignore` — Godot + Unity + Python, plus every mobile/Steam secret type (keystores, `.p8`,
  `.p12`, provisioning profiles, Play service accounts, Firebase configs).
- `.claude/settings.local.json` — the source project's general allow/deny rules, minus its
  one-off entries; adds `godot`, and denies store-upload tools (`fastlane`, `altool`,
  `steamcmd`) and reading signing keys.
- **No `LICENSE`** on purpose: the source repo is MIT, but MIT on a commercial game's code lets
  anyone ship it. Left for the user to decide.

**Testing:** no testable surface (documentation and config only). Verified with `git status`
that `.claude/settings.local.json` is ignored.

**Status: complete.**
