package.path = './lua/?.lua;' .. package.path
local parser = require('mindchart.parser')
local theme = require('mindchart.theme')
local layout = require('mindchart.layout')
local failures = 0
local function check(ok, message)
    if not ok then failures = failures + 1; print('FAIL: ' .. message) end
end
local root = parser.parse_bracket('[Root [Branch, collapsed [Child]]]')
check(root.children[1].collapsed, 'bracket collapse')
root = parser.parse_bracket('[Root [$x[1]$]]')
check(root.children[1].text == '$x[1]$' and #root.children[1].children == 0, 'math brackets')
root = parser.parse_markdown('# Root\n- Branch, style=capsule\n  - Child, style=card')
theme.apply(root, {})
check(root.children[1].style == 'capsule' and root.children[1].shape == 'capsule', 'explicit level-one style')
check(root.children[1].children[1].style == 'card', 'explicit descendant style')
root = parser.parse_markdown('# Root\n- Category\n  - First\n  - Second')
theme.apply(root, {})
for _, n in ipairs(root.children[1].children) do n.height = 60 end
layout.compute(root, {layout='fishbone'})
local causes = root.children[1].children
check(math.abs(causes[1].y-causes[2].y) >= (causes[1].box_height+causes[2].box_height)/2, 'fishbone tall causes')
root = parser.parse_bracket('[Root [Category [Cause [Too deep]]]]')
check(not pcall(layout.compute, root, {layout='fishbone'}), 'fishbone depth diagnostic')
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
assert(failures == 0, tostring(failures) .. ' regression failures')
print('ALL REVIEW REGRESSION TESTS PASSED!')
