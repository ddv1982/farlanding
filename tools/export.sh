#!/usr/bin/env bash
# Builds release exports for macOS, Windows and Linux into build/ (git-ignored),
# from the presets in game/export_presets.cfg. Needs the Godot export templates of
# exactly the engine version in use; this script never downloads them.
#
# Usage: tools/export.sh [macOS|Windows|Linux ...]   (default: all three)
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

for preset in "${presets[@]}"; do
	case "$preset" in
		macOS) out="$BUILD/macos/Farlanding.zip" ;;
		Windows) out="$BUILD/windows/Farlanding.exe" ;;
		Linux) out="$BUILD/linux/Farlanding.x86_64" ;;
		*) fail "unknown preset '$preset' (macOS, Windows or Linux)" ;;
	esac
	mkdir -p "$(dirname "$out")"
	printf '\n==> Exporting %s to %s\n' "$preset" "${out#"$ROOT"/}"
	"$GODOT" --headless --path "$GAME" --export-release "$preset" "$out" \
		|| fail "export of $preset failed"
	[ -e "$out" ] || fail "export of $preset produced no $out"
done

printf '\nExports are in %s\n' "$BUILD"
