# Development Roadmap & Feature Proposals: `mindchart`

This document details upcoming feature proposals, architectural extensions, and release engineering plans for the `mindchart` package beyond the initial MVP.

---

## 1. Overview & Prioritized Pipeline

The roadmap is organized into iterative phases designed to elevate `mindchart` into a comprehensive, publication-grade mind mapping and structural charting engine for LaTeX and LuaLaTeX:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                MindChart Development Roadmap                                │
├─────────┬────────────────────────────────┬────────────┬───────────────┬─────────────────────┤
│ Phase   │ Feature                        │ Category   │ Target Scope  │ Status              │
├─────────┼────────────────────────────────┼────────────┼───────────────┼─────────────────────┤
│ Phase 1 │ Subtree Boundaries (\boundary) │ Visual     │ Boxes & halos │ Completed (v1.0.0)  │
│ Phase 2 │ Tapered Ribbon Connectors      │ Visual     │ Organic ribbon│ Completed (v1.0.0)  │
│ Phase 3 │ Long Text Auto-Wrap & Breaks   │ Typesetting│ max_width, \\ │ Completed (v1.0.0)  │
│ Phase 4 │ Node Tags & Badges             │ Metadata   │ Status, pills │ Completed (v1.0.0)  │
│ Phase 5 │ GitHub CI & CTAN Packaging     │ Tooling    │ Automation    │ Completed (v1.0.0)  │
│ Ext 1   │ Extended Palettes & Themes     │ Theming    │ 10 palettes   │ Completed (v1.0.0)  │
│ Ext 2   │ Subtree Folding (+N badges)    │ Visual     │ Collapsed tree│ Completed (v1.0.0)  │
│ Ext 3   │ PDF Document Bookmarks Sync    │ Metadata   │ hyperref sync │ Completed (v1.0.0)  │
├─────────┼────────────────────────────────┼────────────┼───────────────┼─────────────────────┤
│ Phase 6 │ Vertical & Org-Chart Layout    │ Layout     │ layout=down   │ Completed (v2.0.0)  │
│ Phase 7 │ Native Vector Icons & Symbols  │ Metadata   │ icon=...      │ Next in Progress    │
│ Phase 8 │ Custom Node Geometric Shapes   │ Visual     │ shape=diamond │ Planned (v2.0.0)    │
│ Phase 9 │ Fishbone / Ishikawa Diagram    │ Layout     │ layout=fish   │ Planned (v2.0.0)    │
└─────────┴────────────────────────────────┴────────────┴───────────────┴─────────────────────┘
```

---

## 2. Detailed Feature Specifications

### 2.1 Subtree Boundaries (`\boundary`) *(Completed in v1.0.0)*

#### 2.1.1 Motivation & Visual Paradigm
In modern mind mapping tools (e.g. XMind, MindMaster), users frequently group an entire conceptual cluster, sub-module, or milestone using a **Boundary** (also known as a halo or boundary enclosure). It renders as a soft, translucent colored rounded rectangle or dashed frame enclosing a target node and all its descendants, crowned with an optional boundary title badge.

#### 2.1.2 Syntax & User Interface
```latex
% Enclose an entire subtree starting at a node
\boundary[options]{node_id}{Title Badge}

% Or enclose a range of sibling subtrees
\boundary[options]{from_node}{to_node}{Title Badge}
```

**Supported Options**:
- `color=<color>`: Border and title badge color (inherits from subtree root if omitted).
- `fill=<color>`: Fill color for background halo (defaults to `<color>!8`).
- `fill_opacity=<0.0-1.0>`: Background opacity (default: `0.08` or TeX mix `!8`).
- `style=<dashed|solid|dotted>`: Border stroke style (default: `dashed`).
- `pad=<dimen>`: Padding around the subtree bounding box (default: `4mm`).
- `rounded=<dimen>`: Corner radius of the boundary box (default: `3mm`).
- `title_pos=<top_left|top_center|bottom_left>`: Position of the title badge (default: `top_left`).

#### 2.1.3 Architectural & Implementation Design
1. **AST Layer (`ast.lua`)**:
   - Store parsed boundary definitions in `ast.boundaries = {}`.
   - Each entry contains `{ id, from_id, to_id, title, options }`.
2. **Parser Layer (`parser.lua`)**:
   - Intercept `\boundary[...]` invocations in `parse_command_invocations`.
3. **Layout Layer (`layout.lua`)**:
   - Implement `position_boundaries(ast)`:
     - For single-node boundaries, collect all nodes in its descendant tree using `collect_subtree_nodes(root)`.
     - For range boundaries, collect descendants across all nodes in the range $[from, to]$.
     - Compute the 2D bounding envelope: $[X_{\min}, X_{\max}] \times [Y_{\min}, Y_{\max}]$.
     - Expand envelope by `pad` (e.g. $4\,\text{mm}$).
     - Compute title badge coordinates (e.g. top-left corner with inner offset).
4. **Renderer Layer (`renderer.lua`)**:
   - Render as **Pass 0** (Background Layer, before connectors and nodes) so the fill lies behind branch lines and cards:
     ```latex
     \draw[rounded corners=3mm, dashed, draw=<color>, fill=<fill>] (xmin, ymin) rectangle (xmax, ymax);
     ```
   - Render the title badge pill atop the boundary border.

---

### 2.2 Tapered Ribbon Connectors (`line=tapered`) *(Completed in v1.0.0)*

#### 2.2.1 Motivation & Visual Paradigm
One of XMind's most visually distinctive styles is the **tapered organic ribbon** (or brush connector) linking the central root capsule to Level 1 primary topic cards. Rather than a constant 1.5pt line, the connector starts wide (e.g. 6pt to 10pt) directly hugging the root capsule, then tapers smoothly along a graceful S-curve down to 1.5pt at the child node.

```
       ┌───────────┐      .-'""'-.       ┌───────────┐
       │   Root    ├─────'        '─────┤  Level 1  │
       │  Capsule  ├────.          .────┤   Card    │
       └───────────┘     '-......-'      └───────────┘
          Width: 8pt                       Width: 1.5pt
```

#### 2.2.2 Geometry & Mathematics
Unlike uniform stroke lines (`\draw[line width=1.5pt]`), a tapered ribbon is a closed 2D polygon path filled with solid color:
- **Root Anchor**: $[x_0, y_0]$, initial half-width $w_0$.
- **Target Anchor**: $[x_1, y_1]$, final half-width $w_1$.
- **Upper Boundary**: Cubic Bézier curve $C_{\text{top}}(t)$ from $[x_0, y_0 + w_0]$ to $[x_1, y_1 + w_1]$.
- **Lower Boundary**: Cubic Bézier curve $C_{\text{bottom}}(t)$ from $[x_1, y_1 - w_1]$ to $[x_0, y_0 - w_0]$.
- The path is closed:
  ```latex
  \fill[<branch_color>] (x0, y0+w0) .. controls (c1x, c1y+w) and (c2x, c2y+w) .. (x1, y1+w1)
                        -- (x1, y1-w1) .. controls (c2x, c2y-w) and (c1x, c1y-w) .. (x0, y0-w0) -- cycle;
  ```

#### 2.2.3 Implementation Plan
1. Extend `curve.lua` with `curve.generate_tapered_ribbon(x0, y0, x1, y1, w0, w1, options)`.
2. Add `line=tapered` to global chart options and per-branch options.
3. Apply tapered ribbons primarily between Root (Level 0) and Level 1 branches, smoothly transitioning to standard S-curves or thin ribbons for deeper levels.

---

### 2.3 Long Text Auto-Wrap & Multi-Line Support (`max_width=...`) *(Completed in v1.0.0)*

#### 2.3.1 Motivation & Problem Statement
In technical charts and academic documentation, node labels may contain detailed descriptions or equations that exceed horizontal page budgets if forced onto a single line. Without auto-wrapping, users must either scale down the entire chart or manually break words.

#### 2.3.2 Design & User Interface
- **Global Configuration**:
  ```latex
  \begin{mindchart}[max_width=4.5cm, align=left]
  ```
- **Per-Node Configuration**:
  ```latex
  - Highly Detailed Neural Network Architecture, max_width=3.5cm, align=center
  - Multi-line node with explicit break:\\First Line\\Second Line
  ```

#### 2.3.3 Dimension Measurement & TeX Box Typesetting
In `measure.lua`, when `max_width` is present or text contains `\\`:
1. Typeset text inside a TeX `\vtop` or `\parbox`:
   ```latex
   \sbox\mindchart@box{\parbox{<max_width>}{\raggedright <node_text>}}
   ```
2. Read the resulting multi-line dimensions directly from `tex.box[\mindchart@box]`:
   - `tex.box[\mindchart@box].width` yields exact wrapped width.
   - `tex.box[\mindchart@box].height + tex.box[\mindchart@box].depth` yields exact multi-line height.
3. In `renderer.lua`, emit the node content inside a TikZ `align=left` or `text width=<width>` node container, perfectly aligned with measured dimensions.

---

### 2.4 Node Tags & Badges (`tag=...`, `badge=...`) *(Completed in v1.0.0)*

#### 2.4.1 Motivation & Visual Paradigm
Mind maps often convey metadata such as priority ratings (`P0`, `P1`), status (`Done`, `WIP`), version numbers (`v2.0`), or step sequences (`①`, `②`). Rendering these as structured micro-pills next to topic text improves information density and clarity.

```
┌────────────────────────────────────────────────────────┐
│ [P0] Feature Architecture (v1.2)        [In Progress] │
└────────────────────────────────────────────────────────┘
```

#### 2.4.2 Syntax & User Options
```latex
- Database Optimization, tag=P0, status=Done
- API Gateway, badge=1, tag={Security, v2}
```

**Options**:
- `tag={<string>}`: Rendered as a compact rounded pill (e.g. gray, blue, or theme-tinted) before or after node text.
- `badge={<string|number>}`: Circular or squared counter marker (e.g. `①`, `1`) prepended to the node.
- `tag_color=<color>`: Custom background/text color for the badge.

#### 2.4.3 Layout & Measurement Integration
1. Badges and tags are probed as part of the node during measurement in `measure.lua`, or measured as supplementary boxes.
2. The node's effective layout width is expanded to account for badge width, tag pill widths, and horizontal margins.

---

### 2.5 GitHub Actions CI & CTAN Release Packaging *(Completed in v1.0.0)*

#### 2.5.1 Automated Continuous Integration
To ensure zero regressions across TeX Live updates and platform differences, configure a GitHub Actions CI pipeline:
- **Matrix OS**: `ubuntu-latest`, `windows-latest`, `macos-latest`.
- **TeX Engine**: TeX Live / LuaLaTeX.
- **Verification Steps**:
  1. Headless parser unit tests:
     ```pwsh
     texlua test/test_parser_md.lua
     ```
  2. Test suite compilation:
     ```pwsh
     lualatex -interaction=nonstopmode -output-directory=test test/test_mvp.tex
     lualatex -interaction=nonstopmode -output-directory=test test/test_styles.tex
     lualatex -interaction=nonstopmode -output-directory=test test/test_adv.tex
     lualatex -interaction=nonstopmode -output-directory=test test/test_markdown.tex
     ```

#### 2.5.2 CTAN Distribution Packaging
Prepare an automated build script generating a clean CTAN-compliant TDS archive:
```text
mindchart.tds.zip
├── doc/latex/mindchart/
│   ├── README.md
│   ├── user_guide.pdf
│   └── ...
├── source/latex/mindchart/
│   └── ...
└── tex/latex/mindchart/
    ├── mindchart.sty
    └── lua/mindchart/*.lua
```

---

### 2.6 Vertical & Org-Chart Tree Layout (`layout=down` / `layout=vertical` / `layout=org`) *(Completed in v2.0.0)*

#### 2.6.1 Motivation & Visual Paradigm
While horizontal mind maps excel at expansive technical hierarchies and widescreen documents, classic **Organizational Charts**, decision trees, and workflow taxonomies naturally flow vertically from top to bottom. In this layout, the Root capsule sits at the top center, and hierarchical levels descend downwards, with sibling nodes spaced horizontally across the canvas.

#### 2.6.2 Geometric & Algorithmic Design
1. **Coordinate Flipping**:
   - The depth axis corresponds to $-Y$ (vertical drop per tier: `level_sep`).
   - The breadth axis corresponds to $X$ (horizontal spacing between siblings: `sibling_sep`).
2. **Horizontal Collision Avoidance**:
   - For each node, compute its subtree horizontal span $[X_{\min}, X_{\max}]$.
   - Children subtrees are placed left-to-right without overlap, and the parent is centered directly above them: $X_{\text{parent}} = \frac{X_{\min} + X_{\max}}{2}$.
3. **Connector Geometries**:
   - `line=elbow`: Drops vertically from parent `south` anchor, branches horizontally, and drops into child `north` anchor.
   - `line=curve`: Smooth vertical cubic Bézier S-curves with vertical entrance/exit tangents.
   - `line=tapered`: Vertical tapered ribbon descending from parent bottom to child top.

---

### 2.7 Native Vector Icons & Symbol Indicators (`icon=...`)

#### 2.7.1 Motivation & Problem Statement
Users frequently use visual icons to denote status, warnings, highlights, and categories (e.g. checkmarks, stars, flags, caution signs). Relying on external icon fonts (like `fontawesome5`) introduces extra package dependencies that may not always be available or may conflict with certain font configurations.

#### 2.7.2 Built-in Zero-Dependency Vector Micro-Icons
Implement lightweight, high-fidelity TikZ vector micro-glyphs rendered directly inside the node badge container:
- `icon=check`: Vector emerald checkmark.
- `icon=cross`: Vector red cross.
- `icon=star`: Golden 5-pointed star.
- `icon=flag`: Outlined/filled flag indicator.
- `icon=warn`: Warning triangle with exclamation mark.
- `icon=info`: Informational circled 'i'.
- `icon=fire`: Hot/urgent flame icon.
- `icon=bulb`: Lightbulb / idea indicator.
- `icon=heart`: Heart favorite indicator.

#### 2.7.3 Syntax & Formatting
```latex
- System Security Audit, icon=check, color=27AE60
- Deprecated API Endpoint, icon=warn, color=E74C3C
- Innovation Sprint, icon=bulb, icon_color=F1C40F
```
- Support custom LaTeX macro symbols (e.g. `\faStar`) as fallback when external icon packages are detected.
- Options: `icon_pos=<prefix|suffix>` (default: `prefix`), `icon_color=<color>`.

---

### 2.8 Custom Node Geometric Shapes (`shape=...`)

#### 2.8.1 Motivation & Visual Paradigm
Different node types in system architectures and decision trees demand distinct geometric visual languages (e.g. diamond for decision branches, hexagon for data stores or states, pill/capsule for endpoints).

#### 2.8.2 Supported Shapes
- `shape=card` / `rounded_rect`: Standard rounded rectangle card with theme border and soft fill.
- `shape=capsule` / `pill`: Fully rounded pill ends.
- `shape=rect`: Crisp sharp-cornered rectangle.
- `shape=diamond` / `rhombus`: 4-point diamond for decision branching and conditional logic.
- `shape=hexagon`: 6-point horizontal polygon for microservices, states, and data stores.
- `shape=underline`: Minimalist horizontal rule.

#### 2.8.3 Dimension Measurement & Inner Margins
For non-rectangular geometries (`diamond`, `hexagon`), standard box padding is insufficient to prevent text corners from clipping outside the diagonal boundary. The measurement engine (`measure.lua`) applies geometric aspect ratios ($\sqrt{2}$ factor for diamonds) to calculate effective outer envelopes, ensuring text never breaches node boundaries.

---

### 2.9 Fishbone / Cause-and-Effect Diagram Layout (`layout=fishbone` / `layout=ishikawa`)

#### 2.9.1 Motivation & Visual Paradigm
The **Ishikawa (Fishbone) Diagram** is a standard quality control and systems engineering methodology for root cause analysis:
- A prominent horizontal **Central Spine** points to the **Problem / Effect** head node on the right.
- Major categories (e.g. *Manpower, Machine, Material, Method, Measurement, Milieu*) branch off the central spine as angled diagonal **Ribs** (typically at 60° inclination).
- Detailed contributing causes branch horizontally off each diagonal rib.

#### 2.9.2 Layout Geometry
1. The Problem / Effect card is anchored on the right: $(X_{\text{head}}, 0)$.
2. The spine extends horizontally to the left: $(0, 0)$ to $(X_{\text{head}}, 0)$.
3. Level 1 branches are paired alternately above and below the spine, extending backwards at $60^\circ$ angles.
4. Level 2 causes attach horizontally to their respective category ribs.

---

## 3. Implementation Plan & Milestones

The roadmap features are implemented iteratively following our test-driven verification workflow:

### v1.0.0 Production Release *(Completed)*
- [x] **Milestone 1**: Subtree Boundaries (`\boundary`) implementation and visual test suites.
- [x] **Milestone 2**: Tapered Ribbon Connectors (`line=tapered`) and curve math.
- [x] **Milestone 3**: Long Text Auto-wrap (`max_width`) & Multi-line parsing.
- [x] **Milestone 4**: Node Tags & Badges (`tag`, `badge`, `status`).
- [x] **Milestone 5**: GitHub Actions CI workflow & TDS packaging scripts.
- [x] **Milestone Ext**: Extended color palettes (10 presets), custom theme registration (`\mindchartDefineTheme`), subtree folding (`collapsed`), and PDF bookmarks (`bookmarks=true`).

### v2.0.0 Feature Pipeline *(Active)*
- [x] **Milestone 6 (Phase 6)**: Vertical & Org-Chart Tree Layout (`layout=down`, `layout=org`, `layout=vertical`).
- [ ] **Milestone 7 (Phase 7)**: Native Vector Icons & Symbol Indicators (`icon=...`, TikZ micro-glyphs).
- [ ] **Milestone 8 (Phase 8)**: Custom Node Geometric Shapes (`shape=diamond|hexagon|rect|capsule`).
- [ ] **Milestone 9 (Phase 9)**: Fishbone / Cause-and-Effect Diagram Layout (`layout=fishbone`).
