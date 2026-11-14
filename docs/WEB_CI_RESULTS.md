# Browser implementation and evidence

The starting commit was `dbfb93a13d2bcb3cb52a20742a2fa91a75689ddd`. Results below
were observed while implementing `browser-ci`. CI artifacts identify their checked
out commit and file hashes. Local manifests also record whether the checkout was
dirty, so a working-tree build is not represented as a committed release.

## Verified behavior

- `tools/check.sh` passed after the browser changes and MP3 migration. It covers
  formatting, lint, import, script/resource loading, native GUT suites including
  real-time mixer tests, title boot, and all 11 mission smoke cases.
- Five Python tooling tests passed. They exercise isolation headers and WebAssembly
  MIME, manifest tampering, corrupt template downloads, exporter errors despite a
  zero exit, and stale model-import invalidation.
- The full real-mixer suite passed inside Chromium with 415 tests and 6,374
  assertions. Actual Web Audio output was captured as well. Mixer checks include
  limiter headroom, ducking, planet loudness, and the finale.
- Browser gameplay checks selected workers, built a Reactor, gathered resources,
  produced a unit, caused combat damage, saved a landing, reloaded, and recovered
  the saved Reactor and extra unit. Return-to-title, denied storage, and corrupt
  save refusal are covered.
- Controls checks passed at 1280x720 and 1920x1080 with 100%, 115%, and 130% UI
  scales. Modern right-click movement and the browser blur/pause boundary passed.
- All ten catalog missions passed browser launch checks during development.
  Screenshots were inspected for the restored terrain materials, fog, unit
  visibility, and planet displays. The broader matrix is manually available in CI.
- Actual Safari on macOS reached the title, mission list, briefing, Kessel landing,
  and Fabricator selection. This is smoke coverage; it is not full Safari campaign
  or perceptual audio qualification.

## Export defects found by these checks

Godot 4.7.2's text-to-binary resource conversion discarded authored packed music
layer names and volumes. A Linux pack inspection reproduced 0 names/volumes;
retaining text resources preserved all 16. Changing array default initializers
alone did not solve it. The default browser suite guards the exported data shape.

The project-level audio enum differs from the player-node enum. Stream is project
value `0`. Sample bypassed required effects and failed mixer checks; threaded
Stream passed the complete suite.

Cached imported scenes retained placeholder materials after the post-import
mapper gained new planets. The import preparation step now fingerprints that
mapper and invalidates affected model outputs. A regression checks the mapped
planet materials.

WebGL also exhausted the instance-uniform buffer. Compatibility materials now own
their shader parameters; native Forward Plus retains instance uniforms. Water uses
WebGL's depth convention. A subtitle layout regression reproduced a 373px band for
one short line; the fixed layout passes the focused check.

## Audio assets

All 408 one-shot MP3 encodes passed decoded loudness, clipping, DC, subsonic energy,
and duration analysis. A rebuild check reproduced 408 identical hashes and zero
orphaned entries with FFmpeg 9.0.2 / libmp3lame. Original one-shot WAVs occupied
48,956,010 bytes; MP3 replacements occupy 5,890,278 bytes. The 36 sample-exact WAV
loops and 157 Ogg assets retain their formats. Recipes remain the source.

Godot already compressed WAV imports, so this source reduction is larger than the
Web pack reduction. Filesystem sizes do not establish HTTP transfer or decoded
memory sizes.

## Performance and limits

Hardware profiling used Apple M4, Chromium159, Metal, 1280x720, medium quality,
five seconds warm-up, and no video or trace during measurement. The 233-unit battle
was sampled for 120 seconds. Threaded Stream recorded about 20ms mean frame time
and 46ms p95 before the particle fallback. Single-thread Stream showed essentially
the same p95. It was not selected.

Captured keydown-to-UI-cue responses were approximately 50–78ms in both modes.
The driver reported 64ms output latency. This is captured graph timing, not an
acoustic speaker measurement; the two measurements must not be added blindly.

Material sharing, reduced shadows, and frozen fog did not meet the proposed
33.3ms p95 target and were not retained. An instancing trial cut draw calls but did
not justify its complexity, so it was removed. Web movement and combat effects use
CPU particle equivalents; native effects remain GPU particles.

The proposed 33.3ms large-battle p95 target remains unmet on this active desktop.
Significant WindowServer and other application CPU/GPU activity was present. No
quiet-hardware or 60FPS guarantee is claimed. This is an explicit performance
limit of the first browser milestone, not a passing result for the original target.

A human listening receipt, a complete campaign playthrough in Safari, and GPU /
WebAssembly memory-leak qualification have not been represented as completed.
Automated mixer evidence supplements those checks; it is not a fabricated listener.
Hosting, mobile controls, PWA, cloud saves, and branch-protection changes remain
outside this milestone.
