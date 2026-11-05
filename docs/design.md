# System Design Specification: `mindchart`

---

## 1. Architectural Overview

`mindchart` adopts a three-tier architecture: **TeX Interface Layer**, **Lua Core Pipeline**, and **TikZ Rendering Layer**.

```
                User Source Document (\begin{mindchart}[options] ... \end{mindchart})
                                                │
                                                ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 1. TeX Interface Layer (mindchart.sty & mindchart.lua)                                 │
│    - Intercepts raw input lines verbatim via LuaTeX's process_input_buffer callback    │
│    - Preserves indentation spaces and prevents TeX catcode corruption                  │
│    - Registers custom Lua module searcher for reliable sub-package loading             │
│    - Provides \summary and \rel overlay commands                                       │
└───────────────────────────────────────┬────────────────────────────────────────────────┘
                                        │ Raw Text + Option String
                                        ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 2. Lua Core Pipeline (mindchart/*.lua)                                                 │
│                                                                                        │
│    [ parser.lua ]       Input Text ──────► AST Tree + Overlays (\summary, \rel)        │
│           │                                                                            │
│           ▼                                                                            │
│    [ measure.lua ]      AST ─────────────► Sized AST (Exact widths, heights, depths)   │
│           │                                                                            │
│           ▼                                                                            │
│    [ theme.lua ]        Color Palette ───► Inherited Colors & Node Styles              │
│           │                                                                            │
│           ▼                                                                            │
│    [ layout.lua ]       Sized AST ───────► Positioned AST & Summary Bracket Geometry   │
│           │                                                                            │
│           ▼                                                                            │
│    [ curve.lua ]        Positioned AST ──► Bézier Connectors, Brackets, & Rel Arrows   │
│           │                                                                            │
│           ▼                                                                            │
│    [ renderer.lua ]     Assembly ────────► 4-Pass Optimized TikZ Code Emission         │
└───────────────────────────────────────┬────────────────────────────────────────────────┘
                                        │ Emits via tex.print()
                                        ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 3. TikZ Rendering Layer (TikZ / PGF Engine)                                            │
│    - Executes emitted \begin{tikzpicture}[scale=...] ... \end{tikzpicture}             │
│    - Paints boxes, underline rules, Bézier paths, brackets, and labeled arrows into PDF│
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Directory Structure & File Organization

The package adheres to standard TeX Directory Structure (TDS) recommendations:

```text
mind_chart/
├── docs/
│   ├── requirements.md       # Requirements specification
│   ├── design.md             # System design specification
│   └── user_guide.md         # Comprehensive user manual & examples
├── tex/
│   ├── mindchart.sty         # LaTeX macro package entry point
│   └── mindchart.lua         # Lua bootstrap & searcher registration
└── lua/
    └── mindchart/
        ├── init.lua          # Main Lua entry point & pipeline coordinator
        ├── ast.lua           # AST node definitions, registry & tree utilities
        ├── parser.lua        # Input parser (bracket trees & overlay commands)
        ├── measure.lua       # TeX box dimension probing routines
        ├── layout.lua        # Layout engine (unidirectional, balanced, summaries)
        ├── curve.lua         # Geometric curve calculators (S-curves, brackets, arrows)
        ├── theme.lua         # Palette definitions, hex conversion & style resolver
        └── renderer.lua      # 4-pass TikZ code generator
```

---

## 3. Data Structures: AST & Overlays

### 3.1 Node Structure

The fundamental representation of each tree topic and summary topic is a `Node` table:

```lua
Node = {
    id         = 1,             -- Unique integer node ID
    text       = "Topic Text",  -- Raw node text (supports LaTeX macros / math)
    depth      = 0,             -- Tree depth (0 for root, 1 for main topics, etc.)
    name       = "topic_1",     -- Optional unique string name for overlay referencing
    parent     = nil,           -- Reference to parent Node
    children   = {},            -- List of child Node objects
    options    = {},            -- Per-node custom options (color, side, style, etc.)
    is_summary = false,         -- True if generated as a summary card

    -- Populated by measure.lua (dimensions in TeX points 'pt'):
    width      = 60.5,          -- Natural width of rendered content
    height     = 12.0,          -- Height above baseline
    depth_pt   = 3.2,           -- Depth below baseline

    -- Populated by layout.lua (coordinates in pt):
    x          = 0.0,           -- Anchor X coordinate
    y          = 0.0,           -- Anchor Y coordinate
    pad_x      = 8.0,           -- Horizontal box padding
    pad_y      = 4.0,           -- Vertical box padding
    box_width  = 76.5,          -- Full outer bounding width
    box_height = 23.2,          -- Full outer bounding height
    side       = "right",       -- "left" or "right"
    subtree_height = 120.0,     -- Total bounding height of this node's subtree

    -- Populated by theme.lua:
    color      = "#2980B9",     -- Resolved color code
    style      = "underline",   -- "capsule" | "card" | "boxed" | "underline"
}
```

### 3.2 Overlay Structures

In `ast.lua`:
- `ast.named_nodes[name]`: Fast lookup dictionary mapping string names to `Node` instances.
- `ast.summaries`: List of `{ from = "nameA", to = "nameB", text = "...", node = summary_node, options = {...}, bracket = {...} }`.
- `ast.relationships`: List of `{ from = "nameA", to = "nameB", text = "...", options = {...} }`.

---

## 4. Pipeline Execution Stages

### Stage 1: Input Parsing & Auto-Detection (`parser.lua` & `init.lua`)
1. **Auto-Detection**:
   - `init.lua` inspects the trimmed input stream:
     - If the first non-whitespace character is `[`, invokes `parser.parse_bracket`.
     - Otherwise, invokes `parser.parse_markdown`.
     - Explicit override supported via `syntax=markdown` or `syntax=bracket`.
2. **Overlay Extraction (`parse_command_invocations`)**:
   - Scans input for `\summary[options]{from}{to}{label}` and `\rel[options]{from}{to}{label}`.
   - Instantiates dedicated summary nodes and registers overlay descriptors.
3. **Markdown Indented List Parsing (`parser.parse_markdown`)**:
   - Iterates lines, expanding tabs and calculating column indentation.
   - Recognizes Markdown headings (`#`, `##`, `###`) and list bullets (`-`, `*`, `+`, `1.`).
   - Uses a stack-based algorithm (`indent_stack` & `node_stack`) to resolve parent-child relationships across indentations and dedentations.
   - Protects math mode (`$...$`) and LaTeX braces (`{...}`) to prevent commas inside formulas from prematurely triggering option parsing.
4. **Bracket Tree Parsing (`parser.parse_bracket`)**:
   - Parses nested bracket tokens `[Node declaration [Child 1] [Child 2]]`.
   - Tracks brace balance depth (`{...}`) to ensure LaTeX macros and math formulas with internal brackets/commas are never misidentified as tree tokens.
   - Extracts node options (e.g. `name=...`, `id=...`, `color=...`).
   - Automatically halts tree parsing upon closure of the root bracket (`#stack == 0 and root ~= nil`), ignoring trailing overlay commands.

### Stage 2: Dimension Measurement (`measure.lua`)
- Lua drives TeX in a single compilation pass:
  1. Emits `\mindchartMeasureItem{id}{text}` for all tree nodes and summary nodes.
  2. TeX typesets each item into dedicated `\mindchart@box` and invokes `mindchart.store_dim(id, \the\mindchart@box)`.
  3. Physical dimensions are converted from scaled points (`sp`) to standard points (`pt`) via `dim / 65536.0`.
  4. Finishes with `\mindchartFinishMeasure`, seamlessly resuming Lua pipeline execution.

### Stage 3: Theming & Color Propagation (`theme.lua`)
- Assigns Level 1 branches distinct theme colors cyclically from the selected palette (`rainbow`, `business`, `forest`, `monochrome`).
- Recursively propagates branch colors down to all descendants.
- Resolves colors for summary nodes and provides `theme.to_tikz_color(col)` supporting hex codes (`#RRGGBB` or `RRGGBB`) and named xcolors (`red`, `blue`, etc.).

### Stage 4: Geometric Layout & Balancing (`layout.lua`)
- **Single-Direction Layout**:
  - Recursively computes subtree bounding boxes with collision avoidance.
  - Aligns parent nodes centered against their children's visual span.
- **Bi-Directional Balanced Layout**:
  - Partitions Level 1 children into left and right groups using a greedy height bin-packing algorithm.
  - Propagates side designations recursively.
  - Centers both left and right subtrees symmetrically around the root.
- **Summary Bracket Positioning (`position_summaries`)**:
  - Finds vertical extent $[y_{\text{bot}}, y_{\text{top}}]$ spanning from `from_node` to `to_node`.
  - Places the bracket apex at $y_{\text{mid}} = (y_{\text{top}} + y_{\text{bot}}) / 2$.
  - Positions the bracket horizontally outside the outermost child in the group.
  - Docks the summary topic card at the bracket cusp.

### Stage 5: Curve & Connector Calculation (`curve.lua`)
- **Smooth Cubic Bézier S-Curves**:
  - Exit tangent at parent anchor is horizontal.
  - Entry tangent at child anchor is horizontal.
  - Control points: $c_1 = (x_p + \Delta x/2, y_p)$, $c_2 = (x_c - \Delta x/2, y_c)$.
- **Underline Docking**:
  - Curve transitions smoothly directly into a horizontal baseline rule supporting child text.
- **Bézier Curly Brackets (`curve.generate_bracket`)**:
  - Composed of two symmetric cubic Bézier arcs meeting at a sharp horizontal cusp $(x_{\text{cusp}}, y_{\text{mid}})$.
  - Extends an anchor rule from the cusp to connect with the summary topic node.
- **Cross-Branch Relationships (`curve.generate_relationship`)**:
  - Curved dashed arrow (`->, >=stealth`) with configurable bend angle.
  - Embeds a midway white-padded text badge for relationship annotations.

### Stage 6: 4-Pass TikZ Emission (`renderer.lua`)
Emits clean, high-performance TikZ code to TeX:
1. **Pass 1**: All tree branch connection paths (curves/elbows/underlines).
2. **Pass 2**: All tree topic node shapes and labels.
3. **Pass 3**: All summary curly brackets and summary topic cards.
4. **Pass 4**: All cross-branch relationship curved dashed arrows and annotation badges.
5. Emits `scale=<factor>` and `transform shape` when requested.
