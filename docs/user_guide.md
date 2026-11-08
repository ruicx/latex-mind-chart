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
