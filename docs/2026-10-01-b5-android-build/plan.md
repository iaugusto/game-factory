# B5 — Android build & performance: plan

The rationale is in [`research.md`](./research.md). Scope follows `ROADMAP.md` § B5:
- a debug APK from a script;
- on-device frame time and memory at wave 10 and under `--stress --perf`;
- a 30 s clip;
- playtest notes;
- budgets recorded, met or not.

## Setup (done 2026-10-01; repo-local, git-ignored)

| Path | What |
| --- | --- |
| `.tools/jdk/` | Temurin OpenJDK 17 |
| `.tools/android-sdk/` | cmdline-tools (latest), platform-tools, build-tools 35.0.1 + 36.1.0, platforms;android-35 |
| `.tools/godot-export/` | a hardlink of the pinned Godot + `_sc_` (self-contained); `editor_data/export_templates/4.7.2.stable/` has only the Android templates |
| `.tools/keystores/debug.keystore` | Android's standard debug key (androiddebugkey / android) |
| `.tools/android-home/`, `.tools/java-prefs/`, `.tools/bin/adb` | the SDK's, adb's and Java's state, kept out of `$HOME` |

**Rebuilding it from scratch:** download the four archives listed in `research.md` §3, then
follow the steps in `implementation.md` (2026-10-01 entries).

## Chosen approach

1. **`scripts/android_env.sh`** (sourced) sets the repo-local toolchain env.
   **`scripts/build_android.sh [--install] [--launch="ARGS"]`** does the following:
   - exports `builds/android/hold-the-gate-debug.apk` (arm64 only, the prebuilt template,
     no Gradle);
   - installs it over adb;
   - launches it with game flags through the `command_line_params` intent extra.
2. **`game/export_presets.cfg` (tracked)** holds one "Android" preset:
   - the package is `dev.holdthegate.debug`, a debug placeholder. The real ID is a sensitive
     call, made at B17;
   - version 0.1.0-proto;
   - immersive mode on;
   - tests, GdUnit and probes excluded;
   - no credentials (they come from the env).
3. **`scripts/android_perf.sh`** collects the numbers for each run and writes them to
   `captures/perf/*.txt`:
   - launch with flags;
   - wait N s;
   - pull the `--perf` lines from logcat;
   - `dumpsys meminfo` (PSS);
   - `am start -W` cold-start time;
   - `dumpsys thermalservice`.
4. **The measurement matrix** on the S24:

   | Run | Flags | Renderer |
   | --- | --- | --- |
   | Wave 10, real content | `--map=canyon --autoplay --skip-to-wave=10 --perf` | Mobile, then Compat |
   | Stress | `--autoplay --stress --perf` | Mobile, then Compat |
   | Stress, mixed | `--autoplay --stress=mix --perf` | the winner |
   | Hive finale | `--map=hive --autoplay --skip-to-wave=10 --perf` | the winner |
   | Soak | 10 min autoplay, campaign | the winner |

5. **Frame pacing:** cap mobile at 60 fps (research §6, option 1), behind a data/config
   setting rather than a constant, so a later "smooth 120 Hz" option (interpolated views) can
   switch it off. This only goes in if the uncapped S24 run shows judder, which it should at
   120 Hz.
6. **Renderer:** keep Mobile unless Compatibility is equal or better on the S24. If they're
   equal, choose Compatibility for its device reach (research §5).
7. **A 30 s on-device clip:** `adb shell screenrecord --time-limit 30`, pulled to
   `captures/`.

## Budgets (stated against the budget profile; research §2)

| Budget | Low-end (A15 class) | S24 must show | Treat as a bug if |
| --- | --- | --- | --- |
| Frame time | 16.7 ms p95 at 60 fps | ≤ 4.5 ms avg, ≤ 8 ms p95 | an S24 p95 > 8 ms under stress |
| Sim tick (worst) | ≤ 6 ms | ≤ 1.5 ms | — |
| Memory (PSS) | ≤ 350 MB | ≤ 350 MB (memory doesn't scale with the SoC) | > 350 MB |
| APK size | ≤ 60 MB (prototype) | 37 MB now | > 60 MB |
| Cold start to the campaign screen | ≤ 5 s | ≤ 2 s | > 3 s |

## Testing

- **Existing suites:** `scripts/test.sh` and the tools suite must stay green. The export
  preset and scripts don't touch game code.
- **New unit test:** if the fps cap goes into config, add a test that the config value
  exists and loads (`content_test`).
- **Check:** the build script fails loudly when a toolchain piece is missing (manual check).
- **Check:** the APK passes `zipalign -c -P 16` (16 KB pages) and `apksigner verify`.

## Risks

- **adb over WSL2 on Wi-Fi:** WSL2 NAT mode can reach LAN IPs outbound, and `adb pair` and
  `connect` are outbound, so it should work. Fallback: the user sideloads, and perf is read
  from a log the game writes to `user://` (would need a small `--perf-log` flag).
- **Xclipse Vulkan quirks:** covered by measuring Compatibility too.
- **The `--` separator in intent params:** if Godot splits the params differently on
  Android, the parse in `RunController.parse_args` may miss them. Verify on the first launch.

## Out of scope (later bundles)

- AAB / Gradle build, release signing, the real package ID, the Play Console (B17 / D3).
- Interpolated 120 Hz views (polish, after D1).
- Ads, IAP, analytics SDKs (B15–B16).
