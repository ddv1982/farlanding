"""Print plain Godot logs and reject engine/GUT diagnostics, even after exit 0."""

import argparse
from pathlib import Path
import re

ANSI = re.compile(r'\x1b\[[0-9;]*m')
DIAGNOSTIC = re.compile(
    r'^\s*(?:SCRIPT ERROR|ERROR|WARNING|USER ERROR|USER WARNING|'
    r'\[GUT WARNING\]|\[GUT ERROR\]|\[DEPRECATED\]):', re.MULTILINE
)
# Editor-plugin version lookup is external and rate-limited on shared runners.
IMPORT_NOISE = 'ERROR: [GUT] Could not get version info'


def failures(log: str, allow_import_noise: bool = False) -> list[str]:
    plain = ANSI.sub('', log)
    return [line for line in plain.splitlines()
            if DIAGNOSTIC.match(line)
            and not (allow_import_noise and line == IMPORT_NOISE)]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log', type=Path)
    parser.add_argument('--allow-import-noise', action='store_true')
    args = parser.parse_args()
    plain = ANSI.sub('', args.log.read_text(errors='replace'))
    args.log.with_suffix(args.log.suffix + '.txt').write_text(plain)
    print(plain, end='')
    return int(bool(failures(plain, args.allow_import_noise)))


if __name__ == '__main__':
    raise SystemExit(main())
