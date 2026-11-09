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

--- Allocates and returns the next unique integer node ID.
--- @return number
function ast.next_id()
    node_id_counter = node_id_counter + 1
    return node_id_counter
end

--- Initializes badge and tag sub-objects for a node based on its options.
--- @param node table
function ast.init_badges_and_tags(node)
    local options = node.options or {}

    -- Process badge options
    local badge_val = options.badge or options.priority
    if badge_val and tostring(badge_val) ~= "" and not node.badge_obj then
        node.badge_obj = {
            id = ast.next_id(),
            text = tostring(badge_val),
            options = {
                color = options.badge_color,
                style = options.badge_style or "pill",
            },
            width = 0.0,
            height = 0.0,
            depth_pt = 0.0,
            box_width = 0.0,
            box_height = 0.0,
            gap = 5.0,
        }
    end

    -- Process icon options: icon=<name>, icon_color=<color>, icon_pos=<prefix|suffix>
    local icon_val = options.icon or options.symbol
    if icon_val and tostring(icon_val) ~= "" and not node.icon_obj then
        local raw_icon = tostring(icon_val):match("^%s*(.-)%s*$")
        if raw_icon ~= "" then
            local is_macro = (raw_icon:sub(1, 1) == "\\")
            node.icon_obj = {
                id = ast.next_id(),
                name = raw_icon:lower(),
                raw = raw_icon,
                is_macro = is_macro,
                pos = options.icon_pos or "prefix",
                color = options.icon_color,
                box_width = 11.0,
                box_height = 11.0,
                gap = 5.0,
            }
        end
    end

    -- Process tag options
    local raw_tag = options.tag or options.tags
    local tag_list = {}
    if raw_tag and tostring(raw_tag) ~= "" then
        for t in tostring(raw_tag):gmatch("[^,]+") do
            t = t:match("^%s*(.-)%s*$")
            if t ~= "" then
                table.insert(tag_list, { text = t, is_status = false })
            end
        end
    end

    if options.status and tostring(options.status) ~= "" then
        local s = tostring(options.status):match("^%s*(.-)%s*$")
        if s ~= "" then
            table.insert(tag_list, { text = s, is_status = true })
        end
    end

    if #tag_list > 0 and not node.tag_objs then
        node.tag_objs = {}
        for _, t in ipairs(tag_list) do
            table.insert(node.tag_objs, {
                id = ast.next_id(),
                text = t.text,
                is_status = t.is_status,
                options = {
                    color = options.tag_color,
                    style = options.tag_style or (t.is_status and "pill" or "subtle"),
                },
                width = 0.0,
                height = 0.0,
                depth_pt = 0.0,
                box_width = 0.0,
                box_height = 0.0,
                gap = 3.5,
            })
        end
    end
end

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

        -- Folding & Collapse state
        collapsed = false,
        folded_count = 0,
    }

    if options then
        if options.collapsed == true or options.collapsed == "true" or options.folded == true or options.folded == "true" then
            node.collapsed = true
        end
    end

    if options and (options.name or options.id) then
        local name = options.name or options.id
        ast.named_nodes[name] = node
        node.name = name
    end

    if options then
        ast.init_badges_and_tags(node)
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

--- Counts the total number of descendant nodes in a subtree (excluding the node itself).
--- @param node table
--- @return number
function ast.count_descendants(node)
    if not node or not node.children then return 0 end
    local count = #node.children
    for _, child in ipairs(node.children) do
        count = count + ast.count_descendants(child)
    end
    return count
end

--- Checks if a node is currently visible (i.e. none of its ancestors are collapsed).
--- @param node table
--- @return boolean
function ast.is_node_visible(node)
    if not node then return false end
    local cur = node.parent
    while cur do
        if cur.collapsed then
            return false
        end
        cur = cur.parent
    end
    return true
end

--- Traverses only visible nodes in the tree, pruning subtrees whose parent is collapsed.
--- @param root table The root Node.
--- @param callback function Function receiving (node, parent).
function ast.traverse_visible(root, callback)
    if not root then return end
    callback(root, root.parent)
    if not root.collapsed and root.children then
        for _, child in ipairs(root.children) do
            ast.traverse_visible(child, callback)
        end
    end
end

return ast
