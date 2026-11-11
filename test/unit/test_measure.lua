-- Headless measure tests
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local ast = require("mindchart.ast")
local parser = require("mindchart.parser")

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("FAILED: %s (expected '%s', got '%s')", msg or "", tostring(expected), tostring(actual)))
    end
end

local theme = require("mindchart.theme")

local function check(ok, message) assert(ok, message) end
local root
local measure = require('mindchart.measure')
local renderer = require('mindchart.renderer')
local output = {}
tex = {print = function(line) table.insert(output, line) end}
for _, style in ipairs({'boxed', 'underline', 'classic'}) do
    root = parser.parse_markdown('# Root\n- Branch\n  - Child, fill=solid')
    theme.apply(root, {style=style})
    measure.init(root, {style=style})
    output = {}
    measure.emit_measurement_commands({style=style})
    check(output[2]:find('\\bfseries', 1, true) ~= nil, style .. ' level-one measurement font')
    check(output[3]:find('\\bfseries', 1, true) ~= nil, style .. ' solid measurement font')
end
