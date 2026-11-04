--[[
  mindchart/layout.lua
  Geometric layout engine for single-direction and bi-directional balanced mind maps.
--]]

local ast = require("mindchart.ast")

local layout = {}

-- Layout configuration parameters (in pt)
local DEFAULT_CONFIG = {
    sibling_sep = 14.0,  -- Vertical gap between adjacent sibling subtrees
    level_sep   = 28.0,  -- Horizontal gap between parent and child
    pad_x_capsule = 12.0,
    pad_y_capsule = 6.0,
    pad_x_card    = 8.0,
    pad_y_card    = 5.0,
    pad_x_line    = 4.0,
    pad_y_line    = 2.0,
}

--- Computes visual bounding box dimensions for a node based on its style and text dimensions.
--- @param node table
--- @param cfg table
local function compute_node_box(node, cfg)
    local px, py = cfg.pad_x_line, cfg.pad_y_line
    if node.style == "capsule" or node.depth == 0 then
        px, py = cfg.pad_x_capsule, cfg.pad_y_capsule
    elseif node.style == "card" or node.style == "boxed" then
        px, py = cfg.pad_x_card, cfg.pad_y_card
    end

    node.pad_x = px
    node.pad_y = py
    node.box_width = node.width + 2 * px
    node.box_height = node.height + node.depth_pt + 2 * py
end

--- Recursively computes the subtree bounding height for all nodes.
--- @param node table
--- @param cfg table
local function compute_subtree_heights(node, cfg)
    compute_node_box(node, cfg)

    if #node.children == 0 then
        node.subtree_height = node.box_height
        return
    end

    local children_height = 0
    for i, child in ipairs(node.children) do
        compute_subtree_heights(child, cfg)
        children_height = children_height + child.subtree_height
        if i > 1 then
            children_height = children_height + cfg.sibling_sep
        end
    end

    node.subtree_height = math.max(node.box_height, children_height)
end

--- Positions a subtree in the specified horizontal direction (1 for right, -1 for left).
--- @param node table
--- @param start_x number
--- @param start_y number Center Y for this node's allocated vertical space
--- @param direction number +1 (right) or -1 (left)
--- @param cfg table
local function position_subtree(node, start_x, start_y, direction, cfg)
    node.y = start_y
    if direction == 1 then
        node.x = start_x
    else
        node.x = start_x - node.box_width
    end

    if #node.children == 0 then return end

    -- Total height occupied by children
    local total_children_h = 0
    for i, child in ipairs(node.children) do
        total_children_h = total_children_h + child.subtree_height
        if i > 1 then
            total_children_h = total_children_h + cfg.sibling_sep
        end
    end

    -- Child X anchor
    local child_start_x
    if direction == 1 then
        child_start_x = node.x + node.box_width + cfg.level_sep
    else
        child_start_x = node.x - cfg.level_sep
    end

    -- Stack children vertically, centered around start_y
    local current_y = start_y + (total_children_h / 2.0)
    for _, child in ipairs(node.children) do
        local child_center_y = current_y - (child.subtree_height / 2.0)
        position_subtree(child, child_start_x, child_center_y, direction, cfg)
        current_y = current_y - child.subtree_height - cfg.sibling_sep
    end
end

--- Propagates the side ('left' or 'right') to all descendant nodes.
local function propagate_side(node, side)
    node.side = side
    for _, child in ipairs(node.children) do
        propagate_side(child, side)
    end
end

--- Balanced layout algorithm: partitions Level 1 children across left and right sides.
--- @param root table
--- @param cfg table
local function layout_balanced(root, cfg)
    compute_node_box(root, cfg)
    root.side = "center"

    local left_children = {}
    local right_children = {}

    local unassigned = {}
    for _, child in ipairs(root.children) do
        compute_subtree_heights(child, cfg)
        if child.options.side == "left" then
            table.insert(left_children, child)
        elseif child.options.side == "right" then
            table.insert(right_children, child)
        else
            table.insert(unassigned, child)
        end
    end

    -- Calculate initial heights
    local left_h = 0
    for i, c in ipairs(left_children) do
        left_h = left_h + c.subtree_height + (i > 1 and cfg.sibling_sep or 0)
    end
    local right_h = 0
    for i, c in ipairs(right_children) do
        right_h = right_h + c.subtree_height + (i > 1 and cfg.sibling_sep or 0)
    end

    -- Sort unassigned descending by subtree height for optimal bin-packing
    table.sort(unassigned, function(a, b)
        return a.subtree_height > b.subtree_height
    end)

    for _, c in ipairs(unassigned) do
        if left_h < right_h then
            table.insert(left_children, c)
            left_h = left_h + c.subtree_height + cfg.sibling_sep
        else
            table.insert(right_children, c)
            right_h = right_h + c.subtree_height + cfg.sibling_sep
        end
    end

    -- Mark sides
    for _, c in ipairs(left_children) do propagate_side(c, "left") end
    for _, c in ipairs(right_children) do propagate_side(c, "right") end

    -- Position Root at (0, 0)
    root.x = - (root.box_width / 2.0)
    root.y = 0.0

    -- Position Right Subtrees
    if #right_children > 0 then
        local right_total_h = 0
        for i, c in ipairs(right_children) do
            right_total_h = right_total_h + c.subtree_height + (i > 1 and cfg.sibling_sep or 0)
        end
        local current_y = (right_total_h / 2.0)
        local right_start_x = (root.box_width / 2.0) + cfg.level_sep
        for _, c in ipairs(right_children) do
            local cy = current_y - (c.subtree_height / 2.0)
            position_subtree(c, right_start_x, cy, 1, cfg)
            current_y = current_y - c.subtree_height - cfg.sibling_sep
        end
    end

    -- Position Left Subtrees
    if #left_children > 0 then
        local left_total_h = 0
        for i, c in ipairs(left_children) do
            left_total_h = left_total_h + c.subtree_height + (i > 1 and cfg.sibling_sep or 0)
        end
        local current_y = (left_total_h / 2.0)
        local left_start_x = - (root.box_width / 2.0) - cfg.level_sep
        for _, c in ipairs(left_children) do
            local cy = current_y - (c.subtree_height / 2.0)
            position_subtree(c, left_start_x, cy, -1, cfg)
            current_y = current_y - c.subtree_height - cfg.sibling_sep
        end
    end
end

--- Single-direction layout (growing rightwards or leftwards).
--- @param root table
--- @param direction number 1 for right, -1 for left
--- @param cfg table
local function layout_unidirectional(root, direction, cfg)
    compute_subtree_heights(root, cfg)
    local side_str = (direction == 1) and "right" or "left"
    propagate_side(root, side_str)

    root.x = (direction == 1) and 0.0 or -root.box_width
    root.y = 0.0

    position_subtree(root, root.x, 0.0, direction, cfg)
end

--- Main layout entry point.
--- @param root table
--- @param options table
function layout.compute(root, options)
    options = options or {}
    local mode = options.layout or "right"

    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do cfg[k] = v end
    if options.sibling_sep then cfg.sibling_sep = tonumber(options.sibling_sep) or cfg.sibling_sep end
    if options.level_sep then cfg.level_sep = tonumber(options.level_sep) or cfg.level_sep end

    if mode == "balanced" or mode == "mindmap" then
        layout_balanced(root, cfg)
    elseif mode == "left" then
        layout_unidirectional(root, -1, cfg)
    else
        -- Default: right
        layout_unidirectional(root, 1, cfg)
    end
end

return layout
