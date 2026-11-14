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
- The full real-mixer suite passed inside Chromium with 416 tests and 6,374
  assertions. Actual Web Audio output was captured as well. Mixer checks include
  limiter headroom, ducking, planet loudness, and the finale.
  The save-audio regression verifies that Web local writes stay silent until
  persistent storage confirms them; failed writes emit no success event.
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
- A 30.4-minute Chromium session completed 29 landing, worker-command, quicksave,
  and return-to-title cycles. This used the earlier working-tree export, before
  the PR review fixes. JavaScript heap readings increased from about 177MB to
  386MB; this is usability soak evidence, not memory-leak qualification.

The first hosted software-WebGL run exhausted the three-minute timeout while
the combined six-case menu matrix was still passing assertions. The whole suite
then hit its ten-minute step limit. Each viewport/scale pair now has its own
isolated test, video capture is opt-in, and the browser step allows 30 minutes.
Screenshots and failure traces remain enabled; assertion thresholds and retries
are unchanged. The combined construction/gathering/production/save-reload case
allows eight minutes overall for its multiple simulation waits and two launches.

Software-rendered gameplay also reproduced a test click hitting the construction
worker instead of the adjacent Hauler. The test now moves the finished builder
clear through normal mouse input before selecting the Hauler; production picking
and gameplay rules are unchanged.

The local software-WebGL suite passed 17 cases; the affected gameplay case then
passed separately after that input-flow correction, taking 2.4 minutes. This is
targeted revalidation, not a claim of a repeated full-suite run.

The next hosted run still starved at high/100% defaults: a constructed Reactor
remained unfinished after only 202 simulation ticks, and a correct settings file
reached IndexedDB after the acknowledgement deadline. Fresh Web profiles now
default to low/50%, with saved choices taking precedence and native defaults
unchanged. All 18 browser cases subsequently passed locally with software WebGL
in 4.8 minutes, including settings persistence and the complete build/save flow.
The 1920x1080 menu cases dropped from about 39 to 17 seconds locally. This improves
responsiveness by sacrificing scene resolution and shadows; UI resolution stays
unchanged.

Hosted CI subsequently passed on `5ea70b6`: the native check job, all 18 browser
cases (12.7 minutes), and Seer review were green in
[run 43612674648](https://github.com/ddv1982/farlanding/actions/runs/43612674648).
All inline findings were resolved. The final follow-up only records this evidence.

The downloaded release artifact identifies GitHub's tested merge commit
`f376e989bb714e09e18ae8927ba9691e4131a5b8`, with a clean source tree. Its complete
nine-file inventory passed hash verification using the included tool. Served with
the included server, it launched cold in 4.46 seconds and warm in 2.49 seconds on
the same M4/Chromium session, then reached a Kessel landing through real menu input
with no browser errors. These are observed startup timings on an active desktop,
not a hardware-independent performance guarantee.

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
Mobile controls, PWA, cloud saves, and branch-protection changes remain outside
this milestone. Hosting is covered by the Vercel follow-up below.

## Vercel follow-up

The Vercel Hobby project and both projects' CI Node steps use Node 26.x. A staged
Farlanding deployment successfully retrieved the green `7d92b3e` CI artifact,
verified its archive digest and all nine release files, and served the full game
without a plan upgrade. The hosted browser smoke reached a Kessel landing with no
browser errors. It reproduced missing audio worklets on a protected deployment
until the automation bypass cookie was enabled; the corrected check passed.

Review also caught GitHub's one-minute artifact-redirect lifetime. Preparation now
stores only artifact identity and digest; the build resolves the URL immediately
before downloading with a job-scoped read-only token. Six deployment-tool tests
cover that handoff and rejection of incorrect/dirty/diagnostic/corrupt releases.
The revised download path also retrieved and verified the real nine-file artifact
locally. It does not forward authorization to the redirected storage host.

Production promotion is wired into CI after native/browser gates and the staged
hosted game check. A separate unauthenticated check verifies the stable production
domain after promotion. See [ADR 0020](adr/0020-vercel-ci-deployment.md) for the
artifact handoff, headers, credentials, and rollback constraints.
