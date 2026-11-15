"""Exercise the compiler-policy gate in a fresh, minimal Godot process."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
GODOT = shutil.which(os.environ.get('GODOT', 'godot'))


@unittest.skipUnless(GODOT, 'Godot is required for compiler-policy boundary checks')
class WarningPolicyTest(unittest.TestCase):
    def run_policy(self, override=None):
        project = (ROOT / 'game/project.godot').read_text()
        debug = project.split('[debug]\n', 1)[1].split('\n[', 1)[0]
        if override:
            key, value = override
            lines = [line for line in debug.splitlines() if not line.startswith(key + '=')]
            debug = '\n'.join(lines) + f'\n{key}={value}\n'
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'project.godot').write_text('config_version=5\n\n[debug]\n' + debug)
            shutil.copy(ROOT / 'game/tests/check_scripts.gd', root / 'check_scripts.gd')
            return subprocess.run(
                [GODOT, '--headless', '--audio-driver', 'Dummy', '--path', str(root),
                 '--script', 'res://check_scripts.gd'],
                capture_output=True, text=True, timeout=30,
            )

    def test_committed_policy_passes_in_a_fresh_process(self):
        result = self.run_policy()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('1 files checked, 0 failed', result.stdout)

    def test_warning_level_cannot_silently_drop_back_to_warn(self):
        result = self.run_policy(('gdscript/warnings/unused_variable', '1'))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Enabled GDScript warnings must be errors: unused_variable', result.stderr)

    def test_warnings_cannot_be_globally_disabled(self):
        result = self.run_policy(('gdscript/warnings/enable', 'false'))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('GDScript warnings must stay enabled', result.stderr)

    def test_intentionally_disabled_optional_categories_stay_optional(self):
        result = self.run_policy(('gdscript/warnings/inferred_declaration', '0'))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
