import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from project_integrity import check_audio, check_sim_dependencies


class ProjectIntegrityTest(unittest.TestCase):
    def test_audio_inventory_and_hashes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'audio_src').mkdir()
            audio = root / 'game/assets/audio/a.mp3'
            audio.parent.mkdir(parents=True)
            audio.write_bytes(b'original')
            Path(str(audio) + '.import').touch()
            entry = {'id': 'a', 'file': 'game/assets/audio/a.mp3',
                     'sha256': hashlib.sha256(b'original').hexdigest()}
            manifest = root / 'audio_src/manifest.json'
            manifest.write_text(json.dumps({'sounds': [entry]}))
            self.assertEqual(check_audio(root), [])
            audio.write_bytes(b'changed')
            self.assertIn('hash mismatch', ' '.join(check_audio(root)))
            audio.unlink()
            self.assertIn('missing audio:', ' '.join(check_audio(root)))
            audio.write_bytes(b'original')
            audio.with_name('extra.ogg').touch()
            self.assertIn('untracked generated audio', ' '.join(check_audio(root)))
            manifest.write_text(json.dumps({'sounds': [entry, entry]}))
            self.assertIn('duplicate', ' '.join(check_audio(root)))

    def test_script_boundary_allows_scene_composition(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for layer in ('sim', 'presentation'):
                (root / 'game' / layer).mkdir(parents=True)
            (root / 'game/presentation/visual.gd').write_text('class_name Visual\nextends Node\n')
            script = root / 'game/sim/unit.gd'
            script.write_text('extends Node\n# Visuals listen to events.\n')
            (root / 'game/sim/unit.tscn').write_text('res://presentation/visual.gd')
            self.assertEqual(check_sim_dependencies(root), [])
            script.write_text('Audio.play(&"click")\n')
            self.assertEqual(len(check_sim_dependencies(root)), 1)
            script.write_text('var visual: Visual\n')
            self.assertEqual(len(check_sim_dependencies(root)), 1)
            script.write_text('const SCRIPT = preload("res://presentation/visual.gd")\n')
            self.assertEqual(len(check_sim_dependencies(root)), 1)
