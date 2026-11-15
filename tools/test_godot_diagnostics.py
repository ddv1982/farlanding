import unittest
from godot_diagnostics import failures, IMPORT_NOISE


class GodotDiagnosticsTest(unittest.TestCase):
    def test_all_diagnostic_prefixes_are_rejected_even_with_color(self):
        for prefix in ('SCRIPT ERROR', 'ERROR', 'WARNING', 'USER ERROR',
                       'USER WARNING', '[GUT WARNING]', '[GUT ERROR]', '[DEPRECATED]'):
            with self.subTest(prefix=prefix):
                self.assertEqual(failures(f'\x1b[33m{prefix}: bad\x1b[0m\n'), [prefix + ': bad'])
                self.assertEqual(failures(f'    {prefix}: bad'), ['    ' + prefix + ': bad'])

    def test_only_exact_import_noise_is_allowed_and_only_when_requested(self):
        self.assertEqual(failures(IMPORT_NOISE), [IMPORT_NOISE])
        self.assertEqual(failures(IMPORT_NOISE, True), [])
        other = IMPORT_NOISE + ' and another error'
        self.assertEqual(failures(other, True), [other])
        self.assertEqual(failures(IMPORT_NOISE + '\nERROR: real', True), ['ERROR: real'])

    def test_clean_results_and_summary_counts_are_not_diagnostics(self):
        self.assertEqual(failures('Tests 749\nWarnings 0\nDeprecated 0\nAll tests passed!'), [])
