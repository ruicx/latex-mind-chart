"""Regression checks for preserving files during repeated package builds."""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from scripts.build_package import (
    PackageConfig,
    build_ctan_zip,
    build_tds_zip,
    prepare_dist_directory,
)


class PackagingTests(unittest.TestCase):
    """Verify archive generation in an existing output directory."""

    def test_preserves_existing_files(self) -> None:
        """Build twice without deleting unrelated files.

        Returns
        -------
        None

        Notes
        -----
        Each archive builder also checks ZIP member integrity.
        """
        with TemporaryDirectory() as temporary:
            output = Path(temporary)
            sentinel = output / "keep.txt"
            sentinel.write_text("preserve me", encoding="utf-8")
            config = PackageConfig(dist_dir=output)
            for _ in range(2):
                prepare_dist_directory(output)
                build_ctan_zip(config, build_tds_zip(config))
                self.assertEqual(sentinel.read_text(encoding="utf-8"), "preserve me")


if __name__ == "__main__":
    unittest.main()
