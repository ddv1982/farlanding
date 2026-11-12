#!/usr/bin/env bash
# Runs every local/CI check in order: format, lint, import, script errors, tests,
# boot smoke test. Exits non-zero on the first failure. Works on macOS and Linux.
#
# Env: GODOT (default: godot), GDTOOLKIT_VERSION (default: 4.5.0),
#      CHECK_TIMEOUT seconds per Godot step (default: 300).
set -euo pipefail

GODOT="${GODOT:-godot}"
GDTOOLKIT_VERSION="${GDTOOLKIT_VERSION:-4.5.0}"
CHECK_TIMEOUT="${CHECK_TIMEOUT:-300}"

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
	# Strip ANSI colours so the output and the grep are plain text.
	sed -e $'s/\x1b\\[[0-9;]*m//g' "$log" >"$log.txt"
	cat "$log.txt"
	if [ "$status" -ne 0 ]; then
		fail "$name: godot exited with status $status"
	fi
	if grep -E '^(SCRIPT ERROR|ERROR|WARNING|USER ERROR|USER WARNING):' "$log.txt" >/dev/null; then
		fail "$name: engine reported errors or warnings (see above)"
	fi
}

command -v "$GODOT" >/dev/null || fail "Godot binary '$GODOT' not found (set GODOT=...)"
command -v uvx >/dev/null || fail "uvx not found (install uv: https://docs.astral.sh/uv/)"
command -v perl >/dev/null || fail "perl not found"

step "Format check (gdformat $GDTOOLKIT_VERSION)"
gdtoolkit gdformat --check . || fail "format (run: cd game && uvx --from gdtoolkit==$GDTOOLKIT_VERSION gdformat .)"

step "Lint (gdlint $GDTOOLKIT_VERSION)"
gdtoolkit gdlint . || fail "lint"

step "Headless import"
run_godot import --import

step "Script error check"
run_godot check_scripts -s res://tests/check_scripts.gd

step "Unit tests (GUT)"
run_godot tests -s res://addons/gut/gut_cmdln.gd

step "Boot smoke test (main scene)"
run_godot boot --quit-after 30

printf '\nAll checks passed.\n'
