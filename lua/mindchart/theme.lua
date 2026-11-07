--[[
  mindchart/theme.lua
  Color palettes, styling definitions, and color inheritance engine.
--]]

local ast = require("mindchart.ast")

local theme = {}

-- Predefined Palettes (Hex colors)
theme.palettes = {
    ["rainbow"] = {
        "#E74C3C", -- Coral Red
        "#E67E22", -- Orange
        "#27AE60", -- Emerald Green
        "#16A085", -- Teal
        "#2980B9", -- Sky Blue
        "#8E44AD", -- Violet
        "#D35400", -- Rust
        "#1ABC9C", -- Turquoise
    },
    ["business"] = {
        "#1B4F72", -- Deep Navy
        "#2874A6", -- Ocean Blue
        "#117864", -- Forest Teal
        "#784212", -- Bronze
        "#4A235A", -- Indigo
        "#2E4053", -- Slate
    },
    ["forest"] = {
        "#196F3D", -- Dark Green
        "#27AE60", -- Vibrant Green
        "#117A65", -- Pine Teal
        "#7D6608", -- Olive Gold
        "#52BE80", -- Sage
    },
    ["monochrome"] = {
        "#2C3E50", -- Dark Charcoal
        "#5D6D7E", -- Steel Grey
        "#85929E", -- Medium Grey
        "#34495E", -- Blue Slate
    }
}

theme.root_colors = {
    ["rainbow"] = "#2C3E50",
    ["business"] = "#0E2F44",
    ["forest"] = "#145A32",
    ["monochrome"] = "#1C2833",
}

--- Resolves and assigns colors and styles across all nodes in the tree.
--- @param root table The AST root node.
--- @param options table Global options (e.g. { theme="rainbow", style="classic" })
function theme.apply(root, options)
    options = options or {}
    local theme_name = options.theme or "rainbow"
    local style_name = options.style or "classic"

    local palette = theme.palettes[theme_name] or theme.palettes["rainbow"]
    local root_color = theme.root_colors[theme_name] or "#2C3E50"

    -- Assign root attributes
    root.color = root.options.color or root_color
    root.style = root.options.style or (style_name == "underline" and "capsule" or "capsule")

    -- Assign Level 1 colors and propagate
    local l1_index = 0
    for _, l1_node in ipairs(root.children) do
        l1_index = l1_index + 1
        local chosen_color = l1_node.options.color or palette[((l1_index - 1) % #palette) + 1]
        l1_node.color = chosen_color

        -- Determine Level 1 style
        if not l1_node.style then
            if style_name == "boxed" then
                l1_node.style = "boxed"
            elseif style_name == "underline" then
                l1_node.style = "underline"
            else
                -- classic style: level 1 is rounded card
                l1_node.style = "card"
            end
        end

        -- Propagate color to descendants
        local function propagate(node, parent_color)
            for _, child in ipairs(node.children) do
                child.color = child.options.color or parent_color
                if not child.style then
                    if style_name == "boxed" then
                        child.style = "boxed"
                    else
                        -- classic and underline both use underline for level 2+
                        child.style = "underline"
                    end
                end
                propagate(child, child.color)
            end
        end

        propagate(l1_node, l1_node.color)
    end

    -- Style summary nodes
    for _, s in ipairs(ast.summaries) do
        local from_node = ast.named_nodes[s.from]
        local base_color = (from_node and from_node.color) or root_color
        s.node.color = s.options.color or base_color
        s.node.style = s.options.style or "card"
    end

    -- Style boundary nodes
    for _, b in ipairs(ast.boundaries) do
        local from_node = ast.named_nodes[b.from]
        local base_color = (from_node and from_node.color) or root_color
        b.color = b.options.color or base_color
        if b.node then
            b.node.color = b.color
            b.node.style = "badge"
        end
    end
end

--- Converts a hex string like "#E74C3C" or "E74C3C" to RGB values (0-255).
--- @param hex string
--- @return number, number, number
function theme.hex_to_rgb(hex)
    hex = hex:gsub("#", "")
    if #hex == 6 then
        local r = tonumber(hex:sub(1, 2), 16) or 0
        local g = tonumber(hex:sub(3, 4), 16) or 0
        local b = tonumber(hex:sub(5, 6), 16) or 0
        return r, g, b
    end
    return 0, 0, 0
end

--- Converts a hex color or named color to a TikZ color expression.
--- @param col string
--- @return string
function theme.to_tikz_color(col)
    if not col or col == "" then return "black" end
    local clean = col:gsub("#", "")
    if #clean == 6 and clean:match("^%x+$") then
        local r, g, b = theme.hex_to_rgb(clean)
        return string.format("{rgb,255:red,%d;green,%d;blue,%d}", r, g, b)
    else
        return col
    end
end

return theme
