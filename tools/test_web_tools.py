import importlib.util
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('serve_web', ROOT / 'tools/serve_web.py')
server_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server_module)


class WebToolsTest(unittest.TestCase):
    def test_importer_fingerprint_invalidates_stale_models_only(self):
        import_spec = importlib.util.spec_from_file_location('prepare_import', ROOT / 'tools/prepare_import.py')
        importer_module = importlib.util.module_from_spec(import_spec)
        import_spec.loader.exec_module(importer_module)
        with tempfile.TemporaryDirectory() as temporary:
            game = Path(temporary)
            source = game / 'presentation/import/model_post_import.gd'
            source.parent.mkdir(parents=True)
            source.write_text('first importer')
            settings = game / 'assets/models/terrain.glb.import'
            settings.parent.mkdir(parents=True)
            settings.write_text('path="res://.godot/imported/terrain.scn"\nimport_script/path="res://presentation/import/model_post_import.gd"\n')
            output = game / '.godot/imported/terrain.scn'
            output.parent.mkdir(parents=True)
            output.write_bytes(b'stale')
            self.assertEqual(importer_module.prepare(game), 1)
            self.assertFalse(output.exists())
            output.write_bytes(b'fresh')
            self.assertEqual(importer_module.prepare(game), 0)
            self.assertEqual(output.read_bytes(), b'fresh')
            source.write_text('changed importer')
            self.assertEqual(importer_module.prepare(game), 1)


    def test_manifest_detects_changed_missing_and_unexpected_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            bundle = Path(temporary)
            for name in ('index.html', 'index.js', 'index.pck', 'index.wasm'):
                (bundle / name).write_bytes(b'original')
            command = ['python3', str(ROOT / 'tools/web_manifest.py'), str(bundle)]
            subprocess.run(command, check=True)
            subprocess.run(command + ['--verify'], check=True)
            for mode in ('changed', 'missing', 'extra'):
                with self.subTest(mode=mode):
                    if mode == 'changed':
                        (bundle / 'index.wasm').write_bytes(b'corrupt')
                    elif mode == 'missing':
                        (bundle / 'index.wasm').unlink()
                    else:
                        (bundle / 'index.wasm').write_bytes(b'original')
                        (bundle / 'unexpected').write_bytes(b'new')
                    result = subprocess.run(command + ['--verify'], capture_output=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(b'mismatch', result.stderr)

    def test_installer_rejects_corrupt_download(self):
        with tempfile.TemporaryDirectory() as temporary:
            curl = Path(temporary) / 'curl'
            curl.write_text("#!/bin/sh\nwhile [ \"$1\" != \"-o\" ]; do shift; done\nshift\nprintf corrupt > \"$1\"\n")
            curl.chmod(0o755)
            environment = {**os.environ, 'PATH': temporary + os.pathsep + os.environ['PATH']}
            result = subprocess.run(['bash', str(ROOT / 'tools/install_godot_templates.sh')],
                                    env=environment, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b'SHA-512 mismatch', result.stderr)

    def test_export_rejects_zero_exit_with_script_errors(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'tools').mkdir()
            shutil.copy(ROOT / 'tools/export.sh', root / 'tools/export.sh')
            shutil.copy(ROOT / 'tools/prepare_import.py', root / 'tools/prepare_import.py')
            importer = root / 'game/presentation/import/model_post_import.gd'
            importer.parent.mkdir(parents=True)
            importer.write_text('importer')
            godot = root / 'godot'
            godot.write_text('#!/bin/sh\nif [ "$1" = "--version" ]; then echo 4.7.2.stable.test; elif [ "$4" = "--import" ]; then exit 0; else echo "SCRIPT ERROR: simulated export failure"; fi\n')
            godot.chmod(0o755)
            result = subprocess.run(['bash', str(root / 'tools/export.sh'), 'Web'],
                                    env={**os.environ, 'GODOT': str(godot)}, capture_output=True)
            if b'are not installed' in result.stderr:
                self.skipTest('Install Web export templates to test the export boundary')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b'reported errors or warnings', result.stderr)
            self.assertIn(b'SCRIPT ERROR', (root / 'build/logs/export-Web.log.txt').read_bytes())

    def test_server_headers_and_wasm_type(self):
        from functools import partial
        with tempfile.TemporaryDirectory() as temporary:
            (Path(temporary) / 'index.wasm').write_bytes(b'wasm')
            handler = partial(server_module.WebHandler, directory=temporary)
            with server_module.LoopbackServer(('127.0.0.1', 0), handler) as server:
                thread = threading.Thread(target=server.serve_forever)
                thread.start()
                try:
                    with urlopen(f'http://127.0.0.1:{server.server_port}/index.wasm') as response:
                        self.assertEqual(response.headers['Content-Type'], 'application/wasm')
                        self.assertEqual(response.headers['Cross-Origin-Opener-Policy'], 'same-origin')
                        self.assertEqual(response.headers['Cross-Origin-Embedder-Policy'], 'require-corp')
                finally:
                    server.shutdown()
                    thread.join()


if __name__ == '__main__':
    unittest.main()
