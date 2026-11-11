-- Headless theme tests
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
-- Test 7: Theme Expansion & Custom Theme Registration

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


local function check(ok, message) assert(ok, message) end
local root
root = parser.parse_markdown('# Root\n- Branch, style=capsule\n  - Child, style=card')
theme.apply(root, {})
check(root.children[1].style == 'capsule' and root.children[1].shape == 'capsule', 'explicit level-one style')
check(root.children[1].children[1].style == 'card', 'explicit descendant style')
