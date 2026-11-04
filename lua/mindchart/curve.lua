--[[
  mindchart/curve.lua
  Calculates geometric connection paths between parent and child nodes.
--]]

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
    local col = child.color or "#2C3E50"
    local lw = line_width or 1.2

    if line_style == "elbow" then
        local mid_x = (xp + xc) / 2.0
        if child.style == "underline" then
            return string.format(
                "\\draw[draw={%s}, line width=%.2fpt, rounded corners=3pt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) |- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                col, lw, xp, yp, mid_x, yp, xc, yc, x_end, y_end
            )
        else
            return string.format(
                "\\draw[draw={%s}, line width=%.2fpt, rounded corners=3pt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) |- (%.2fpt, %.2fpt);",
                col, lw, xp, yp, mid_x, yp, xc, yc
            )
        end
    elseif line_style == "straight" then
        if child.style == "underline" then
            return string.format(
                "\\draw[draw={%s}, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                col, lw, xp, yp, xc, yc, x_end, y_end
            )
        else
            return string.format(
                "\\draw[draw={%s}, line width=%.2fpt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
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
                "\\draw[draw={%s}, line width=%.2fpt] (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
                col, lw, xp, yp, c1x, c1y, c2x, c2y, xc, yc, x_end, y_end
            )
        else
            return string.format(
                "\\draw[draw={%s}, line width=%.2fpt] (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt);",
                col, lw, xp, yp, c1x, c1y, c2x, c2y, xc, yc
            )
        end
    end
end

return curve
