--[[
  mindchart/renderer.lua
  Renders the layout-calculated and styled AST into clean TikZ vector commands.
--]]

local ast = require("mindchart.ast")
local curve = require("mindchart.curve")
local theme = require("mindchart.theme")
local icon = require("mindchart.icon")

local renderer = {}
local chart_counter = 0

--- Emits a TeX line without adding interword glue to the surrounding document.
local function emit(command)
    tex.print(command .. "%")
end

--- Wraps displayed text in optional PDF links and chart-local destinations.
local function linked_text(node)
    local text, opts = node.text, node.options
    if opts.href then
        text = string.format("\\mindchartLink{href}{%s}{%s}", opts.href, text)
    elseif opts.ref then
        text = string.format("\\mindchartLink{ref}{%s}{%s}", opts.ref, text)
    elseif opts.target then
        text = string.format("\\mindchartLink{target}{%s}{%s}", opts.target, text)
    elseif opts.node_ref then
        local target = ast.named_nodes[opts.node_ref]
        if not target or not ast.is_node_visible(target) then
            error("mindchart: node_ref must name a visible node: " .. opts.node_ref)
        end
        text = string.format("\\mindchartLink{target}{mc-link-%d-%d}{%s}", chart_counter, target.id, text)
    end
    if node.name then
        text = string.format("\\mindchartDestination{mc-link-%d-%d}{%s}", chart_counter, node.id, text)
    end
    if opts.label then text = string.format("\\mindchartDestination{%s}{%s}", opts.label, text) end
    return text
end

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
    local text = linked_text(node)
    local cx = node.x + (node.box_width / 2.0)
    local cy = node.y
    local col_tikz = to_tikz_color(node.color or "#2C3E50")

    local sh = node.shape or (node.style == "underline" and "underline" or (node.depth == 0 and "capsule" or "card"))

    -- Determine alignment
    local al = node.options.align or (options and options.align)
    if not al then
        if sh == "underline" or node.style == "underline" then
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

    -- Determine fill / stroke mode
    local is_solid = (node.depth == 0 and node.options.fill ~= "none" and node.options.fill ~= "white")
                     or (node.options.fill == "solid" or node.options.fill == true)

    local style_str = ""
    local text_col = "{rgb,255:red,44;green,62;blue,80}"
    local font_str = ", font={" .. theme.font(node) .. "}"

    if is_solid then
        style_str = string.format("fill=%s", col_tikz)
        text_col = "white"
    else
        local lw = (node.style == "boxed") and "0.8pt" or "1.0pt"
        style_str = string.format("draw=%s, line width=%s, fill=white", col_tikz, lw)
    end

    if node.options.fill and node.options.fill ~= "solid" and node.options.fill ~= true then
        style_str = style_str .. ", fill=" .. to_tikz_color(node.options.fill)
        text_col = "{rgb,255:red,44;green,62;blue,80}"
    end
    if node.options.draw then style_str = style_str .. ", draw=" .. to_tikz_color(node.options.draw) end
    if node.options.line_width then style_str = style_str .. ", line width=" .. node.options.line_width .. "pt" end
    if node.options.text_color then text_col = to_tikz_color(node.options.text_color) end

    -- Determine shape option in TikZ
    local shape_opt = "rounded corners=4pt"
    if sh == "capsule" then
        shape_opt = "rounded rectangle, rounded rectangle arc length=180"
    elseif sh == "card" then
        local rc = (node.style == "boxed") and "3pt" or "4pt"
        shape_opt = string.format("rounded corners=%s", rc)
    elseif sh == "rect" then
        shape_opt = "sharp corners"
    elseif sh == "diamond" then
        local aspect = math.max(1.0, math.min(3.5, node.box_width / math.max(1.0, node.box_height)))
        shape_opt = string.format("diamond, aspect=%.2f", aspect)
    elseif sh == "ellipse" then
        shape_opt = "ellipse"
    elseif sh == "badge" then
        shape_opt = "rounded corners=3pt"
    end

    local has_badge = (node.badge_obj and node.badge_obj.width ~= nil)
    local has_tags = (node.tag_objs and #node.tag_objs > 0)
    local has_icon = (node.icon_obj ~= nil)

    if not has_badge and not has_tags and not has_icon then
        if sh == "underline" then
            -- Underline style: Text sits directly on top of the underline
            local tx = node.x + node.pad_x + (node.width / 2.0)
            local ty = node.y
            return string.format(
                "\\node (mc_node_%d) [anchor=center, text=%s%s, inner sep=2pt%s] at (%.2fpt, %.2fpt) {%s};",
                node.id, text_col, font_str, extra_opts, tx, ty, text
            )
        elseif sh == "hexagon" then
            local hw = node.box_width / 2.0
            local hh = node.box_height / 2.0
            local dx = math.min(10.0, hh)
            local hex_path = string.format(
                "\\filldraw[%s] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- cycle;",
                style_str,
                cx - hw + dx, cy + hh,
                cx + hw - dx, cy + hh,
                cx + hw, cy,
                cx + hw - dx, cy - hh,
                cx - hw + dx, cy - hh,
                cx - hw, cy
            )
            local node_cmd = string.format(
                "\\node (mc_node_%d) [text=%s%s, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt%s] at (%.2fpt, %.2fpt) {%s};",
                node.id, text_col, font_str, node.box_width, node.box_height, extra_opts, cx, cy, text
            )
            return hex_path .. " " .. node_cmd
        else
            return string.format(
                "\\node (mc_node_%d) [%s, %s, text=%s%s, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt%s] at (%.2fpt, %.2fpt) {%s};",
                node.id, shape_opt, style_str, text_col, font_str, node.box_width, node.box_height, extra_opts, cx, cy, text
            )
        end
    end

    -- Compound node containing badge, text, and/or tags
    local parts = {}

    -- 1. Container shape (named mc_node_<id> for relationship anchors)
    if sh == "underline" then
        table.insert(parts, string.format(
            "\\node (mc_node_%d) [anchor=center, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {};",
            node.id, node.box_width, node.box_height, cx, cy
        ))
    elseif sh == "hexagon" then
        local hw = node.box_width / 2.0
        local hh = node.box_height / 2.0
        local dx = math.min(10.0, hh)
        table.insert(parts, string.format(
            "\\filldraw[%s] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- cycle;",
            style_str,
            cx - hw + dx, cy + hh,
            cx + hw - dx, cy + hh,
            cx + hw, cy,
            cx + hw - dx, cy - hh,
            cx - hw + dx, cy - hh,
            cx - hw, cy
        ))
        table.insert(parts, string.format(
            "\\node (mc_node_%d) [minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {};",
            node.id, node.box_width, node.box_height, cx, cy
        ))
    else
        table.insert(parts, string.format(
            "\\node (mc_node_%d) [%s, %s, minimum width=%.2fpt, minimum height=%.2fpt, inner sep=0pt] at (%.2fpt, %.2fpt) {};",
            node.id, shape_opt, style_str, node.box_width, node.box_height, cx, cy
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

    -- 2.5 Prefix Icon
    if has_icon and node.icon_obj.pos ~= "suffix" then
        local ico = node.icon_obj
        local ix = x_cur + (ico.box_width / 2.0)
        local ico_cmd = icon.render(ico, ix, cy, node.color)
        table.insert(parts, ico_cmd)
        x_cur = x_cur + ico.box_width + ico.gap
    end

    -- 3. Main Text
    table.insert(parts, string.format(
        "\\node [anchor=west, text=%s%s, inner sep=0pt%s] at (%.2fpt, %.2fpt) {%s};",
        text_col, font_str, extra_opts, x_cur, cy, text
    ))
    x_cur = x_cur + node.width

    -- 3.5 Suffix Icon
    if has_icon and node.icon_obj.pos == "suffix" then
        local ico = node.icon_obj
        x_cur = x_cur + ico.gap
        local ix = x_cur + (ico.box_width / 2.0)
        local ico_cmd = icon.render(ico, ix, cy, node.color)
        table.insert(parts, ico_cmd)
        x_cur = x_cur + ico.box_width
    end

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
    chart_counter = chart_counter + 1
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
                    local dest_name = string.format("mc_chart_%d_node_%d", chart_counter, n.id)
                    emit(string.format("\\mindchartEmitBookmark{%d}{%s}{%s}", lvl, bm_title, dest_name))
                end
            end
        end)
    end

    if options.fit_width or options.fit_height then
        emit(string.format("\\mindchartFitBegin{%s}{%s}", options.fit_width or "0pt", options.fit_height or "0pt"))
    end
    emit(string.format(
        "\\begin{tikzpicture}[baseline=(current bounding box.center), scale=%s, every node/.style={transform shape, outer sep=0pt}]",
        scale
    ))

    -- Pass 0a: Draw all subtree boundary background boxes
    for _, b in ipairs(ast.boundaries) do
        local box_cmd = render_boundary_box(b)
        if box_cmd ~= "" then
            emit(box_cmd)
        end
    end

    -- Pass 0b: Draw all subtree boundary title badges
    for _, b in ipairs(ast.boundaries) do
        local badge_cmd = render_boundary_badge(b)
        if badge_cmd ~= "" then
            emit(badge_cmd)
        end
    end

    -- Pass 1: Draw all connection curves (visible nodes only)
    if root.is_fishbone then
        local root_col = to_tikz_color(root.color or "#2C3E50")
        emit(string.format(
            "\\draw[draw=%s, line width=2.4pt, ->, >=stealth] (%.2fpt, 0pt) -- (%.2fpt, 0pt);",
            root_col, root.spine_start_x or 0.0, root.spine_end_x or root.x
        ))
    end

    ast.traverse_visible(root, function(node, parent)
        if parent then
            local effective_line = node.options.line or line_style
            local path_cmd = curve.generate_path(parent, node, effective_line, line_width)
            -- Replace raw hex in path_cmd with TikZ color
            local col_tikz = to_tikz_color(node.color or "#2C3E50")
            path_cmd = path_cmd:gsub("{#[%x%X]+}", col_tikz)
            emit(path_cmd)
        end
    end)

    -- Pass 2: Draw all node shapes and labels (visible nodes only)
    ast.traverse_visible(root, function(node)
        local node_cmd = render_node(node, options)
        emit(node_cmd)

        -- If node is collapsed, draw fold indicator pill
        if node.collapsed and #node.children > 0 then
            local fold_cmd = render_fold_indicator(node)
            if fold_cmd ~= "" then
                emit(fold_cmd)
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
                emit(bracket_cmd)

                local s_node_cmd = render_node(s.node, options)
                emit(s_node_cmd)
            end
        end
    end

    for _, note in ipairs(ast.notes) do
        if note.visible then emit(render_node(note.node, options)) end
    end

    -- Pass 4: Draw cross-branch relationships
    for _, r in ipairs(ast.relationships) do
        local from_node = ast.named_nodes[r.from]
        local to_node = ast.named_nodes[r.to]
        if from_node and to_node and ast.is_node_visible(from_node) and ast.is_node_visible(to_node) then
            local rel_cmd = curve.generate_relationship(r, from_node, to_node)
            emit(rel_cmd)
        end
    end

    emit("\\end{tikzpicture}")
    if options.fit_width or options.fit_height then emit("\\mindchartFitEnd") end
end

return renderer
