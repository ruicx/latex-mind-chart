--[[
  mindchart/curve.lua
  Calculates geometric connection paths between parent and child nodes.
--]]

local theme = require("mindchart.theme")

local curve = {}

--- Checks whether a node should be treated as an underline node.
--- @param node table|nil
--- @return boolean
local function is_underline(node)
    if not node then return false end
    if node.shape then
        return node.shape == "underline"
    end
    return node.style == "underline"
end

--- Calculates the anchor point coordinates for parent exit and child entry.
--- @param parent table
--- @param child table
--- @return number, number, number, number, number, number
--- (xp, yp, xc, yc, x_line_end, y_line_end)
function curve.get_anchors(parent, child)
    if child.side == "down" then
        local xp = parent.x + (parent.box_width / 2.0)
        local yp = parent.y - (parent.box_height / 2.0)
        local xc = child.x + (child.box_width / 2.0)
        local yc = child.y + (child.box_height / 2.0)
        local x_line_end = xc
        local y_line_end = yc
        if is_underline(child) then
            y_line_end = child.y - (child.box_height / 2.0)
        end
        return xp, yp, xc, yc, x_line_end, y_line_end
    end

    local xp, yp
    local is_right = (child.side == "right")

    -- Parent exit point
    if is_right then
        xp = parent.x + parent.box_width
    else
        xp = parent.x
    end

    if is_underline(parent) then
        yp = parent.y - (parent.box_height / 2.0)
    else
        yp = parent.y
    end

    -- Child entry point
    local xc, yc, x_line_end, y_line_end
    if is_right then
        xc = child.x
        if is_underline(child) then
            yc = child.y - (child.box_height / 2.0)
            x_line_end = child.x + child.box_width
            y_line_end = yc
        else
            yc = child.y
            x_line_end = xc
            y_line_end = yc
        end
    else
        xc = child.x + child.box_width
        if is_underline(child) then
            yc = child.y - (child.box_height / 2.0)
            x_line_end = child.x
            y_line_end = yc
        else
            yc = child.y
            x_line_end = xc
            y_line_end = yc
        end
    end

    return xp, yp, xc, yc, x_line_end, y_line_end
end

--- Generates a TikZ path string for a tapered organic ribbon connector.
--- Starts wide at parent and smoothly tapers down to child along cubic Bézier curves.
--- @param parent table
--- @param child table
--- @param line_width number Global line width multiplier (default 1.2)
--- @return string TikZ fill and draw command
function curve.generate_tapered_path(parent, child, line_width)
    local xp, yp, xc, yc, x_end, y_end = curve.get_anchors(parent, child)
    local col = theme.to_tikz_color(child.color or "#2C3E50")
    local lw = line_width or 1.2
    local lw_scale = lw / 1.2

    -- Determine ribbon widths based on parent hierarchy depth
    local start_w, end_w
    if parent.depth == 0 then
        -- Root to Level 1: iconic wide organic ribbon
        start_w = 7.5 * lw_scale
        end_w = 2.0 * lw_scale
    elseif parent.depth == 1 then
        -- Level 1 to Level 2
        start_w = 2.8 * lw_scale
        end_w = 1.3 * lw_scale
    else
        -- Level 2+
        start_w = 1.6 * lw_scale
        end_w = 1.1 * lw_scale
    end

    if child.options.start_w then
        start_w = tonumber(child.options.start_w) or start_w
    end
    if child.options.end_w then
        end_w = tonumber(child.options.end_w) or end_w
    end

    local w0 = start_w / 2.0
    local w1 = end_w / 2.0

    if child.side == "down" then
        local yp_eff = yp
        if not is_underline(parent) then
            yp_eff = yp + 1.5
        else
            yp_eff = yp + 0.5
        end

        local yc_eff = yc
        if not is_underline(child) then
            yc_eff = yc - 1.5
        end

        local dy = yc_eff - yp_eff
        local c1y = yp_eff + (dy * 0.5)
        local c2y = yc_eff - (dy * 0.5)

        local ribbon_fill = string.format(
            "\\fill[fill=%s] (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) -- cycle;",
            col,
            xp - w0, yp_eff,
            xp - w0, c1y,
            xc - w1, c2y,
            xc - w1, yc_eff,
            xc + w1, yc_eff,
            xc + w1, c2y,
            xp + w0, c1y,
            xp + w0, yp_eff
        )

        if is_underline(child) then
            local underline_draw = string.format(
                "\\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                col, end_w, child.x, child.y - (child.box_height / 2.0), child.x + child.box_width, child.y - (child.box_height / 2.0)
            )
            return ribbon_fill .. " " .. underline_draw
        else
            return ribbon_fill
        end
    end

    local is_right = (child.side == "right")
    local sign = is_right and 1.0 or -1.0

    -- Overlap slightly into parent if parent has a solid filled shape (capsule, card, boxed)
    local xp_eff = xp
    if not is_underline(parent) then
        xp_eff = xp - (sign * 1.5)
    else
        xp_eff = xp - (sign * 0.5)
    end

    -- Overlap slightly into child if child has a solid box/card
    local xc_eff = xc
    if not is_underline(child) then
        xc_eff = xc + (sign * 1.5)
    end

    local dx = xc_eff - xp_eff
    local c1x = xp_eff + (dx * 0.5)
    local c2x = xc_eff - (dx * 0.5)

    local ribbon_fill = string.format(
        "\\fill[fill=%s] (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) -- cycle;",
        col,
        xp_eff, yp + w0,
        c1x, yp + w0,
        c2x, yc + w1,
        xc_eff, yc + w1,
        xc_eff, yc - w1,
        c2x, yc - w1,
        c1x, yp - w0,
        xp_eff, yp - w0
    )

    if is_underline(child) then
        local underline_draw = string.format(
            "\\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
            col, end_w, xc, yc, x_end, y_end
        )
        return ribbon_fill .. " " .. underline_draw
    else
        return ribbon_fill
    end
end

--- Generates a TikZ path string connecting parent and child.
--- @param parent table
--- @param child table
--- @param line_style string "curve" | "elbow" | "straight" | "tapered"
--- @param line_width number Line width in pt
--- @return string TikZ draw command
function curve.generate_path(parent, child, line_style, line_width)
    local col = theme.to_tikz_color(child.color or "#2C3E50")
    local lw = line_width or 1.2

    if child.is_fishbone then
        if child.joint_x and child.rib_start_x then
            -- Category Rib connecting to spine
            return string.format(
                "\\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                col, lw * 1.35,
                child.rib_start_x, child.rib_start_y,
                child.joint_x, child.joint_y
            )
        elseif child.attach_x then
            -- Cause branch connecting horizontally to the rib
            if is_underline(child) then
                local ul_y = child.y - (child.box_height / 2.0)
                return string.format(
                    "\\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt); \\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                    col, lw, child.x + child.box_width, ul_y, child.attach_x, ul_y,
                    col, lw, child.x, ul_y, child.x + child.box_width, ul_y
                )
            else
                return string.format(
                    "\\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                    col, lw, child.x + child.box_width, child.y, child.attach_x, child.y
                )
            end
        end
    end

    local xp, yp, xc, yc, x_end, y_end = curve.get_anchors(parent, child)

    if child.side == "down" then
        if line_style == "tapered" or line_style == "organic" then
            return curve.generate_tapered_path(parent, child, line_width)
        elseif line_style == "elbow" then
            local mid_y = (yp + yc) / 2.0
            if is_underline(child) then
                local ul_y = child.y - (child.box_height / 2.0)
                return string.format(
                    "\\draw[draw=%s, line width=%.2fpt, rounded corners=3pt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt); \\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                    col, lw, xp, yp, xp, mid_y, xc, mid_y, xc, yc,
                    col, lw, child.x, ul_y, child.x + child.box_width, ul_y
                )
            else
                return string.format(
                    "\\draw[draw=%s, line width=%.2fpt, rounded corners=3pt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                    col, lw, xp, yp, xp, mid_y, xc, mid_y, xc, yc
                )
            end
        elseif line_style == "straight" then
            if is_underline(child) then
                local ul_y = child.y - (child.box_height / 2.0)
                return string.format(
                    "\\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt); \\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                    col, lw, xp, yp, xc, yc,
                    col, lw, child.x, ul_y, child.x + child.box_width, ul_y
                )
            else
                return string.format(
                    "\\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                    col, lw, xp, yp, xc, yc
                )
            end
        else
            -- Default: Smooth vertical cubic Bézier S-curve
            local dy = yc - yp
            local c1y = yp + (dy * 0.5)
            local c2y = yc - (dy * 0.5)
            if is_underline(child) then
                local ul_y = child.y - (child.box_height / 2.0)
                return string.format(
                    "\\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt); \\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                    col, lw, xp, yp, xp, c1y, xc, c2y, xc, yc,
                    col, lw, child.x, ul_y, child.x + child.box_width, ul_y
                )
            else
                return string.format(
                    "\\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt);",
                    col, lw, xp, yp, xp, c1y, xc, c2y, xc, yc
                )
            end
        end
    end

    if line_style == "tapered" or line_style == "organic" then
        return curve.generate_tapered_path(parent, child, line_width)
    elseif line_style == "elbow" then
        local mid_x = (xp + xc) / 2.0
        if is_underline(child) then
            return string.format(
                "\\draw[draw=%s, line width=%.2fpt, rounded corners=3pt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) |- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                col, lw, xp, yp, mid_x, yp, xc, yc, x_end, y_end
            )
        else
            return string.format(
                "\\draw[draw=%s, line width=%.2fpt, rounded corners=3pt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) |- (%.2fpt, %.2fpt);",
                col, lw, xp, yp, mid_x, yp, xc, yc
            )
        end
    elseif line_style == "straight" then
        if is_underline(child) then
            return string.format(
                "\\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                col, lw, xp, yp, xc, yc, x_end, y_end
            )
        else
            return string.format(
                "\\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                col, lw, xp, yp, xc, yc
            )
        end
    else
        -- Default: Smooth cubic Bézier S-curve
        local dx = xc - xp
        local c1x = xp + (dx * 0.5)
        local c1y = yp
        local c2x = xc - (dx * 0.5)
        local c2y = yc

        if is_underline(child) then
            return string.format(
                "\\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                col, lw, xp, yp, c1x, c1y, c2x, c2y, xc, yc, x_end, y_end
            )
        else
            return string.format(
                "\\draw[draw=%s, line width=%.2fpt] (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt);",
                col, lw, xp, yp, c1x, c1y, c2x, c2y, xc, yc
            )
        end
    end
end

--- Generates a TikZ path string for a curly summary bracket.
--- @param b table Bracket geometry table { x, y_top, y_bot, y_mid, w, side, color }
--- @param node table The associated summary node
--- @return string TikZ draw command
function curve.generate_bracket(b, node)
    local col = theme.to_tikz_color(b.color or "#2C3E50")
    local w = b.w or 10.0

    if b.side == "down" then
        local cusp_y = b.y - w
        local mid_ctrl_y = b.y - (w * 0.5)
        local node_connect_y = node.y + (node.box_height / 2.0)

        local path = string.format(
            "\\draw[draw=%s, line width=1.3pt] (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
            col,
            b.x_left, b.y,
            b.x_left, mid_ctrl_y,
            b.x_mid, mid_ctrl_y,
            b.x_mid, cusp_y,
            b.x_mid, mid_ctrl_y,
            b.x_right, mid_ctrl_y,
            b.x_right, b.y,
            b.x_mid, cusp_y,
            b.x_mid, node_connect_y
        )
        return path
    end

    local is_right = (b.side ~= "left")
    local sign = is_right and 1.0 or -1.0

    local cusp_x = b.x + (sign * w)
    local mid_ctrl_x = b.x + (sign * w * 0.5)

    local node_connect_x = is_right and node.x or (node.x + node.box_width)

    local path = string.format(
        "\\draw[draw=%s, line width=1.3pt] (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
        col,
        b.x, b.y_top,
        mid_ctrl_x, b.y_top,
        mid_ctrl_x, b.y_mid,
        cusp_x, b.y_mid,
        mid_ctrl_x, b.y_mid,
        mid_ctrl_x, b.y_bot,
        b.x, b.y_bot,
        cusp_x, b.y_mid,
        node_connect_x, b.y_mid
    )
    return path
end

--- Generates a TikZ path string for a cross-branch relationship arrow.
--- @param r table Relationship descriptor { from, to, text, options }
--- @param from_node table
--- @param to_node table
--- @return string TikZ draw command
function curve.generate_relationship(r, from_node, to_node)
    local opts = r.options or {}
    local col = theme.to_tikz_color(opts.color or "#E74C3C")
    local line_type = opts.line or "dashed"

    -- Bend calculation: support bend=X, bend=-X, bend_left=X, bend_right=X
    local bend_clause = ""
    if opts["bend left"] or opts.bend_left then
        bend_clause = string.format("bend left=%s", opts["bend left"] or opts.bend_left)
    elseif opts["bend right"] or opts.bend_right then
        bend_clause = string.format("bend right=%s", opts["bend right"] or opts.bend_right)
    else
        local bend = opts.bend or "25"
        if bend:match("^%-?%d+$") then
            local num = tonumber(bend)
            if num and num < 0 then
                bend_clause = string.format("bend right=%d", math.abs(num))
            else
                bend_clause = string.format("bend left=%s", bend)
            end
        else
            bend_clause = "bend left=25"
        end
    end

    -- Node boundary anchors: uses named TikZ nodes for automatic border clipping,
    -- or explicit anchors (e.g. from_anchor=south, to_anchor=west).
    local from_anchor = opts.from_anchor or opts.anchor_from
    local to_anchor = opts.to_anchor or opts.anchor_to

    local from_spec = from_anchor and string.format("(mc_node_%d.%s)", from_node.id, from_anchor)
                                  or string.format("(mc_node_%d)", from_node.id)
    local to_spec = to_anchor and string.format("(mc_node_%d.%s)", to_node.id, to_anchor)
                              or string.format("(mc_node_%d)", to_node.id)

    if r.lane then
        local ax, bx = from_node.x + from_node.box_width/2, to_node.x + to_node.box_width/2
        local label = ""
        if r.node then
            local width = r.node.max_width and string.format(", text width=%.2fpt", r.node.width) or ""
            label = string.format(
                " \\node[anchor=center, font=\\scriptsize, align=center, inner sep=2pt, fill=%s%s] at (%.2fpt, %.2fpt) {%s};",
                theme.to_tikz_color(opts.fill or "white"), width, r.node.x+r.node.box_width/2, r.node.y, r.text)
        end
        return string.format(
            "\\draw[draw=%s, %s, ->, >=stealth, line width=1.1pt] %s -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- %s;",
            col, line_type, from_spec, ax, r.lane, bx, r.lane, to_spec) .. label
    end

    -- Label positioning and styling
    local label_code = ""
    if r.text and r.text ~= "" then
        local node_attrs = {}

        -- Position along path: pos=0.3, midway, near start, near end, etc.
        local pos = opts.pos
        if pos then
            if tonumber(pos) then
                table.insert(node_attrs, string.format("pos=%s", pos))
            else
                table.insert(node_attrs, pos)
            end
        else
            table.insert(node_attrs, "midway")
        end

        -- Placement side / orientation: above, below, auto, sloped
        local side = opts.side or opts.align or opts.placement
        if side then
            table.insert(node_attrs, side)
        end
        if opts.above then table.insert(node_attrs, "above") end
        if opts.below then table.insert(node_attrs, "below") end
        if opts.sloped then table.insert(node_attrs, "sloped") end
        if opts.auto then table.insert(node_attrs, "auto") end

        -- Background fill (default: white, or none/color)
        local fill = opts.fill or "white"
        if fill ~= "none" and fill ~= "false" then
            local fill_col = theme.to_tikz_color(fill)
            table.insert(node_attrs, string.format("fill=%s", fill_col))
            local fill_op = opts.fill_opacity or opts.opacity
            if fill_op then
                table.insert(node_attrs, string.format("fill opacity=%s", fill_op))
            end
        end

        local inner_sep = opts.inner_sep or opts.padding or "2pt"
        table.insert(node_attrs, string.format("inner sep=%s", inner_sep))
        table.insert(node_attrs, "rounded corners=2pt")
        table.insert(node_attrs, "font=\\scriptsize")
        table.insert(node_attrs, "text={rgb,255:red,44;green,62;blue,80}")

        label_code = string.format(" node[%s] {%s}", table.concat(node_attrs, ", "), r.text)
    end

    local cmd = string.format(
        "\\draw[draw=%s, %s, ->, >=stealth, line width=1.1pt] %s to[%s]%s %s;",
        col, line_type, from_spec, bend_clause, label_code, to_spec
    )
    return cmd
end

return curve
