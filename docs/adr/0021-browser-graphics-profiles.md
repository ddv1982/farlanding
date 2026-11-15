# 0021 — Browser graphics profiles and renderer calibration

Status: accepted

## Context

Fresh Web profiles previously selected Low and 50% 3D resolution to accommodate
software-rendered CI. This removed shadows/glow and rendered only a quarter of
the pixels. The resulting picture did not represent the game's authored look.
WebGL2 Compatibility also shades differently from desktop Forward+.

## Decision

Use authored `GraphicsProfile` resources for High (100%, 2× MSAA, 4096 shadows,
SSAO/glow), Balanced (100%, no MSAA, 2048 shadows, SSAO/glow), and Performance
(50%, no MSAA/shadows/SSAO/glow). High is the fresh-profile default. Resolution
and MSAA can be customized independently. Simulation and audio are unaffected.

On Web, multiply the saved UI scale by display pixel density so HUD dimensions
follow CSS pixels while the 3D canvas retains its physical resolution. Reconcile
this runtime scale when the window size changes, without writing preferences.

CI selects Performance through the same launcher as a player. It proves
correctness on software WebGL2, not hardware performance or High visual quality.
Hardware qualification records physical canvas size, DPR, browser and renderer.

Preserve existing preferences. Old Web Low/50% files cannot reliably distinguish
an automatic downgrade from an intentional choice, so offer Keep Current or Use
High once. A version stamp records the decision without resetting progress,
controls, audio or accessibility settings. Existing files without MSAA retain Off.

Prepare scene-local environments before weather caches their baselines. On
Compatibility, calibrate direct/ambient lighting against fixed-camera Forward+
references, lower the glow threshold for LDR highlights, preserve overbright
emission hues, and mix fog-of-war colors in linear space. Forward+ retains its
authored lighting and emission. Visibility still comes from the same vision map.

## Consequences

High costs more GPU time and is not a universal frame-rate guarantee. Players
can select Performance before launch. Web still uses Compatibility/WebGL2;
Forward+ HDR, volumetrics and temporal AA cannot be promised in the browser.
Diagnostic reference scenes and benchmarks stay excluded from release exports.
Measurements and limitations are recorded in [WEB_GRAPHICS.md](../WEB_GRAPHICS.md).
