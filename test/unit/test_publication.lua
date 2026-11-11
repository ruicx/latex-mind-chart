-- Publication features: styles, annotations, and non-overlapping overlays.
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path
local ast = require('mindchart.ast')
local parser = require('mindchart.parser')
local theme = require('mindchart.theme')
local layout = require('mindchart.layout')

local function overlaps(a, b)
    return a.x < b.x + b.box_width and b.x < a.x + a.box_width
        and math.abs(a.y - b.y) < (a.box_height + b.box_height) / 2
end

for _, mode in ipairs({'right', 'left', 'balanced', 'org', 'fishbone'}) do
    local root = parser.parse_markdown([[# Root
  - Alpha, name=a
    - Detail
  - Beta, name=b, font=\large
\summary{a}{b}{First summary}
\summary{a}{b}{Second summary}
\boundary{a}{Group}
\note[name=note, side=right]{a}{Independent annotation}
\rel{a}{b}{Dependency}
]])
    assert(#ast.notes == 1 and #root.children == 2, 'note must not enter tree')
    local opts = {layout=mode, avoid_overlaps='true', branch_style=[[font=\small,fill=yellow,pad_x=12]]}
    theme.apply(root, opts)
    assert(root.children[1].options.font == [[\small]], 'branch style applied')
    assert(root.children[2].options.font == [[\large]], 'local option wins')
    local function dims(n) n.width=80; n.height=12; n.depth_pt=3 end
    ast.traverse_preorder(root, dims)
    for _, list in ipairs({ast.summaries, ast.boundaries, ast.notes, ast.relationships}) do
        for _, entry in ipairs(list) do if entry.node then dims(entry.node) end end
    end
    layout.compute(root, opts)
    local nodes = {}
    ast.traverse_visible(root, function(n) table.insert(nodes,n) end)
    for _, list in ipairs({ast.summaries, ast.boundaries, ast.notes, ast.relationships}) do
        for _, entry in ipairs(list) do
            if entry.node then
                for _, other in ipairs(nodes) do
                    assert(not overlaps(entry.node, other), mode .. ': overlay overlap')
                end
                table.insert(nodes, entry.node)
            end
        end
    end
end

parser.parse_bracket([=[ [Root [Child, name=a]]\note[name=n]{a}{Note} ]=])
assert(#ast.notes == 1 and ast.named_nodes.n, 'bracket note registration')
parser.parse_markdown('# Fresh')
assert(#ast.notes == 0, 'notes reset between charts')

local root = parser.parse_markdown([[# Root
  - Folded, collapsed
    - Hidden, name=hidden
  - Visible, name=v
\note[name=n]{hidden}{Hidden note}
\rel{v}{n}{Hidden relationship}
]])
theme.apply(root, {})
layout.compute(root, {avoid_overlaps=true})
assert(not ast.notes[1].visible and not ast.is_node_visible(ast.named_nodes.n), 'hidden note pruned')
assert(ast.relationships[1].lane == nil, 'relationship to hidden note pruned')
root = parser.parse_markdown('# Root\n\\note{missing}{Note}')
assert(not pcall(theme.apply, root, {}), 'missing note anchor rejected')

local output = {}
tex = {print=function(line) table.insert(output, line) end, box={}}
local mindchart = require('mindchart')
local measure = require('mindchart.measure')
root = parser.parse_markdown('# Root')
measure.init(root, {})
root.font_size = 10
tex.box[1] = {width=200*65536, height=80*65536, depth=20*65536}
mindchart.fit(1, 100*65536, 0)
assert(output[#output]:find('0.5000000000',1,true), 'width-only fit')
mindchart.fit(1, 0, 25*65536)
assert(output[#output]:find('0.2500000000',1,true), 'height fit includes depth')
mindchart.fit(1, 300*65536, 200*65536)
assert(output[#output]:find('1.0000000000',1,true), 'fit never enlarges')
assert(not pcall(mindchart.fit,1,-1,0), 'negative limit rejected')
print('Publication tests passed')
