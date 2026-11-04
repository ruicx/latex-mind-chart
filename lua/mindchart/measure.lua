--[[
  mindchart/measure.lua
  Coordinates exact text dimension probing via TeX boxes.
--]]

local ast = require("mindchart.ast")

local measure = {}

local active_ast = nil
local node_map = {}

--- Initializes measurement for an AST.
--- @param root table The AST root node.
function measure.init(root)
    active_ast = root
    node_map = {}
    ast.traverse_preorder(root, function(node)
        node_map[node.id] = node
    end)
end

--- Emits TeX measurement commands into the input stream.
function measure.emit_measurement_commands()
    if not active_ast then return end

    ast.traverse_preorder(active_ast, function(node)
        tex.print(string.format("\\mindchartMeasureItem{%d}{%s}", node.id, node.text))
    end)
    tex.print("\\mindchartFinishMeasure")
end

--- Records physical dimensions measured by TeX.
--- @param id number The node ID.
--- @param box_num number The integer index of the TeX box register.
function measure.store_dim(id, box_num)
    local node = node_map[id]
    if not node then return end

    local b = tex.box[box_num]
    if b then
        node.width = b.width / 65536.0
        node.height = b.height / 65536.0
        node.depth_pt = b.depth / 65536.0
    else
        node.width = 0.0
        node.height = 0.0
        node.depth_pt = 0.0
    end
end

--- Retrieves the active AST after measurement is complete.
--- @return table The AST root node.
function measure.get_ast()
    return active_ast
end

return measure
