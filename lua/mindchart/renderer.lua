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

--- Calculates a soft pastel tint RGB or fallback for borders and fills.
--- @param hex_or_name string
--- @param factor number 0.0 to 1.0 (e.g. 0.12 for 12% tint)
--- @return string
local function get_tint_rgb(hex_or_name, factor)
    if not hex_or_name or hex_or_name == "" then
        hex_or_name = "#2C3E50"
    end
    local clean = hex_or_name:gsub("#", "")
    if #clean == 6 and clean:match("^%x+$") then
        local r, g, b = theme.hex_to_rgb(clean)
        local rt = math.floor(255 - (255 - r) * factor + 0.5)
        local gt = math.floor(255 - (255 - g) * factor + 0.5)
        local bt = math.floor(255 - (255 - b) * factor + 0.5)
        return string.format("{rgb,255:red,%d;green,%d;blue,%d}", rt, gt, bt)
    else
        return string.format("%s!%d", hex_or_name, math.floor(factor * 100))
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

    local has_badge = (node.badge_obj and node.badge_obj.width ~= nil)
    local has_tags = (node.tag_objs and #node.tag_objs > 0)

    if not has_badge and not has_tags then
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

    -- Compound node containing badge, text, and/or tags
    local parts = {}

    -- 1. Container shape (named mc_node_<id> for relationship anchors)
    if node.style == "capsule" or node.depth == 0 then
        table.insert(parts, string.format(
            "\\node (mc_node_%d) [fill=%s, rounded corners=6pt, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {};",
            node.id, col_tikz, node.box_width, node.box_height, cx, cy
        ))
    elseif node.style == "card" then
        table.insert(parts, string.format(
            "\\node (mc_node_%d) [draw=%s, line width=1.2pt, fill=white, rounded corners=4pt, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {};",
            node.id, col_tikz, node.box_width, node.box_height, cx, cy
        ))
    elseif node.style == "boxed" then
        table.insert(parts, string.format(
            "\\node (mc_node_%d) [draw=%s, line width=0.8pt, fill=white, rounded corners=3pt, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {};",
            node.id, col_tikz, node.box_width, node.box_height, cx, cy
        ))
    else
        table.insert(parts, string.format(
            "\\node (mc_node_%d) [anchor=center, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {};",
            node.id, node.box_width, node.box_height, cx, cy
        ))
    end

    local x_cur = node.x + node.pad_x

    -- 2. Badge (leading)
    if has_badge then
        local b = node.badge_obj
        local bx = x_cur + (b.box_width / 2.0)
        local b_col = to_tikz_color(b.color or node.color or "#2C3E50")
        if b.options.style == "subtle" then
            local bg_tint = get_tint_rgb(b.color or node.color or "#2C3E50", 0.15)
            table.insert(parts, string.format(
                "\\node (mc_badge_%d) [fill=%s, rounded corners=3pt, text=%s, font=\\scriptsize\\bfseries, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {%s};",
                b.id, bg_tint, b_col, b.box_width, b.box_height, bx, cy, b.text
            ))
        else
            table.insert(parts, string.format(
                "\\node (mc_badge_%d) [fill=%s, rounded corners=3pt, text=white, font=\\scriptsize\\bfseries, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {%s};",
                b.id, b_col, b.box_width, b.box_height, bx, cy, b.text
            ))
        end
        x_cur = x_cur + b.box_width + b.gap
    end

    -- 3. Main Text
    local text_font = ""
    local text_col = "{rgb,255:red,44;green,62;blue,80}"
    if node.style == "capsule" or node.depth == 0 then
        text_col = "white"
        text_font = ", font=\\bfseries"
    elseif node.style == "card" then
        text_font = ", font=\\bfseries"
    end

    table.insert(parts, string.format(
        "\\node [anchor=west, text=%s%s, inner sep=0pt%s] at (%.2fpt, %.2fpt) {%s};",
        text_col, text_font, extra_opts, x_cur, cy, node.text
    ))
    x_cur = x_cur + node.width

    -- 4. Tags (trailing)
    if has_tags then
        x_cur = x_cur + 6.0
        for _, t in ipairs(node.tag_objs) do
            local tag_x = x_cur + (t.box_width / 2.0)
            local t_col = to_tikz_color(t.color or node.color or "#2C3E50")
            if t.options.style == "pill" then
                table.insert(parts, string.format(
                    "\\node (mc_tag_%d) [fill=%s, rounded corners=2.5pt, text=white, font=\\tiny\\bfseries, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {%s};",
                    t.id, t_col, t.box_width, t.box_height, tag_x, cy, t.text
                ))
            else
                -- Default subtle style
                local bg_tint = get_tint_rgb(t.color or node.color or "#2C3E50", 0.12)
                local border_tint = get_tint_rgb(t.color or node.color or "#2C3E50", 0.38)
                table.insert(parts, string.format(
                    "\\node (mc_tag_%d) [draw=%s, line width=0.6pt, fill=%s, rounded corners=2.5pt, text=%s, font=\\tiny\\bfseries, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {%s};",
                    t.id, border_tint, bg_tint, t_col, t.box_width, t.box_height, tag_x, cy, t.text
                ))
            end
            x_cur = x_cur + t.box_width + t.gap
        end
    end

    return table.concat(parts, " ")
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
    if not b.box or not b.node or b.node.text == "" then return "" end

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

--- Generates TikZ statements for an XMind-style fold/collapse indicator badge.
--- @param node table
--- @return string
local function render_fold_indicator(node)
    if not node or not node.collapsed or #node.children == 0 then return "" end

    local is_down = (node.side == "down")
    local is_right = (node.side ~= "left")
    local col_tikz = to_tikz_color(node.color or "#2C3E50")

    local anchor_y
    if node.style == "underline" then
        anchor_y = node.y - (node.box_height / 2.0)
    else
        anchor_y = node.y
    end

    local stem_x1, stem_x2, badge_x
    local stem_y1, stem_y2, badge_y
    if is_down then
        local cx = node.x + (node.box_width / 2.0)
        local y_edge = node.y - (node.box_height / 2.0)
        stem_x1 = cx
        stem_x2 = cx
        badge_x = cx
        stem_y1 = y_edge
        stem_y2 = y_edge - 5.0
        badge_y = y_edge - 12.0
    elseif is_right then
        local x_edge = node.x + node.box_width
        stem_x1 = x_edge
        stem_x2 = x_edge + 5.0
        badge_x = x_edge + 12.0
        stem_y1 = anchor_y
        stem_y2 = anchor_y
        badge_y = anchor_y
    else
        local x_edge = node.x
        stem_x1 = x_edge
        stem_x2 = x_edge - 5.0
        badge_x = x_edge - 12.0
        stem_y1 = anchor_y
        stem_y2 = anchor_y
        badge_y = anchor_y
    end

    local count_str
    if node.options.fold_style == "plus" then
        count_str = "+"
    else
        count_str = "+" .. tostring(node.folded_count or #node.children)
    end

    local parts = {}
    -- Stem connecting line
    table.insert(parts, string.format(
        "\\draw [draw=%s, line width=1.0pt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
        col_tikz, stem_x1, stem_y1, stem_x2, stem_y2
    ))
    -- Pill / circle badge
    table.insert(parts, string.format(
        "\\node (mc_fold_%d) [fill=%s, rounded corners=3pt, text=white, font=\\tiny\\bfseries, minimum height=9.0pt, inner sep=1.8pt] at (%.2fpt, %.2fpt) {%s};",
        node.id, col_tikz, badge_x, badge_y, count_str
    ))

    return table.concat(parts, " ")
end

--- Sanitizes LaTeX node text into a clean plain-text string for PDF bookmarks.
--- @param text string
--- @return string
local function sanitize_for_bookmark(text)
    if not text or text == "" then return "" end
    local s = tostring(text)
    -- Replace \\ with space
    s = s:gsub("\\\\", " ")
    -- Replace \frac{num}{den} with num/den
    s = s:gsub("\\frac%s*(%b{})%s*(%b{})", function(num, den)
        return num:sub(2, -2) .. "/" .. den:sub(2, -2)
    end)
    -- Strip math mode delimiters ($...$)
    s = s:gsub("%$(.-)%$", "%1")
    -- Strip LaTeX formatting commands: \textbf{...}, \textit{...}, etc.
    s = s:gsub("\\[%a]+%*?%s*(%b{})", function(grp)
        return grp:sub(2, -2)
    end)
    -- Keep Greek/math command names without backslash (\alpha -> alpha, \mu -> mu)
    -- while preserving escaped characters like \&, \%, \_
    s = s:gsub("\\([%a]+)", "%1")
    -- Strip curly braces
    s = s:gsub("[{}]", "")
    -- Normalize whitespace
    s = s:gsub("%s+", " ")
    s = s:match("^%s*(.-)%s*$") or ""
    return s
end

renderer.sanitize_for_bookmark = sanitize_for_bookmark

--- Emits the full TikZ picture to TeX.
--- @param root table The AST root node.
--- @param options table Global options.
function renderer.render(root, options)
    options = options or {}
    local is_vertical = (options.layout == "org" or options.layout == "down" or options.layout == "vertical" or options.layout == "tree_down")
    local line_style = options.line or (is_vertical and "elbow" or "curve")
    local line_width = tonumber(options.line_width) or 1.2
    local scale = options.scale or "1"

    -- Emit PDF Bookmarks if requested
    if options.bookmarks == true or options.bookmarks == "true" or options.pdf_bookmarks then
        local base_lvl = tonumber(options.bookmark_level) or 1
        local max_d = tonumber(options.bookmark_depth) or 4
        local trav = (options.bookmark_collapsed == true or options.bookmark_collapsed == "true")
                     and ast.traverse_preorder or ast.traverse_visible
        trav(root, function(n)
            if n.depth <= max_d and n.options.bookmark ~= "false" and n.options.bookmark ~= false then
                local bm_title = n.options.bookmark or sanitize_for_bookmark(n.text)
                if bm_title ~= "" then
                    local lvl = base_lvl + n.depth
                    local dest_name = string.format("mc_node_%d", n.id)
                    tex.print(string.format("\\mindchartEmitBookmark{%d}{%s}{%s}", lvl, bm_title, dest_name))
                end
            end
        end)
    end

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

    -- Pass 1: Draw all connection curves (visible nodes only)
    ast.traverse_visible(root, function(node, parent)
        if parent then
            local effective_line = node.options.line or line_style
            local path_cmd = curve.generate_path(parent, node, effective_line, line_width)
            -- Replace raw hex in path_cmd with TikZ color
            local col_tikz = to_tikz_color(node.color or "#2C3E50")
            path_cmd = path_cmd:gsub("{#[%x%X]+}", col_tikz)
            tex.print(path_cmd)
        end
    end)

    -- Pass 2: Draw all node shapes and labels (visible nodes only)
    ast.traverse_visible(root, function(node)
        local node_cmd = render_node(node, options)
        tex.print(node_cmd)

        -- If node is collapsed, draw fold indicator pill
        if node.collapsed and #node.children > 0 then
            local fold_cmd = render_fold_indicator(node)
            if fold_cmd ~= "" then
                tex.print(fold_cmd)
            end
        end
    end)

    -- Pass 3: Draw summary brackets and summary nodes
    for _, s in ipairs(ast.summaries) do
        local from_node = ast.named_nodes[s.from]
        local to_node = ast.named_nodes[s.to]
        if from_node and to_node and ast.is_node_visible(from_node) and ast.is_node_visible(to_node) then
            if s.bracket and s.node then
                local bracket_cmd = curve.generate_bracket(s.bracket, s.node)
                tex.print(bracket_cmd)

                local s_node_cmd = render_node(s.node, options)
                tex.print(s_node_cmd)
            end
        end
    end

    -- Pass 4: Draw cross-branch relationships
    for _, r in ipairs(ast.relationships) do
        local from_node = ast.named_nodes[r.from]
        local to_node = ast.named_nodes[r.to]
        if from_node and to_node and ast.is_node_visible(from_node) and ast.is_node_visible(to_node) then
            local rel_cmd = curve.generate_relationship(r, from_node, to_node)
            tex.print(rel_cmd)
        end
    end

    tex.print("\\end{tikzpicture}")
end

return renderer
