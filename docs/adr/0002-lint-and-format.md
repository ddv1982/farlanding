# 0002 — Lint and format: gdtoolkit 4.5.0, plus Godot's own checks

- Status: accepted
- Date: 2026-11-12

## Context

PLAN §3.7 asks for gdtoolkit (`gdformat`, `gdlint`) in CI. gdtoolkit's latest release is
4.5.0; there is no 4.7-specific release. We need to know whether it parses the GDScript 4.7
syntax we write.

Checked against the Phase 0 code: typed loop variables (`for x: int in ...`), typed
dictionaries (`Dictionary[StringName, State]`), `@warning_ignore_start/_restore`, inner classes,
lambdas, static functions, typed default arguments. gdtoolkit 4.5.0 parses, formats and lints
all of it.

## Decision

- Pin `gdtoolkit==4.5.0`, run through `uvx --python 3.12` (no project Python environment).
- Config files `game/gdlintrc` and `game/gdformatrc`: defaults, line length 100, tabs,
  `addons/` and `.godot/` excluded. gdtoolkit only finds these files in its working directory,
  so it is always run from `game/` (`tools/check.sh` does this).
- gdlint cannot check types. Type strictness comes from Godot itself: in `project.godot`,
  `untyped_declaration`, all `unsafe_*` warnings, `inference_on_variant`, `narrowing_conversion`,
  `incompatible_ternary` and `int_as_enum_without_cast` are errors (level 2).
  `debug/gdscript/warnings/directory_rules` keeps `res://addons` excluded (4.7 replaced the old
  `exclude_addons` flag with this; 0 = exclude).
- `godot --check-only` is not used: in 4.7.2 it does not load autoloads (false errors) and exits
  0 even on parse errors. `game/tests/check_scripts.gd` loads every script and scene instead.

## Consequences

If a future GDScript feature is not parsed by gdtoolkit, either avoid it or exclude that file in
`gdlintrc`/`gdformatrc` and note it here.
