--[[
  mindchart/curve.lua
  Calculates geometric connection paths between parent and child nodes.
--]]

local theme = require("mindchart.theme")

local curve = {}

--- Calculates the anchor point coordinates for parent exit and child entry.
--- @param parent table
--- @param child table
--- @return number, number, number, number, number, number
--- (xp, yp, xc, yc, x_line_end, y_line_end)
function curve.get_anchors(parent, child)
    local xp, yp
    local is_right = (child.side == "right")

    -- Parent exit point
    if is_right then
        xp = parent.x + parent.box_width
    else
        xp = parent.x
    end

    if parent.style == "underline" then
        yp = parent.y - (parent.box_height / 2.0)
    else
        yp = parent.y
    end

    -- Child entry point
    local xc, yc, x_line_end, y_line_end
    if is_right then
        xc = child.x
        if child.style == "underline" then
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
        if child.style == "underline" then
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

--- Generates a TikZ path string connecting parent and child.
--- @param parent table
--- @param child table
--- @param line_style string "curve" | "elbow" | "straight"
--- @param line_width number Line width in pt
--- @return string TikZ draw command
function curve.generate_path(parent, child, line_style, line_width)
    local xp, yp, xc, yc, x_end, y_end = curve.get_anchors(parent, child)
    local col = theme.to_tikz_color(child.color or "#2C3E50")
    local lw = line_width or 1.2

    if line_style == "elbow" then
        local mid_x = (xp + xc) / 2.0
        if child.style == "underline" then
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
        if child.style == "underline" then
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

        if child.style == "underline" then
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
    local bend = opts.bend or "25"
    local bend_clause = ""
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

    local ax = from_node.x + (from_node.box_width / 2.0)
    local ay = from_node.y
    local bx = to_node.x + (to_node.box_width / 2.0)
    local by = to_node.y

    local label_code = ""
    if r.text and r.text ~= "" then
        label_code = string.format(" node[midway, fill=white, rounded corners=2pt, inner sep=2pt, font=\\scriptsize, text={rgb,255:red,44;green,62;blue,80}] {%s}", r.text)
    end

    local cmd = string.format(
        "\\draw[draw=%s, %s, ->, >=stealth, line width=1.1pt] (%.2fpt, %.2fpt) to[%s]%s (%.2fpt, %.2fpt);",
        col, line_type, ax, ay, bend_clause, label_code, bx, by
    )
    return cmd
end

return curve
