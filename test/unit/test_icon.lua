-- Headless icon tests
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
local function mock_dims(node)
    node.width = 60.0
    node.height = 10.0
    node.depth_pt = 3.0
    for _, c in ipairs(node.children) do
        mock_dims(c)
    end
end
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

