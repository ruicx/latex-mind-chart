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

---

## 3. Node Syntax & Formatting

### 3.1 Inline LaTeX & Math Formulas
Any standard LaTeX commands or math formulas can be embedded in node labels:

```latex
[Machine Learning
  [Supervised
    [Linear Model $\hat{y} = Wx + b$]
    [Complex Formula $\int_0^1 f(x)\,dx$]
  ]
  [Formatting: \textbf{Bold}, \textit{Italic}, \texttt{Code}]
]
```

### 3.2 Node Naming & Per-Node Options
Nodes can be assigned options using `key=value` after a comma:

- `name=<id>` or `id=<id>`: Assigns a unique name for overlay referencing.
- `color=<hex|name>`: Overrides branch color (e.g. `color=E74C3C` or `color=blue`).
- `side=left` or `side=right`: Forces a Level 1 branch to a specific side in a `balanced` map.

```latex
[Parent
  [Special Branch, name=sp_branch, color=E74C3C]
]
```

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
