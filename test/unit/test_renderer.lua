-- Headless renderer tests
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


local function check(ok, message) assert(ok, message) end
local root
local output = {}
tex = {print = function(line) table.insert(output, line) end}
local destinations = {}
for _ = 1, 2 do
    root = parser.parse_bracket('[Root [Child]]')
    theme.apply(root, {})
    layout.compute(root, {})
    output = {}
    renderer.render(root, {bookmarks=true})
    for _, line in ipairs(output) do
        local destination = line:match('\\mindchartEmitBookmark.*{(mc_chart_[^}]+)}')
        if destination then
            check(not destinations[destination], 'unique PDF destination')
            destinations[destination] = true
        end
    end
end
local count = 0
for _ in pairs(destinations) do count = count + 1 end
check(count == 4, 'all bookmark destinations emitted')
