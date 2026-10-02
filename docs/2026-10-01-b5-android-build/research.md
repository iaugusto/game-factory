# B5 — Android build & performance: research

Work item from `ROADMAP.md` § B5 (Google Play first, per the user on 2026-09-29). The goal is
to answer one question: does Hold the Gate build for Android and run within budget on a real
phone, and which knobs matter? The answer feeds **D1** (continue, pivot or stop).

## 1. Inputs and approvals (2026-10-01)

**The user's answers**, collected 2026-10-01:
- **The phone is a Galaxy S24:**
  - Exynos 2400 (Xclipse 940 GPU) in Brazil and Europe; Snapdragon 8 Gen 3 (Adreno 750) in
    the US and China. `adb shell getprop ro.soc.model` will confirm which;
  - 8 GB RAM;
  - a 1080×2340 screen with an adaptive refresh rate of up to 120 Hz.
- **Toolchain:** approved, repo-local in git-ignored `.tools/`.
- **Delivery:** the APK reaches the phone over **wireless debugging** (adb pair / connect over
  Wi-Fi). WSL2 can't see USB devices without usbipd-win.
- **Signing:** a **debug keystore** only. Release signing and the real package name are a
  separate decision (B17 / D3).

## 2. The S24 is not the budget device

The S24 is a 2024 flagship. Smooth play on it says little about the Play audience's median
phone, so the plan treats it as the **measurement device** and states the budget against a
named low-end profile:

| Profile | Example | SoC / GPU | RAM | Role |
| --- | --- | --- | --- | --- |
| Test device | Galaxy S24 | Exynos 2400 / Xclipse 940 (or SD 8 Gen 3) | 8 GB | Real measurements |
| Budget profile | Galaxy A15 (4G) | Helio G99 / Mali-G57 MC2 | 4 GB | The device the budgets are written for |

A Helio G99 runs CPU-bound code about 3–4× slower than the S24's big cores (Geekbench 6
single-core: about 700 vs about 2,100–2,300). Its GPU is about 8–10× weaker. **Rule of thumb
for this work item:** a frame or sim cost measured on the S24 must sit at about **¼ of the
budget**, so the A15-class device stays inside it. A real low-end device (or Play's pre-launch
report device lab, in D3) is the true test; this is a stand-in until then.

## 3. Godot 4.7 Android export: what it needs

From the Godot docs, *Exporting for Android* (4.7), plus the templates' own `config.gradle`:
- **JDK:** OpenJDK 17.
- **SDK:** platform-tools, build-tools, platform and cmdline-tools.
  - The docs list build-tools 35.0.1 and platform 35.
  - The 4.7.2 template targets **SDK 36** (build-tools 36.1.0, minSdk 24).
  - Both build-tools versions are installed; Godot picks the one that matches the target.
- **NDK and CMake:** only needed for **Gradle builds** (custom builds, plugins, AAB). A plain
  APK export uses the prebuilt `android_debug.apk` / `android_release.apk` templates, so B5
  skips the NDK (about 2 GB).
  - **The Play Store requires an AAB,** which needs the Gradle build. That moves to B17 / D3.
- **Signing:** the debug keystore can come from the env vars
  `GODOT_ANDROID_KEYSTORE_DEBUG_{PATH,USER,PASSWORD}`, so no path or password goes into
  `export_presets.cfg`. Godot 4 already moves credentials out of the preset into
  `.godot/export_credentials.cfg`.
- **Launch arguments:** the 4.7 activity reads the string-array intent extra
  `command_line_params`. The activity itself isn't exported; its exported launcher alias is
  `com.godot.game.GodotAppLauncher`. So
  `am start -n PKG/com.godot.game.GodotAppLauncher --esa command_line_params "--,--perf"`
  passes the game's flags. `print` output goes to logcat.

**Keeping the toolchain out of `$HOME`** (CLAUDE.md §5). Each tool writes there by default, so
each needed its own fix:
- **Godot editor settings and templates** (`~/.config/godot`, `~/.local/share/godot`): a
  hardlinked copy of the pinned binary in `.tools/godot-export/` with a `_sc_` marker
  (self-contained mode) keeps both beside the binary. The desktop editor and the user's saves
  are untouched.
- **sdkmanager:** it writes `~/.android` (including an `analytics.settings` file) and
  `~/.java`, because it reads Java's `user.home`. The fix is
  `JAVA_TOOL_OPTIONS=-Duser.home=… -Djava.util.prefs.userRoot=…`.
- **adb:** it ignores `ANDROID_USER_HOME` and `ANDROID_SDK_HOME` and always uses
  `$HOME/.android` for its key pair. A wrapper runs it with `HOME=.tools/android-home`. The
  Godot export also probes adb, so the export runs with the same `HOME`.

## 4. Play Store technical requirements that touch B5

- **Target API level:** new apps and updates must target the API level of the latest year
  (35 since 2025-08-31; 36 is expected around 2026-08). The 4.7.2 template targets 36, so
  this is covered.
- **16 KB page sizes:** from 2025-11-01, apps with native code that target Android 15+ must
  support 16 KB pages. Godot has built its Android libraries with 16 KB alignment since 4.4
  or 4.5. **Check:** run `zipalign -c -P 16 -v 4` on the APK.
- **64-bit:** arm64-v8a is required. B5 ships **arm64 only**, which halves the native
  library size. Dropping armeabi-v7a cuts out very old and very cheap devices; revisit at D3
  with Play Console reach data.
- **Size:** the Play base module is limited to 200 MB compressed (AAB). The APK is 37 MB.

## 5. Rendering method: Mobile (Vulkan) vs Compatibility (GLES3)

The project uses `renderer/rendering_method="mobile"`.

**For Compatibility.** For a **2D** game, Godot's guidance leans towards Compatibility on
Android:
- it reaches more devices: GLES3 drivers are more mature on cheap Mali/PowerVR parts, and
  Vulkan drivers on low-end Android are a known source of crashes;
- it costs less per frame for simple 2D.

**For Mobile:**
- it's what the project already uses;
- it helps if heavier 2D lighting or effects arrive.

**Xclipse risk.** The Exynos S24's Xclipse (AMD RDNA) GPU has a history of Vulkan driver
quirks with Godot. If the Mobile renderer misbehaves there, that alone is a reason to switch.

**Approach:** measure both on the S24 (one project setting), with the same stress load, and
recommend one. Godot's `rendering/rendering_device/fallback_to_opengl3` (default on) already
falls back automatically when Vulkan is missing.

## 6. Frame pacing at 120 Hz

The S24's screen runs at up to 120 Hz (adaptive). The game's sim ticks at **60 Hz** in
`_physics_process`, and the views (`EnemyField.sync` and the others) draw the sim's **raw**
positions each frame. At 120 fps, enemies move only on every second frame, which looks like
judder. Options:

1. **Cap at 60 fps on mobile** (`Engine.max_fps = 60`, or `application/run/max_fps`):
   - no judder;
   - half the GPU work, less heat and better battery life, which matters for a game played
     in sessions;
   - typical for 2D mobile tower-defence games;
   - one setting, done.
2. **Interpolate the views:** draw at
   `lerp(prev, cur, Engine.get_physics_interpolation_fraction())`:
   - smooth at 120 Hz;
   - needs previous positions per enemy, shot and crate in the views (not in core);
   - Godot's built-in physics interpolation doesn't apply, because the views draw MultiMesh
     instances from sim data rather than moving nodes in physics.
3. **Raise the sim to 120 Hz:** this doubles the sim cost (the sim tick is the open perf
   risk from E4/E5a) and changes every balance number tied to ticks. Rejected.

**Recommendation:** 1 for B5, measured. Keep 2 as a later polish option ("120 Hz smooth
mode"). Godot 4.4+ uses Android's Swappy frame pacing, so a 60 fps cap on a 120 Hz panel
paces evenly.

## 7. What to measure (ROADMAP "done when" + handover §5)

| Metric | How | Desktop reference |
| --- | --- | --- |
| Frame time (avg / p95 / max) | the game's `--perf` (logcat), wave 10 and `--stress` | sim tick 1.3–2.4 ms |
| Sim tick | `--perf` (time spent in `Run.step`) | same |
| Draw calls | `--perf` | Outpost 82 … new maps 109–120 under stress |
| Memory (PSS) | `adb shell dumpsys meminfo PKG` | — |
| Cold start to the campaign screen | `am start -W` (TotalTime) | — |
| APK size | file size | 37 MB |
| Thermal behaviour | 10-minute autoplay, frame time at the start vs the end, `dumpsys thermalservice` | — |

## 8. Sources

- Godot docs, *Exporting for Android* (stable = 4.7):
  https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
- Godot 4.7.2 Android templates, `config.gradle` and `AndroidManifest.xml` (in
  `android_source.zip`).
- Google Play, *Target API level requirements*:
  https://developer.android.com/google/play/requirements/target-sdk
- Android developers, *Support 16 KB page sizes*:
  https://developer.android.com/guide/practices/page-sizes
- Google Play, *64-bit requirement*: https://developer.android.com/google/play/requirements/64-bit
- Godot docs, *Renderers* (Compatibility vs Mobile vs Forward+):
  https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- Samsung Galaxy S24 specs (regional SoC split):
  https://www.gsmarena.com/samsung_galaxy_s24-12773.php
- Galaxy A15 specs: https://www.gsmarena.com/samsung_galaxy_a15-12637.php

## 9. Open questions

- **Which S24 variant?** Exynos or Snapdragon. The first adb connection answers it.
- **Measure only on the S24, or borrow a cheaper phone?** Any Android phone of about 2021 or
  later at the low end would give a real number. That's a question for the user, raised in the
  report.
