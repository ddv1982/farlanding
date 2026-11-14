# Run Farlanding in a browser with CI verification

Make the existing RTS playable in a desktop browser. Keep the native game working and extend CI to build and exercise Web exports.

Deliver WEB-01 through WEB-05 in order. Each phase depends on the accepted previous phase. These are planning labels, not opened PRs.

Hosting, Vercel, mobile controls, PWA installation, and cloud saves come later. Implementation was subsequently authorized through full-send. See [implementation evidence](WEB_CI_RESULTS.md) for completed checks and remaining limits. Hosting remains deferred.

## Establish the baseline

The planning baseline is `dbfb93a13d2bcb3cb52a20742a2fa91a75689ddd`. Its [main CI run](https://github.com/ddv1982/farlanding/actions/runs/43577966604) passed.

The existing workflow runs `tools/check.sh`. That script covers formatting, lint, import, script errors, GUT tests, title boot, and mission smoke tests. CI does not install export templates, export games, or run a browser.

`game/export_presets.cfg` and `tools/export.sh` support native platforms only. `game/project.godot` selects Forward Plus. The audio bus layout uses a limiter, sidechain compressors, and low-pass filters. Saves and settings use `user://`.

No browser prototype, listening test, or browser performance measurement was produced during planning. WEB-01 must settle the open runtime choices before later phases depend on them.

## Apply the verification rules

- Preserve the native check job throughout the work.
- Record exact baseline and candidate SHAs with every result.
- Use logs and manifests for build facts, recordings and measurements for audio, and real browser input for gameplay.
- Use a fresh test profile. Keep the origin stable during persistence tests.
- Allow software-rendered WebGL2 for hosted CI correctness tests. Require hardware acceleration for performance acceptance.
- Stop on a failed phase gate. Do not call an export successful gameplay or call headless tests browser proof.
- Review player-visible changes in WEB-01, WEB-03, and WEB-05 with screenshots and video before merge.

## Prove browser feasibility and local export in WEB-01

### Change the export path

- [ ] Record native title, Kessel, and tidal visuals before changes.
- [ ] Add a Web preset and `tools/export.sh Web` that emit `build/web/index.html` and its complete bundle. Preserve native export defaults.
- [ ] Use Godot 4.7.2 and matching templates. Select Compatibility through a Web-specific renderer override.
- [ ] Add `tools/serve_web.py` for loopback-only HTTP, correct WebAssembly MIME type, optional isolation headers, and clean shutdown.
- [ ] Coordinate project settings edits with the open Godot editor so it cannot overwrite them. Preserve unrelated unsaved buffers.
- [ ] Audit editor-addon dependencies and autoloads before excluding them. Never leave a dangling `MCPRuntimeProbe` autoload or preload.

### Settle rendering and audio choices

- [ ] Check each planet under Compatibility. Verify team colours, independent unit parameters, construction previews, health bars, fog, stealth, canopy, lava, and water.
- [ ] Reproduce tidal shoreline and depth behavior before changing `tide_water.gdshader`. Fix only demonstrated renderer differences.
- [ ] Compare single-thread Sample, single-thread Stream, and threaded Stream exports using the audio protocol below.
- [ ] Choose single-thread only if it preserves the required sound and frame pacing. Choose threaded Stream when the evidence requires it. Record HTTP isolation requirements.
- [ ] Record the choice, candidate SHAs, evidence, and tradeoffs in `docs/adr/0019-web-runtime.md`. Recheck ADR numbering when work starts.

Work can touch `game/project.godot`, `game/export_presets.cfg`, `tools/export.sh`, the local server, relevant shaders, graphics settings, audio diagnostics, and the ADR. Keep diagnostic content out of release exports.

### Pass the gate

Run `tools/check.sh`. Export from a clean import and serve the result locally. Reach the title and play a Kessel landing with selection, movement, gathering, construction, production, and combat. Check every planet's rendering and record audio evidence for the chosen mode.

Record three cold starts and a fixed 120-second route on the reference machine. Record its OS, browser version, GPU, viewport, and quality. Proposed starting budgets are at most 30 seconds to start on localhost and frame-time p95 at most 33.3 ms during the route. These are unmeasured targets. Revise them explicitly if feasibility evidence requires it.

## Produce repeatable CI artifacts in WEB-02

### Extend the build job

- [ ] Keep the native check job and add Web export after it passes.
- [ ] Download checksum-verified engine and matching templates. Replace the current version-only engine cache key with a version, platform, and checksum key. Add a separate template cache.
- [ ] Exercise empty-cache and warm-cache builds. Do not depend on a developer's imported `.godot` directory.
- [ ] Bound download, import, and export duration. Fail on engine error logs as well as exit codes.
- [ ] Upload the complete Web bundle, manifest hashes, commit SHA, engine version, preset, and required server headers.
- [ ] Upload failure logs. Keep permissions read-only and add no deployment credentials.
- [ ] Document artifact download, extraction, and local serving in `README.md`.

Work can touch `.github/workflows/ci.yml`, `tools/install_godot_templates.sh`, `tools/export.sh`, and `README.md`.

### Pass the gate

Verify manifest SHA and file hashes from workflow logs and the extracted artifact. Demonstrate a checksum mismatch and an export error fail with useful logs.

Download the actual CI artifact. Serve it through the documented server and check actual HTTP response headers. The artifact itself has no HTTP headers. Reach the title, launch Kessel and Thalassa, and reload without missing assets. Persistence acceptance belongs to WEB-03.

Compare artifact startup with WEB-01 on the same reference machine, browser, server, and cache conditions. Investigate a regression above 20 percent. Record clean and cached CI duration separately. Use a 30-minute export timeout.

## Make browser controls audio and saves reliable in WEB-03

### Adapt browser behavior

- [ ] Add a user-gesture start action that enables audio.
- [ ] Request fullscreen from a click or key event. Update the game setting when browser Esc exits fullscreen. Do not automatically restore it at startup.
- [ ] Choose browser-safe quicksave and quickload defaults. Preserve native bindings and user rebinding. F5 currently conflicts with reload.
- [ ] Prevent page scrolling and context menus only while the game owns the canvas. Test both mouse schemes, wheel zoom, middle drag, and releasing input outside the canvas.
- [ ] Clear held input and pause safely on focus loss or tab hide. Resume without unwanted simulation catch-up.
- [ ] Hide or replace title Quit in Web builds. Keep a clear route from mission menus back to the title.
- [ ] Test campaign progress, landing saves, keybinds, and settings across reload and browser reopening at the same origin.
- [ ] Show an accurate warning when persistence is unavailable or writes fail. Do not trust only `OS.is_userfs_persistent()`.
- [ ] Test all menus at 1280x720 and 1920x1080 with each supported UI scale.

Work can touch settings, bindings, camera input, UI, main scene behavior, audio, saves, campaign persistence, browser integration, export shell configuration, and their tests.

### Pass the gate

Run native checks and add behavior tests for changed settings, bindings, focus, and save handling. In the actual browser, save a known landing state, reload, and assert the expected units, resources, mission, and campaign progress. Repeat with denied storage and verify the warning.

Complete the input and menu cases above. Apply the audio protocol after a real user gesture. Record screenshots, a short gameplay video, audio capture, measurements, and the named listening receipt.

Measure against WEB-02 on the same machine. Proposed gates are unloaded input response below 100 ms, save confirmation within 2 seconds, and no frame-time p95 regression above 20 percent. Any lost save fails regardless of timing.

## Gate CI on browser gameplay in WEB-04

### Add deterministic browser checks

- [ ] Add pinned browser-test dependencies and a lockfile under `tools/web_tests/`.
- [ ] Run Chromium against the exact release artifact. Use software-rendered WebGL2 on hosted Linux where needed. Record the backend and fail if no working WebGL2 context exists.
- [ ] Keep a release smoke test for title, mission launch, rendering, and real input.
- [ ] Add a separate `WebDiagnostics` preset, export command, and output directory for deeper fixture tests. Update `game/export_presets.cfg` and `tools/export.sh` explicitly.
- [ ] Explicitly include the diagnostic fixture and dependencies despite the existing `tests/*` exclusion. Verify the release bundle excludes them.
- [ ] Use a fixed seed, viewport, camera, and bounded scenario. Diagnostics may expose read-only state and screen coordinates. Drive actions through actual pointer and keyboard events.
- [ ] Assert game-ready state and state transitions. Use bounded predicate waits instead of fixed sleeps or assuming that a canvas means the game loaded.
- [ ] Exercise worker selection, movement, construction, production, a deterministic enemy encounter, save recovery, and Return to title.
- [ ] Archive console and network logs, screenshots, traces, video, browser version, and manifests on failure.
- [ ] Run a short suite on PRs and main. Start the broader mission matrix as a manually dispatched workflow.

Work can touch the CI workflow, browser test tooling, local server, `game/tests/web/`, export presets, export script, and run documentation. No arbitrary production command endpoint or editor MCP dependency is needed.

### Pass the gate

Run ten consecutive suites at the candidate SHA with no hidden retry successes. Deliberately break asset loading, game-ready state, and saved-state expectations in disposable fixtures. Each must fail with useful evidence.

Use a 10-minute smoke timeout and a separate 30-minute broad-suite timeout. A missing hardware GPU does not fail software-rendered correctness checks. A missing functional WebGL2 context does.

Document required job names. Check repository rules separately before claiming those jobs block merges.

## Meet performance and browser acceptance in WEB-05

### Measure and fix observed limits

- [ ] Profile the exact release artifact before optimizing. Separate startup, transfer, decoded asset memory, steady play, long frames, and save time.
- [ ] Add the existing `tests/bench/bench_battle.tscn` and dependencies to WebDiagnostics for the 233-unit benchmark. Keep the benchmark excluded from release.
- [ ] Record diagnostic overhead with probes enabled and disabled. Report release gameplay and diagnostic benchmark results separately.
- [ ] Reduce the measured bottleneck. Consider audio encoding and preloading if payload or decoded audio dominates. Local source-file size is not download size.
- [ ] Preserve tactical readability, simulation behavior, fog accuracy, discovery cues, and important sounds.
- [ ] Test Chrome, Firefox, and actual Safari on macOS. WebKit automation supplements Safari testing.
- [ ] Launch every mission and exercise every planet rule. Complete representative conquest, exploration, and stealth objectives.
- [ ] Finish a 30-minute session with building, gathering, combat, discovery, saving, loading, mission completion, and campaign continuation.

Work can touch presentation, audio assets and playback, project settings, export presets, `tools/export.sh`, benchmark fixtures, browser tests, `docs/PERFORMANCE.md`, and `README.md`.

### Pass the gate

Use three interleaved baseline and candidate runs on the same hardware-accelerated machine and browser. Record exact versions and quality. Apply the audio protocol in real Safari as well as the primary browser.

Proposed gates are frame-time p95 at most 33.3 ms at 1280x720 medium quality during the battle, no repeatable post-warmup stall above 250 ms, and cold localhost startup at most 30 seconds. Across three equivalent load-return cycles, investigate memory growth above 20 percent after comparable settling. Mark unavailable memory probes as gaps.

Publish measured results, supported browser versions, local run commands, and remaining limitations. Keep hosting in a later plan.

## Verify audio with recordings measurements and listening

Replay the same timed sequence for native reference and each browser candidate. Include music, an Advisor line, clear and storm states, positional cues, and busy combat.

Record actual tab or system audio without microphone bleed. Measure music level before, during, and after the Advisor. Compare high-frequency energy in clear and storm states. Check the limiter with a controlled loud sequence. Define tolerances from the native reference before judging candidates.

Read-only `AudioServer` bus peaks from a diagnostic export can supplement recordings using existing `tests/audio/` patterns. Bus peaks cannot prove audible output or spectral filtering. If capture is unavailable, leave those checks unproven.

A human listening receipt records listener name, date, SHA, browser version, output device, scenario, expected cue, observed cue, dropout status, and PASS or FAIL. Include recording timestamps and measurement files. A screenshot never proves audio behavior.

## Record decisions and open risks

Sequence Work into Verifiable Units gives each phase a checkable result before the next starts. Experience First preserves sound and tactical readability before choosing the most convenient thread mode. Prove It Works requires actual browser input, reload recovery, and audio evidence.

The renderer, thread mode, and audio path remain unresolved until WEB-01. Browser performance is not established by the native headless figures in `docs/PERFORMANCE.md`.

IndexedDB persistence depends on browser policy and origin. Clearing storage or changing the future hosting origin can remove access to previous local saves. Mobile support remains outside this milestone.

## Read before implementation

- [Godot 4.7 Web exports](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html) covers Compatibility, audio modes, persistence, fullscreen, serving, and isolation requirements.
- [Godot 4.7 shader uniforms](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/shading_language.html) documents per-instance uniforms and Compatibility restrictions.
- [CONVENTIONS.md](CONVENTIONS.md), [PERFORMANCE.md](PERFORMANCE.md), and [PLAN.md](PLAN.md) define the existing architecture and checks.
