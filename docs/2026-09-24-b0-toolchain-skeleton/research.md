# Research — B0 toolchain & skeleton

Covered by the prototype work item: [`../2026-09-24-hold-the-gate-prototype/research.md`](../2026-09-24-hold-the-gate-prototype/research.md)
§4 (engine, tests, machine). Facts checked at the start of this bundle (GitHub API, 2026-09-24):

- **Godot 4.7.2-stable** (published 2026-08-18) is the current stable release.
  - The Linux x86_64 editor is 78 MB zipped and has an official SHA512 in `SHA512-SUMS.txt`.
  - The **export templates are 1.28 GB** — the prototype plan's "~150 MB total" was wrong.
- **GdUnit4 v6.2.1** (2026-08-20) is the latest release.
  - Its README lists compatibility with Godot 4.5–4.7.1. 4.7.2 is a patch release, and running
    the suite on it is the proof.
  - GUT, the fallback, was not needed.
