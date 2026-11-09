--[[
  mindchart/icon.lua
  Zero-dependency TikZ vector micro-icons and symbol indicators.
--]]

local theme = require("mindchart.theme")

local icon = {}

-- Predefined semantic colors for built-in vector icons
local DEFAULT_ICON_COLORS = {
    check   = "#27AE60", -- Emerald Green
    tick    = "#27AE60",
    ok      = "#27AE60",
    cross   = "#E74C3C", -- Crimson Red
    cancel  = "#E74C3C",
    close   = "#E74C3C",
    x       = "#E74C3C",
    star    = "#F1C40F", -- Golden Amber
    flag    = "#E67E22", -- Orange
    warn    = "#E67E22", -- Warning Amber
    warning = "#E67E22",
    alert   = "#E74C3C",
    info    = "#2980B9", -- Sky Blue
    fire    = "#E74C3C", -- Red Flame
    flame   = "#E74C3C",
    urgent  = "#E74C3C",
    bulb    = "#F1C40F", -- Yellow Lightbulb
    idea    = "#F1C40F",
    heart   = "#E74C3C", -- Ruby Heart
    circle  = "#3498DB", -- Blue Dot
    dot     = "#3498DB",
    lock    = "#7F8C8D", -- Slate Gray
    gear    = "#7F8C8D", -- Slate Gray
    cog     = "#7F8C8D",
}

--- Resolves the TikZ color string for an icon.
--- @param name string Icon name
--- @param override_col string|nil Explicit user color
--- @param fallback_col string|nil Node branch color
--- @return string TikZ color string
function icon.get_color(name, override_col, fallback_col)
    local hex_or_name = override_col or DEFAULT_ICON_COLORS[name] or fallback_col or "#2C3E50"
    return theme.to_tikz_color(hex_or_name)
end

--- Generates TikZ statements to render a vector icon centered at (cx, cy).
--- @param ico table Icon descriptor table { name, raw, color, pos, box_width, box_height }
--- @param cx number Center X coordinate in pt
--- @param cy number Center Y coordinate in pt
--- @param node_color string|nil Fallback color from parent node
--- @return string TikZ draw/fill commands
function icon.render(ico, cx, cy, node_color)
    if not ico then return "" end

    local name = ico.name or ""
    local col_tikz = icon.get_color(name, ico.color, node_color)

    -- 1. Check if it's a LaTeX macro fallback (e.g. \faCheck, \faStar)
    if ico.raw and ico.raw:sub(1, 1) == "\\" then
        return string.format(
            "\\node at (%.2fpt, %.2fpt) {%s};",
            cx, cy, ico.raw
        )
    end

    -- 2. Predefined TikZ Vector Micro-Glyphs
    if name == "check" or name == "tick" or name == "ok" then
        -- Emerald green filled circle with crisp white checkmark
        return string.format(
            "\\fill[fill=%s] (%.2fpt, %.2fpt) circle (4.2pt); \\draw[draw=white, line width=1.1pt, line cap=round, line join=round] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
            col_tikz, cx, cy,
            cx - 2.2, cy - 0.2,
            cx - 0.6, cy - 1.8,
            cx + 2.2, cy + 1.6
        )
    elseif name == "cross" or name == "cancel" or name == "close" or name == "x" then
        -- Red filled circle with crisp white 'x'
        return string.format(
            "\\fill[fill=%s] (%.2fpt, %.2fpt) circle (4.2pt); \\draw[draw=white, line width=1.1pt, line cap=round] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
            col_tikz, cx, cy,
            cx - 1.8, cy - 1.8, cx + 1.8, cy + 1.8,
            cx - 1.8, cy + 1.8, cx + 1.8, cy - 1.8
        )
    elseif name == "star" then
        -- Golden 5-pointed filled star
        local r_out = 4.5
        local r_in = 1.9
        local pts = {}
        for k = 0, 9 do
            local angle = (math.pi / 2.0) + (k * math.pi / 5.0)
            local r = (k % 2 == 0) and r_out or r_in
            local px = cx + (r * math.cos(angle))
            local py = cy + (r * math.sin(angle))
            table.insert(pts, string.format("(%.2fpt, %.2fpt)", px, py))
        end
        return string.format(
            "\\fill[fill=%s] %s -- cycle;",
            col_tikz, table.concat(pts, " -- ")
        )
    elseif name == "flag" then
        -- Flagpole and triangular pennant
        return string.format(
            "\\draw[draw=%s, line width=1.1pt, line cap=round] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt); \\fill[fill=%s] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- cycle;",
            col_tikz, cx - 2.4, cy - 4.5, cx - 2.4, cy + 4.5,
            col_tikz, cx - 2.4, cy + 4.5, cx + 3.2, cy + 2.5, cx - 2.4, cy + 0.5
        )
    elseif name == "warn" or name == "warning" or name == "alert" then
        -- Amber triangle with white exclamation mark
        return string.format(
            "\\fill[fill=%s, rounded corners=0.8pt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) -- cycle; \\draw[draw=white, line width=1.1pt, line cap=round] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt); \\fill[fill=white] (%.2fpt, %.2fpt) circle (0.6pt);",
            col_tikz,
            cx, cy + 4.5,
            cx + 4.4, cy - 3.5,
            cx - 4.4, cy - 3.5,
            cx, cy + 2.0, cx, cy - 0.2,
            cx, cy - 2.0
        )
    elseif name == "info" then
        -- Blue circle with white 'i'
        return string.format(
            "\\fill[fill=%s] (%.2fpt, %.2fpt) circle (4.2pt); \\fill[fill=white] (%.2fpt, %.2fpt) circle (0.65pt); \\draw[draw=white, line width=1.1pt, line cap=round] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
            col_tikz, cx, cy,
            cx, cy + 1.8,
            cx, cy + 0.5, cx, cy - 2.0
        )
    elseif name == "fire" or name == "flame" or name == "urgent" then
        -- Vibrant curved organic flame
        local outer = string.format(
            "\\fill[fill=%s] (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) -- cycle;",
            col_tikz,
            cx, cy - 4.2,
            cx - 3.6, cy - 1.0, cx - 1.5, cy + 1.8, cx, cy + 4.5,
            cx + 1.5, cy + 1.8, cx + 3.6, cy - 1.0, cx, cy - 4.2
        )
        local inner = string.format(
            "\\fill[fill={rgb,255:red,241;green,196;blue,15}] (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) -- cycle;",
            cx, cy - 3.8,
            cx - 1.8, cy - 1.8, cx - 0.8, cy - 0.2, cx, cy + 1.5,
            cx + 0.8, cy - 0.2, cx + 1.8, cy - 1.8, cx, cy - 3.8
        )
        return outer .. " " .. inner
    elseif name == "bulb" or name == "idea" then
        -- Yellow lightbulb
        return string.format(
            "\\fill[fill=%s] (%.2fpt, %.2fpt) circle (3.0pt); \\fill[fill=%s, rounded corners=0.5pt] (%.2fpt, %.2fpt) rectangle (%.2fpt, %.2fpt); \\fill[fill={rgb,255:red,127;green,140;blue,141}] (%.2fpt, %.2fpt) rectangle (%.2fpt, %.2fpt);",
            col_tikz, cx, cy + 1.2,
            col_tikz, cx - 1.5, cy - 2.8, cx + 1.5, cy - 0.8,
            cx - 0.9, cy - 4.0, cx + 0.9, cy - 2.8
        )
    elseif name == "heart" then
        -- Ruby red heart shape
        return string.format(
            "\\fill[fill=%s] (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) .. controls (%.2fpt, %.2fpt) and (%.2fpt, %.2fpt) .. (%.2fpt, %.2fpt) -- cycle;",
            col_tikz,
            cx, cy - 4.2,
            cx - 4.0, cy - 0.5, cx - 3.2, cy + 3.2, cx, cy + 1.2,
            cx + 3.2, cy + 3.2, cx + 4.0, cy - 0.5, cx, cy - 4.2
        )
    elseif name == "lock" then
        -- Security padlock
        return string.format(
            "\\draw[draw=%s, line width=1.1pt] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) arc[start angle=180, end angle=0, radius=1.9pt] -- (%.2fpt, %.2fpt); \\fill[fill=%s, rounded corners=0.8pt] (%.2fpt, %.2fpt) rectangle (%.2fpt, %.2fpt); \\fill[fill=white] (%.2fpt, %.2fpt) circle (0.6pt);",
            col_tikz, cx - 1.9, cy - 0.2, cx - 1.9, cy + 1.6, cx + 1.9, cy - 0.2,
            col_tikz, cx - 3.2, cy - 4.2, cx + 3.2, cy - 0.2,
            cx, cy - 2.0
        )
    elseif name == "gear" or name == "cog" or name == "settings" then
        -- Gear wheel
        return string.format(
            "\\draw[draw=%s, line width=1.4pt] (%.2fpt, %.2fpt) circle (2.8pt); \\fill[fill=%s] (%.2fpt, %.2fpt) circle (1.0pt); \\draw[draw=%s, line width=1.1pt, line cap=round] (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt) (%.2fpt, %.2fpt) -- (%.2fpt, %.2fpt);",
            col_tikz, cx, cy,
            col_tikz, cx, cy,
            col_tikz,
            cx - 4.2, cy, cx + 4.2, cy,
            cx, cy - 4.2, cx, cy + 4.2
        )
    else
        -- Default fallback: clean circular bullet dot
        return string.format(
            "\\fill[fill=%s] (%.2fpt, %.2fpt) circle (3.8pt);",
            col_tikz, cx, cy
        )
    end
end

return icon
