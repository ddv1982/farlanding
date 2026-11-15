# Project maintainability improvements

Baseline: `593b8a5`. The audit covered game code, test ownership, tooling, CI,
asset pipelines and architecture documentation. Preserve gameplay, save formats,
resource paths, rendering quality and the tested-artifact deployment pipeline.

## Phase 1: make diagnostics trustworthy

Dispose the Verdance test fixture explicitly, replace deprecated GUT frame waits
with their identical physics-frame successor, and reject GUT warnings and
deprecations alongside engine diagnostics. Share diagnostic classification between
checks and exports. Run Python tooling checks locally as well as in CI.
Proof: diagnostic fixtures, focused Verdance run and complete native checks.

## Phase 2: fix runtime defects before restructuring

Reproduce placement over blocking props, then include public map obstacles without
revealing unseen enemy buildings to AI. Validate malformed save containers and
resource types before replacing the running landing. Preserve legacy saves.
Proof: focused failing-before regressions, placement commands and save round trips.

## Phase 3: clarify responsibilities

Use the existing LandingMap contract in Main instead of reflective property access.
Split world restoration into named ordered phases without exposing its registries.
Separate one-shot playback pools from mission/music orchestration in Audio while
preserving its public API, randomness, voice budgets and shutdown behavior.
Proof: mission/pause/save tests, planetary round trips and real-mixer audio tests.

## Phase 4: maintain the boundaries

Document actual composition roots and scene composition, fixture/node/RID ownership,
and the current autoloads. Add inexpensive asset manifest and simulation dependency
checks. Clarify separate art rebuild pipelines and hand-tuned audio resource ownership.
Keep third-party addons unchanged and avoid bulk asset regeneration.

## Phase 5: qualify and release

Run complete native checks, every-mission smoke, browser gameplay/persistence and
real-mixer qualification. Measure any proposed performance optimization against the
same scenario; ship only justified changes with unchanged visual settings. Obtain an
independent Sol review, resolve CI/bot findings, merge normally and verify both staged
and public Vercel deployment of the exact merge commit.

Menu navigation includes direct title-screen loading with Back/Escape return paths.
The browser launcher retains a deliberate Play gesture for browser audio, uses the
field-equipment palette, and places clearly explained graphics overrides under Launch options.
The README play link is https://farlanding.app; verify that domain after release.

The favicon is a separate visual addition. Keep its source editable and include a
Godot-compatible raster icon; do not couple it to runtime architecture.

## Research basis

Godot recommends focused scenes/classes and parent-provided dependencies:
[Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html).
Its [project organization guidance](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)
supports consistent paths and isolated third-party addons, rather than gratuitous moves.
[Static typing](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
improves diagnostics and enables optimized operations. Ref's primary-source
[GDScript analyzer reference](https://github.com/godotengine/godot/blob/master/modules/gdscript/README.md)
explains the limits of dynamic access and the role of typed interfaces.

Do not rewrite the command queue, fixed-tick simulation, navigation cutter/traffic,
resource-driven definitions or platform rendering/audio adapters. A broad rewrite
would increase migration risk without an observed defect or measured benefit.

## Added gameplay slice: selling buildings

Add a tick-driven sell command and a selected-building action with refund preview
and confirmation. Completed placeable buildings return half their construction
cost; unfinished sites cancel for a full refund. Refund queued production through
the existing cancellation rule. Protect other factions, the Lander and story
machines. Prove single refunds, queue cleanup, immediate snapshot removal and
navigation/power/vent release, then verify the visible browser flow.

## Added exploration slice: remove advance discovery markers

Remove floating discovery question marks and unresolved-site minimap icons. Show
site models once their ground is explored, preserve scanning/rewards and chain
availability, and record only completed player surveys on the minimap. Update
onboarding and orbital-preview copy. ADR 0023 records this user-requested decision.
Proof: unknown versus explored visibility, enemy versus player map records, scan
feedback, saved vision, and browser screenshots on the actual maps.
