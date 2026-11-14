#!/usr/bin/env python3
"""Create or verify the identity and complete file inventory of a Web artifact."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def inventory(directory):
    return {str(path.relative_to(directory)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(directory.rglob('*'))
            if path.is_file() and path != directory / 'manifest.json'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--preset', default='Web')
    args = parser.parse_args()
    target = args.directory / 'manifest.json'
    files = inventory(args.directory)
    if args.verify:
        manifest = json.loads(target.read_text())
        if manifest['files'] != files:
            raise SystemExit('Web artifact file inventory or hash mismatch')
        print('Verified artifact', manifest['commit'], manifest['preset'], len(files), 'files')
    else:
        if not all(name in files for name in ('index.html', 'index.js', 'index.pck', 'index.wasm')):
            raise SystemExit('Incomplete Web export')
        commit = subprocess.check_output(
            ['git', 'rev-parse', 'HEAD'], text=True).strip()
        target.write_text(json.dumps({
            'commit': commit,
            'dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip()),
            'engine': '4.7.2.stable', 'preset': args.preset,
            'headers': {'Cross-Origin-Opener-Policy': 'same-origin',
                        'Cross-Origin-Embedder-Policy': 'require-corp'},
            'files': files,
        }, indent=2) + '\n')


if __name__ == '__main__':
    main()
