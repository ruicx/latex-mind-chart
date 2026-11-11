# Requirements Specification: `mindchart`

A Modern XMind-Style Mind Map Rendering Package for LaTeX.

---

## 1. Overview & Motivation

The current mainstream solution for mind mapping in LaTeX is the TikZ `mindmap` library. However, its visual paradigm is based on Tony Buzan's classical radial bubble maps, which presents significant drawbacks in modern document preparation:
1. **Low Page Utilization**: Large circular bubbles consume excessive whitespace, making multi-level or text-heavy hierarchies inefficient to typeset.
2. **Dated Aesthetic**: Lacks the sleek, horizontal, streamlined visual appeal of modern productivity tools such as XMind or MindMaster.
3. **Rigid Customization**: Implementing custom tree spacing, automatic collision avoidance, and bi-directional balanced horizontal trees using pure TeX macros is notoriously complex and error-prone.

**Project Goal**: Build an out-of-the-box, elegant LaTeX package (`mindchart`) designed specifically for **LuaLaTeX**, delivering horizontal and bi-directional balanced mind maps with an **XMind-like modern aesthetic**.

---

## 2. Technical Stack & Rationale

The project adopts the **LuaTeX (Lua 5.3+) + TikZ rendering pipeline**:

- **LaTeX Interface Layer**:
  - Leverages standard LaTeX2e kernel `\NewDocumentEnvironment{mindchart}{ O{} +b }` for robust unexpanded verbatim-like body capture.
  - Zero external legacy environment dependencies (e.g. no dependency on `environ.sty`).
- **Computation & Layout Engine (Lua 5.3+)**:
  - Parses user input into a tree Abstract Syntax Tree (AST) and overlays (`\summary`, `\rel`).
  - Performs recursive tree layout and collision avoidance algorithms.
  - Automatically balances subtrees across left and right sides.
  - Calculates cubic Bézier curve control points, mathematical curly braces, and precise underline anchor coordinates.
- **Rendering Engine (TikZ/PGF)**:
  - Consumes generated TikZ drawing primitives from Lua to render vector PDFs.
- **Key Justifications**:
  1. **Zero External Toolchain Dependencies**: Operates natively in standard TeX distributions (TeX Live, MacTeX, MiKTeX) and cloud platforms (e.g., Overleaf) without requiring Python or `-shell-escape`.
  2. **Sub-millimeter Exact Dimension Probing**: Lua directly queries TeX internal boxes (`tex.box`), obtaining exact rendered widths, heights, and depths of any LaTeX fragment (including math formulas, CJK characters, and custom macros) prior to layout.
  3. **Algorithmic Elegance & Performance**: Tree geometry, bin-packing balancing, and collision avoidance are implemented cleanly and efficiently in Lua.

---

## 3. Functional Requirements

### 3.1 Core Configuration System

The package supports independent, composable switching across **Layout**, **Visual Style**, **Color Theme**, and **Scale**.

```
              ┌────────────────────────────────────────────────────────┐
              │ Configuration Matrix                                   │
              ├─────────────┬─────────────┬────────────┬───────────────┤
              │   Layout    │ Visual Style│ Color Theme│   Line Type   │
              ├─────────────┼─────────────┼────────────┼───────────────┤
              │ right       │ classic     │ rainbow    │ curve (S-arc) │
              │ balanced    │ boxed       │ business   │ elbow (angle) │
              │ left        │ underline   │ forest     │ straight      │
              │             │             │ monochrome │               │
              └─────────────┴─────────────┴────────────┴───────────────┘
```

#### 3.1.1 Layout Modes (`layout = <name>`)
- **`right` (Logic Chart Right)**: Root on the far left, expanding strictly to the right. Ideal for process flows, outlines, and causal trees.
- **`balanced` (Balanced Mind Map)**: Root centered, primary branches distributed automatically across left and right sides based on subtree heights via greedy bin-packing.
- **`left` (Logic Chart Left)**: Root on the far right, expanding strictly to the left.

#### 3.1.2 Visual Styles (`style = <name>`)
- **`classic` (XMind Default)**:
  - Root: Solid high-contrast capsule (pill) or large rounded box.
  - Level 1: Colored rounded card/box with branch theme color.
  - Level 2+: **Underline style** where text rests atop horizontal branch lines.
  - Connectors: Smooth organic cubic Bézier S-curves.
- **`boxed`**: All hierarchy levels use rounded rectangular cards/frames with progressively lighter borders and paddings.
- **`underline` / `minimal`**: All non-root nodes use minimalist underline support lines.

#### 3.1.3 Connector Line Styles (`line = <name>`)
- **`curve`**: Smooth cubic Bézier S-curves with horizontal entrance/exit tangents.
- **`elbow`**: Rounded orthogonal elbow lines (3pt corner radius).
- **`straight`**: Direct straight lines.

#### 3.1.4 Color Themes (`theme = <name>`)
- **Theme Color Propagation**: Each Level 1 branch receives a distinct theme color, which automatically propagates to all descendant nodes and connecting curves.
- **Built-in Palettes**:
  - `rainbow`: Distinct vibrant colors (red, orange, green, cyan, blue, purple) cyclically assigned.
  - `business`: Professional navy, slate blue, teal, and steel blue shades suitable for technical reports and academic papers.
  - `forest`: Deep green, sage, olive, and warm bronze tones.
  - `monochrome`: Grayscale and black line frames optimized for traditional monochrome journal publication.
- **Color Format Flexibility**: Supports standard hex codes (e.g. `color=E74C3C` or `color=#E74C3C`) and named LaTeX xcolors (`color=red`, `color=blue`).

#### 3.1.5 Scaling (`scale = <factor>`)
- Support scaling down or up whole charts (e.g., `scale=0.8`) to fit page constraints gracefully.

---

### 3.2 Overlay Elements: Summaries and Relationships

#### 3.2.1 Summary Brackets (`\summary`)
- Group a range of sibling nodes using a mathematically smooth cubic Bézier curly bracket (`}` or `{`).
- Sprout a summary topic card at the cusp of the bracket.
- Syntax: `\summary[options]{from_node}{to_node}{Summary Label}`.

#### 3.2.2 Cross-Branch Relationships (`\rel`)
- Connect any two arbitrary nodes across different branches with a curved, dashed arrow.
- Support centered label badges with white background padding.
- Syntax: `\rel[options]{from_node}{to_node}{Label Text}`.
  - Options: `color=<color>`, `bend=<degrees>`, `line=<dashed|solid|dotted>`.

---

### 3.3 User Syntax & Authoring Experience

The package provides two authoring syntaxes with automatic format detection:

1. **Markdown Indented List Notation (Recommended)**:
   ```latex
   \begin{mindchart}[layout=right, theme=rainbow]
   # Deep Learning Architecture
     - Input Layer
     - Representation Learning, name=rep
       - Convolutional Backbone, name=cnn
       - Attention Transformer, name=tf
     - Output Classifier, name=out
       - Softmax Probability
   \summary{cnn}{tf}{Feature Extractors}
   \rel[bend=30]{rep}{out}{Representation Flow}
   \end{mindchart}
   ```
   - Automatically supports `# Heading` syntax, indented bullet items (`-`, `*`, `+`, `1.`), and plain indented text.
   - Spaces and tabs are preserved without LaTeX catcode corruption using LuaTeX buffer hooks.

2. **Bracket Tree Notation**:
   ```latex
   \begin{mindchart}[layout=balanced, theme=forest]
   [Deep Learning Architecture
     [Representation Learning, name=rep
       [Convolutional Backbone, name=cnn]
       [Attention Transformer, name=tf]
     ]
     [Output Classifier, name=out]
   ]
   \summary{cnn}{tf}{Feature Extractors}
   \rel[bend=30]{rep}{out}{Representation Flow}
   \end{mindchart}
   ```

3. **Node Naming & Options**: Support `name=<id>` and `id=<id>` for referencing in overlays, `color=<hex|name>` for branch overrides, and `side=left|right` for balanced trees.
4. **TeX Content Preservation**: Full support for inline math formulas (e.g. `$\hat{y} = Wx + b$`), formatting macros (`\textbf`, `\mathcal`), and special characters without pre-expansion breakage.

---

### 3.4 Future Roadmap (Post-MVP)

For complete technical specifications, mathematical foundations, and implementation milestones, refer to the dedicated [Development Roadmap](file:///D:/work/tex/mind_chart/docs/roadmap.md):

1. **Subtree Boundaries (`\boundary`)**: Soft colored rounded boxes and badges enclosing entire subtrees.
2. **Tapered Ribbon Connectors (`line=tapered`)**: Variable-width organic Bézier brush ribbon paths.
3. **Long Text Auto-Wrap & Multi-Line Support (`max_width=...`)**: Dynamic TeX box wrapping and newline support.
4. **Tags & Badges (`tag=...`, `badge=...`)**: Metadata chips, priority markers, and numbering markers.
5. **Automation & CI**: GitHub Actions multi-platform workflow and TDS packaging for CTAN.

### 3.5 Publication and Navigation Requirements

- Constrain the final chart width and/or total height using exact TeX box
  dimensions. Shrink uniformly without enlargement; warn when fitted main-label
  fonts fall below a configurable point-size threshold.
- Offer opt-in rectangle avoidance for summary cards/brackets, boundary titles,
  and measured relationship labels. Preserve manual curved relationships as an
  explicit per-relationship option. General obstacle-free routing is outside
  this iteration.
- Apply shared root, first-level, and deeper-topic styles before measurement,
  with individual node options taking precedence.
- Support independent measured notes positioned relative to named tree topics,
  including visibility under folding, without adding them to the tree hierarchy.
- Support external URLs, document references, explicit PDF anchors, and
  chart-local named-node links through optional `hyperref` integration.
- Validate styled measurement against actual TikZ node dimensions and fitted
  output against both page limits. Include Chinese text and mixed overlays in
  the visual fixtures.
