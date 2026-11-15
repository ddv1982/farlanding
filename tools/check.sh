#!/usr/bin/env bash
# Runs every local/CI check in order: format, lint, import, script errors, tests,
# boot and mission smoke tests. Exits non-zero on the first failure. Works on macOS
# and Linux.
#
# Env: GODOT (default: godot), GDTOOLKIT_VERSION (default: 4.5.0),
#      CHECK_TIMEOUT seconds per Godot step (default: 600).
set -euo pipefail

GODOT="${GODOT:-godot}"
GDTOOLKIT_VERSION="${GDTOOLKIT_VERSION:-4.5.0}"
CHECK_TIMEOUT="${CHECK_TIMEOUT:-600}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME="$ROOT/game"
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

step() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nFAILED: %s\n' "$*" >&2; exit 1; }

# Portable timeout (GNU `timeout` is not on stock macOS). Godot can hang after an
# internal script error, so every Godot step is bounded.
with_timeout() { perl -e 'alarm shift; exec @ARGV or die "exec: $!"' "$CHECK_TIMEOUT" "$@"; }

gdtoolkit() {
	# gdtoolkit reads gdlintrc/gdformatrc from the cwd; they exclude addons/.
	(cd "$GAME" && uvx --quiet --python 3.12 --from "gdtoolkit==$GDTOOLKIT_VERSION" "$@")
}

# Runs Godot headless, shows its output, and fails on a non-zero exit or on any
# engine error/warning line in the output (Godot often exits 0 after an error).
run_godot() {
	local name="$1"
	shift
	local log="$LOG_DIR/$name.log"
	local status=0
	with_timeout "$GODOT" --headless --path "$GAME" "$@" >"$log" 2>&1 || status=$?
	local diagnostic_status=0
	if [ "$name" = import ]; then
		python3 "$ROOT/tools/godot_diagnostics.py" "$log" --allow-import-noise || diagnostic_status=$?
	else
		python3 "$ROOT/tools/godot_diagnostics.py" "$log" || diagnostic_status=$?
	fi
	[ "$status" -eq 0 ] || fail "$name: godot exited with status $status"
	[ "$diagnostic_status" -eq 0 ] || fail "$name: engine or GUT reported diagnostics (see above)"
}

command -v "$GODOT" >/dev/null || fail "Godot binary '$GODOT' not found (set GODOT=...)"
command -v uvx >/dev/null || fail "uvx not found (install uv: https://docs.astral.sh/uv/)"
command -v perl >/dev/null || fail "perl not found"

step "Python tooling tests and project integrity"
python3 -m unittest discover -s "$ROOT/tools" -p 'test_*.py'
python3 "$ROOT/tools/project_integrity.py"

step "Format check (gdformat $GDTOOLKIT_VERSION)"
gdtoolkit gdformat --check . || fail "format (run: cd game && uvx --from gdtoolkit==$GDTOOLKIT_VERSION gdformat .)"

step "Lint (gdlint $GDTOOLKIT_VERSION)"
gdtoolkit gdlint . || fail "lint"

step "Headless import"
python3 "$ROOT/tools/prepare_import.py"
run_godot import --import

step "Script error check"
run_godot check_scripts -s res://tests/check_scripts.gd

# Most tests only wait on frames and physics frames, so they run without real-time
# frame sync (--fixed-fps: every frame is 1/60 s of game time, drawn as fast as the
# machine allows), about four times faster. The audio tests listen to the real mixer,
# which needs wall-clock time, so they run on their own (ADR 0018).
GUT_ARGS=(-s res://addons/gut/gut_cmdln.gd -gconfig= -gexit -glog=1)
GUT_FAST="$(cd "$GAME" && find tests -name 'test_*.gd' -not -path 'tests/audio/*' | sort | sed 's|^|res://|' | paste -sd, -)"

step "Unit tests (GUT, simulated time: all but audio)"
run_godot tests --fixed-fps 60 "${GUT_ARGS[@]}" -gtest="$GUT_FAST"

step "Unit tests (GUT, real time: audio)"
run_godot tests_audio "${GUT_ARGS[@]}" -gdir=res://tests/audio -ginclude_subdirs -gprefix=test_ -gsuffix=.gd

step "Boot smoke test (main scene)"
run_godot boot --quit-after 30

step "Mission smoke test (every mission on its real map)"
run_godot mission_smoke res://tests/smoke/mission_smoke.tscn

printf '\nAll checks passed.\n'
