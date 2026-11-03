# System Design Specification: `mindchart`

---

## 1. Architectural Overview

`mindchart` adopts a three-tier architecture: **TeX Interface Layer**, **Lua Core Pipeline**, and **TikZ Rendering Layer**.

```
                User Source Document (\begin{mindchart}[options] ... \end{mindchart})
                                                │
                                                ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 1. TeX Interface Layer (mindchart.sty)                                                 │
│    - Captures raw environment content without pre-expansion                            │
│    - Parses key-value package/environment options                                      │
│    - Loads required TikZ libraries and delegates processing to Lua                     │
└───────────────────────────────────────┬────────────────────────────────────────────────┘
                                        │ Raw Text + Option Table
                                        ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 2. Lua Core Pipeline (mindchart/*.lua)                                                 │
│                                                                                        │
│    [ parser.lua ]       Input Text ──────► Abstract Syntax Tree (AST)                  │
│           │                                                                            │
│           ▼                                                                            │
│    [ measure.lua ]      AST ─────────────► Sized AST (Exact widths, heights, depths)   │
│           │                                                                            │
│           ▼                                                                            │
│    [ layout.lua ]       Sized AST ───────► Positioned AST (Coordinates (x, y), sides)  │
│           │                                                                            │
│           ▼                                                                            │
│    [ curve.lua ]        Positioned AST ──► Geometric Paths (Bézier curves & underlines)│
│           │                                                                            │
│           ▼                                                                            │
│    [ theme.lua ]        Color Palette ───► Inherited Color Codes & TikZ Styles         │
│           │                                                                            │
│           ▼                                                                            │
│    [ renderer.lua ]     Assembly ────────► Standard TikZ Drawing Commands              │
└───────────────────────────────────────┬────────────────────────────────────────────────┘
                                        │ Emits via tex.print()
                                        ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 3. TikZ Rendering Layer (TikZ / PGF Engine)                                            │
│    - Executes emitted \begin{tikzpicture} ... \end{tikzpicture}                        │
│    - Paints boxes, underline rules, and Bézier paths into final PDF vector output      │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Directory Structure & File Organization

The package adheres to standard TeX Directory Structure (TDS) recommendations:

```text
mind_chart/
├── docs/
│   ├── requirements.md       # Requirements specification
│   └── design.md             # System design specification
├── tex/
│   └── mindchart.sty         # LaTeX macro package entry point
└── lua/
    └── mindchart/
        ├── init.lua          # Main Lua entry point & pipeline coordinator
        ├── ast.lua           # AST node definitions and tree utility functions
        ├── parser.lua        # Input parsers (bracket notation & indented list)
        ├── measure.lua       # TeX box dimension probing routines
        ├── layout.lua        # Layout engine coordinator and layout strategies
        ├── curve.lua         # Geometric curve calculators (S-curve, elbow, etc.)
        ├── theme.lua         # Palette definitions and style configurations
        └── renderer.lua      # TikZ code generator
```

---

## 3. Data Structures: Abstract Syntax Tree (AST)

The fundamental internal representation of a mind map is an AST node table:

```lua
Node = {
    id       = 1,             -- Unique integer node ID
    text     = "Topic Text",  -- Raw node text (may contain LaTeX macros / math)
    depth    = 0,             -- Tree depth (0 for root, 1 for main topics, etc.)
    parent   = nil,           -- Reference to parent Node
    children = {},            -- List of child Node objects
    options  = {},            -- Per-node custom options (e.g., color, side)

    -- Populated by measure.lua (dimensions in TeX points 'pt'):
    width    = 60.5,          -- Natural width of rendered content
    height   = 12.0,          -- Height above baseline
    depth_pt = 3.2,           -- Depth below baseline

    -- Populated by layout.lua (coordinates in centimeters or pt):
    x        = 0.0,           -- Anchor X coordinate
    y        = 0.0,           -- Anchor Y coordinate
    side     = "right",       -- "left" or "right" (for bi-directional layout)
    subtree_height = 120.0,   -- Total bounding height of this node's subtree

    -- Populated by theme.lua:
    color    = "mindchart@blue", -- Inherited or explicit branch color
    style    = "underline",      -- Resolved node visual style
}
```

---

## 4. Pipeline Execution Stages

### Stage 1: Input Parsing (`parser.lua`)
- Captures environment text.
- Supports two syntax flavours:
  1. **Bracket Trees**: `[Root [Topic A [Subtopic A1]] [Topic B]]`.
  2. **Indented Lists**: Hierarchical markdown-style `- item` structures.
- Generates the hierarchical `Node` tree.

### Stage 2: Dimension Measurement (`measure.lua`)
- In standard TeX macro packages, node sizes are either guessed or deferred to TikZ node anchors, which makes collision-free compact layout difficult.
- In `mindchart`, Lua drives TeX directly:
  1. Lua places node text inside a dedicated TeX box (e.g., `\setbox\mindchartbox=\hbox{<text>}`).
  2. Queries `tex.box[\mindchartbox].width`, `tex.box[\mindchartbox].height`, and `tex.box[\mindchartbox].depth`.
  3. Converts scaled points (`sp`) to standard points (`pt`) via `dim / 65536`.
  4. Stores exact dimensions on the AST node.

### Stage 3: Geometric Layout & Balancing (`layout.lua`)
- **Strategy Pattern**: Layout engines implement a standard interface:
  ```lua
  function LayoutStrategy:compute(root_node, options) -> void
  ```
- **Single-Direction Layout (`right` / `left`)**:
  - Implements a modern variant of the Reingold-Tilford / Walker compact tree algorithm.
  - Recursively positions children along the primary axis, accumulating vertical offsets with configurable padding.
  - Aligns parent nodes vertically centered against their children's visual center.
- **Bi-Directional Balanced Layout (`balanced`)**:
  - Separates Level 1 children into two candidate groups: `left_subtrees` and `right_subtrees`.
  - **Greedy Height Bin-Packing Algorithm**:
    1. Calculate total subtree bounding box heights for all Level 1 children.
    2. Sort Level 1 children by subtree height in descending order.
    3. Greedily assign each child to the side with smaller accumulated height.
    4. Respect manual overrides if a node explicitly specifies `side=left` or `side=right`.
  - Layout left subtrees propagating in the $-X$ direction, and right subtrees in the $+X$ direction.

### Stage 4: Geometric Curves & Connectors (`curve.lua`)
- Computes cubic Bézier paths and straight line segments between parent and child anchor points.
- **Classic Underline Connection**:
  - For a rightward branch:
    - Path starts at parent exit anchor $(x_{p}, y_{p})$.
    - Cubic Bézier S-curve transitions to the child text bottom-left anchor $(x_{c}, y_{c} - \text{depth})$.
    - Horizontal line extends along the baseline from $(x_{c}, y_{c} - \text{depth})$ to $(x_{c} + \text{width}, y_{c} - \text{depth})$.
  - For a leftward branch:
    - Path transitions to child text bottom-right anchor and underlines leftward.
- **Tapered Ribbon Path (Advanced Curve)**:
  - Generates top and bottom offset Bézier curves to create a closed polygon path filled with the branch color, transitioning smoothly from thick (e.g., 4pt) at root to thin (1pt) at leaves.

### Stage 5: Styling & Color Inheritance (`theme.lua`)
- Palette registry stores ordered color tables (hex codes or named xcolors).
- Traverses the AST:
  - Assigns unique palette color $C_i$ to each Level 1 child $i$.
  - Recursively propagates $C_i$ to all descendant nodes unless an explicit override exists.
  - Root node receives a neutral dark slate / theme-contrasting color.

### Stage 6: TikZ Code Emission (`renderer.lua`)
- Assembles all positioned nodes and calculated paths into optimized TikZ drawing statements.
- Emits statements to TeX via `tex.print()`.

---

## 5. Extensibility & Plugin Architecture

The design guarantees extensibility by keeping Layout, Curve, and Theme registries completely decoupled:

```lua
-- Register a custom layout
mindchart.register_layout("fishbone", function(root, opts) ... end)

-- Register a custom line connector
mindchart.register_connector("waveform", function(parent_pt, child_pt, opts) ... end)

-- Register a custom color theme
mindchart.register_theme("nordic", {
    "#5E81AC", "#81A1C1", "#88C0D0", "#8FBCBB", "#A3BE8C", "#D08770"
})
```

This ensures that adding new layouts (e.g., Fishbone diagrams, Timeline trees) or visual styles requires zero modifications to the core parsing or TeX interface layers.
