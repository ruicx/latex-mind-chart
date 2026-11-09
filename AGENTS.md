# Developer & Agent Guidelines: `mindchart`

This guide is designed for AI coding agents and human contributors working on the `mindchart` codebase. It outlines the architectural invariants, file responsibilities, design patterns, and verification workflows.

---

## 1. Architectural Principles

1. **Zero External Toolchain Dependencies**:
   - The package runs purely inside **LuaLaTeX** using Lua 5.3+.
   - Do **not** introduce Python, Node.js, or external CLI dependencies that require `-shell-escape`.
2. **Sub-Millimeter Exact Dimension Probing**:
   - Text boxes are typeset into TeX registers (`\sbox\mindchart@box{...}`) and probed via `tex.box[box_num]`.
   - Never estimate font widths with string length heuristics during actual rendering.
3. **Verbatim Input Interception**:
   - Indented Markdown syntax relies on exact leading whitespace and raw newlines.
   - LaTeX's standard argument scanner (`+b`) strips leading indentation and converts newlines to spaces. Therefore, `mindchart` intercepts source lines using LuaTeX's `process_input_buffer` callback before TeX tokenization occurs.
4. **Clean TDS Structure**:
   - LaTeX macros live in `tex/`.
   - Lua core logic lives in `lua/mindchart/`.
   - Tests and visual benchmarks live in `test/`.
   - Documentation in `docs/` must strictly remain in **English**.

---

## 2. Directory Structure & Module Responsibilities

```text
mind_chart/
├── .github/
│   └── workflows/
│       └── ci.yml          # Cross-platform GitHub Actions CI matrix
├── AGENTS.md               # Agent & contributor guidelines (this file)
├── README.md               # User-facing project overview and showcases
├── LICENSE                 # MIT License
├── .gitignore              # TeX and ephemeral file exclusions
├── docs/                   # Documentation in English
│   ├── requirements.md     # Functional & non-functional requirements
│   ├── design.md           # System architecture, pipeline, and data structures
│   ├── user_guide.md       # User guide, option tables, syntax, and overlay reference
│   └── roadmap.md          # Future roadmap & milestone planning
├── scripts/
│   └── build_package.py    # CTAN TDS packaging engine (NumPy docs + static typing)
├── tex/
│   ├── mindchart.sty       # LaTeX package entry point, box registers & buffer callbacks
│   └── mindchart.lua       # Custom module searcher for ./lua/
├── lua/
│   └── mindchart/
│       ├── init.lua        # Coordinator, options parser, syntax auto-detection
│       ├── ast.lua         # AST Node definition, tree traversal, named node registry
│       ├── parser.lua      # Bracket parser & Markdown indented list parser
│       ├── measure.lua     # Dimension probing pipeline with TeX box registers
│       ├── layout.lua      # Layout engines (right, left, balanced bin-packing, summaries)
│       ├── curve.lua       # Bézier S-curves, elbows, curly brackets, relationship paths
│       ├── theme.lua       # Palette definitions, hex colors, branch color inheritance
│       └── renderer.lua    # 4-pass TikZ code generator
└── test/
    ├── test_mvp.tex        # Basic MVP logic chart & balanced map
    ├── test_styles.tex     # Visual styles (classic, boxed, underline), lines, and themes
    ├── test_adv.tex        # Overlays (\summary curly brackets, \rel dashed curved arrows)
    ├── test_markdown.tex   # Markdown indented lists, math formulas, balanced maps
    └── test_parser_md.lua  # Standalone headless unit test suite for AST parser
```

---

## 3. Critical Implementation Rules & Invariants

### 3.1 Syntax Parsing & Math Formula Protection
- In `parser.lua`, node declarations are separated into text and options via commas (e.g. `Topic, color=red, name=t1`).
- **Invariant**: Formulas like `$\hat{y} = Wx + b$` or `$\mathcal{L}(y, \hat{y})$` contain commas that must **not** be split as option separators. Always track math mode state (`$` toggle) and grouping brace depth (`{...}`).

### 3.2 Scaling & TikZ Transform Shape
- In `renderer.lua`, the TikZ environment is emitted as:
  ```latex
  \begin{tikzpicture}[baseline=(current bounding box.center), scale=<factor>, every node/.style={transform shape, outer sep=0pt}]
  ```
- **Invariant**: Never override `every node` with a subsequent `/.style` that omits `transform shape`. Without `transform shape`, TikZ only scales coordinate positions while keeping font sizes at 100%, causing text boxes to crash into one another.

### 3.3 Summary Brackets Covering Entire Subtrees
- In `layout.lua`, `position_summaries` must encompass **all descendant subtrees** of the nodes in the summarized range (`collect_subtree_nodes`).
- **Invariant**: The curly bracket must sit to the outside of the outermost child node in the group ($X_{\max}$ for right-growing trees), rather than resting on the Level 1 parent, ensuring summary brackets and topic cards never overlap child branches.

### 3.4 Relationship Arrow Anchoring
- In `renderer.lua`, every rendered node is assigned a named TikZ node `(mc_node_<id>)`.
- In `curve.lua`, `generate_relationship` connects `(mc_node_<from>) to (mc_node_<to>)`.
- **Invariant**: Never use raw center coordinates `(ax, ay) to (bx, by)` for relationship arrows. TikZ automatically clips named nodes at their outer visual boundary, preventing lines and arrowheads from piercing node text.

---

## 4. Verification & Testing Workflow

Before committing any modifications, run the following verification steps:

1. **Run Headless Parser Unit Tests**:
   ```pwsh
   texlua test/test_parser_md.lua
   ```
   Must exit with code 0 and report `ALL PARSER UNIT TESTS PASSED!`.

2. **Compile LaTeX Test Suites with LuaLaTeX**:
   ```pwsh
   lualatex -interaction=nonstopmode -output-directory=test test/test_mvp.tex
   lualatex -interaction=nonstopmode -output-directory=test test/test_styles.tex
   lualatex -interaction=nonstopmode -output-directory=test test/test_adv.tex
   lualatex -interaction=nonstopmode -output-directory=test test/test_markdown.tex
   lualatex -interaction=nonstopmode -output-directory=test test/test_vertical.tex
   ```
   All test files must compile cleanly with exit code 0.

3. **Inspect Rendered Visual Previews**:
   Convert the generated PDFs to high-resolution PNGs and inspect with `read_file`:
   ```pwsh
   pdftoppm -png -r 150 test/test_markdown.pdf test/markdown_preview
   ```

4. **Verify Build Scripts & Packaging**:
   Lint and type-check packaging scripts:
   ```pwsh
   uvx ruff check scripts/build_package.py
   uvx ty check scripts/build_package.py
   ```
   Generate distribution archives:
   ```pwsh
   python scripts/build_package.py
   ```
   Must exit with code 0 and generate `dist/mindchart.tds.zip` and `dist/mindchart.zip`.

---

## 5. Git Commit Standards

All commits must follow this structure:

```text
<Type>: <summary>

1. First change description.
2. Second change description.
3. Third change description.
```

- Allowed `<Type>` prefixes: `Feat`, `BugFix`, `Refactor`, `Doc`.
- A blank line must separate the subject from the numbered body list.
