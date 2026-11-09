-- Test script for markdown parser
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local ast = require("mindchart.ast")
local parser = require("mindchart.parser")

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("FAILED: %s (expected '%s', got '%s')", msg or "", tostring(expected), tostring(actual)))
    end
end

-- Test 1: Mixed Headings and Indented Bullets with Overlays and Math
local md_input1 = [[
# Central Topic, color=2ECC71
  - Branch 1, name=b1, color=E74C3C
    - Leaf 1.1 $\alpha, \beta$
    - Leaf 1.2, name=l12
  - Branch 2, name=b2
    - Leaf 2.1
      - Subleaf 2.1.1
\summary[color=3498DB]{b1}{b2}{Core Concepts}
\rel[bend=25]{l12}{b2}{Data Link}
]]

local root1 = parser.parse_markdown(md_input1)
assert(root1 ~= nil, "Root 1 should not be nil")
assert_eq(root1.text, "Central Topic", "Root 1 text")
assert_eq(root1.options.color, "2ECC71", "Root 1 color option")
assert_eq(#root1.children, 2, "Root 1 child count")

local b1 = root1.children[1]
assert_eq(b1.text, "Branch 1", "Branch 1 text")
assert_eq(b1.options.color, "E74C3C", "Branch 1 color")
assert_eq(#b1.children, 2, "Branch 1 children count")
assert_eq(b1.children[1].text, "Leaf 1.1 $\\alpha, \\beta$", "Leaf 1.1 text with math and comma")
assert_eq(b1.children[2].text, "Leaf 1.2", "Leaf 1.2 text")

local b2 = root1.children[2]
assert_eq(b2.text, "Branch 2", "Branch 2 text")
assert_eq(#b2.children, 1, "Branch 2 children count")
assert_eq(b2.children[1].text, "Leaf 2.1", "Leaf 2.1 text")
assert_eq(#b2.children[1].children, 1, "Leaf 2.1 children count")
assert_eq(b2.children[1].children[1].text, "Subleaf 2.1.1", "Subleaf 2.1.1 text")

-- Verify named nodes
assert(ast.named_nodes["b1"] == b1, "named_nodes['b1'] is b1")
assert(ast.named_nodes["b2"] == b2, "named_nodes['b2'] is b2")
assert(ast.named_nodes["l12"] == b1.children[2], "named_nodes['l12'] is Leaf 1.2")

-- Verify overlays
assert_eq(#ast.summaries, 1, "Summaries count")
assert_eq(ast.summaries[1].from, "b1", "Summary from")
assert_eq(ast.summaries[1].to, "b2", "Summary to")
assert_eq(ast.summaries[1].text, "Core Concepts", "Summary label")
assert_eq(ast.summaries[1].options.color, "3498DB", "Summary color option")

assert_eq(#ast.relationships, 1, "Relationships count")
assert_eq(ast.relationships[1].from, "l12", "Rel from")
assert_eq(ast.relationships[1].to, "b2", "Rel to")
assert_eq(ast.relationships[1].text, "Data Link", "Rel label")
assert_eq(ast.relationships[1].options.bend, "25", "Rel bend option")

print("Test 1 passed successfully!")

-- Test 2: Pure Heading hierarchy (#, ##, ###)
local md_input2 = [[
# Main Theme
## Category A
### Item A1
### Item A2
## Category B
### Item B1
]]

local root2 = parser.parse_markdown(md_input2)
assert_eq(root2.text, "Main Theme", "Root 2 text")
assert_eq(#root2.children, 2, "Root 2 children count")
assert_eq(root2.children[1].text, "Category A", "Category A text")
assert_eq(#root2.children[1].children, 2, "Category A children count")
assert_eq(root2.children[1].children[1].text, "Item A1", "Item A1 text")
assert_eq(root2.children[1].children[2].text, "Item A2", "Item A2 text")
assert_eq(root2.children[2].text, "Category B", "Category B text")
assert_eq(#root2.children[2].children, 1, "Category B children count")
assert_eq(root2.children[2].children[1].text, "Item B1", "Item B1 text")

print("Test 2 passed successfully!")

-- Test 3: Pure Bullet hierarchy without headings
local md_input3 = [[
- Project Root
  * Stage 1
    + Task 1.1
    + Task 1.2
  * Stage 2
    1. Task 2.1
    2. Task 2.2
]]

local root3 = parser.parse_markdown(md_input3)
assert_eq(root3.text, "Project Root", "Root 3 text")
assert_eq(#root3.children, 2, "Root 3 children count")
assert_eq(root3.children[1].text, "Stage 1", "Stage 1 text")
assert_eq(#root3.children[1].children, 2, "Stage 1 children count")
assert_eq(root3.children[1].children[1].text, "Task 1.1", "Task 1.1 text")
assert_eq(root3.children[2].text, "Stage 2", "Stage 2 text")
assert_eq(#root3.children[2].children, 2, "Stage 2 children count")
assert_eq(root3.children[2].children[1].text, "Task 2.1", "Task 2.1 text")
assert_eq(root3.children[2].children[2].text, "Task 2.2", "Task 2.2 text")

print("Test 3 passed successfully!")

-- Test 4: Subtree Boundaries (\boundary) in Markdown and Bracket notations
local md_input4 = [[
# System Architecture
  - Data Pipeline, name=data
    - Cleaning
    - Normalization
  - Core Engine, name=engine
    - Feature Transformer, name=ft
    - Model Backbone, name=bb
  - Evaluation, name=eval
\boundary[color=blue, style=dashed]{engine}{Deep Neural Core}
\boundary[color=E74C3C]{ft}{bb}{Transformer Subsystem}
\boundary[color=27AE60]{eval}
]]

local root4 = parser.parse_markdown(md_input4)
assert_eq(root4.text, "System Architecture", "Root 4 text")
assert_eq(#ast.boundaries, 3, "Boundaries count")

-- Boundary 1: single node with title
local bnd1 = ast.boundaries[1]
assert_eq(bnd1.from, "engine", "bnd1 from")
assert_eq(bnd1.to, "engine", "bnd1 to")
assert_eq(bnd1.title, "Deep Neural Core", "bnd1 title")
assert_eq(bnd1.options.color, "blue", "bnd1 color")
assert_eq(bnd1.options.style, "dashed", "bnd1 style")
assert(bnd1.node ~= nil, "bnd1.node should exist")
assert_eq(bnd1.node.text, "Deep Neural Core", "bnd1.node text")
assert_eq(bnd1.node.style, "badge", "bnd1.node style")

-- Boundary 2: range with title
local bnd2 = ast.boundaries[2]
assert_eq(bnd2.from, "ft", "bnd2 from")
assert_eq(bnd2.to, "bb", "bnd2 to")
assert_eq(bnd2.title, "Transformer Subsystem", "bnd2 title")
assert_eq(bnd2.options.color, "E74C3C", "bnd2 color")
assert(bnd2.node ~= nil, "bnd2.node should exist")
assert_eq(bnd2.node.text, "Transformer Subsystem", "bnd2.node text")

-- Boundary 3: single node without title
local bnd3 = ast.boundaries[3]
assert_eq(bnd3.from, "eval", "bnd3 from")
assert_eq(bnd3.to, "eval", "bnd3 to")
assert_eq(bnd3.title, "", "bnd3 title should be empty")
assert_eq(bnd3.options.color, "27AE60", "bnd3 color")
assert(bnd3.node == nil, "bnd3.node should be nil when title is empty")

-- Bracket notation test with \boundary
local bracket_input = [[
[Root
  [SubA, name=sa
    [LeafA1]
  ]
]
\boundary[color=red]{sa}{Subsystem A}
]]
local root_b = parser.parse_bracket(bracket_input)
assert_eq(#ast.boundaries, 1, "Bracket boundary count")
assert_eq(ast.boundaries[1].from, "sa", "Bracket boundary from")
assert_eq(ast.boundaries[1].title, "Subsystem A", "Bracket boundary title")

print("Test 4 passed successfully!")

-- Test 5: Multi-line and Auto-wrap text with line continuations and options
local md_input5 = [[
# Root Topic
  - Line 1 of Subtopic\\
    Line 2 of Subtopic, name=ml1, max_width=4cm, align=left
  - Three Line Topic\\
    Second Line\\
    Third Line, name=ml2
  - Single line with break\\directly here, name=ml3
]]

local root5 = parser.parse_markdown(md_input5)
assert(root5 ~= nil, "Root 5 should not be nil")
assert_eq(root5.text, "Root Topic", "Root 5 text")
assert_eq(#root5.children, 3, "Root 5 children count")

local ml1 = root5.children[1]
assert_eq(ml1.text, [=[Line 1 of Subtopic\\Line 2 of Subtopic]=], "ml1 text joined with \\\\")
assert_eq(ml1.options.name, "ml1", "ml1 name option")
assert_eq(ml1.options.max_width, "4cm", "ml1 max_width option")
assert_eq(ml1.options.align, "left", "ml1 align option")
assert(ast.named_nodes["ml1"] == ml1, "named_nodes['ml1'] should match ml1")

local ml2 = root5.children[2]
assert_eq(ml2.text, [=[Three Line Topic\\Second Line\\Third Line]=], "ml2 text three lines joined")
assert_eq(ml2.options.name, "ml2", "ml2 name option")

local ml3 = root5.children[3]
assert_eq(ml3.text, [=[Single line with break\\directly here]=], "ml3 text on single line")
assert_eq(ml3.options.name, "ml3", "ml3 name option")

-- Bracket notation multi-line test
local bracket_input5 = [[
[Root
  [First Line\\
   Second Line, name=bml1, max_width=3.5cm, align=center]
]
]]
local root_b5 = parser.parse_bracket(bracket_input5)
assert(root_b5 ~= nil, "Root B5 should not be nil")
local bml1 = root_b5.children[1]
assert_eq(bml1.text, [=[First Line\\Second Line]=], "bml1 text cleaned with \\\\")
assert_eq(bml1.options.name, "bml1", "bml1 name")
assert_eq(bml1.options.max_width, "3.5cm", "bml1 max_width")
assert_eq(bml1.options.align, "center", "bml1 align")

print("Test 5 passed successfully!")

-- Test 6: Node Badges and Tags (badge, priority, tag, status)
local md_input6 = [[
# System Architecture
  - API Gateway, badge=1, tag=Networking, name=gw
  - Core Processing, priority=P0, tag={Security, v2.0}, status=Done, name=core
  - Async Worker, status=WIP, name=worker
]]

local root6 = parser.parse_markdown(md_input6)
assert(root6 ~= nil, "Root 6 should not be nil")
assert_eq(#root6.children, 3, "Root 6 children count")

local gw = root6.children[1]
assert(gw.badge_obj ~= nil, "gw.badge_obj should exist")
assert_eq(gw.badge_obj.text, "1", "gw badge text")
assert(gw.tag_objs ~= nil, "gw.tag_objs should exist")
assert_eq(#gw.tag_objs, 1, "gw tags count")
assert_eq(gw.tag_objs[1].text, "Networking", "gw tag 1 text")
assert_eq(gw.tag_objs[1].is_status, false, "gw tag 1 is not status")

local core = root6.children[2]
assert(core.badge_obj ~= nil, "core.badge_obj should exist")
assert_eq(core.badge_obj.text, "P0", "core badge text from priority")
assert(core.tag_objs ~= nil, "core.tag_objs should exist")
assert_eq(#core.tag_objs, 3, "core tags count (2 tags + 1 status)")
assert_eq(core.tag_objs[1].text, "Security", "core tag 1")
assert_eq(core.tag_objs[2].text, "v2.0", "core tag 2")
assert_eq(core.tag_objs[3].text, "Done", "core status tag")
assert_eq(core.tag_objs[3].is_status, true, "core tag 3 is status")

local worker = root6.children[3]
assert(worker.badge_obj == nil, "worker should have no badge")
assert(worker.tag_objs ~= nil, "worker.tag_objs should exist")
assert_eq(#worker.tag_objs, 1, "worker tags count")
assert_eq(worker.tag_objs[1].text, "WIP", "worker status text")
assert_eq(worker.tag_objs[1].is_status, true, "worker status is_status")

-- Bracket notation test with badges & tags
local bracket_input6 = [[
[Root
  [Subsystem A, badge=A, status=TODO]
]
]]
local root_b6 = parser.parse_bracket(bracket_input6)
assert(root_b6 ~= nil, "Root B6 should not be nil")
local sa = root_b6.children[1]
assert(sa.badge_obj ~= nil, "sa.badge_obj should exist")
assert_eq(sa.badge_obj.text, "A", "sa badge text")
assert(sa.tag_objs ~= nil, "sa.tag_objs should exist")
assert_eq(sa.tag_objs[1].text, "TODO", "sa tag text")
assert_eq(sa.tag_objs[1].is_status, true, "sa tag is status")

print("Test 6 passed successfully!")

-- Test 7: Theme Expansion & Custom Theme Registration
local theme = require("mindchart.theme")

-- 1. Check built-in palettes
assert(theme.palettes["nord"] ~= nil, "nord theme exists")
assert(theme.palettes["morandi"] ~= nil, "morandi theme exists")
assert(theme.palettes["dracula"] ~= nil, "dracula theme exists")
assert(theme.palettes["ocean"] ~= nil, "ocean theme exists")
assert(theme.palettes["sunset"] ~= nil, "sunset theme exists")
assert(theme.palettes["solarized"] ~= nil, "solarized theme exists")
assert(theme.palettes["warm"] ~= nil, "warm alias exists")
assert_eq(theme.palettes["warm"], theme.palettes["sunset"], "warm is alias for sunset")

-- 2. Test theme.apply with built-in theme
local md_input7 = [[
# Architecture
  - Frontend
  - Backend
]]
local root7 = parser.parse_markdown(md_input7)
theme.apply(root7, { theme = "nord" })
assert_eq(root7.color, "#2E3440", "Root node nord color")
assert_eq(root7.children[1].color, "#5E81AC", "Child 1 nord color")
assert_eq(root7.children[2].color, "#88C0D0", "Child 2 nord color")

-- 3. Test theme.define_theme with key-value spec
theme.define_theme("corporate", "root=#112233, palette={#AA0000, #00AA00, #0000AA}")
assert(theme.palettes["corporate"] ~= nil, "corporate theme registered")
assert_eq(#theme.palettes["corporate"], 3, "corporate palette size")
assert_eq(theme.root_colors["corporate"], "#112233", "corporate root color")

local root7b = parser.parse_markdown(md_input7)
theme.apply(root7b, { theme = "corporate" })
assert_eq(root7b.color, "#112233", "Root node corporate color")
assert_eq(root7b.children[1].color, "#AA0000", "Child 1 corporate color")
assert_eq(root7b.children[2].color, "#00AA00", "Child 2 corporate color")

-- 4. Test theme.define_theme with plain comma-separated colors
theme.define_theme("simple", "#FF1122, #33FF44")
assert(theme.palettes["simple"] ~= nil, "simple theme registered")
assert_eq(#theme.palettes["simple"], 2, "simple palette size")

-- 5. Test ad-hoc inline palette in options
local root7c = parser.parse_markdown(md_input7)
theme.apply(root7c, { palette = "{#123456, #654321}", root_color = "#999999" })
assert_eq(root7c.color, "#999999", "Root node inline custom root color")
assert_eq(root7c.children[1].color, "#123456", "Child 1 inline palette color")
assert_eq(root7c.children[2].color, "#654321", "Child 2 inline palette color")

print("Test 7 passed successfully!")

-- Test 8: Node Folding & Collapsed Subtree Counting & PDF Bookmarks
local md_input8 = [[
# System Architecture
  - Ingestion Layer
    - Kafka Event Ingestion
    - Schema Registry
  - Compute Engine, collapsed
    - Stream Engine
      - Flink State
      - Window Metrics
    - Batch Engine
  - Storage Layer, folded
    - S3 Object Store
]]

local root8 = parser.parse_markdown(md_input8)
assert(root8 ~= nil, "Root 8 should not be nil")
assert_eq(#root8.children, 3, "Root 8 children count")

local ingestion = root8.children[1]
assert_eq(ingestion.collapsed, false, "Ingestion is not collapsed")

local compute = root8.children[2]
assert_eq(compute.collapsed, true, "Compute Engine is collapsed")
local comp_desc = ast.count_descendants(compute)
assert_eq(comp_desc, 4, "Compute Engine has 4 total descendants (2 L2 + 2 L3)")

local storage = root8.children[3]
assert_eq(storage.collapsed, true, "Storage Layer is folded/collapsed")
local store_desc = ast.count_descendants(storage)
assert_eq(store_desc, 1, "Storage Layer has 1 descendant")

-- Verify visibility traversal
local visible_nodes = {}
ast.traverse_visible(root8, function(node)
    table.insert(visible_nodes, node.text)
end)
-- Visible should be: System Architecture, Ingestion Layer, Kafka Event Ingestion, Schema Registry, Compute Engine, Storage Layer
assert_eq(#visible_nodes, 6, "Visible node count with collapsed subtrees")

-- Verify ast.is_node_visible
assert(ast.is_node_visible(ingestion.children[1]), "Kafka is visible")
assert(not ast.is_node_visible(compute.children[1]), "Stream Engine child of collapsed node is NOT visible")
assert(not ast.is_node_visible(compute.children[1].children[1]), "Flink State grandchild of collapsed node is NOT visible")

-- Verify bookmark text sanitization
local renderer = require("mindchart.renderer")
assert_eq(renderer.sanitize_for_bookmark([[Distributed Stream\\Processing Engine]]), "Distributed Stream Processing Engine")
assert_eq(renderer.sanitize_for_bookmark([[Feature Scaling: $x' = \frac{x - \mu}{\sigma}$]]), "Feature Scaling: x' = x - mu/sigma")
assert_eq(renderer.sanitize_for_bookmark([[OAuth2 \& OIDC Provider, tag=Security]]), [[OAuth2 \& OIDC Provider, tag=Security]])
assert_eq(renderer.sanitize_for_bookmark([[\textbf{Bold Label}]]), "Bold Label")

print("Test 8 passed successfully!")

-- Test 9: Vertical & Org-Chart Layout and Anchors
local layout = require("mindchart.layout")
local curve = require("mindchart.curve")
local theme = require("mindchart.theme")

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

-- Test 10: Native Vector Micro-Icons & Symbol Indicators
local icon = require("mindchart.icon")

local md_input10 = [[
# System Audit, icon=star
  - Security Verification, icon=check, status=Done
  - Urgent Fix, icon=fire, icon_pos=suffix, badge=P0
  - Deprecated Feature, icon=warn
  - Creative Idea, icon=bulb
  - Loved Feature, icon=heart
]]

local root10 = parser.parse_markdown(md_input10)
assert(root10 ~= nil, "Root 10 should not be nil")
assert_eq(root10.icon_obj.name, "star", "Root icon is star")
assert_eq(root10.icon_obj.pos, "prefix", "Root icon pos is prefix")

local n_sec = root10.children[1]
assert(n_sec.icon_obj ~= nil, "Security node has icon_obj")
assert_eq(n_sec.icon_obj.name, "check", "Security icon is check")
assert_eq(n_sec.icon_obj.pos, "prefix", "Security icon pos is prefix")

local n_urg = root10.children[2]
assert_eq(n_urg.icon_obj.name, "fire", "Urgent icon is fire")
assert_eq(n_urg.icon_obj.pos, "suffix", "Urgent icon pos is suffix")

-- Verify icon rendering produces valid TikZ commands
local cmd_check = icon.render(n_sec.icon_obj, 10, 20, "#27AE60")
assert(cmd_check:find("circle"), "Check icon has circle")
assert(cmd_check:find("draw=white"), "Check icon has white checkmark")

local cmd_star = icon.render(root10.icon_obj, 0, 0, "#F1C40F")
assert(cmd_star:find("cycle"), "Star icon has closed cycle polygon")

local cmd_warn = icon.render(root10.children[3].icon_obj, 5, 5, "#E67E22")
assert(cmd_warn:find("rounded corners"), "Warn icon has triangle with rounded corners")

local cmd_fire = icon.render(n_urg.icon_obj, 15, 25, "#E74C3C")
assert(cmd_fire:find("controls"), "Fire icon uses organic Bezier controls")

-- Verify layout width accounts for icon
local cfg = {
    pad_x_capsule = 12.0, pad_y_capsule = 6.0,
    pad_x_card = 8.0, pad_y_card = 5.0,
    pad_x_line = 4.0, pad_y_line = 2.0,
    sibling_sep = 14.0, level_sep = 28.0
}
n_sec.width = 50.0
n_sec.height = 10.0
n_sec.depth_pt = 2.0
layout.compute(root10, { layout = "right" })
assert(n_sec.box_width > 50.0 + 8.0 * 2, "Box width includes icon and status tags")

print("Test 10 passed successfully!")

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

print("ALL PARSER UNIT TESTS PASSED!")
