import sys
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from release import next_version


class ReleaseVersionTests(unittest.TestCase):
    def test_default_patch(self):
        self.assertEqual(next_version('1.1.9', ''), '1.1.10')

    def test_explicit_minor_and_resume(self):
        self.assertEqual(next_version('1.1.0', '1.2.0'), '1.2.0')
        self.assertEqual(next_version('1.2.0', '1.2.0'), '1.2.0')

    def test_invalid_or_older(self):
        for version in ['1.0.9', 'v1.2.0', '1.2', '01.2.0', '1.2.0-rc1']:
            with self.subTest(version=version), self.assertRaises(ValueError):
                next_version('1.1.0', version)
