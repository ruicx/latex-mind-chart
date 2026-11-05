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

print("ALL PARSER UNIT TESTS PASSED!")
