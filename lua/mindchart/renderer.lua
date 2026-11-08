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
--- @param options table|nil Global options
--- @return string
local function render_node(node, options)
    local cx = node.x + (node.box_width / 2.0)
    local cy = node.y
    local col_tikz = to_tikz_color(node.color or "#2C3E50")

    -- Determine alignment
    local al = node.options.align or (options and options.align)
    if not al then
        if node.style == "underline" then
            al = (node.side == "left" and "right" or "left")
        else
            al = "center"
        end
    end

    local is_multi = node.is_multiline or (node.text:find("\\\\") ~= nil) or (node.max_width ~= nil)
    local extra_opts = ""
    if is_multi then
        if node.max_width then
            extra_opts = string.format(", align=%s, text width=%.2fpt", al, node.width)
        else
            extra_opts = string.format(", align=%s", al)
        end
    end

    if node.style == "capsule" or node.depth == 0 then
        -- Root / Capsule: Solid fill, high contrast white text, bold
        return string.format(
            "\\node (mc_node_%d) [fill=%s, rounded corners=6pt, text=white, font=\\bfseries, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt%s] at (%.2fpt, %.2fpt) {%s};",
            node.id, col_tikz, node.box_width, node.box_height, extra_opts, cx, cy, node.text
        )
    elseif node.style == "card" then
        -- Level 1 Card: Rounded box with colored border and white background
        return string.format(
            "\\node (mc_node_%d) [draw=%s, line width=1.2pt, fill=white, rounded corners=4pt, text={rgb,255:red,44;green,62;blue,80}, font=\\bfseries, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt%s] at (%.2fpt, %.2fpt) {%s};",
            node.id, col_tikz, node.box_width, node.box_height, extra_opts, cx, cy, node.text
        )
    elseif node.style == "boxed" then
        -- Boxed: Clean thin border card
        return string.format(
            "\\node (mc_node_%d) [draw=%s, line width=0.8pt, fill=white, rounded corners=3pt, text={rgb,255:red,44;green,62;blue,80}, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt%s] at (%.2fpt, %.2fpt) {%s};",
            node.id, col_tikz, node.box_width, node.box_height, extra_opts, cx, cy, node.text
        )
    else
        -- Underline style: Text sits directly on top of the underline
        local tx = node.x + node.pad_x + (node.width / 2.0)
        local ty = node.y
        return string.format(
            "\\node (mc_node_%d) [anchor=center, text={rgb,255:red,44;green,62;blue,80}, inner sep=2pt%s] at (%.2fpt, %.2fpt) {%s};",
            node.id, extra_opts, tx, ty, node.text
        )
    end
end

--- Generates TikZ statements for a subtree boundary box (background).
--- @param b table
--- @return string
local function render_boundary_box(b)
    local box = b.box
    if not box then return "" end

    local col_tikz = to_tikz_color(b.color or "#2C3E50")
    local rounded = tonumber(b.options.rounded) or 4.0
    local line_w = tonumber(b.options.line_width) or 0.8
    local style = b.options.style or "dashed"

    local style_str = "dashed"
    if style == "solid" then
        style_str = "solid"
    elseif style == "dotted" then
        style_str = "dotted"
    end

    -- Fill color calculation
    local fill_str = ""
    if b.options.fill == "none" then
        fill_str = ""
    elseif b.options.fill then
        fill_str = string.format(", fill=%s", to_tikz_color(b.options.fill))
    else
        -- Default: soft 8% tint of b.color on white
        local raw_col = b.color or "#2C3E50"
        local clean = raw_col:gsub("#", "")
        if #clean == 6 and clean:match("^%x+$") then
            local r, g, b_val = theme.hex_to_rgb(clean)
            local rt = math.floor(255 - (255 - r) * 0.08 + 0.5)
            local gt = math.floor(255 - (255 - g) * 0.08 + 0.5)
            local bt = math.floor(255 - (255 - b_val) * 0.08 + 0.5)
            fill_str = string.format(", fill={rgb,255:red,%d;green,%d;blue,%d}", rt, gt, bt)
        else
            fill_str = string.format(", fill=%s!8", raw_col)
        end
    end

    local opacity_str = ""
    if b.options.fill_opacity then
        opacity_str = string.format(", fill opacity=%s", b.options.fill_opacity)
    end

    return string.format(
        "\\draw [draw=%s, %s, line width=%.2fpt, rounded corners=%.2fpt%s%s] (%.2fpt, %.2fpt) rectangle (%.2fpt, %.2fpt);",
        col_tikz, style_str, line_w, rounded, fill_str, opacity_str,
        box.x_min, box.y_min, box.x_max, box.y_max
    )
end

--- Generates TikZ statements for a subtree boundary title badge.
--- @param b table
--- @return string
local function render_boundary_badge(b)
    if not b.node or b.node.text == "" then return "" end

    local col_tikz = to_tikz_color(b.color or "#2C3E50")
    local cx = b.node.x + (b.node.box_width / 2.0)
    local cy = b.node.y
    local badge_style = b.options.title_style or "pill"

    if badge_style == "card" or badge_style == "white" then
        return string.format(
            "\\node (mc_boundary_badge_%d) [draw=%s, line width=0.8pt, fill=white, rounded corners=3pt, text=%s, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {\\scriptsize\\bfseries %s};",
            b.node.id, col_tikz, col_tikz, b.node.box_width, b.node.box_height, cx, cy, b.node.text
        )
    else
        -- Solid pill (default)
        return string.format(
            "\\node (mc_boundary_badge_%d) [fill=%s, rounded corners=3pt, text=white, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {\\scriptsize\\bfseries %s};",
            b.node.id, col_tikz, b.node.box_width, b.node.box_height, cx, cy, b.node.text
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

    -- Pass 0a: Draw all subtree boundary background boxes
    for _, b in ipairs(ast.boundaries) do
        local box_cmd = render_boundary_box(b)
        if box_cmd ~= "" then
            tex.print(box_cmd)
        end
    end

    -- Pass 0b: Draw all subtree boundary title badges
    for _, b in ipairs(ast.boundaries) do
        local badge_cmd = render_boundary_badge(b)
        if badge_cmd ~= "" then
            tex.print(badge_cmd)
        end
    end

    -- Pass 1: Draw all connection curves
    ast.traverse_preorder(root, function(node, parent)
        if parent then
            local effective_line = node.options.line or line_style
            local path_cmd = curve.generate_path(parent, node, effective_line, line_width)
            -- Replace raw hex in path_cmd with TikZ color
            local col_tikz = to_tikz_color(node.color or "#2C3E50")
            path_cmd = path_cmd:gsub("{#[%x%X]+}", col_tikz)
            tex.print(path_cmd)
        end
    end)

    -- Pass 2: Draw all node shapes and labels
    ast.traverse_preorder(root, function(node)
        local node_cmd = render_node(node, options)
        tex.print(node_cmd)
    end)

    -- Pass 3: Draw summary brackets and summary nodes
    for _, s in ipairs(ast.summaries) do
        if s.bracket and s.node then
            local bracket_cmd = curve.generate_bracket(s.bracket, s.node)
            tex.print(bracket_cmd)

            local s_node_cmd = render_node(s.node, options)
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
