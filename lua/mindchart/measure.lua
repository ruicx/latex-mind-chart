--[[
  mindchart/measure.lua
  Coordinates exact text dimension probing via TeX boxes.
--]]

local ast = require("mindchart.ast")

local measure = {}

local active_ast = nil
local active_options = {}
local node_map = {}

--- Normalizes dimension string, ensuring units like 'pt' exist if numeric.
--- @param dim any
--- @return string|nil
local function normalize_dim(dim)
    if not dim or dim == "" then return nil end
    dim = tostring(dim):gsub("%s+", "")
    if dim:match("^%d+%.?%d*$") then
        return dim .. "pt"
    end
    return dim
end

--- Initializes measurement for an AST.
--- @param root table The AST root node.
--- @param options table|nil Global options
function measure.init(root, options)
    active_ast = root
    active_options = options or {}
    node_map = {}
    ast.traverse_preorder(root, function(node)
        node_map[node.id] = node
        if node.badge_obj then
            node_map[node.badge_obj.id] = node.badge_obj
        end
        if node.tag_objs then
            for _, tag in ipairs(node.tag_objs) do
                node_map[tag.id] = tag
            end
        end
    end)

    -- Also index summary nodes
    for _, s in ipairs(ast.summaries) do
        if s.node then
            node_map[s.node.id] = s.node
        end
    end

    -- Also index boundary badge nodes
    for _, b in ipairs(ast.boundaries) do
        if b.node then
            node_map[b.node.id] = b.node
        end
    end
end

--- Emits TeX measurement commands into the input stream.
--- @param options table|nil Global options
function measure.emit_measurement_commands(options)
    options = options or active_options or {}
    local global_mw = normalize_dim(options.max_width)
    local global_al = options.align

    if not active_ast then return end

    ast.traverse_preorder(active_ast, function(node)
        local mw = normalize_dim(node.options.max_width) or global_mw
        local al = node.options.align or global_al or "center"
        local has_break = (node.text:find("\\\\") ~= nil)

        node.align = al
        if mw then
            node.max_width = mw
        end

        local global_style = options.style or "classic"
        local is_card = (node.style == "card" or node.options.style == "card" or
            ((not node.style or node.style == "classic") and node.depth == 1 and global_style == "classic"))
        local is_capsule = (node.depth == 0 or node.style == "capsule" or node.options.style == "capsule")
        local is_bold = is_capsule or is_card
        local measure_text = node.text
        if is_bold then
            measure_text = "\\bfseries " .. node.text:gsub("\\\\", "\\\\\\bfseries ")
        end

        if mw or has_break then
            tex.print(string.format(
                "\\mindchartMeasureMulti{%d}{%s}{%s}{%s}",
                node.id, mw or "", al, measure_text
            ))
        else
            tex.print(string.format("\\mindchartMeasureItem{%d}{%s}", node.id, measure_text))
        end

        -- Measure badge if present
        if node.badge_obj and node.badge_obj.text ~= "" then
            tex.print(string.format("\\mindchartMeasureItem{%d}{{\\scriptsize\\bfseries %s}}", node.badge_obj.id, node.badge_obj.text))
        end

        -- Measure tags if present
        if node.tag_objs then
            for _, tag in ipairs(node.tag_objs) do
                if tag.text ~= "" then
                    tex.print(string.format("\\mindchartMeasureItem{%d}{{\\tiny\\bfseries %s}}", tag.id, tag.text))
                end
            end
        end
    end)

    -- Measure summary nodes
    for _, s in ipairs(ast.summaries) do
        if s.node and s.node.text ~= "" then
            local mw = normalize_dim(s.options.max_width) or global_mw
            local al = s.options.align or global_al or "center"
            local has_break = (s.node.text:find("\\\\") ~= nil)

            s.node.align = al
            if mw then
                s.node.max_width = mw
            end

            local measure_text = "\\bfseries " .. s.node.text:gsub("\\\\", "\\\\\\bfseries ")

            if mw or has_break then
                tex.print(string.format(
                    "\\mindchartMeasureMulti{%d}{%s}{%s}{%s}",
                    s.node.id, mw or "", al, measure_text
                ))
            else
                tex.print(string.format("\\mindchartMeasureItem{%d}{%s}", s.node.id, measure_text))
            end
        end
    end

    -- Measure boundary badge nodes
    for _, b in ipairs(ast.boundaries) do
        if b.node and b.node.text ~= "" then
            tex.print(string.format("\\mindchartMeasureItem{%d}{{\\scriptsize\\bfseries %s}}", b.node.id, b.node.text))
        end
    end

    tex.print("\\mindchartFinishMeasure")
end

--- Records physical dimensions measured by TeX.
--- @param id number The node ID.
--- @param box_num number The integer index of the TeX box register.
--- @param is_multiline boolean|nil
function measure.store_dim(id, box_num, is_multiline)
    local node = node_map[id]
    if not node then return end

    local b = tex.box[box_num]
    if b then
        node.width = b.width / 65536.0
        node.height = b.height / 65536.0
        node.depth_pt = b.depth / 65536.0
        node.is_multiline = (is_multiline == true)
    else
        node.width = 0.0
        node.height = 0.0
        node.depth_pt = 0.0
        node.is_multiline = false
    end
end

--- Retrieves the active AST after measurement is complete.
--- @return table The AST root node.
function measure.get_ast()
    return active_ast
end

return measure
