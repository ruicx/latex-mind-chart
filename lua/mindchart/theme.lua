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
    },
    ["nord"] = {
        "#5E81AC", -- Frost Blue
        "#88C0D0", -- Ice Blue
        "#81A1C1", -- Glacier Blue
        "#A3BE8C", -- Aurora Green
        "#D08770", -- Aurora Orange
        "#B48EAD", -- Aurora Purple
        "#EBCB8B", -- Aurora Yellow
        "#BF616A", -- Aurora Red
    },
    ["morandi"] = {
        "#7B8B88", -- Muted Sage
        "#C49C94", -- Muted Rose
        "#8E9CAE", -- Dusty Blue
        "#BCA888", -- Warm Khaki
        "#96897B", -- Muted Clay
        "#6C7B7F", -- Dusty Teal
        "#B08B59", -- Muted Ochre
        "#8A7968", -- Warm Umber
    },
    ["dracula"] = {
        "#BD93F9", -- Dracula Purple
        "#FF79C6", -- Dracula Pink
        "#50FA7B", -- Dracula Green
        "#8BE9FD", -- Dracula Cyan
        "#FFB86C", -- Dracula Orange
        "#F1FA8C", -- Dracula Yellow
        "#FF5555", -- Dracula Red
    },
    ["ocean"] = {
        "#134074", -- Deep Sea Blue
        "#0077B6", -- Pacific Blue
        "#0096C7", -- Cerulean
        "#00B4D8", -- Bright Teal
        "#48CAE4", -- Sky Turquoise
        "#023E8A", -- Cobalt Blue
    },
    ["sunset"] = {
        "#E63946", -- Crimson Red
        "#F77F00", -- Amber Orange
        "#FCBF49", -- Warm Gold
        "#D62828", -- Fiery Coral
        "#E76F51", -- Terracotta
        "#9D0208", -- Deep Ruby
    },
    ["solarized"] = {
        "#268BD2", -- Blue
        "#2AA198", -- Cyan
        "#859900", -- Green
        "#B58900", -- Yellow
        "#CB4B16", -- Orange
        "#DC322F", -- Red
        "#D33682", -- Magenta
        "#6C71C4", -- Violet
    },
}

-- Aliases
theme.palettes["warm"] = theme.palettes["sunset"]

theme.root_colors = {
    ["rainbow"]    = "#2C3E50",
    ["business"]   = "#0E2F44",
    ["forest"]     = "#145A32",
    ["monochrome"] = "#1C2833",
    ["nord"]       = "#2E3440",
    ["morandi"]    = "#3A3F44",
    ["dracula"]    = "#282A36",
    ["ocean"]      = "#0B2545",
    ["sunset"]     = "#4A1525",
    ["warm"]       = "#4A1525",
    ["solarized"]  = "#073642",
}

--- Registers a new user-defined theme palette.
--- @param name string Theme identifier
--- @param spec string|table Either a table { root=..., palette={...} } or a string spec
function theme.define_theme(name, spec)
    if not name or name == "" then return end
    name = tostring(name):match("^%s*(.-)%s*$")

    local root_col = "#2C3E50"
    local colors = {}

    if type(spec) == "table" then
        root_col = spec.root or root_col
        colors = spec.palette or {}
    elseif type(spec) == "string" then
        -- Check if spec uses key-value: root=..., palette={...}
        local root_match = spec:match("root%s*=%s*([^,{}]+)")
        if root_match then
            root_col = root_match:match("^%s*(.-)%s*$")
        end

        local pal_match = spec:match("palette%s*=%s*{(.-)}") or spec:match("palette%s*=%s*([^,}]+)")
        if pal_match then
            for col in pal_match:gmatch("[^,]+") do
                col = col:match("^%s*(.-)%s*$")
                if col ~= "" then
                    table.insert(colors, col)
                end
            end
        else
            -- Plain comma-separated list of colors
            for col in spec:gmatch("[^,]+") do
                col = col:match("^%s*(.-)%s*$")
                if col ~= "" and not col:match("^root%s*=") then
                    table.insert(colors, col)
                end
            end
        end
    end

    if #colors > 0 then
        theme.palettes[name] = colors
        theme.root_colors[name] = root_col
    end
end

--- Normalizes a geometric shape string name.
--- @param raw any
--- @return string|nil
function theme.normalize_shape(raw)
    if not raw then return nil end
    raw = tostring(raw):lower():match("^%s*(.-)%s*$")
    if raw == "diamond" or raw == "rhombus" then
        return "diamond"
    elseif raw == "hexagon" or raw == "hex" then
        return "hexagon"
    elseif raw == "capsule" or raw == "pill" or raw == "rounded" then
        return "capsule"
    elseif raw == "rect" or raw == "rectangle" or raw == "box" then
        return "rect"
    elseif raw == "card" or raw == "rounded_rect" then
        return "card"
    elseif raw == "underline" or raw == "line" then
        return "underline"
    elseif raw == "ellipse" or raw == "oval" or raw == "circle" then
        return "ellipse"
    end
    return raw
end

--- Resolves and assigns colors and styles across all nodes in the tree.
--- @param root table The AST root node.
--- @param options table Global options (e.g. { theme="rainbow", style="classic" })
function theme.apply(root, options)
    options = options or {}
    local is_vertical = (options.layout == "org" or options.layout == "down" or options.layout == "vertical" or options.layout == "tree_down")
    local is_fishbone = (options.layout == "fishbone" or options.layout == "ishikawa" or options.layout == "cause_effect")
    local theme_name = options.theme or "rainbow"
    local style_name = options.style or "classic"
    local global_shape = theme.normalize_shape(options.shape)

    if is_fishbone then
        root.is_fishbone = true
    end

    local palette
    local root_color = "#2C3E50"

    -- Support ad-hoc inline palette in options: palette={#E74C3C, #3498DB} or palette="#E74C3C, #3498DB"
    if options.palette then
        local pal_list = {}
        local raw_pal = tostring(options.palette)
        raw_pal = raw_pal:match("^{?(.-)}?$") or raw_pal
        for col in raw_pal:gmatch("[^,]+") do
            col = col:match("^%s*(.-)%s*$")
            if col ~= "" then
                table.insert(pal_list, col)
            end
        end
        if #pal_list > 0 then
            palette = pal_list
            root_color = options.root_color or palette[1]
        end
    end

    if not palette then
        palette = theme.palettes[theme_name] or theme.palettes["rainbow"]
        root_color = theme.root_colors[theme_name] or "#2C3E50"
    end

    if options.root_color then
        root_color = options.root_color
    end

    -- Assign root attributes
    root.color = root.options.color or root_color
    root.style = root.options.style or (style_name == "underline" and "capsule" or "capsule")
    root.shape = theme.normalize_shape(root.options.shape or global_shape) or "capsule"

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

        local l1_shape = theme.normalize_shape(l1_node.options.shape or global_shape)
        if l1_shape then
            l1_node.shape = l1_shape
            if l1_shape ~= "underline" and not l1_node.options.style then
                l1_node.style = "card"
            elseif l1_shape == "underline" then
                l1_node.style = "underline"
            end
        else
            l1_node.shape = (l1_node.style == "underline" and "underline" or (l1_node.style == "capsule" and "capsule" or "card"))
        end

        -- Propagate color to descendants
        local function propagate(node, parent_color)
            for _, child in ipairs(node.children) do
                child.color = child.options.color or parent_color
                if not child.style then
                    if style_name == "boxed" then
                        child.style = "boxed"
                    elseif is_vertical and style_name ~= "underline" then
                        child.style = "boxed"
                    else
                        -- classic and underline both use underline for level 2+
                        child.style = "underline"
                    end
                end

                local c_shape = theme.normalize_shape(child.options.shape or global_shape)
                if c_shape then
                    child.shape = c_shape
                    if c_shape ~= "underline" and not child.options.style then
                        child.style = (style_name == "boxed" or is_vertical) and "boxed" or "card"
                    elseif c_shape == "underline" then
                        child.style = "underline"
                    end
                else
                    child.shape = (child.style == "underline" and "underline" or (child.style == "capsule" and "capsule" or "card"))
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
        s.node.shape = theme.normalize_shape(s.options.shape or s.node.options.shape or global_shape) or "card"
    end

    -- Style boundary nodes
    for _, b in ipairs(ast.boundaries) do
        local from_node = ast.named_nodes[b.from]
        local base_color = (from_node and from_node.color) or root_color
        b.color = b.options.color or base_color
        if b.node then
            b.node.color = b.color
            b.node.style = "badge"
            b.node.shape = "badge"
        end
    end

    -- Style badge and tag objects
    ast.traverse_preorder(root, function(node)
        if node.badge_obj then
            node.badge_obj.color = node.badge_obj.options.color or node.color or root_color
        end
        if node.tag_objs then
            for _, tag in ipairs(node.tag_objs) do
                if tag.is_status then
                    local low = tag.text:lower()
                    if low == "done" or low == "finished" or low == "completed" or low == "ok" or low == "pass" then
                        tag.color = tag.options.color or "#27AE60" -- Emerald Green
                    elseif low == "wip" or low == "doing" or low == "in progress" or low == "active" then
                        tag.color = tag.options.color or "#E67E22" -- Orange
                    elseif low == "todo" or low == "pending" or low == "blocked" then
                        tag.color = tag.options.color or "#7F8C8D" -- Slate
                    else
                        tag.color = tag.options.color or node.color or root_color
                    end
                else
                    tag.color = tag.options.color or node.color or root_color
                end
            end
        end
    end)
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

--- Returns the font weight shared by measurement and rendering.
--- @param node table
--- @return boolean
function theme.is_bold(node)
    return node.depth == 0 or node.depth == 1 or node.style == "card"
        or node.options.fill == "solid" or node.options.fill == true
end

return theme
