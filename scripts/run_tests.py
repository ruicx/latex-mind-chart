"""Run unit, LuaLaTeX, visual compilation, and installed-package checks."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import time
import zipfile
from pathlib import Path


def run_check(name: str, command: list[str], cwd: Path, output: Path,
              environment: dict[str, str]) -> bool:
    """Execute a check and retain its complete output.

    Parameters
    ----------
    name : str
        Unique log name.
    command : list[str]
        Program and arguments, without shell interpretation.
    cwd : Path
        Working directory.
    output : Path
        Log directory.
    environment : dict[str, str]
        Child environment.

    Returns
    -------
    bool
        Whether the command passed without duplicate PDF destinations.
    """
    started = time.monotonic()
    log = output / f"{name}.log"
    try:
        with log.open("w", encoding="utf-8") as stream:
            result = subprocess.run(command, cwd=cwd, env=environment,
                                    stdout=stream, stderr=subprocess.STDOUT, check=False)
        text = log.read_text(encoding="utf-8", errors="replace").lower()
        passed = result.returncode == 0 and not any(
            marker in text for marker in ("duplicate destination", "destination with the same identifier")
        )
    except OSError as error:
        log.write_text(str(error), encoding="utf-8")
        passed = False
    print(f"{'PASS' if passed else 'FAIL'} {name} ({time.monotonic() - started:.1f}s)", flush=True)
    if not passed:
        print(f"  See {log}", flush=True)
    return passed


def installed_check(root: Path, output: Path, environment: dict[str, str]) -> bool:
    """Compile from an isolated directory using the generated TDS archive.

    Parameters
    ----------
    root : Path
        Repository root.
    output : Path
        Persistent verification artifacts.
    environment : dict[str, str]
        Child environment.

    Returns
    -------
    bool
        Whether installed loading and rendering succeeded.

    Notes
    -----
    The temporary working directory has no source-tree Lua search path.
    """
    with tempfile.TemporaryDirectory(prefix="mindchart-install-") as temporary:
        work = Path(temporary)
        tree = work / "texmf"
        with zipfile.ZipFile(output / "package" / "mindchart.tds.zip") as archive:
            archive.extractall(tree)
        source = root / "test" / "integration" / "test_installed.tex"
        (work / source.name).write_bytes(source.read_bytes())
        child_env = environment.copy()
        child_env["TEXMFHOME"] = str(tree)
        for key in ("TEXINPUTS", "LUAINPUTS", "LUA_PATH", "LUA_CPATH"):
            child_env.pop(key, None)
        return run_check("installed-package", ["lualatex", "-interaction=nonstopmode",
                         "-halt-on-error", f"-output-directory={output}", source.name],
                         work, output, child_env)


def main() -> int:
    """Run selected checks and report an aggregate exit status.

    Returns
    -------
    int
        Zero only when every selected check passes.
    """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--group", choices=("all", "unit", "integration", "visual", "package"),
                        default="all")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = root / "build" / "test"
    output.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    results: list[bool] = []
    groups = ("unit", "integration", "visual", "package") if args.group == "all" else (args.group,)
    for group in groups:
        if group == "unit":
            for source in sorted((root / "test" / "unit").glob("test_*.lua")):
                results.append(run_check(source.stem, ["texlua", str(source)], root, output, environment))
            commands = [
                ("python-unit", [sys.executable, "-m", "unittest", "discover", "-s", "test/unit", "-p", "test_*.py"]),
                ("ruff", ["uvx", "ruff", "check", "scripts", "test/unit"]),
                ("ty", ["uvx", "ty", "check", "scripts", "test/unit"]),
            ]
            for name, command in commands:
                results.append(run_check(name, command, root, output, environment))
        elif group in ("integration", "visual"):
            destination = output / group
            destination.mkdir(exist_ok=True)
            for source in sorted((root / "test" / group).glob("test_*.tex")):
                if source.stem == "test_installed":
                    continue
                for pass_number in (1, 2):
                    passed = run_check(f"{group}-{source.stem}-{pass_number}",
                                       ["lualatex", "-interaction=nonstopmode", "-halt-on-error",
                                        f"-output-directory={destination}", str(source)],
                                       root, output, environment)
                    results.append(passed)
                    if not passed:
                        break
        else:
            passed = run_check("package-build", [sys.executable, "scripts/build_package.py",
                               "--dist-dir", str(output / "package")], root, output, environment)
            results.append(passed)
            if passed:
                results.append(installed_check(root, output, environment))
    print(f"{sum(results)}/{len(results)} checks passed. Logs: {output}")
    print("Visual checks compile examples; they do not certify visual appearance.")
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
