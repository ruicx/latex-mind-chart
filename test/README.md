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
with a 0.01 pt tolerance. The render-bounds fixture additionally compares actual TikZ cardinal-anchor distances
against layout dimensions for rectangular and rounded cards, wrapping, multiline
labels, and scaling, with a 0.1 pt tolerance. Other shapes and compound decorations
still require visual inspection.

## Visual inspection

Compilation success does not certify appearance. For changed examples, convert
generated PDFs with Poppler and inspect every affected page:

```sh
pdftoppm -png -r 150 build/test/visual/test_markdown.pdf build/test/markdown_preview
```

Automated image comparison is not currently enabled.

## Additional contract coverage

- `unit/test_branch_length.lua` checks opt-in underline endpoint alignment across
  parents and depths, independent balanced sides, card preservation, and
  restoring natural widths. `visual/test_branch_length.tex` compares natural and
  equal lengths with real text, including math, left-growing, and balanced maps.
- The branch-length unit suite also covers 60 combinations of three visual
  styles, four horizontal layout names, and five connector names. It checks
  emitted path endpoints, unchanged boxed cards, and explicit underline shape
  overrides. `integration/test_branch_styles.tex` asserts real measured widths
  and cross-parent endpoint alignment for all three styles and four connector
  types, plus boxed charts with explicit underline leaves.
- `unit/test_contracts.lua` checks finite positive dimensions and pairwise node
  separation for five layouts and three styles, using varying synthetic sizes.
  It also checks aliases, single-node charts, folded roots, visible subtree
  enclosure, relationship anchors, bookmark options, and state isolation.
- Hidden overlay checks cover relationships, summaries, and boundaries in four
  tree layouts. Boundary recomputation is tested across folding and unfolding.
- Parser tests compare both syntax forms with grouped commas, math brackets,
  escaped dollars, nested TeX groups, line breaks, CRLF, tabs, node decorations,
  all options in a representative declaration, and all three overlay types.
- `integration/test_state_isolation.tex` exercises real measurement and rendering
  across consecutive charts with different direction, width, style, folding,
  bookmarks, and overlays.
- Packaging tests check member paths, runtime module and example inclusion,
  showcase assets, nested archive bytes, preservation of existing files, missing
  source files, and malformed ZIP rejection.

## Remaining limits

Publication coverage is split across `unit/test_publication.lua` (overlay
rectangle separation in five layouts, style precedence, note visibility,
invalid note anchors, fitting limits), `integration/test_publication.tex`
(real styled text and rendered node widths, final fitted dimensions, repeated
chart-local link names), and `visual/test_publication.tex` (Chinese labels,
deep branches, formulas, repeated summaries, boundaries, notes, and links).
The Chinese example uses `ctex`, `luatexja`, and the bundled Fandol fonts so it
does not depend on operating-system Chinese fonts. Inspect the generated PDF;
the geometric tests do not certify relationship routing or general visual quality.

These are representative cases, not a proof for every possible tree. Pixel/image
baselines are not established; existing showcase images are not golden tests.
The parser's error contracts for missing delimiters, duplicate node names,
unknown overlay references, and malformed option values are not documented yet.
Tests intentionally do not freeze their current accidental behavior. Those
policies need to be defined before asserting specific rejection or recovery.
Deep-tree resource limits and all compound-shape geometry combinations are also
not covered by an exhaustive matrix.
CI runs the same entry point on Linux, Windows, and macOS and uploads logs and PDFs
even after test failures.
