-- Whole-tree underline endpoint alignment and opt-in layout behavior.
package.path = "./lua/?.lua;" .. package.path

local ast = require("mindchart.ast")
local parser = require("mindchart.parser")
local theme = require("mindchart.theme")
local layout = require("mindchart.layout")
local curve = require("mindchart.curve")

local function prepare(mode, enabled)
    local root = parser.parse_markdown([[
# Root
  - A, side=right
    - X
    - Long
  - Longest, side=right
  - Box, shape=card, side=right
  - B, side=left
  - Medium, side=left
]])
    local options = {layout=mode, style="underline", equal_branch_length=enabled}
    theme.apply(root, options)
    ast.traverse_preorder(root, function(node)
        node.width, node.height, node.depth_pt = #node.text * 10, 10, 2
    end)
    layout.compute(root, options)
    return root, options
end

for _, mode in ipairs({"right", "left", "balanced", "mindmap"}) do
    for _, enabled in ipairs({true, "true"}) do
        local root, options = prepare(mode, enabled)
        local a, _, box, b, medium = table.unpack(root.children)
        assert(a.width == 10, "Measured text width is preserved")
        assert(box.box_width == box.width + 16, "Card keeps its natural width")
        assert(a.children[1].box_width == a.children[2].box_width, "Nested sibling lines equal")
        assert(b.box_width == medium.box_width, "Other siblings equal")
        if mode == "balanced" or mode == "mindmap" then
            assert(b.box_width < a.box_width, "Balanced sides have independent maximum widths")
        end
        local endpoints = {}
        ast.traverse_visible(root, function(node)
            if node.shape == "underline" and (#node.children == 0 or node.collapsed) then
                local ending = node.side == "left" and node.x or node.x + node.box_width
                if endpoints[node.side] then
                    assert(ending == endpoints[node.side], mode .. ": all leaf ends align across parents and depths")
                else
                    endpoints[node.side] = ending
                end
                assert(node.box_width >= node.width + 8, "Rule fits measured text")
            end
        end)
        local _, _, _, _, ending = curve.get_anchors(a, a.children[1])
        assert(ending == endpoints[a.side], "Rendered rule reaches the tree endpoint")
        local xp, _, xc = curve.get_anchors(a, a.children[1])
        assert(math.abs(xp - xc) == 28, "Descendants start beyond the extended rule")
        options.equal_branch_length = false
        layout.compute(root, options)
        assert(a.box_width == 18, "Recomputation restores natural width")
    end
end

for _, enabled in ipairs({false, "false"}) do
    local root = prepare("right", enabled)
    assert(root.children[1].box_width == 18, "Disabled option keeps natural width")
    assert(root.children[2].box_width == 78, "Disabled option keeps longest width")
end
local root = prepare("right", nil)
assert(root.children[1].box_width == 18, "Default keeps natural width")

-- Layouts without sibling horizontal rules keep their existing geometry.
for _, mode in ipairs({"vertical", "fishbone"}) do
    local original = prepare(mode, false)
    local expected = {}
    ast.traverse_visible(original, function(node)
        expected[#expected + 1] = {node.x, node.y, node.box_width, node.box_height}
    end)
    local enabled = prepare(mode, true)
    local index = 0
    ast.traverse_visible(enabled, function(node)
        index = index + 1
        for key, value in ipairs({node.x, node.y, node.box_width, node.box_height}) do
            assert(value == expected[index][key], mode .. ": geometry unchanged")
        end
    end)
end
-- Folded nodes align as leaves, while hidden descendants cannot enlarge the tree.
for _, mode in ipairs({"right", "left", "balanced"}) do
    local root = parser.parse_markdown([[
# Root
  - Fold, collapsed, side=right
    - Hidden
  - Visible, side=right
]])
    local options = {layout=mode, style="underline", equal_branch_length=true}
    theme.apply(root, options)
    ast.traverse_preorder(root, function(node)
        node.width, node.height, node.depth_pt = 30, 10, 2
    end)
    root.children[1].children[1].width = 10000
    layout.compute(root, options)
    local folded, visible = table.unpack(root.children)
    assert(folded.box_width == 38 and visible.box_width == 38, "Hidden text does not affect alignment")
    local _, _, _, _, folded_end = curve.get_anchors(root, folded)
    local _, _, _, _, visible_end = curve.get_anchors(root, visible)
    assert(folded_end == visible_end, "Folded branch endpoint aligns")
end
print("Whole-tree branch endpoint tests passed.")

-- Every visual style and connector uses the same aligned geometry where rules exist.
local matrix_input = [[
# Root
  - First, side=right
    - Short
    - Longer label
  - Second group, side=right
    - X
  - Left, side=left
    - Small
    - Wider text
]]
for _, style in ipairs({"classic", "underline", "boxed"}) do
    for _, mode in ipairs({"right", "left", "balanced", "mindmap"}) do
        for _, line in ipairs({"curve", "elbow", "straight", "tapered", "organic"}) do
            local root = parser.parse_markdown(matrix_input)
            local options = {style=style, layout=mode, line=line}
            theme.apply(root, options)
            ast.traverse_preorder(root, function(node)
                node.width, node.height, node.depth_pt = #node.text * 10, 10, 2
            end)
            layout.compute(root, options)
            local natural = {}
            ast.traverse_visible(root, function(node)
                natural[node.id] = {x=node.x, y=node.y, width=node.box_width}
            end)
            options.equal_branch_length = true
            layout.compute(root, options)
            local endpoints, leaves, extended = {}, 0, false
            ast.traverse_visible(root, function(node)
                local before = natural[node.id]
                if style == "boxed" then
                    assert(node.shape ~= "underline", "Boxed defaults have no underline rules")
                    assert(node.x == before.x and node.y == before.y and node.box_width == before.width,
                        "Boxed layout remains unchanged with every connector")
                elseif node.shape == "underline" and #node.children == 0 then
                    leaves = leaves + 1
                    local _, _, _, _, x, y = curve.get_anchors(node.parent, node)
                    if endpoints[node.side] then
                        assert(x == endpoints[node.side], style .. "/" .. mode .. "/" .. line .. ": leaf ends align")
                    else
                        endpoints[node.side] = x
                    end
                    -- Check the emitted path's final point, not only the layout anchors.
                    local path = curve.generate_path(node.parent, node, line, 1.2)
                    local ending = string.format("(%.2fpt, %.2fpt);", x, y)
                    assert(path:sub(-#ending) == ending, "Connector draws to the aligned endpoint")
                    assert(node.box_width >= before.width, "Alignment never shortens measured rules")
                    extended = extended or node.box_width > before.width
                elseif node.shape ~= "underline" then
                    assert(node.box_width == before.width, "Card widths are preserved")
                end
            end)
            if style ~= "boxed" then
                assert(leaves == 5 and extended, "Style matrix exercises alignment on every leaf")
            end
        end
    end
end

-- Explicit underline shapes opt into alignment even with the boxed visual style.
for _, mode in ipairs({"right", "left", "balanced"}) do
    local root = parser.parse_markdown(matrix_input)
    local options = {layout=mode, style="boxed", leaf_style="shape=underline", equal_branch_length=true}
    theme.apply(root, options)
    ast.traverse_preorder(root, function(node)
        node.width, node.height, node.depth_pt = #node.text * 10, 10, 2
    end)
    layout.compute(root, options)
    local endpoints = {}
    ast.traverse_visible(root, function(node)
        if node.depth == 1 then assert(node.shape == "card", "Boxed parents keep cards") end
        if #node.children == 0 then
            assert(node.shape == "underline", "Leaf shape overrides boxed style")
            local _, _, _, _, x = curve.get_anchors(node.parent, node)
            assert(not endpoints[node.side] or x == endpoints[node.side], "Explicit underline ends align")
            endpoints[node.side] = x
        end
    end)
end
print("Branch length style and connector matrix passed (60 combinations plus shape overrides).")
