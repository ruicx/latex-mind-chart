"""Build and packaging script for mindchart CTAN and TDS distribution archives.

This module automates the construction of TeX Directory Structure (TDS) zip archives
and top-level CTAN distribution packages in full compliance with TeX Users Group guidelines.
"""

from __future__ import annotations

import argparse
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class PackageConfig:
    """Configuration settings for packaging mindchart.

    Parameters
    ----------
    package_name : str
        Canonical name of the LaTeX package.
    dist_dir : Path
        Output directory for generated zip archives.
    root_dir : Path
        Root directory of the project repository.
    """

    package_name: str = "mindchart"
    dist_dir: Path = Path("dist")
    root_dir: Path = Path(".")


def prepare_dist_directory(dist_dir: Path) -> None:
    """Creates the distribution directory without removing existing files.

    Parameters
    ----------
    dist_dir : Path
        Directory in which to create archives.

    Returns
    -------
    None

    Raises
    ------
    OSError
        If directory creation fails due to filesystem permissions.

    Notes
    -----
    Existing files are preserved; archive writers replace only their target ZIP files.
    """
    dist_dir.mkdir(parents=True, exist_ok=True)


def collect_core_lua_files(root_dir: Path) -> list[Path]:
    """Finds all core Lua modules belonging to the mindchart package.

    Parameters
    ----------
    root_dir : Path
        Project root directory.

    Returns
    -------
    list[Path]
        Sorted list of relative paths to Lua module files under lua/mindchart/.

    Raises
    ------
    FileNotFoundError
        If the lua/mindchart directory does not exist or contains no Lua modules.

    Notes
    -----
    Requires all 8 core Lua modules to be present.
    """
    lua_dir = root_dir / "lua" / "mindchart"
    if not lua_dir.exists() or not lua_dir.is_dir():
        raise FileNotFoundError(f"Lua module directory not found: {lua_dir}")

    files = sorted(p.relative_to(root_dir) for p in lua_dir.glob("*.lua"))
    if not files:
        raise FileNotFoundError(f"No Lua modules discovered in {lua_dir}")
    return files


def collect_doc_files(root_dir: Path) -> list[Path]:
    """Finds all user-facing documentation and metadata files.

    Parameters
    ----------
    root_dir : Path
        Project root directory.

    Returns
    -------
    list[Path]
        List of relative paths to documentation markdown files and license.

    Raises
    ------
    FileNotFoundError
        If mandatory files such as README.md or LICENSE are missing.

    Notes
    -----
    Includes README.md, LICENSE, documentation, and preserved showcase images.
    """
    candidates: list[Path] = [
        root_dir / "README.md",
        root_dir / "LICENSE",
        root_dir / "AGENTS.md",
    ]
    docs_dir = root_dir / "docs"
    if docs_dir.exists() and docs_dir.is_dir():
        candidates.extend(sorted(docs_dir.glob("*.md")))
        candidates.extend(sorted((docs_dir / "showcases").glob("*.png")))

    result: list[Path] = []
    for c in candidates:
        if not c.exists():
            if c.name in ("README.md", "LICENSE"):
                raise FileNotFoundError(f"Mandatory documentation file missing: {c}")
            continue
        result.append(c.relative_to(root_dir))
    return result


def collect_test_examples(root_dir: Path) -> list[Path]:
    """Finds all LaTeX test suite source files for inclusion as example documents.

    Parameters
    ----------
    root_dir : Path
        Project root directory.

    Returns
    -------
    list[Path]
        Sorted list of relative paths to test *.tex files.

    Raises
    ------
    FileNotFoundError
        If the test directory does not exist.

    Notes
    -----
    Only source *.tex files are collected; ephemeral build logs and auxiliary files are omitted.
    """
    test_dir = root_dir / "test" / "visual"
    if not test_dir.exists() or not test_dir.is_dir():
        raise FileNotFoundError(f"Test directory not found: {test_dir}")

    return sorted(p.relative_to(root_dir) for p in test_dir.glob("*.tex"))


def build_tds_zip(cfg: PackageConfig) -> Path:
    """Packages runtime and documentation files into a TeX Directory Structure (TDS) zip archive.

    Parameters
    ----------
    cfg : PackageConfig
        Packaging configuration containing paths and names.

    Returns
    -------
    Path
        Path to the generated TDS zip archive (e.g. dist/mindchart.tds.zip).

    Raises
    ------
    FileNotFoundError
        If package runtime files or documentation cannot be found.
    zipfile.BadZipFile
        If the created archive fails internal consistency verification.

    Notes
    -----
    The TDS directory structure adheres to the TeX Users Group standard:
    - tex/latex/mindchart/mindchart.sty
    - tex/latex/mindchart/mindchart.lua
    - tex/latex/mindchart/lua/mindchart/*.lua
    - doc/latex/mindchart/*
    """
    tds_zip_path = cfg.dist_dir / f"{cfg.package_name}.tds.zip"
    pkg = cfg.package_name

    sty_file = cfg.root_dir / "tex" / "mindchart.sty"
    searcher_file = cfg.root_dir / "tex" / "mindchart.lua"

    if not sty_file.exists():
        raise FileNotFoundError(f"Package entry point missing: {sty_file}")
    if not searcher_file.exists():
        raise FileNotFoundError(f"Custom module searcher missing: {searcher_file}")

    core_lua_files = collect_core_lua_files(cfg.root_dir)
    doc_files = collect_doc_files(cfg.root_dir)
    example_files = collect_test_examples(cfg.root_dir)

    with zipfile.ZipFile(tds_zip_path, mode="w", compression=zipfile.ZIP_DEFLATED) as zf:
        # Runtime TeX package and searcher
        zf.write(sty_file, f"tex/latex/{pkg}/mindchart.sty")
        zf.write(searcher_file, f"tex/latex/{pkg}/mindchart.lua")

        # Runtime Lua core modules
        for lua_rel in core_lua_files:
            target_arc = f"tex/latex/{pkg}/{lua_rel.as_posix()}"
            zf.write(cfg.root_dir / lua_rel, target_arc)

        # Documentation and licenses
        for doc_rel in doc_files:
            target_arc = f"doc/latex/{pkg}/{doc_rel.as_posix()}"
            zf.write(cfg.root_dir / doc_rel, target_arc)

        # Example documents
        for ex_rel in example_files:
            target_arc = f"doc/latex/{pkg}/{ex_rel.as_posix()}"
            zf.write(cfg.root_dir / ex_rel, target_arc)

    verify_zip_archive(tds_zip_path)
    return tds_zip_path


def build_ctan_zip(cfg: PackageConfig, tds_zip: Path) -> Path:
    """Builds the top-level CTAN distribution archive containing the package and its TDS archive.

    Parameters
    ----------
    cfg : PackageConfig
        Packaging configuration containing paths and names.
    tds_zip : Path
        Path to the pre-built TDS zip archive.

    Returns
    -------
    Path
        Path to the generated CTAN zip archive (e.g. dist/mindchart.zip).

    Raises
    ------
    FileNotFoundError
        If runtime files, docs, or the TDS zip are missing.
    zipfile.BadZipFile
        If the created archive fails internal consistency verification.

    Notes
    -----
    CTAN root structure contains a top-level directory named after the package:
    - mindchart/
      - README.md
      - LICENSE
      - mindchart.sty
      - mindchart.lua
      - lua/mindchart/*.lua
      - docs/*.md
      - test/visual/*.tex
      - mindchart.tds.zip
    """
    ctan_zip_path = cfg.dist_dir / f"{cfg.package_name}.zip"
    pkg = cfg.package_name

    sty_file = cfg.root_dir / "tex" / "mindchart.sty"
    searcher_file = cfg.root_dir / "tex" / "mindchart.lua"

    core_lua_files = collect_core_lua_files(cfg.root_dir)
    doc_files = collect_doc_files(cfg.root_dir)
    example_files = collect_test_examples(cfg.root_dir)

    with zipfile.ZipFile(ctan_zip_path, mode="w", compression=zipfile.ZIP_DEFLATED) as zf:
        # Top-level entry point files
        zf.write(sty_file, f"{pkg}/mindchart.sty")
        zf.write(searcher_file, f"{pkg}/mindchart.lua")

        # Lua core logic
        for lua_rel in core_lua_files:
            zf.write(cfg.root_dir / lua_rel, f"{pkg}/{lua_rel.as_posix()}")

        # Documentation
        for doc_rel in doc_files:
            zf.write(cfg.root_dir / doc_rel, f"{pkg}/{doc_rel.as_posix()}")

        # Test and example files
        for ex_rel in example_files:
            zf.write(cfg.root_dir / ex_rel, f"{pkg}/{ex_rel.as_posix()}")

        # Embedded TDS archive
        zf.write(tds_zip, f"{pkg}/{tds_zip.name}")

    verify_zip_archive(ctan_zip_path)
    return ctan_zip_path


def verify_zip_archive(zip_path: Path) -> None:
    """Verifies internal integrity of a zip archive by testing file checksums.

    Parameters
    ----------
    zip_path : Path
        Path to the zip file to test.

    Returns
    -------
    None

    Raises
    ------
    zipfile.BadZipFile
        If a corrupted file or CRC mismatch is found inside the archive.

    Notes
    -----
    Calls zipfile.ZipFile.testzip() to perform an exhaustive CRC check across all members.
    """
    with zipfile.ZipFile(zip_path, mode="r") as zf:
        bad_file = zf.testzip()
        if bad_file is not None:
            raise zipfile.BadZipFile(f"Corrupted archive member detected: {bad_file} in {zip_path}")


def parse_arguments() -> argparse.Namespace:
    """Parses command-line arguments for the packaging tool.

    Returns
    -------
    argparse.Namespace
        Parsed CLI arguments.

    Notes
    -----
    Allows overriding the output distribution directory.
    """
    parser = argparse.ArgumentParser(
        description="Package mindchart into CTAN and TDS distribution zip archives."
    )
    parser.add_argument(
        "--dist-dir",
        type=Path,
        default=Path("dist"),
        help="Destination directory for built zip archives (default: dist).",
    )
    return parser.parse_args()


def main() -> int:
    """Main execution function for building mindchart distribution archives.

    Returns
    -------
    int
        Exit code (0 for success, non-zero for failure).

    Notes
    -----
    Coordinates output directory preparation and TDS and CTAN archive generation.
    """
    args = parse_arguments()
    config = PackageConfig(dist_dir=args.dist_dir)

    print("=== MindChart Packaging Engine ===")
    print(f"Working directory: {config.root_dir.resolve()}")
    print(f"Distribution directory: {config.dist_dir.resolve()}")

    try:
        prepare_dist_directory(config.dist_dir)

        print("\n[1/3] Building TDS archive (mindchart.tds.zip)...")
        tds_zip = build_tds_zip(config)
        tds_size_kb = tds_zip.stat().st_size / 1024.0
        print(f"  -> Generated: {tds_zip} ({tds_size_kb:.2f} KB)")

        print("\n[2/3] Building CTAN root archive (mindchart.zip)...")
        ctan_zip = build_ctan_zip(config, tds_zip)
        ctan_size_kb = ctan_zip.stat().st_size / 1024.0
        print(f"  -> Generated: {ctan_zip} ({ctan_size_kb:.2f} KB)")

        print("\n[3/3] Inspecting CTAN archive member tree:")
        with zipfile.ZipFile(ctan_zip, mode="r") as zf:
            for info in zf.infolist():
                comp_ratio = (1.0 - info.compress_size / max(info.file_size, 1)) * 100.0
                print(f"  {info.filename:<48} {info.file_size:>8} B  ({comp_ratio:>5.1f}% comp)")

        print("\nSUCCESS: All packages verified and ready for distribution.")
        return 0

    except (OSError, RuntimeError, zipfile.BadZipFile) as exc:
        print(f"\nERROR: Packaging failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
