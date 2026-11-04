--[[
  mindchart/renderer.lua
  Renders the layout-calculated and styled AST into clean TikZ vector commands.
--]]

local ast = require("mindchart.ast")
local curve = require("mindchart.curve")
local theme = require("mindchart.theme")

local renderer = {}

--- Converts a hex color to a TikZ rgb expression: "{rgb,255:red,R;green,G;blue,B}"
--- @param hex string
--- @return string
local function to_tikz_color(hex)
    local r, g, b = theme.hex_to_rgb(hex)
    return string.format("{rgb,255:red,%d;green,%d;blue,%d}", r, g, b)
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
            "\\node[fill=%s, rounded corners=6pt, text=white, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {\\textbf{%s}};",
            col_tikz, node.box_width, node.box_height, cx, cy, node.text
        )
    elseif node.style == "card" then
        -- Level 1 Card: Rounded box with colored border and white background
        return string.format(
            "\\node[draw=%s, line width=1.2pt, fill=white, rounded corners=4pt, text={rgb,255:red,44;green,62;blue,80}, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {\\textbf{%s}};",
            col_tikz, node.box_width, node.box_height, cx, cy, node.text
        )
    elseif node.style == "boxed" then
        -- Boxed: Clean thin border card
        return string.format(
            "\\node[draw=%s, line width=0.8pt, fill=white, rounded corners=3pt, text={rgb,255:red,44;green,62;blue,80}, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {%s};",
            col_tikz, node.box_width, node.box_height, cx, cy, node.text
        )
    else
        -- Underline style: Text sits directly on top of the underline
        local tx = node.x + node.pad_x + (node.width / 2.0)
        local ty = node.y
        return string.format(
            "\\node[anchor=center, text={rgb,255:red,44;green,62;blue,80}, inner sep=0pt] at (%.2fpt, %.2fpt) {%s};",
            tx, ty, node.text
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

    tex.print("\\begin{tikzpicture}[baseline=(current bounding box.center), every node/.style={outer sep=0pt}]")

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

    tex.print("\\end{tikzpicture}")
end

return renderer
