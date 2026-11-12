# 0001 — Unit-test framework: GUT 9.7.1

- Status: accepted
- Date: 2026-11-12

## Context

PLAN §3.7 asks for GUT or gdUnit4, whichever supports Godot 4.7 best, run headless in CI.

Checked on 2026-11-12:

- **GUT 9.7.0** (2026-06-19) lists "Compatibility changes for Godot 4.7" in its release notes,
  including changes for 4.7's stricter return-type checking of doubles. **9.7.1** (2026-07-10)
  is a bug-fix release on top. Release: https://github.com/bitwes/Gut/releases/tag/v9.7.1
- **gdUnit4 6.2.x** (latest 6.2.3, 2026-11-01) is actively maintained too. It was not
  evaluated in depth: GUT's release notes name 4.7 explicitly, GUT is a single GDScript addon
  with a simple headless CLI, and the PLAN lists it first.

Verified locally with Godot 4.7.2: the vendored GUT loads with our strict warning settings
(addons are excluded from warnings), runs headless via `gut_cmdln.gd`, and exits non-zero on a
failing test.

## Decision

Vendor GUT 9.7.1 unmodified into `game/addons/gut/` (from the `v9.7.1` tag tarball). Tests live
in `game/tests/`, files named `test_*.gd`, extending `GutTest`. Options are in
`game/.gutconfig.json`. CI and `tools/check.sh` run:

    godot --headless --path game -s res://addons/gut/gut_cmdln.gd

## Consequences

- GUT skips (with only a printed error) a test script that fails to parse. `tools/check.sh`
  therefore also fails on any `SCRIPT ERROR`/`ERROR` line, and `tests/check_scripts.gd` loads
  every project script before the tests run.
- Upgrading GUT means replacing `game/addons/gut/` wholesale and re-running `tools/check.sh`.
