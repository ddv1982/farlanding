#!/usr/bin/env python3
"""Vercel build: unpack the verified GitHub CI release, never rebuild the game."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import tempfile
from urllib.request import urlopen
import zipfile


def file_digest(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def unpack(archive, output, expected_digest, expected_commit):
    if file_digest(archive) != expected_digest:
        raise ValueError('CI artifact archive hash mismatch')
    with tempfile.TemporaryDirectory() as temporary:
        bundle = Path(temporary)
        with zipfile.ZipFile(archive) as zipped:
            for item in zipped.infolist():
                path = PurePosixPath(item.filename)
                if path.is_absolute() or '..' in path.parts:
                    raise ValueError('Invalid artifact path')
                if path.parts[:2] != ('build', 'web') or item.is_dir():
                    continue
                target = bundle.joinpath(*path.parts[2:])
                target.parent.mkdir(parents=True, exist_ok=True)
                with zipped.open(item) as source, target.open('wb') as dest:
                    shutil.copyfileobj(source, dest)
        manifest = json.loads((bundle / 'manifest.json').read_text())
        if (manifest['commit'] != expected_commit or manifest['dirty']
                or manifest['preset'] != 'Web'):
            raise ValueError('Artifact is not the clean release for this commit')
        actual = {str(path.relative_to(bundle)): file_digest(path)
                  for path in bundle.rglob('*') if path.is_file() and path != bundle / 'manifest.json'}
        if actual != manifest['files']:
            raise ValueError('Web release file inventory or hash mismatch')
        if not {'index.html', 'index.js', 'index.wasm', 'index.pck'} <= actual.keys():
            raise ValueError('Incomplete Web release')
        if output.exists():
            shutil.rmtree(output)
        shutil.copytree(bundle, output)
        print(f'Prepared tested release {expected_commit}: {len(actual)} verified files')


def main():
    config = json.loads(Path('artifact.json').read_text())
    if not config['url'].startswith('https://'):
        raise ValueError('Artifact download must use HTTPS')
    with tempfile.TemporaryDirectory() as temporary:
        archive = Path(temporary) / 'release.zip'
        with urlopen(config['url'], timeout=180) as response, archive.open('wb') as dest:
            shutil.copyfileobj(response, dest)
        unpack(archive, Path('public'), config['sha256'], config['commit'])


if __name__ == '__main__':
    main()
