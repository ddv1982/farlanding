# Browser graphics qualification

The browser uses Godot 4.7.2 Compatibility/WebGL2, while the desktop editor uses
Forward+. The goal is a sharp picture with the same planet palette, readable
silhouettes and atmospheric effects. It is not pixel-identical HDR rendering.

## Profiles and persistence

| Profile | 3D resolution | MSAA | Shadow atlas | SSAO / glow |
| --- | --- | --- | --- | --- |
| High (fresh default) | 100% | 2× | 4096, soft | Authored |
| Balanced | 100% | Off | 2048 | Authored |
| Performance | 50% | Off | Off | Off |

The launcher can override saved graphics explicitly. Saved uses existing
preferences. Resolution and antialiasing are independently adjustable
in Settings; the preset selector reports Custom when they differ. The old Web
Low/50% default gets a one-time upgrade choice. Neither choice changes controls,
audio, accessibility, tutorial history or campaign progress.

Environments are local to scene instances, so visiting a Low menu cannot turn
off an environment's authored glow for a later High scene. Renderer preparation
happens before weather initialization, preserving storm interpolation baselines.
The browser keeps a full physical-pixel canvas while sizing the HUD in CSS pixels:
UI scale multiplies display pixel density, so Retina sharpness does not shrink
menus or controls. The saved UI preference remains 100/115/130%.

## Reproduce the evidence

Build release and diagnostic exports with `tools/export.sh Web WebDiagnostics`.
From `tools/web_tests`, use these commands on an otherwise idle hardware GPU:

```sh
WEB_VISUALS=1 npm test -- visual.spec.cjs
WEB_GRAPHICS_QUALIFY=1 npm test -- graphics.spec.cjs
WEB_PERFORMANCE=1 WEB_BENCH_QUALITY=high WEB_BENCH_MSAA=2 npm test -- performance.spec.cjs
WEB_PERFORMANCE=1 WEB_BENCH_QUALITY=high WEB_BENCH_MSAA=2 WEB_BENCH_NORMAL=1 npm test -- performance.spec.cjs
```

The battle is the seeded 233-unit encounter, with five seconds of warm-up and
120 seconds measured. The normal lane keeps the starting mission and camera,
without adding armies. `WEB_BENCH_SECONDS=30` is a short diagnostic, not a
replacement for the full measurement. `WEB_WIDTH`, `WEB_HEIGHT`, and `WEB_DPR`
control the browser viewport; attached reports record actual canvas/CSS sizes.
`WEB_SOFTWARE=1 WEB_GRAPHICS_PROFILE=low npm test` reproduces CI's correctness
profile. Performance tests record evidence rather than turning software GPU
timing into a hardware release gate.

For a native reference, launch the diagnostic scene directly, e.g.:

```sh
godot --path game --rendering-method forward_plus --resolution 1280x720 \
  res://tests/web/visual_compare.tscn -- --visual=conquest --visual-output=/tmp/native-conquest
```

Repeat with `gl_compatibility` and with `thalassa_recovery`, `emberfall_conquest`,
`verdance_conquest`, `hollow_power`. The comparison uses seed 1729, the authored
landing camera and starting crew, a paused simulation and fixed quality/scale.
Animated shaders and visual/audio effects remain real, so this is a visual
reference, not a byte-identical image test. Native output includes a PNG and
metadata; Web attaches PNGs and renderer/profile/viewport metadata. An additional
`orbit` reference uses the real Meridian backdrop with a fixed clean camera
composition, without campaign UI or route spoilers; this is the README ship image.

## Evidence and remaining limits

Before changing production defaults, five Forward+ and five native Compatibility
references plus ten browser Low/High references were captured. The old High/100%
AA-off 233-unit hardware baseline on Apple M4 / Chromium 159 / ANGLE Metal at
1280×720, DPR 1 produced frame p95 values of 34.06, 33.91 and 34.53 ms across
three 120-second runs. This already missed the strict 33.3 ms large-battle target.
Do not describe mean frame time as a p95 pass.

The first new High/100%/2× MSAA 120-second battle run measured mean 17.34 ms,
p95 26.00 ms and max 46.90 ms, with render-submit p95 8.65 ms and draw-call p95
2786. This is one observed device result, not a causal performance claim from the
lighting calibration or a guarantee for other hardware.

Three subsequent 120-second High runs on the same idle M4 / ANGLE Metal device
measured frame p95 values of **25.42, 26.11 and 27.04 ms**, all within the
33.3 ms large-battle budget. Means were 17.38–17.46 ms; maxima 55.48–77.80 ms.
The live starting-mission lane (no added armies, peak 26 units) measured mean
16.67 ms, p95 18.49 ms, max 45.13 ms and render-submit p95 2.55 ms over 120
seconds. The strict 16.7 ms p95 normal-play target is therefore still unmet;
the approximately 60 FPS mean is not a p95 pass. Neither lane certifies 1080p
or Retina performance; those sizes have visual/input checks only.

Qualification on the same M4 machine:

| Check | Observed result |
| --- | --- |
| Native gameplay / real-time mixer | 713 + 416 tests passed; all 11 mission smoke tests passed |
| Graphics UI regression | 13 tests, 68 assertions passed |
| Chromium hardware functional suite | 23 cases passed, including Retina menu input, legacy Keep / High and save recovery |
| Chromium software correctness profile | Performance gameplay and persistence checks passed; CI also covers Retina menu input |
| High visual references | Six each passed in Chromium 159, Firefox and Playwright WebKit |
| 1920×1080, DPR 1 | Actual 1920×1080 canvas, High / scale 1 / 2× MSAA |
| 1280×720, DPR 2 | Actual 2560×1440 canvas, High / scale 1 / 2× MSAA |
| Retina input qualification | Six menu layouts, movement, build/gather/produce/save and graphics migration passed at DPR 2 |
| Python build/deployment tooling | 13 tests passed |

The references include all five planets and the clean orbital composition. They
were inspected for sharp edges, palette, terrain readability, shadows, glow and
missing geometry. WebKit visual smoke is not a full Safari gameplay or hardware
performance certification. Native lighting remains authored Forward+; browser
LDR glow and tone response are deliberately calibrated approximations.

The palette atlas intentionally uses nearest filtering: faces sample swatch
centers. Increasing filtering or texture size cannot add authored surface detail.
The model inventory already has one static body plus named animated parts per
unit; blindly joining those parts breaks legs, wheels, turrets and fans. No
unmeasured batching or asset rewrite is included solely to lower draw calls.

Local evidence lives under the ignored `build/evidence/graphics/` directory.
CI attaches its export logs and browser evidence to the workflow run. Hardware
results are device-specific; they do not certify every integrated GPU or Safari.

## Primary references

- [Godot 4.7 renderer features](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html)
- [Environment and post-processing](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html)
- [Environment properties and Compatibility glow limitations](https://docs.godotengine.org/en/4.7/classes/class_environment.html)
- [Window content scaling](https://docs.godotengine.org/en/4.7/classes/class_window.html)
- [Web export limitations](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html)
