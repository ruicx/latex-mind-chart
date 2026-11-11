"""Verify failure reporting by the unified test runner."""

import os
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from scripts.run_tests import run_check


class RunnerTests(unittest.TestCase):
    """Exercise process exit codes, missing tools, and retained diagnostics."""

    def test_command_results(self) -> None:
        """Verify command results and logs for successful and failed checks.

        Returns
        -------
        None
        """
        with TemporaryDirectory() as temporary:
            output = Path(temporary)
            cases = [
                ("success", [sys.executable, "-c", "print('completed')"], True),
                ("failure", [sys.executable, "-c", "raise SystemExit(2)"], False),
                ("missing", [str(output / "missing-executable")], False),
                ("duplicate", [sys.executable, "-c", "print('duplicate destination')"], False),
            ]
            for name, command, expected in cases:
                with self.subTest(name=name):
                    self.assertEqual(run_check(name, command, output, output, dict(os.environ)), expected)
                    self.assertTrue((output / f"{name}.log").is_file())


if __name__ == "__main__":
    unittest.main()
