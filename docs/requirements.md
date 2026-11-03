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

After evaluating pure TeX/TikZ, TikZ+Forest, external Python preprocessors, and native LuaTeX, the project adopts the **LuaTeX (Lua 5.3+) + TikZ rendering pipeline**:

- **Computation & Layout Engine (Lua 5.3+)**:
  - Parses user input into a tree Abstract Syntax Tree (AST).
  - Performs recursive tree layout and collision avoidance algorithms.
  - Automatically balances subtrees across left and right sides.
  - Calculates cubic Bézier curve control points and precise underline anchor coordinates.
- **Rendering Engine (TikZ/PGF)**:
  - Consumes generated TikZ drawing primitives from Lua to render vector PDFs.
- **Key Justifications**:
  1. **Zero External Toolchain Dependencies**: Operates natively in standard TeX distributions (TeX Live, MacTeX, MiKTeX) and cloud platforms (e.g., Overleaf) without requiring Python or `-shell-escape`.
  2. **Sub-millimeter Exact Dimension Probing**: Lua directly queries TeX internal boxes (`tex.box`), obtaining exact rendered widths, heights, and depths of any LaTeX fragment (including math formulas, CJK characters, and custom macros) prior to layout.
  3. **Algorithmic Elegance & Performance**: Tree geometry, bin-packing balancing, and collision avoidance can be implemented cleanly and efficiently in Lua compared to TeX macro expansions.

---

## 3. Functional Requirements

### 3.1 Three-Axis Orthogonal Configuration System

The package must support independent, composable switching across three dimensions: **Layout**, **Visual Style**, and **Color Theme**.

```
              ┌────────────────────────────────────────┐
              │ Configuration Matrix                   │
              ├─────────────┬─────────────┬────────────┤
              │   Layout    │ Visual Style│ Color Theme│
              ├─────────────┼─────────────┼────────────┤
              │ right       │ classic     │ rainbow    │
              │ balanced    │ boxed       │ business   │
              │ left        │ underline   │ forest     │
              │ (down/org)  │ elbow       │ monochrome │
              └─────────────┴─────────────┴────────────┘
```

#### 3.1.1 Layout Modes (`layout = <name>`)
- **`right` (Logic Chart Right)**: Root on the far left, expanding strictly to the right. Ideal for process flows, outlines, and causal trees.
- **`balanced` (Balanced Mind Map)**: Root centered, primary branches distributed automatically across left and right sides based on subtree heights.
- **`left` (Logic Chart Left)**: Root on the far right, expanding strictly to the left.
- **`down` / `org` (Post-MVP)**: Downward organizational hierarchy layout.

#### 3.1.2 Visual Styles (`style = <name>`)
- **`classic` (XMind Default)**:
  - Root: Solid high-contrast capsule (pill) or large rounded box.
  - Level 1: Colored rounded card/box with branch theme color.
  - Level 2+: **Underline style** where text rests atop horizontal branch lines.
  - Connectors: Smooth organic cubic Bézier S-curves.
- **`boxed`**: All hierarchy levels use rounded rectangular cards/frames with progressively lighter borders and paddings.
- **`underline` / `minimal`**: All non-root nodes use minimalist underline support lines.
- **`elbow`**: Engineering/architectural layout with rounded orthogonal elbow lines.

#### 3.1.3 Color Themes (`theme = <name>`)
- **Theme Color Propagation**: Each Level 1 branch receives a distinct theme color, which automatically propagates to all descendant nodes and connecting curves.
- **Built-in Palettes**:
  - `rainbow`: Distinct vibrant colors (red, orange, green, cyan, blue, purple) cyclically assigned.
  - `business`: Professional navy, slate blue, teal, and steel blue shades suitable for technical reports and academic papers.
  - `forest`: Deep green, sage, olive, and warm bronze tones.
  - `monochrome`: Grayscale and black line frames optimized for traditional monochrome journal publication.
- **Custom Palette API**: Provide an interface for users to register custom hexadecimal or RGB color lists.

### 3.2 User Syntax & Authoring Experience
- Provide clear environment syntax (`\begin{mindchart}[<options>] ... \end{mindchart}`).
- Support hierarchical bracket notation (e.g., `[Root [Topic 1 [Subtopic 1]] [Topic 2]]`).
- Support optional indented list / Markdown-like notation.
- Allow arbitrary LaTeX content inside node text (e.g., inline math `$\sum_{i=1}^n x_i$`, formatting macros, line breaks).
- Support per-node attribute overrides (e.g., `[Topic 1, color=red, side=left]`).

### 3.3 Advanced Features (Post-MVP)
1. **Summaries (Brackets)**: Curly brackets grouping multiple sibling nodes to spawn a summary topic node.
2. **Relationships**: Curved dashed arrows connecting non-adjacent nodes with optional annotation labels.
3. **Boundaries**: Highlight boxes/halos enclosing specific subtrees.
4. **Tags & Badges**: Micro-labels, numbering badges, and callout markers alongside node text.

---

## 4. Non-Functional Requirements

1. **Rendering Robustness & Alignment Accuracy**:
   - Zero node overlapping and collision-free tree layouts.
   - Exact baseline docking for underline-style subtopics (no vertical gaps or floating text).
2. **Performance**:
   - Near-instantaneous layout calculation for typical mind maps (< 200 nodes) in Lua.
3. **Clean Decoupling & Maintainability**:
   - Strict separation between parsing, dimension measurement, geometric layout, curve generation, and TikZ rendering.
4. **CTAN Packaging Compatibility**:
   - Organized following standard TeX Directory Structure (TDS) for seamless packaging and distribution.
