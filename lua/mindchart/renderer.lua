--[[
  mindchart/renderer.lua
  Renders the layout-calculated and styled AST into clean TikZ vector commands.
--]]

local ast = require("mindchart.ast")
local curve = require("mindchart.curve")
local theme = require("mindchart.theme")

local renderer = {}

--- Converts a hex color or named color to a TikZ color expression
--- @param col string
--- @return string
local function to_tikz_color(col)
    if not col or col == "" then return "black" end
    local clean = col:gsub("#", "")
    if #clean == 6 and clean:match("^%x+$") then
        local r, g, b = theme.hex_to_rgb(clean)
        return string.format("{rgb,255:red,%d;green,%d;blue,%d}", r, g, b)
    else
        return col
    end
end

--- Generates TikZ statements for a single node.
--- @param node table
--- @return string
local function render_node(node)
    local cx = node.x + (node.box_width / 2.0)
    local cy = node.y
    local col_tikz = to_tikz_color(node.color or "#2C3E50")

    if node.style == "capsule" or node.depth == 0 then
        -- Root / Capsule: Solid fill, high contrast white text, bold
        return string.format(
            "\\node (mc_node_%d) [fill=%s, rounded corners=6pt, text=white, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {\\textbf{%s}};",
            node.id, col_tikz, node.box_width, node.box_height, cx, cy, node.text
        )
    elseif node.style == "card" then
        -- Level 1 Card: Rounded box with colored border and white background
        return string.format(
            "\\node (mc_node_%d) [draw=%s, line width=1.2pt, fill=white, rounded corners=4pt, text={rgb,255:red,44;green,62;blue,80}, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {\\textbf{%s}};",
            node.id, col_tikz, node.box_width, node.box_height, cx, cy, node.text
        )
    elseif node.style == "boxed" then
        -- Boxed: Clean thin border card
        return string.format(
            "\\node (mc_node_%d) [draw=%s, line width=0.8pt, fill=white, rounded corners=3pt, text={rgb,255:red,44;green,62;blue,80}, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {%s};",
            node.id, col_tikz, node.box_width, node.box_height, cx, cy, node.text
        )
    else
        -- Underline style: Text sits directly on top of the underline
        local tx = node.x + node.pad_x + (node.width / 2.0)
        local ty = node.y
        return string.format(
            "\\node (mc_node_%d) [anchor=center, text={rgb,255:red,44;green,62;blue,80}, inner sep=2pt] at (%.2fpt, %.2fpt) {%s};",
            node.id, tx, ty, node.text
        )
    end
end

--- Emits the full TikZ picture to TeX.
--- @param root table The AST root node.
--- @param options table Global options.
function renderer.render(root, options)
    options = options or {}
    local line_style = options.line or "curve"
    local line_width = tonumber(options.line_width) or 1.2
    local scale = options.scale or "1"

    tex.print(string.format(
        "\\begin{tikzpicture}[baseline=(current bounding box.center), scale=%s, every node/.style={transform shape, outer sep=0pt}]",
        scale
    ))

    -- Pass 1: Draw all connection curves
    ast.traverse_preorder(root, function(node, parent)
        if parent then
            local path_cmd = curve.generate_path(parent, node, line_style, line_width)
            -- Replace raw hex in path_cmd with TikZ color
            local col_tikz = to_tikz_color(node.color or "#2C3E50")
            path_cmd = path_cmd:gsub("{#[%x%X]+}", col_tikz)
            tex.print(path_cmd)
        end
    end)

    -- Pass 2: Draw all node shapes and labels
    ast.traverse_preorder(root, function(node)
        local node_cmd = render_node(node)
        tex.print(node_cmd)
    end)

    -- Pass 3: Draw summary brackets and summary nodes
    for _, s in ipairs(ast.summaries) do
        if s.bracket and s.node then
            local bracket_cmd = curve.generate_bracket(s.bracket, s.node)
            tex.print(bracket_cmd)

            local s_node_cmd = render_node(s.node)
            tex.print(s_node_cmd)
        end
    end

    -- Pass 4: Draw cross-branch relationships
    for _, r in ipairs(ast.relationships) do
        local from_node = ast.named_nodes[r.from]
        local to_node = ast.named_nodes[r.to]
        if from_node and to_node then
            local rel_cmd = curve.generate_relationship(r, from_node, to_node)
            tex.print(rel_cmd)
        end
    end

    tex.print("\\end{tikzpicture}")
end

return renderer
