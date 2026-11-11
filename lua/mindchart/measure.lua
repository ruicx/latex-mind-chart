--[[
  mindchart/measure.lua
  Coordinates exact text dimension probing via TeX boxes.
--]]

local ast = require("mindchart.ast")
local theme = require("mindchart.theme")

local measure = {}

--- Emits a TeX line without adding interword glue to the surrounding document.
local function emit(command)
    tex.print(command .. "%")
end

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
    local function index_node(node)
        node_map[node.id] = node
        if node.badge_obj then
            node_map[node.badge_obj.id] = node.badge_obj
        end
        if node.icon_obj and node.icon_obj.is_macro then
            node_map[node.icon_obj.id] = node.icon_obj
        end
        if node.tag_objs then
            for _, tag in ipairs(node.tag_objs) do
                node_map[tag.id] = tag
            end
        end
    end
    ast.traverse_preorder(root, index_node)

    -- Also index summary nodes
    for _, s in ipairs(ast.summaries) do
        if s.node then
            index_node(s.node)
        end
    end

    -- Also index boundary badge nodes
    for _, b in ipairs(ast.boundaries) do
        if b.node then
            node_map[b.node.id] = b.node
        end
    end
    for _, entries in ipairs({ast.notes, ast.relationships}) do
        for _, entry in ipairs(entries) do
            if entry.node then index_node(entry.node) end
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

    local function emit_node(node)
        local mw = normalize_dim(node.options.max_width) or global_mw
        local al = node.options.align or global_al or "center"
        local has_break = (node.text:find("\\\\") ~= nil)

        node.align = al
        if mw then
            node.max_width = mw
        end

        local font = theme.font(node)
        local measure_text = font .. string.format("\\mindchartRecordFont{%d}", node.id)
            .. node.text:gsub("\\\\", function() return "\\\\" .. font .. " " end)

        if mw or has_break then
            emit(string.format(
                "\\mindchartMeasureMulti{%d}{%s}{%s}{%s}",
                node.id, mw or "", al, measure_text
            ))
        else
            emit(string.format("\\mindchartMeasureItem{%d}{%s}", node.id, measure_text))
        end

        -- Measure badge if present
        if node.badge_obj and node.badge_obj.text ~= "" then
            emit(string.format("\\mindchartMeasureItem{%d}{{\\scriptsize\\bfseries %s}}", node.badge_obj.id, node.badge_obj.text))
        end

        -- Measure icon if present and is a macro
        if node.icon_obj and node.icon_obj.is_macro and node.icon_obj.raw ~= "" then
            emit(string.format("\\mindchartMeasureItem{%d}{%s}", node.icon_obj.id, node.icon_obj.raw))
        end

        -- Measure tags if present
        if node.tag_objs then
            for _, tag in ipairs(node.tag_objs) do
                if tag.text ~= "" then
                    emit(string.format("\\mindchartMeasureItem{%d}{{\\tiny\\bfseries %s}}", tag.id, tag.text))
                end
            end
        end
    end
    ast.traverse_preorder(active_ast, emit_node)
    for _, note in ipairs(ast.notes) do emit_node(note.node) end
    for _, rel in ipairs(ast.relationships) do
        if rel.node then emit_node(rel.node) end
    end

    -- Summary cards use the same font and wrapping contract as tree nodes.
    for _, summary in ipairs(ast.summaries) do
        if summary.node then emit_node(summary.node) end
    end

    -- Measure boundary badge nodes
    for _, b in ipairs(ast.boundaries) do
        if b.node and b.node.text ~= "" then
            emit(string.format("\\mindchartMeasureItem{%d}{{\\scriptsize\\bfseries %s}}", b.node.id, b.node.text))
        end
    end

    emit("\\mindchartFinishMeasure")
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

--- Records the selected main-label font size in points.
function measure.store_font(id, size)
    if node_map[id] then node_map[id].font_size = size end
end

--- Returns the smallest visible main-label font size (excluding math scripts and badges).
function measure.minimum_font()
    local size = math.huge
    ast.traverse_visible(active_ast, function(n) size = math.min(size, n.font_size or math.huge) end)
    for _, note in ipairs(ast.notes) do
        if note.visible then size = math.min(size, note.node.font_size or math.huge) end
    end
    return size
end

return measure
