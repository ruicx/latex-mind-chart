# `mindchart` — Modern XMind-Style Mind Maps for LaTeX

[Chinese README](README_zh.md)

[![CI](https://github.com/ruicx/latex-mind-chart/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ruicx/latex-mind-chart/actions/workflows/ci.yml)
[![Engine: LuaLaTeX](https://img.shields.io/badge/Engine-LuaLaTeX-blue.svg)](https://www.luatex.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Architecture: Lua + TikZ](https://img.shields.io/badge/Architecture-Lua%20%2B%20TikZ-orange.svg)](docs/design.md)

`mindchart` is a high-performance LaTeX package that renders modern, elegant, XMind-style mind maps directly inside **LuaLaTeX**. 

By combining the computational power of **Lua 5.3+** with the vector rendering fidelity of **TikZ/PGF**, `mindchart` computes geometric layouts, exact text dimensions, organic Bézier curves, and overlays in a single compilation pass—**without external Python scripts, CLI tools, or `-shell-escape`**.

---

## 🌟 Key Features

- **🚀 Native & Zero External Dependencies**: Runs out-of-the-box on standard TeX Live, MacTeX, MiKTeX, and cloud environments like Overleaf.
- **📝 Dual Authoring Syntaxes**:
  - **Markdown Indented Lists** (Recommended): Rapidly author maps using `# Headings` and `- indented bullets`.
  - **Bracket Trees**: Nested Outliner format (`[Root [Branch [Leaf]]]`).
  - **Smart Auto-Detection**: Automatically identifies format without manual configuration.
- **📐 Sub-Millimeter Dimension Probing**: Queries TeX's internal box registers (`tex.box`) directly from Lua, measuring exact widths and heights of text, math formulas, and formatting macros before laying out nodes.
- **🎨 Composable Configuration Matrix**:
  - **5 Layouts**: Right-expanding logic chart, Left-expanding logic chart, Bi-directional balanced mind map (greedy bin-packing), Downward Organizational Chart (`layout=org` / `layout=down`), and Ishikawa / Fishbone Diagram (`layout=fishbone` / `layout=ishikawa`).
  - **7 Geometric Shapes**: Capsule (`capsule`/`pill`), Card (`card`), Sharp rectangle (`rect`), Diamond (`diamond`/`rhombus`), Hexagon (`hexagon`/`hex`), Ellipse (`ellipse`), Underline rule (`underline`).
  - **3 Visual Styles**: Classic (capsule root, card branches, underline leaves), Boxed (rounded cards), Underline (minimalist).
  - **4 Line Connectors**: Smooth cubic Bézier S-curves, tapered ribbons, rounded orthogonal elbows, and straight lines.
  - **10 Curated Color Themes & Custom Palettes**: `rainbow`, `business`, `forest`, `monochrome`, `nord`, `morandi`, `dracula`, `ocean`, `sunset`, `solarized`, ad-hoc inline lists (`palette={...}`), and custom defined palettes (`\mindchartDefineTheme`).
- **✨ Overlays, Annotations & Micro-Icons**:
  - **Native Vector Micro-Icons**: Zero-dependency TikZ micro-glyphs (`icon=check|star|warn|fire|bulb|lock|...`) and LaTeX macro fallbacks.
  - **Summary Brackets (`\summary`)**: Mathematical cubic Bézier curly brackets encompassing entire subtrees with dedicated summary topic cards.
  - **Cross-Branch Relationships (`\rel`)**: Curved dashed connection arrows with automatic node boundary clipping, configurable curve angles, and text annotation badges.
  - **Subtree Folding & Indicators**: Collapse busy subtrees with `collapsed` / `folded` and render neat `+N` badge indicators.
  - **PDF Document Bookmarks**: Auto-emit nested PDF bookmarks synchronized with `hyperref` (`bookmarks=true`).
- **🔍 Proportional Scaling**: Seamless scaling via `scale=<factor>` where coordinates, fonts, and node shapes scale in perfect lockstep.

---

## 🖼️ Gallery & Showcases

### 1. Markdown Indented List with Overlays & Math

```latex
\begin{mindchart}[layout=right, theme=rainbow, style=classic, line=curve, scale=0.72]
# Deep Learning System, color=2ECC71
  - Data Preprocessing, name=data, color=3498DB
    - Tokenization \& Cleaning
    - Feature Scaling: $x' = \frac{x - \mu}{\sigma}$
  - Representation Learning, name=rep, color=E74C3C
    - Convolutional Backbone, name=cnn
      - ResNet-50
      - EfficientNet-V2
    - Attention Transformer, name=tf
      - Multi-Head Self-Attention
      - Feed-Forward Network
  - Output Classifier, name=out, color=F39C12
    - Logits \& Linear Layer: $\hat{y} = Wx + b$
    - Softmax Activation: $P(y|x) = \frac{e^{z_i}}{\sum e^{z_j}}$
\summary[color=E74C3C]{cnn}{tf}{Feature Extractors}
\rel[bend=-10, to_anchor=west, pos=0.35, color=9B59B6]{data}{tf}{Direct Token Embedding}
\end{mindchart}
```

![Markdown Logic Chart Showcase](docs/showcases/markdown_preview-1.png)

---

### 2. Balanced Map (Underline Style) & Pure Heading Hierarchy

![Balanced Map and Boxed Headings Showcase](docs/showcases/markdown_preview-2.png)

---

### 3. Fishbone / Cause-and-Effect Diagrams

Use `layout=fishbone` (alias `ishikawa`) for three-level diagrams: problem, category,
and cause. Categories alternate above and below the spine; use `side=top` or
`side=bottom` on a category to choose its position. Causes use underline rules with
`style=classic` and cards with `style=boxed`.

![Classic Fishbone Root Cause Analysis](docs/showcases/fishbone_preview-1.png)

![Boxed Fishbone Manufacturing Analysis](docs/showcases/fishbone_preview-2.png)

See the [example source](test/visual/test_fishbone.tex) and
[fishbone guide](docs/user_guide.md#39-fishbone--cause-and-effect-diagrams-layoutfishbone--layoutishikawa).

---

## ⚡ Quick Start

### Requirements
- **LuaLaTeX** (`lualatex`).
- LaTeX packages `tikz` and `xcolor` (automatically loaded).

### Minimal Example

Save the following as `example.tex` and compile with `lualatex example.tex`:

```latex
\documentclass{article}
\usepackage{mindchart}

\begin{document}

\begin{mindchart}[layout=right, theme=rainbow]
# Machine Learning Architecture
  - Data Pipeline
    - Feature Normalization: $z = \frac{x - \mu}{\sigma}$
    - Data Augmentation
  - Model Core, name=model
    - Convolutional Layers, name=conv
    - Transformer Attention, name=attn
  - Prediction Head, name=head
    - Linear Projection: $\hat{y} = Wx + b$
    - Loss Calculation
\summary{conv}{attn}{Feature Encoders}
\rel[bend=25]{model}{head}{Forward Pass}
\end{mindchart}

\end{document}
```

---

## ⚙️ Configuration Reference

Pass comma-separated key-value pairs to `\begin{mindchart}[...]` on the opening
line; put tree content on the following line. Numeric spacing and line widths
below are in points. Width and fitting options accept TeX dimensions.

### Layout & Input

| Option | Values | Default | Description |
| :--- | :--- | :---: | :--- |
| `layout` | `right`, `left`, `balanced` / `mindmap`, `org` / `down` / `vertical` / `tree_down`, `fishbone` / `ishikawa` / `cause_effect` | `right` | Tree direction or fishbone layout. Fishbone supports problem, category, and cause levels only. |
| `syntax` | `auto`, `markdown` / `md`, `bracket` | `auto` | Detect Markdown or bracket input unless explicitly selected. |
| `equal_branch_length` | `true`, `false` | `false` | Align node starts and ends in horizontal columns; visible leaves share a final column. Applies to `right`, `left`, and `balanced` / `mindmap` only. |
| `level_sep` | Number | `28`; vertical: `26` | Gap between tree levels. Does not control fishbone ribs. |
| `sibling_sep` | Number | `14`; vertical: `18` | Gap between sibling subtrees; also contributes to minimum fishbone cause spacing. |

Equal branch lengths align node columns, not curved connector lengths. Balanced
layouts align each side independently. See [layout details](docs/user_guide.md#21-layout-options-layout--name).

### Style & Text

| Option | Values | Default | Description |
| :--- | :--- | :---: | :--- |
| `style` | `classic`, `boxed`, `underline` | `classic` | Default node styling across hierarchy levels. |
| `shape` | `capsule`, `card`, `rect`, `diamond`, `hexagon`, `ellipse`, `underline` | By style and depth | Default node shape; local node shapes take precedence. |
| `line` | `curve`, `tapered` / `organic`, `elbow`, `straight` | `curve`; vertical: `elbow` | Tree connector geometry. Fishbone uses straight ribs and horizontal cause connectors. |
| `line_width` | Number | `1.2` | Tree connector width. Fishbone ribs are thicker; the spine width is fixed at 2.4pt. |
| `theme` | `rainbow`, `business`, `forest`, `monochrome`, `nord`, `morandi`, `dracula`, `ocean`, `sunset` / `warm`, `solarized`, registered theme names | `rainbow` | Branch palette with inherited descendant colors. |
| `palette` | `{HEX1, HEX2, ...}` | Theme palette | Override the branch palette; its first color also supplies the root color unless overridden. |
| `root_color` | Hex or named color | Theme root color or first inline palette color | Root color override. |
| `max_width` | TeX dimension, e.g. `4cm` | Unset | Default text wrapping width; local node settings take precedence. |
| `align` | `left`, `center`, `right` | `center` | Default multiline text alignment. |
| `root_style` | `{key=value, ...}` | Unset | Shared node options at depth 0. |
| `branch_style` | `{key=value, ...}` | Unset | Shared node options at depth 1. |
| `leaf_style` | `{key=value, ...}` | Unset | Shared node options at depth 2 and deeper, including intermediate topics. |

Local node options override shared hierarchy options. Notes and overlay labels do
not inherit these groups. See [shared styles](docs/user_guide.md#52-shared-styles-by-hierarchy-level).

### Scaling & Publication Layout

| Option | Values | Default | Description |
| :--- | :--- | :---: | :--- |
| `scale` | Factor, e.g. `0.85`, `1.2` | `1` | Scale coordinates, shapes, and text together before fitting. |
| `fit_width`, `fit_height` | Nonnegative TeX dimensions, e.g. `\linewidth`, `18cm` | Unconstrained | Shrink the completed picture to the supplied limits, including overlays. Zero leaves an axis unconstrained; fitting never enlarges the picture. |
| `min_font_size` | Number | `6` | Warn when the smallest visible main-label font after fitting falls below this size. Does not override fitting limits. |
| `avoid_overlaps` | `true`, `false` | `false` | Move overlay labels and summary cards clear of visible node boxes and other overlay labels. Connector crossings can remain. |

See [publication layout and its limits](docs/user_guide.md#5-publication-layout-and-navigation).

### Bookmarks

Load `hyperref` to include chart bookmarks in the PDF outline.

| Option | Values | Default | Description |
| :--- | :--- | :---: | :--- |
| `bookmarks` | `true`, `false` | `false` | Generate nested PDF bookmarks. |
| `bookmark_depth` | Integer | `4` | Maximum exported node depth; the root is depth 0. |
| `bookmark_level` | Integer | `1` | PDF outline level assigned to the root. |
| `bookmark_collapsed` | `true`, `false` | `false` | Include hidden descendants of collapsed nodes in bookmarks. |

### Overlays & Node Flags

- **Summary Brackets**:
  ```latex
  \summary[options]{from_node_name}{to_node_name}{Summary Label}
  ```
- **Cross-Branch Relationships**:
  ```latex
  \rel[options]{from_node_name}{to_node_name}{Relationship Label}
  ```
  - Options: `color=<hex|name>`, `bend=<degrees>`, `line=<dashed|solid|dotted>`, `pos=<0.0-1.0>`, `side=<above|below|auto>`, `from_anchor=<anchor>`, `to_anchor=<anchor>`, `fill=<color|none>`.
- **Subtree Folding**:
  ```latex
  - Complex Subsystem, collapsed
    - Hidden Child 1
    - Hidden Child 2
  ```

For node options and overlay parameters, see [node formatting](docs/user_guide.md#33-node-naming--per-node-options),
[summaries, relationships, and boundaries](docs/user_guide.md#4-overlay-elements),
[independent notes](docs/user_guide.md#54-independent-notes), and
[PDF links](docs/user_guide.md#55-pdf-links-and-references).

---

## 📦 Distribution & Packaging

`mindchart` includes a standalone packaging engine that generates CTAN-ready zip archives and TeX Directory Structure (TDS) bundles:

```pwsh
python scripts/build_package.py
```

Generated distribution archives:
- `dist/mindchart.tds.zip`: Installable directly into `TEXMFHOME` or `TEXMFLOCAL`.
- `dist/mindchart.zip`: Complete archive ready for CTAN submission containing sources, docs, examples, and the TDS bundle.

---

## 📚 Documentation

For in-depth specifications and guides, refer to the `docs/` directory:

- [Requirements Specification (`docs/requirements.md`)](docs/requirements.md): System requirements, configuration matrix, and design goals.
- [System Architecture & Design (`docs/design.md`)](docs/design.md): Three-tier architecture, pipeline stages, AST structures, and algorithms.
- [User Guide (`docs/user_guide.md`)](docs/user_guide.md): Comprehensive reference, option tables, syntax examples, and overlay guide.
- [Agent & Contributor Guidelines (`AGENTS.md`)](AGENTS.md): Coding rules, invariants, and verification workflows for agents and developers.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

## Publication layout

Publication features include complete-picture fitting (`fit_width`, `fit_height`),
opt-in overlay avoidance (`avoid_overlaps=true`), hierarchy styles (`root_style`,
`branch_style`, `leaf_style`), independent `\note` cards, and PDF links (`href`,
`ref`, `target`, `node_ref`). See [the user guide](docs/user_guide.md#5-publication-layout-and-navigation)
for syntax and limits, and [the publication example](test/visual/test_publication.tex).

## Development verification

Run `python scripts/run_tests.py` to execute all checks. See [the test guide](test/README.md) for prerequisites, groups, and visual inspection. Generated files are stored in `build/test/`.
