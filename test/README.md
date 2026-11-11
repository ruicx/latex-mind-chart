# Verification

Run all checks from the repository root:

```sh
python scripts/run_tests.py
```

The script resolves repository paths relative to itself, so invoking its absolute
path from another working directory also works. It requires Python 3.11+, TeX Live
with `texlua` and `lualatex`, and `uvx` for Ruff and ty. TeX packages are listed in
`.github/workflows/ci.yml`. The first `uvx` run may need network access. Python and
uv are development tools, not runtime dependencies of the LaTeX package.

| Group | Coverage |
| --- | --- |
| `unit` | Lua parsing, syntax equivalence, themes, geometry, icons, command generation; Python packaging; Ruff and ty |
| `integration` | Real TeX box dimensions, optional environment settings, complete rendering, and multiple charts with bookmarks |
| `visual` | Styles, overlays, Markdown, vertical layouts, and fishbone examples |
| `package` | ZIP generation and compilation using an isolated installed TDS tree outside the source directory |

Select a group with `python scripts/run_tests.py --group unit` (or `integration`,
`visual`, `package`). The default runs all groups serially. Every check reports its
result and duration. Missing tools count as failures. The final exit status is
nonzero if any check fails. Package installation runs only if archive creation
succeeds. TeX documents compile twice; duplicate PDF destination warnings fail the
check. Other warnings remain in the logs for inspection.

## Files and artifacts

- `unit/test_*.lua`: independent headless suites, grouped by the module under test.
- `unit/test_*.py`: Python unittest discovery; packaging preserves unrelated files.
- `integration/test_*.tex`: executable assertions and full-pipeline fixtures.
  `test_installed.tex` belongs to the package group and uses `\usepackage{mindchart}`.
- `visual/test_*.tex`: representative documents distributed as examples.
- `build/test/`: ignored logs, generated PDFs, and distribution archives.
- `docs/showcases/`: preserved historical preview images, including README assets;
  these are not automated visual baselines.

The existing numbered Lua test blocks were retained during the split. Regression
assertions now live beside the corresponding module tests rather than in a general
regression file. Layout unit tests use synthetic dimensions; only integration
tests prove actual TeX measurement behavior. The measurement fixture compares
single-line and multiline dimensions against independently typeset expected boxes
with a 0.01 pt tolerance. It does not prove every final TikZ shape fits its contents.

## Visual inspection

Compilation success does not certify appearance. For changed examples, convert
generated PDFs with Poppler and inspect every affected page:

```sh
pdftoppm -png -r 150 build/test/visual/test_markdown.pdf build/test/markdown_preview
```

Automated image comparison is not currently enabled. Broader geometry combinations,
invalid-input contracts, and folded overlay interactions remain future coverage.
CI runs the same entry point on Linux, Windows, and macOS and uploads logs and PDFs
even after test failures.
