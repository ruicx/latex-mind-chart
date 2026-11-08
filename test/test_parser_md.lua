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

print("ALL PARSER UNIT TESTS PASSED!")
