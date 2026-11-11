-- Headless layout tests
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local ast = require("mindchart.ast")
local parser = require("mindchart.parser")

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("FAILED: %s (expected '%s', got '%s')", msg or "", tostring(expected), tostring(actual)))
    end
end

local theme = require("mindchart.theme")
local layout = require("mindchart.layout")
local curve = require("mindchart.curve")
-- Test 9: Vertical & Org-Chart Layout and Anchors

local md_input9 = [[
# Executive Committee, color=1B4F72
  - Engineering Division, name=eng, color=2874A6
    - Platform Architecture, name=plat
    - Core Systems Team
  - Product Division, name=prod, color=117864
    - Growth Strategy
\summary{eng}{prod}{Core Technology Units}
]]

local root9 = parser.parse_markdown(md_input9)
assert(root9 ~= nil, "Root 9 should not be nil")
assert_eq(#root9.children, 2, "Root 9 children count")

-- Mock text dimensions for headless execution
local function mock_dims(node)
    node.width = 60.0
    node.height = 10.0
    node.depth_pt = 3.0
    for _, c in ipairs(node.children) do
        mock_dims(c)
    end
end
mock_dims(root9)
for _, s in ipairs(ast.summaries) do
    if s.node then mock_dims(s.node) end
end

theme.apply(root9, { layout = "org" })
assert_eq(root9.children[1].style, "card", "Level 1 in org chart is card")
assert_eq(root9.children[1].children[1].style, "boxed", "Level 2 in org chart is boxed")

layout.compute(root9, { layout = "org" })
assert_eq(root9.side, "down", "Root side is down in vertical layout")
assert_eq(root9.children[1].side, "down", "Child side is down in vertical layout")
assert(root9.y > root9.children[1].y, "Depth increases downwards (parent Y > child Y)")
assert(root9.children[1].y > root9.children[1].children[1].y, "Level 1 Y > Level 2 Y")

-- Check horizontal disjointness between sibling subtrees
local child1 = root9.children[1]
local child2 = root9.children[2]
assert(child2.x > child1.x, "Child 2 is to the right of Child 1")

-- Check vertical anchors
local xp, yp, xc, yc, x_end, y_end = curve.get_anchors(root9, child1)
assert_eq(xp, root9.x + root9.box_width / 2.0, "Parent exit anchor X is center bottom")
assert_eq(yp, root9.y - root9.box_height / 2.0, "Parent exit anchor Y is center bottom")
assert_eq(xc, child1.x + child1.box_width / 2.0, "Child entry anchor X is center top")
assert_eq(yc, child1.y + child1.box_height / 2.0, "Child entry anchor Y is center top")

-- Check elbow path generation
local path_elbow = curve.generate_path(root9, child1, "elbow", 1.2)
assert(path_elbow:find("rounded corners=3pt"), "Elbow path has rounded corners")

-- Check summary horizontal bracket
assert(#ast.summaries > 0, "Summary exists")
local s = ast.summaries[#ast.summaries]
assert(s.bracket ~= nil, "Summary bracket is populated")
assert_eq(s.bracket.side, "down", "Summary bracket side is down")
assert(s.bracket.x_left ~= nil and s.bracket.x_right ~= nil, "Summary bracket has horizontal span")
local bracket_tikz = curve.generate_bracket(s.bracket, s.node)
assert(bracket_tikz:find("controls"), "Bracket TikZ path generated")

print("Test 9 passed successfully!")


-- Test 11: Custom Node Geometric Shapes
local md_input11 = [[
# System Control Flow, shape=capsule
  - Authorization Decision, shape=diamond, color=E74C3C
    - Token Valid?, shape=rhombus
    - Fallback Strategy, shape=card
  - Data Store Cluster, shape=hexagon, color=3498DB
    - Sharded Partition, shape=hex
    - Cache Layer, shape=pill
  - Compute Worker, shape=rect, color=2ECC71
    - Container Pod, shape=rectangle
    - Raw Metric Node, shape=underline
]]

local root11 = parser.parse_markdown(md_input11)
assert(root11 ~= nil, "Root 11 should not be nil")
assert_eq(root11.options.shape, "capsule", "Root shape option")

local auth_node = root11.children[1]
local data_node = root11.children[2]
local worker_node = root11.children[3]

assert_eq(auth_node.options.shape, "diamond", "Auth node shape option")
assert_eq(data_node.options.shape, "hexagon", "Data node shape option")
assert_eq(worker_node.options.shape, "rect", "Worker node shape option")

-- Test shape normalization
assert_eq(theme.normalize_shape("rhombus"), "diamond", "rhombus normalizes to diamond")
assert_eq(theme.normalize_shape("hex"), "hexagon", "hex normalizes to hexagon")
assert_eq(theme.normalize_shape("pill"), "capsule", "pill normalizes to capsule")
assert_eq(theme.normalize_shape("rectangle"), "rect", "rectangle normalizes to rect")
assert_eq(theme.normalize_shape("rounded_rect"), "card", "rounded_rect normalizes to card")

-- Mock dimensions and apply theme
mock_dims(root11)
theme.apply(root11, { theme = "rainbow", style = "classic" })

assert_eq(root11.shape, "capsule", "Root shape is capsule")
assert_eq(auth_node.shape, "diamond", "Auth shape is diamond")
assert_eq(auth_node.children[1].shape, "diamond", "Child shape normalized to diamond")
assert_eq(auth_node.children[2].shape, "card", "Child shape is card")
assert_eq(data_node.shape, "hexagon", "Data shape is hexagon")
assert_eq(data_node.children[1].shape, "hexagon", "Child shape normalized to hexagon")
assert_eq(data_node.children[2].shape, "capsule", "Child shape normalized to capsule")
assert_eq(worker_node.shape, "rect", "Worker shape is rect")
assert_eq(worker_node.children[1].shape, "rect", "Child shape normalized to rect")
assert_eq(worker_node.children[2].shape, "underline", "Child shape is underline")

-- Compute layout and verify box dimensions
layout.compute(root11, { layout = "right" })

-- Diamond should have extra padding/expansion to prevent text clipping
assert(auth_node.box_width > auth_node.width * 1.5, "Diamond box width expanded for diagonal boundary")
assert(auth_node.box_height >= 22.0, "Diamond box height has minimum height")

-- Hexagon should have dx point cap allowance
assert(data_node.box_width >= data_node.width + 2 * 16.0, "Hexagon box width includes side tips")

-- Anchor points check
local xp11, yp11, xc11, yc11, xe11, ye11 = curve.get_anchors(root11, auth_node)
assert_eq(xp11, root11.x + root11.box_width, "Parent exit anchor X is right edge")
assert_eq(yp11, root11.y, "Parent exit anchor Y is center")
assert_eq(xc11, auth_node.x, "Child entry anchor X is left tip of diamond")
assert_eq(yc11, auth_node.y, "Child entry anchor Y is center tip of diamond")

-- Underline leaf anchor check
local leaf_ul = worker_node.children[2]
local _, _, xc_ul, yc_ul, xe_ul, ye_ul = curve.get_anchors(worker_node, leaf_ul)
assert_eq(yc_ul, leaf_ul.y - (leaf_ul.box_height / 2.0), "Underline child attaches at bottom baseline")
assert_eq(xe_ul, leaf_ul.x + leaf_ul.box_width, "Underline line spans across width")

print("Test 11 passed successfully!")


-- Test 12: Fishbone / Ishikawa Cause-and-Effect Diagram Layout
local md_input12 = [[
# High Server Latency, color=E74C3C
  - Hardware Capacity, color=3498DB
    - High CPU Load
    - Low RAM
  - Network Gateway, color=2ECC71
    - DNS Lookup Delay
    - Packet Dropped
  - Software Engine, color=E67E22
    - Lock Contention
    - Thread Pool Starved
  - Database System, color=9B59B6
    - Slow Query
    - Missing Index
]]

local root12 = parser.parse_markdown(md_input12)
assert(root12 ~= nil, "Root 12 should not be nil")
assert_eq(#root12.children, 4, "Root 12 has 4 categories")

mock_dims(root12)
theme.apply(root12, { layout = "fishbone", theme = "rainbow" })

assert(root12.is_fishbone == true, "Root is_fishbone flag is set")

layout.compute(root12, { layout = "fishbone" })

-- Check alternating category placement
local c1 = root12.children[1]
local c2 = root12.children[2]
local c3 = root12.children[3]
local c4 = root12.children[4]

assert_eq(c1.side, "top", "Category 1 placed on top")
assert_eq(c2.side, "bottom", "Category 2 placed on bottom")
assert_eq(c3.side, "top", "Category 3 placed on top")
assert_eq(c4.side, "bottom", "Category 4 placed on bottom")

assert(c1.y > 0, "Top category Y is above spine")
assert(c2.y < 0, "Bottom category Y is below spine")
assert(c3.y > 0, "Top category Y is above spine")
assert(c4.y < 0, "Bottom category Y is below spine")

-- Check station X progression (from left to right towards head)
assert(c3.joint_x > c1.joint_x, "Station 2 joint is to the right of Station 1 joint")
assert(root12.x > c3.joint_x, "Head node is to the right of all category joints")

-- Check spine coordinates
assert(root12.spine_start_x < c1.x, "Spine starts to the left of the leftmost category/cause")
assert_eq(root12.spine_end_x, root12.x, "Spine ends at the Head node")

-- Check rib and cause connection generation
local rib_path = curve.generate_path(root12, c1, "straight", 1.2)
assert(rib_path:find("%-%-"), "Rib path is straight diagonal line")

local cause1 = c1.children[1]
assert(cause1.attach_x > cause1.x + cause1.box_width, "Cause connects horizontally to rib on its right")
local cause_path = curve.generate_path(c1, cause1, "straight", 1.2)
assert(cause_path:find("%-%-"), "Cause branch connects horizontally")

print("Test 12 passed successfully!")


local function check(ok, message) assert(ok, message) end
local root
root = parser.parse_markdown('# Root\n- Category\n  - First\n  - Second')
theme.apply(root, {})
for _, n in ipairs(root.children[1].children) do n.height = 60 end
layout.compute(root, {layout='fishbone'})
local causes = root.children[1].children
check(math.abs(causes[1].y-causes[2].y) >= (causes[1].box_height+causes[2].box_height)/2, 'fishbone tall causes')
root = parser.parse_bracket('[Root [Category [Cause [Too deep]]]]')
local ok, message = pcall(layout.compute, root, {layout='fishbone'})
check(not ok and tostring(message):find('fishbone supports only root, category, and cause levels', 1, true), 'fishbone depth diagnostic')
