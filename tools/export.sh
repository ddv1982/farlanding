#!/usr/bin/env bash
# Builds release exports for macOS, Windows and Linux into build/ (git-ignored),
# from the presets in game/export_presets.cfg. Needs the Godot export templates of
# exactly the engine version in use; this script never downloads them.
#
# Usage: tools/export.sh [macOS|Windows|Linux|Web ...]   (default: all three)
# Env:   GODOT (default: godot)
set -euo pipefail

GODOT="${GODOT:-godot}"
REQUIRED_VERSION="4.7.2.stable"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME="$ROOT/game"
BUILD="$ROOT/build"

fail() { printf '\nFAILED: %s\n' "$*" >&2; exit 1; }

command -v "$GODOT" >/dev/null || fail "Godot binary '$GODOT' not found (set GODOT=...)"

# "4.7.2.stable.official.ed1daf0bf" -> "4.7.2.stable"
version="$("$GODOT" --version 2>/dev/null | head -n 1 | cut -d. -f1-4)"
if [ "$version" != "$REQUIRED_VERSION" ]; then
	fail "Godot $REQUIRED_VERSION is required, '$GODOT' is '$version'."
fi

case "$(uname -s)" in
	Darwin) templates="$HOME/Library/Application Support/Godot/export_templates/$REQUIRED_VERSION" ;;
	Linux) templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$REQUIRED_VERSION" ;;
	*) templates="${APPDATA:-}/Godot/export_templates/$REQUIRED_VERSION" ;;
esac
if [ ! -d "$templates" ]; then
	fail "Godot export templates $REQUIRED_VERSION are not installed (looked in '$templates').
Install them from the Godot editor (Editor > Manage Export Templates) or unpack
Godot_v4.7.2-stable_export_templates.tpz from godotengine.org into that folder,
then run this script again."
fi

presets=("$@")
if [ "${#presets[@]}" -eq 0 ]; then
	presets=(macOS Windows Linux)
fi

python3 "$ROOT/tools/prepare_import.py"
mkdir -p "$BUILD/logs"
import_log="$BUILD/logs/export-import.log"
status=0
perl -e 'alarm shift; exec @ARGV or die "exec: $!"' "${EXPORT_TIMEOUT:-1800}" \
	"$GODOT" --headless --path "$GAME" --import >"$import_log" 2>&1 || status=$?
diagnostic_status=0
python3 "$ROOT/tools/godot_diagnostics.py" "$import_log" --allow-import-noise || diagnostic_status=$?
[ "$status" -eq 0 ] || fail "export import failed (status $status; $import_log)"
[ "$diagnostic_status" -eq 0 ] || fail "export import reported errors or warnings ($import_log)"

for preset in "${presets[@]}"; do
	case "$preset" in
		macOS) out="$BUILD/macos/Farlanding.zip" ;;
		Windows) out="$BUILD/windows/Farlanding.exe" ;;
		Linux) out="$BUILD/linux/Farlanding.x86_64" ;;
		Web) out="$BUILD/web/index.html" ;;
		WebDiagnostics) out="$BUILD/web-diagnostics/index.html" ;;
		*) fail "unknown preset '$preset' (macOS, Windows, Linux or Web)" ;;
	esac
	if [[ "$preset" == Web* ]]; then
		rm -rf "$(dirname "$out")"
	fi
	mkdir -p "$(dirname "$out")" "$BUILD/logs"
	log="$BUILD/logs/export-$preset.log"
	printf '\n==> Exporting %s to %s\n' "$preset" "${out#"$ROOT"/}"
	status=0
	perl -e 'alarm shift; exec @ARGV or die "exec: $!"' "${EXPORT_TIMEOUT:-1800}" \
		"$GODOT" --headless --path "$GAME" --export-release "$preset" "$out" >"$log" 2>&1 || status=$?
	diagnostic_status=0
	python3 "$ROOT/tools/godot_diagnostics.py" "$log" || diagnostic_status=$?
	[ "$status" -eq 0 ] || fail "export of $preset failed (status $status; $log)"
	[ "$diagnostic_status" -eq 0 ] || fail "export of $preset reported errors or warnings ($log)"
	[ -e "$out" ] || fail "export of $preset produced no $out"
	if [[ "$preset" == Web* ]]; then
		# Favicon caches can retain an old image even after the page revalidates.
		# Version the exported links by content before hashing the release manifest.
		python3 - "$out" <<'PY'
import hashlib
from pathlib import Path
import sys

page = Path(sys.argv[1])
html = page.read_text()
for name in ("index.icon.png", "index.apple-touch-icon.png"):
    version = hashlib.sha256((page.parent / name).read_bytes()).hexdigest()[:16]
    original = f'href="{name}"'
    if html.count(original) != 1:
        raise ValueError(f"Expected one exported icon link: {name}")
    html = html.replace(original, f'href="{name}?v={version}"')
page.write_text(html)
PY
		python3 "$ROOT/tools/web_manifest.py" "$(dirname "$out")" --preset "$preset"
	fi
done

printf '\nExports are in %s\n' "$BUILD"
