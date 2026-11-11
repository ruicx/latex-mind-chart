"""Regression checks for preserving files during repeated package builds."""

import unittest
import zipfile
from pathlib import Path
from tempfile import TemporaryDirectory

from scripts.build_package import (
    PackageConfig,
    build_ctan_zip,
    build_tds_zip,
    prepare_dist_directory,
    verify_zip_archive,
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

    def test_archive_contents(self) -> None:
        """Verify runtime modules, examples, and README image targets are shipped.

        Returns
        -------
        None
        """
        with TemporaryDirectory() as temporary:
            config = PackageConfig(dist_dir=Path(temporary))
            tds = build_tds_zip(config)
            ctan = build_ctan_zip(config, tds)
            with zipfile.ZipFile(tds) as archive:
                names = set(archive.namelist())
                self.assertIn("tex/latex/mindchart/mindchart.sty", names)
                for module in Path("lua/mindchart").glob("*.lua"):
                    self.assertIn("tex/latex/mindchart/" + module.as_posix(), names)
                for example in Path("test/visual").glob("*.tex"):
                    self.assertIn("doc/latex/mindchart/" + example.as_posix(), names)
                self.assertIn("doc/latex/mindchart/docs/showcases/markdown_preview-1.png", names)
                self.assertFalse(any(name.endswith((".log", ".aux", ".pdf")) for name in names))
            with zipfile.ZipFile(ctan) as archive:
                self.assertEqual(archive.read("mindchart/mindchart.tds.zip"), tds.read_bytes())

    def test_invalid_inputs(self) -> None:
        """Reject missing package sources and malformed ZIP archives.

        Returns
        -------
        None
        """
        with TemporaryDirectory() as temporary:
            output = Path(temporary)
            with self.assertRaisesRegex(FileNotFoundError, "entry point missing"):
                build_tds_zip(PackageConfig(root_dir=output, dist_dir=output))
            invalid = output / "invalid.zip"
            invalid.write_bytes(b"not a ZIP archive")
            with self.assertRaises(zipfile.BadZipFile):
                verify_zip_archive(invalid)


if __name__ == "__main__":
    unittest.main()
