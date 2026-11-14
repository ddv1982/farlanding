#!/usr/bin/env bash
set -euo pipefail
version=4.7.2
checksum=ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079
case "$(uname -s)" in
  Darwin) destination="$HOME/Library/Application Support/Godot/export_templates/$version.stable" ;;
  Linux) destination="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version.stable" ;;
  *) printf 'Unsupported template installer platform\n' >&2; exit 1 ;;
esac
archive="$(mktemp)"
trap 'rm -f "$archive"' EXIT
curl --fail --location --retry 3 --connect-timeout 30 --max-time 900 \
  "https://github.com/godotengine/godot/releases/download/$version-stable/Godot_v$version-stable_export_templates.tpz" -o "$archive"
python3 - "$archive" "$destination" "$checksum" <<'PY'
import hashlib
import pathlib
import sys
import zipfile
archive, destination, expected = sys.argv[1:]
with open(archive, 'rb') as source:
    actual = hashlib.file_digest(source, 'sha512').hexdigest()
if actual != expected:
    raise SystemExit('Export template SHA-512 mismatch')
destination = pathlib.Path(destination)
destination.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(archive) as bundle:
    for name in ('version.txt', 'web_release.zip', 'web_nothreads_release.zip'):
        (destination / name).write_bytes(bundle.read('templates/' + name))
print('Verified Godot 4.7.2 Web templates installed in', destination)
PY
