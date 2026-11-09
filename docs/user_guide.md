# User Guide: `mindchart`

A modern, XMind-style mind map rendering package for LuaLaTeX.

---

## 1. Quick Start

### 1.1 Requirements
- Compilation Engine: **LuaLaTeX** (`lualatex`)
- Required LaTeX packages: `tikz`, `xcolor` (automatically loaded by `mindchart`)

### 1.2 Minimal Example

```latex
\documentclass{article}
\usepackage{mindchart}

\begin{document}

\begin{mindchart}
[Project Overview
  [Phase 1: Planning
    [Requirements Analysis]
    [Architecture Design]
  ]
  [Phase 2: Development
    [Core Engine]
    [User Interface]
  ]
  [Phase 3: Release]
]
\end{mindchart}

\end{document}
```

---

## 2. Configuration Options

Options can be supplied as comma-separated key-value pairs in the environment argument:

```latex
\begin{mindchart}[layout=balanced, theme=rainbow, style=classic, line=curve, scale=0.9]
...
\end{mindchart}
```

### 2.1 Layout Options (`layout = <name>`)

| Value | Description | Default |
| :--- | :--- | :---: |
| `right` | Standard logic chart growing strictly to the right. | Yes |
| `balanced` | Bi-directional balanced mind map (automatically splits Level 1 branches left & right). | No |
| `left` | Logic chart growing strictly to the left. | No |
| `org` / `down` / `vertical` | Organizational Chart / Downward Tree (root centered at top, branches descending downwards with orthogonal elbow bus lines). | No |

### 2.2 Visual Styles (`style = <name>`)

| Value | Visual Appearance |
| :--- | :--- |
| `classic` *(Default)* | Root is a solid rounded capsule; Level 1 are rounded cards; Level 2+ are clean underline branches. |
| `boxed` | Every hierarchy level uses rounded card boxes with thin colored borders. |
| `underline` | Minimalist layout where all non-root nodes rest on horizontal underline rules. |

### 2.3 Connector Line Styles (`line = <name>`)

| Value | Appearance |
| :--- | :--- |
| `curve` *(Default)* | Smooth organic cubic Bézier S-curves. |
| `tapered` / `organic` | XMind-style calligraphic ribbon connectors that start thick at the root and taper down smoothly. |
| `elbow` | Engineering/architectural rounded orthogonal lines. |
| `straight` | Direct straight connector lines. |

### 2.4 Color Themes (`theme = <name>`)

Branch theme colors automatically propagate to all subtopics:

| Theme | Description |
| :--- | :--- |
| `rainbow` *(Default)* | Vibrant multi-color palette (Coral, Orange, Emerald, Teal, Sky Blue, Purple). |
| `business` | Professional corporate palette (Navy, Slate, Teal, Bronze, Indigo). |
| `forest` | Calming natural green palette (Dark Green, Mint, Sage, Olive). |
| `monochrome` | High-contrast grayscale and black lines, optimized for academic journals. |
| `nord` | Crisp Arctic polar palette (Polar Night root, Frost Blue, Ice Blue, Glacier, Aurora Green). |
| `morandi` | Elegant, low-saturation muted pastel palette (Muted Sage, Rose, Dusty Blue, Khaki, Umber). |
| `dracula` | High-contrast dark-aesthetic tech palette (Dracula Dark root, Purple, Pink, Green, Cyan, Orange). |
| `ocean` | Deep maritime gradient palette (Midnight Navy root, Deep Sea, Pacific, Cerulean, Bright Teal). |
| `sunset` / `warm` | Warm dusk gradient palette (Deep Wine root, Crimson, Amber, Gold, Fiery Coral, Terracotta). |
| `solarized` | Precision Solarized palette (Base02 root, Blue, Cyan, Green, Yellow, Orange, Red, Magenta). |

#### 2.4.1 Custom Theme Registration (`\mindchartDefineTheme`)
You can register custom organizational or brand color themes globally in LaTeX:

```latex
\mindchartDefineTheme{mybrand}{
  root = 1A365D,
  palette = {2B6CB0, 319795, 38A169, D69E2E, E53E3E, 805AD5}
}

\begin{mindchart}[theme=mybrand]
...
\end{mindchart}
```

Or using a simple comma-separated list of colors:
```latex
\mindchartDefineTheme{minimal}{#2C3E50, #E74C3C, #3498DB, #2ECC71}
```

#### 2.4.2 Ad-Hoc Inline Palettes (`palette = {...}`)
Supply an ad-hoc custom palette directly to a specific `mindchart` environment:

```latex
\begin{mindchart}[palette={E63946, F77F00, FCBF49, 0077B6}, root_color=2C3E50]
...
\end{mindchart}
```

### 2.5 Scaling (`scale = <factor>`)
- Scales the entire mind map proportionally:
  ```latex
  \begin{mindchart}[scale=0.8] ... \end{mindchart}
  ```

### 2.6 Global Text Width & Alignment (`max_width`, `align`)
- Set default maximum wrapping width and text alignment for all nodes:
  ```latex
  \begin{mindchart}[max_width=4cm, align=left] ... \end{mindchart}
  ```

### 2.7 PDF Bookmarks & Navigation (`bookmarks = true`)
Automatically injects the mind map hierarchy into the PDF document outline / bookmarks tree (when `hyperref` is loaded), enabling instant clickable sidebar navigation in all PDF readers:

```latex
\usepackage[bookmarks=true]{hyperref}
\usepackage{mindchart}

\begin{mindchart}[bookmarks=true, bookmark_depth=3]
# System Architecture
  - Ingestion Layer
    - Kafka Event Ingestion
  - Compute Engine
...
\end{mindchart}
```

- `bookmarks=true` or `bookmarks`: Enables PDF outline generation for the chart.
- `bookmark_depth=<number>`: Maximum hierarchy depth to export (default: `4`).
- `bookmark_level=<number>`: Base starting level in the PDF outline tree (default: `1`).
- `bookmark="<text>"`: Custom outline label override for a specific node (or `bookmark=false` to exclude it).
- Math formulas and LaTeX formatting macros are automatically sanitized into clean plain-text strings for the PDF catalog.

---

## 3. Node Syntax & Formatting

### 3.1 Authoring Syntax Modes

`mindchart` supports two authoring syntaxes with automatic format detection:

#### Mode A: Markdown Indented List Syntax (Recommended)
Author topics rapidly using standard Markdown headings (`#`) and indented bullet points (`-`, `*`, `+`, `1.`):

```latex
\begin{mindchart}[layout=right, theme=rainbow]
# Deep Learning Architecture
  - Data Pipeline
    - Tokenization \& Cleaning
    - Feature Scaling: $x' = \frac{x - \mu}{\sigma}$
  - Representation Learning, name=rep
    - Convolutional Backbone, name=cnn
    - Attention Transformer, name=tf
  - Output Classifier, name=out
    - Logits \& Linear Layer: $\hat{y} = Wx + b$
    - Softmax Activation
\summary{cnn}{tf}{Feature Extractors}
\rel[bend=30]{rep}{out}{Representation Flow}
\end{mindchart}
```

You can also use pure Markdown headings (`#`, `##`, `###`):
```latex
\begin{mindchart}[theme=business]
# Project
## Phase 1
### Task 1.1
### Task 1.2
## Phase 2
### Task 2.1
\end{mindchart}
```

#### Mode B: Bracket Notation
Classic nested bracket format:

```latex
\begin{mindchart}[layout=right]
[Deep Learning Architecture
  [Representation Learning, name=rep
    [Convolutional Backbone, name=cnn]
    [Attention Transformer, name=tf]
  ]
  [Output Classifier, name=out]
]
\summary{cnn}{tf}{Feature Extractors}
\end{mindchart}
```

> **Auto-Detection**: If the first non-blank character is `[`, bracket mode is chosen; otherwise, markdown mode is chosen. You can also explicitly enforce mode via `syntax=markdown` or `syntax=bracket`.

### 3.2 Inline LaTeX & Math Formulas
Any standard LaTeX commands or math formulas can be embedded in node labels in both syntaxes:

```latex
# Machine Learning
  - Supervised Learning
    - Linear Model: $\hat{y} = Wx + b$
    - Complex Integral: $\int_0^1 f(x)\,dx$
  - Formatting: \textbf{Bold}, \textit{Italic}, \texttt{Code}
```

### 3.3 Node Naming & Per-Node Options
Nodes can be assigned options using `key=value` after a comma:

- `name=<id>` or `id=<id>`: Assigns a unique name for overlay referencing.
- `color=<hex|name>`: Overrides branch color (e.g. `color=E74C3C` or `color=blue`).
- `side=left` or `side=right`: Forces a Level 1 branch to a specific side in a `balanced` map.
- `max_width=<dim>`: Constrains maximum label width and auto-wraps long text (e.g. `max_width=3.5cm` or `max_width=120pt`).
- `align=left|center|right`: Controls horizontal text alignment within the multi-line node box.

```latex
# Architecture
  - Client Layer, name=client, color=3498DB, side=left
  - Backend Services, name=server, color=2ECC71, side=right, max_width=3.2cm, align=left
```

### 3.4 Multi-Line Text Breaks & Auto-Wrapping

`mindchart` provides flexible multi-line support:

1. **Explicit Line Breaks (`\\`)**:
   Insert `\\` anywhere within a node label:
   ```latex
   # Distributed Stream\\Processing Engine
     - Real-Time Ingestion\\\& ETL Pipeline
   ```

2. **Markdown Source Line Continuation (`\\`)**:
   In Markdown syntax, ending a source line with `\\` seamlessly continues the label onto the next indented line:
   ```latex
   - High Throughput Distributed\\
     Stream Processing Engine, name=engine
   ```

3. **Auto-Wrapping with `max_width`**:
   Specify `max_width` on the `\begin{mindchart}` environment or on individual nodes. LaTeX's paragraph engine typesets the text into exact bounding boxes:
   ```latex
   - OpenTelemetry Distributed Trace Aggregation, max_width=3.5cm, align=right
   ```

4. **Context-Aware Automatic Alignment**:
   If `align` is not explicitly set:
   - **Capsule / Card / Boxed / Badges**: Defaults to `center`.
   - **Underline Style (Right Side)**: Defaults to `left` (flush to parent branch anchor).
   - **Underline Style (Left Side)**: Defaults to `right` (flush to parent branch anchor).

### 3.5 Node Badges, Metadata Tags, and Status Indicators

`mindchart` allows adding structured metadata, step counters, priority pills, version badges, and workflow status indicators to any node:

```latex
\begin{mindchart}[theme=rainbow, style=classic]
# Release Engineering Pipeline
  - Ingestion Gateway, badge=1, tag=v2.4, status=Done
    - Kafka Event Ingestion, priority=P0, status=Done
    - Proto Schema Validation, tag=gRPC, status=Done
  - Stream Compute Engine, badge=2, tag={Flink, Rust}, status=WIP
    - Exactly-Once State Checkpoints, priority=P0, tag=High-Priority, status=WIP
    - Sliding Window Metrics, status=TODO
  - Lakehouse Storage \& Query, badge=3, tag={Iceberg, S3}, status=TODO
    - Parquet Vectorized Writer, priority=P1
    - Trino Distributed SQL Engine, tag={Analytics, BI}
\end{mindchart}
```

#### 1. Badges & Priority Markers (`badge`, `priority`)
- `badge=<string|number>`: A leading micro-badge prepended to the node text (e.g. `badge=1`, `badge=A`, `badge=P0`).
- `priority=<string|number>`: An alias for `badge` (e.g. `priority=P0`).
- **Visual Styling**:
  - `badge_style=pill` *(Default)*: Solid colored fill with bold white text. Short 1-2 character badges render as symmetric circular markers.
  - `badge_style=subtle`: Soft 15% background tint with colored text.
  - `badge_color=<color>`: Overrides badge background color (inherits branch color by default).

#### 2. Categorical Metadata Tags (`tag`, `tags`)
- `tag=<string>`: A trailing micro-pill appended after the node text (e.g. `tag=v2.4`, `tag=gRPC`).
- `tag={<string1>, <string2>, ...}`: Multiple comma-separated tags enclosed in braces (e.g. `tag={Flink, Rust}`).
- **Visual Styling**:
  - `tag_style=subtle` *(Default)*: Modern soft pastel appearance with 12% background tint, 38% border stroke, and colored text.
  - `tag_style=pill`: Solid colored fill with bold white text.
  - `tag_color=<color>`: Overrides tag color (inherits branch color by default).

#### 3. Semantic Status Indicators (`status`)
Standardized semantic workflow status indicators rendered as trailing micro-pills:
- `status=Done`: Emerald Green (`#27AE60`) completion badge.
- `status=WIP` / `status=InProgress`: Bright Orange (`#E67E22`) work-in-progress badge.
- `status=TODO`: Slate Gray (`#7F8C8D`) planned task badge.

### 3.6 Subtree Folding & Collapse (`collapsed`, `folded`)

In multi-tier or complex mind maps, authors can fold secondary branches to present a clean, high-level overview without cluttering the page:

```latex
\begin{mindchart}[theme=rainbow, style=classic, line=tapered]
# Microservices Platform
  - API Gateway
    - Authentication Envoy Filter
  - Compute Cluster, collapsed
    - Kubernetes Worker Node Pools
    - Serverless Functions
    - GPU Vector Batch Nodes
  - Distributed Storage, folded
    - S3 Object Store
    - Distributed Spanner
\end{mindchart}
```

#### Key Capabilities:
- **Automatic Descendant Counting**: Folded nodes compute the total number of collapsed sub-topics and render an XMind-style pill at the branch connection socket (e.g. `+3`, `+4`).
- **Dynamic Space Reclamation**: Collapsed subtrees do not reserve canvas whitespace, allowing adjacent sibling branches to pack tightly and conserving page margins.
- **Bi-Directional Support**: Fold indicators dock cleanly on the right side of right-growing branches and on the left side of left-growing branches across all visual styles (`classic`, `card`, `boxed`, `underline`).
- **Fold Indicator Style**: `fold_style=count` *(Default)* displays `+N` with the descendant count; `fold_style=plus` displays `+`.

### 3.7 Native Vector Icons & Symbol Indicators (`icon`, `symbol`)

`mindchart` includes a zero-dependency, pure TikZ vector micro-glyph engine for adorning topic nodes with rich status, warning, category, and highlight icons without requiring external icon font packages (such as `fontawesome5`):

```latex
\begin{mindchart}[theme=rainbow, style=classic]
# Sprint Management
  - Security Infrastructure, icon=lock, color=27AE60
    - SSL Certificate Renewal, icon=check
    - Penetration Testing, icon=fire, icon_color=E74C3C
  - Performance Optimization, icon=gear, color=3498DB
    - Memory Leak Profiling, icon=warn
    - Database Query Caching, icon=star, icon_color=F1C40F
  - Product Roadmap, icon=bulb, color=9B59B6
    - Mobile App Redesign, icon=heart
    - API Documentation, icon=info
\end{mindchart}
```

#### Supported Native Micro-Icons:
| Icon Name | Description & Visual Glyph |
| :--- | :--- |
| `check` | Emerald circled white vector checkmark. |
| `cross` | Red circled white cross indicator. |
| `star` | Golden 5-pointed vector star. |
| `flag` | Crimson flagpole with pennant. |
| `warn` | Amber warning triangle with exclamation mark. |
| `info` | Cerulean circled informational 'i'. |
| `fire` | Fiery orange two-segment Bézier flame. |
| `bulb` | Golden lightbulb / idea indicator. |
| `heart` | Crimson heart favorite glyph. |
| `lock` | Slate security padlock with shackle. |
| `gear` | Industrial multi-tooth cogwheel. |
| `circle` | Filled circular status dot. |

#### Icon Configuration Options:
- `icon=<name>` or `symbol=<name>`: Specifies the icon name from the table above.
- `icon_pos=prefix|suffix` (default: `prefix`): Positions the icon before the text/badge or at the end of the node container.
- `icon_color=<color>`: Overrides the icon's primary foreground or badge color (inherits branch color by default).
- **LaTeX Macro Fallback**: If `icon` is specified as a LaTeX macro (e.g. `icon=\faStar` or `icon=\ding{51}`), `mindchart` automatically measures the macro dimensions in a TeX box and renders it natively inside the node.

### 3.8 Custom Node Geometric Shapes (`shape=...`)

`mindchart` allows assigning explicit geometric shapes to individual topics or globally to the entire map:

```latex
\begin{mindchart}[theme=rainbow, layout=right, style=classic]
# System Control Flow, shape=capsule
  - Authorization Gateway, shape=diamond, color=E74C3C
    - Access Token Valid?, shape=diamond
    - Deny Request, shape=card, icon=cross
  - Storage Subsystem, shape=hexagon, color=3498DB
    - Sharded Shard Cluster, shape=hexagon
    - In-Memory Cache, shape=capsule, icon=lock
  - Compute Execution, shape=rect, color=2ECC71
    - Container Pod, shape=rect, icon=gear
    - Minimal Metric, shape=underline
  - Distributed State, shape=ellipse, color=9B59B6
    - Active Operational State, shape=capsule, icon=check
    - Failover Recovery Mode, shape=diamond
\end{mindchart}
```

#### Supported Geometric Shapes:
| Shape Option | Aliases | Description & Visual Form |
| :--- | :--- | :--- |
| `card` | `rounded_rect` | Modern rounded rectangle with 4pt rounded corners and theme border. |
| `capsule` | `pill`, `rounded` | Fully rounded pill container with semi-circular 180° ends. |
| `rect` | `rectangle`, `box` | Crisp sharp-cornered rectangle (`sharp corners`). |
| `diamond` | `rhombus` | 4-point diamond with automatic diagonal margin expansion and safety aspect scaling. |
| `hexagon` | `hex` | 6-point horizontal polygon with flat top/bottom and pointed left/right vertices. |
| `ellipse` | `oval`, `circle` | Smooth geometric ellipse circumscribing inner topic text. |
| `underline` | `line` | Minimalist horizontal baseline rule without outer box container. |

- **Global Configuration**: Set default shape for all nodes via `\begin{mindchart}[shape=rect]`.
- **Automatic Anchor Geometry**: Connectors, elbow buses, and relationship arrows attach precisely to the apex tip of diamonds and hexagons without clipping or piercing node labels.

---

## 4. Overlay Elements

### 4.1 Summary Brackets (`\summary`)
Encloses a group of sibling nodes with a smooth curly bracket and creates a summary card topic:

```latex
\begin{mindchart}
[Web Development
  [Frontend
    [HTML5, name=html]
    [CSS3, name=css]
    [JavaScript, name=js]
  ]
]
\summary{html}{js}{Core Web Technologies}
\end{mindchart}
```

### 4.2 Cross-Branch Relationships (`\rel`)
Draws a curved, dashed arrow with an annotation badge connecting any two nodes:

```latex
\begin{mindchart}
[Fullstack System
  [Frontend, name=fe]
  [Backend, name=be]
]
\rel[color=E74C3C, bend=30]{fe}{be}{REST API Calls}
\end{mindchart}
```

#### Relationship Options:
- `color=<hex|name>`: Line and arrow color (default: `#E74C3C`).
- `bend=<degrees>`: Curve angle (positive bends left, negative bends right, default: `25`).
- `line=<dashed|solid|dotted>`: Line stroke style (default: `dashed`).
- `pos=<factor|keyword>`: Position of label along path (`pos=0.3`, `pos=0.7`, `near start`, `near end`, default: `midway`). Useful to avoid obscuring nearby text.
- `side=<placement>`: Placement relative to line (`above`, `below`, `auto`, `sloped`).
- `from_anchor=<anchor>`, `to_anchor=<anchor>`: Specific node docking points (`north`, `south`, `east`, `west`). Defaults to automatic boundary clipping.
- `fill=<color|none>`: Background fill for label badge (default: `white`, set `none` for transparent).

### 4.3 Subtree Boundaries (`\boundary`)
Encloses a specific topic subtree (or a range of sibling subtrees) within a soft, colored rounded background or dashed border, crowned with a customizable title badge:

```latex
% Enclose an entire subtree starting at a node
\boundary[options]{target_node}{Title Badge}

% Or enclose a range of sibling subtrees
\boundary[options]{from_node}{to_node}{Title Badge}
```

```latex
\begin{mindchart}
# Deep Learning System
  - Representation Learning, name=rep
    - Convolutional Backbone, name=cnn
    - Attention Transformer, name=tf
\boundary[color=E74C3C, style=dashed]{rep}{Representation Backbone}
\end{mindchart}
```

#### Boundary Options:
- `color=<hex|name>`: Border and title badge color (automatically inherits from the target subtree's theme color if omitted).
- `style=<dashed|solid|dotted>`: Border stroke style (default: `dashed`).
- `fill=<color|none>`: Background fill color (defaults to a soft 8% tint of the branch color; set `none` for transparent background).
- `fill_opacity=<factor>`: Background fill opacity (e.g. `0.08`, `0.15`).
- `pad=<pt>`: Outer padding around the enclosed subtree bounding box (default: `5.0`).
- `rounded=<pt>`: Corner radius of the boundary box (default: `4.0`).
- `line_width=<pt>`: Border stroke width (default: `0.8`).
- `title_style=<pill|card>`: Title badge visual style (`pill` for solid colored pill with white text; `card` for white card with colored border and text; default: `pill`).
- `title_pos=<top_left|top_center|top_right|bottom_left>`: Placement of the title badge on the boundary frame (default: `top_left`).
