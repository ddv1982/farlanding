import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from vercel_build import unpack

COMMIT = 'a' * 40
ROOT = Path(__file__).resolve().parent.parent


class VercelDeployTest(unittest.TestCase):
    def archive(self, directory, *, preset='Web', dirty=False, corrupt=False, extra=False):
        files = {name: name.encode() for name in ('index.html', 'index.js', 'index.wasm', 'index.pck')}
        manifest = {'commit': COMMIT, 'dirty': dirty, 'preset': preset,
                    'files': {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}}
        path = directory / 'release.zip'
        with zipfile.ZipFile(path, 'w') as archive:
            for name, data in files.items():
                archive.writestr('build/web/' + name, b'corrupt' if corrupt and name == 'index.pck' else data)
            archive.writestr('build/web/manifest.json', json.dumps(manifest))
            archive.writestr('tools/serve_web.py', 'not a public asset')
            if extra:
                archive.writestr('build/web/extra/manifest.json', '{}')
        return path, hashlib.sha256(path.read_bytes()).hexdigest()

    def test_only_verified_release_files_become_public(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            archive, digest = self.archive(directory)
            output = directory / 'public'
            output.mkdir()
            (output / 'stale.txt').write_text('old deployment')
            unpack(archive, output, digest, COMMIT)
            self.assertEqual({p.name for p in output.iterdir()},
                             {'index.html', 'index.js', 'index.wasm', 'index.pck', 'manifest.json'})
            self.assertEqual((output / 'index.pck').read_bytes(), b'index.pck')

    def test_bad_digest_wrong_commit_dirty_and_diagnostic_artifacts_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            for mode in ['archive', 'commit', 'dirty', 'diagnostic', 'file', 'extra']:
                with self.subTest(mode=mode):
                    archive, digest = self.archive(directory, preset='WebDiagnostics' if mode == 'diagnostic' else 'Web',
                                                   dirty=mode == 'dirty', corrupt=mode == 'file', extra=mode == 'extra')
                    with self.assertRaises(ValueError):
                        unpack(archive, directory / 'public', '0' * 64 if mode == 'archive' else digest,
                               'b' * 40 if mode == 'commit' else COMMIT)
                    self.assertFalse((directory / 'public').exists())

    def test_archive_cannot_write_outside_the_bundle(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            archive, _ = self.archive(directory)
            with zipfile.ZipFile(archive, 'a') as zipped:
                zipped.writestr('build/web/../../escape', 'bad')
            digest = hashlib.sha256(archive.read_bytes()).hexdigest()
            with self.assertRaisesRegex(ValueError, 'Invalid artifact path'):
                unpack(archive, directory / 'public', digest, COMMIT)
            self.assertFalse((directory / 'escape').exists())

    def test_vercel_headers_support_threads_and_wasm(self):
        config = json.loads((ROOT / 'vercel.json').read_text())
        self.assertFalse(config['git']['deploymentEnabled'])
        headers = {h['key']: h['value'] for h in config['headers'][0]['headers']}
        self.assertEqual(headers['Cross-Origin-Opener-Policy'], 'same-origin')
        self.assertEqual(headers['Cross-Origin-Embedder-Policy'], 'require-corp')
        self.assertEqual(config['headers'][1]['headers'][0]['value'], 'application/wasm')


if __name__ == '__main__':
    unittest.main()
