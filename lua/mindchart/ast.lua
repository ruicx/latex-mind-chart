--[[
  mindchart/ast.lua
  Data structures and helper functions for mind map Abstract Syntax Tree (AST).
--]]

local ast = {}

local node_id_counter = 0
ast.named_nodes = {}
ast.summaries = {}
ast.relationships = {}
ast.boundaries = {}

--- Creates a new AST Node.
--- @param text string The raw text/content of the node.
--- @param options table|nil Optional table of per-node options (e.g. side, color).
--- @return table The newly initialized Node.
function ast.new_node(text, options)
    node_id_counter = node_id_counter + 1
    local node = {
        id = node_id_counter,
        text = text or "",
        depth = 0,
        parent = nil,
        children = {},
        options = options or {},

        -- Dimensions (in pt), populated by measurement
        width = 0.0,
        height = 0.0,
        depth_pt = 0.0,

        -- Positioning (in pt), populated by layout
        x = 0.0,
        y = 0.0,
        side = "right", -- "left" or "right"
        subtree_height = 0.0,

        -- Appearance, populated by theme
        color = nil,
        style = nil,
    }

    if options and (options.name or options.id) then
        local name = options.name or options.id
        ast.named_nodes[name] = node
        node.name = name
    end

    return node
end

--- Resets the global node ID counter and registries.
function ast.reset_counter()
    node_id_counter = 0
    ast.named_nodes = {}
    ast.summaries = {}
    ast.relationships = {}
    ast.boundaries = {}
end

--- Adds a child node to a parent node, setting depth and parent reference.
--- @param parent table The parent Node.
--- @param child table The child Node.
function ast.add_child(parent, child)
    child.parent = parent
    child.depth = parent.depth + 1
    child.side = parent.side
    table.insert(parent.children, child)
end

--- Pre-order traversal of the tree.
--- @param root table The root Node.
--- @param callback function Function receiving (node, parent).
function ast.traverse_preorder(root, callback)
    if not root then return end
    callback(root, root.parent)
    for _, child in ipairs(root.children) do
        ast.traverse_preorder(child, callback)
    end
end

--- Post-order traversal of the tree.
--- @param root table The root Node.
--- @param callback function Function receiving (node, parent).
function ast.traverse_postorder(root, callback)
    if not root then return end
    for _, child in ipairs(root.children) do
        ast.traverse_postorder(child, callback)
    end
    callback(root, root.parent)
end

--- Counts the total number of nodes in the subtree rooted at `root`.
--- @param root table
--- @return number
function ast.count_nodes(root)
    local count = 0
    ast.traverse_preorder(root, function()
        count = count + 1
    end)
    return count
end

return ast
