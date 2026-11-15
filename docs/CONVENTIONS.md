# Conventions

Short rules for everyone writing code in `game/`. The why lives in `docs/PLAN.md` §3.

## Before you push

Run `tools/check.sh`. It runs format check, lint, headless import, a script-error check, the
unit tests, every-mission smoke, Python tooling tests and source/asset integrity checks.
It must exit 0. CI runs the same script. Engine and GUT warnings/deprecations fail the gate.

- Format: `cd game && uvx --from gdtoolkit==4.5.0 gdformat .`
- Tests: `godot --headless --path game -s res://addons/gut/gut_cmdln.gd`

## GDScript

- Follow the official GDScript style guide; `gdformat` decides layout.
- **Static types everywhere.** Untyped declarations and unsafe access/calls/casts are errors
  (set in `project.godot`). Give every variable, parameter and return a type. To use a
  `Variant` (e.g. a dictionary value), assign it to a typed local first:
  `var tick: int = data["tick"]`.
- `class_name` on every script, except autoload scripts (the autoload name is their global
  name) and test scripts.
- Files and folders `snake_case`. A scene and its script sit side by side with the same name.
- Signals are named in the past tense: `unit_died`, `selection_changed`.
- Private members start with `_`. Doc comments use `##`.
- No string node paths across scene boundaries. Use exported references or groups.

## Dependencies point one way

    core  <-  sim  <-  ai / missions  <-  presentation / ui / audio

Simulation **scripts** must not depend on UI, audio or presentation scripts;
`tools/project_integrity.py` checks adapter class/path references. Simulation emits typed
signals on `Events` (or its own nodes), and adapters listen. Entity **scenes** may compose
simulation and visual children. `Main` and `LandingMap` are composition roots: they wire
the layers and provide dependencies before children enter the tree. Scene composition
does not imply that simulation code may call its visual children.

## Architecture rules in practice

- **Every order is a `Command`** pushed into the mission's `CommandQueue`; it executes on the
  next sim tick. Player input, enemy AI and mission scripts all use this one path.
- **Gameplay runs on `SimClock` ticks (10 Hz)**, not in `_process`. Visuals interpolate with
  `SimClock.get_interpolation_fraction()`.
- **Mission-scoped things hang off `MissionContext`**, never an autoload. Autoloads are only
  `Events`, `Game`, `Settings`, `Audio` and `UiTheme`; the editor integration also
  installs `MCPRuntimeProbe` (disabled by release feature, see the Web runtime ADR).
  `SaveSlots` is a static service, not an autoload.
- **Definitions are data**: new unit types are new `UnitDef` `.tres` files, not new code.
- **Composition over inheritance**: an entity is a thin root plus component nodes.
- **Saveable from day one**: any class that holds gameplay state has `to_dict()` /
  `from_dict()` and a `SAVE_VERSION` constant written into the dictionary.

## Units and names

- 1 Godot unit = 1 metre. Speeds per second, angles in degrees in data files.
- Asset names: `<faction>_<kind>_<name>`, e.g. `concord_unit_ranger.glb`.

## Tests

- GUT tests live in `game/tests/`, named `test_<thing>.gd`, extending `GutTest`.
- Drive time by hand in tests (`SimClock.advance()`), not by waiting real frames.
- New core behaviour comes with a test.

## Repository

- Commit `*.import` and `*.uid` files; never commit `.godot/`.
- Binaries go through Git LFS once it is enabled (see `.gitattributes`).
- Record expensive-to-reverse choices as a short ADR in `docs/adr/`.

## Ownership and cleanup

- A scene owns its child nodes. Configure dependencies before `add_child()`, which runs `_ready()`.
- A RefCounted fixture does not own nodes it attaches elsewhere: retain the fixture and call
  its `dispose()` in `after_each`. Use GUT's autofree helpers only when they actually register ownership.
- A service that creates server RIDs releases them explicitly (`PathService.release()`).
  Keep cleanup with the owner, including navigation, traffic registration and shader globals.
- Restore snapshots in dependency order: identities before references, planetary conditions
  before path-dependent orders. Preserve the save version unless the serialized shape changes.
- Audio source recipes own generated streams and import sidecars; existing SoundEvents own
  hand-tuned mix values. `project_integrity.py` checks hashes/inventory without regenerating audio.
  Recipe edits also need the deterministic `audio_src/build.py --check` command documented in
  `docs/AUDIO_PROVENANCE.md`; encoder versions can affect output hashes.
