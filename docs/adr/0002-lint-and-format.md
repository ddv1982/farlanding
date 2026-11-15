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

## Verification note (2026-11-15)

Only the explicitly stored warning overrides are project policy; engine defaults
supply other settings. The earlier list overstated the committed configuration:
`inference_on_variant` and `directory_rules` are engine defaults rather than explicit
overrides in this checkout. Verified through the running 4.7.2 editor: inference is
level 2 and directory rules are `{ "res://addons": 0 }`, matching the intended policy.
The script/resource load check and actual project settings remain the executable authority. Engine and GUT diagnostic classification is now shared
by local checks and exports; GUT warnings and deprecated APIs also fail checks.

## Editor warnings must reach CI (2026-11-15 follow-up)

A live-editor check exposed shadowing warnings despite clean headless runtime logs.
Fresh startup with all currently enabled warning categories promoted from Warn (1)
to Error (2) reproduced them. Runtime log-prefix scanning alone cannot enforce these
editor diagnostics. All enabled categories now use Error, while disabled categories
and the engine's addon exclusion stay as configured. `check_scripts.gd` refuses any
category left at Warn, or a globally disabled warning system, so later engine
upgrades cannot silently weaken this policy.

Fix local shadowing names, unused locals and static-call syntax; express intentional
integer truncation explicitly. Keep interface signal annotations narrowly scoped
and justified by their external emitters. Do not hide warnings with file-wide ignores.
