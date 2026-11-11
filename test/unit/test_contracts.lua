-- Cross-feature contracts for visible geometry, overlays, and chart isolation.
package.path = './lua/?.lua;' .. package.path
local ast = require('mindchart.ast')
local parser = require('mindchart.parser')
local theme = require('mindchart.theme')
local layout = require('mindchart.layout')
local renderer = require('mindchart.renderer')
local failures = {}
local checks = 0
local function check(condition, description)
    checks = checks + 1
    if not condition then failures[#failures + 1] = description end
end
local function prepare(input, options)
    local root = parser.parse_markdown(input)
    theme.apply(root, options)
    ast.traverse_preorder(root, function(node)
        node.width = 25 + node.id % 4 * 17
        node.height = 12 + node.id % 3 * 13
        node.depth_pt = 3
    end)
    layout.compute(root, options)
    return root
end
local function render(root, options)
    local lines = {}
    tex = {print = function(line) lines[#lines + 1] = line end}
    renderer.render(root, options)
    return table.concat(lines, '\n')
end
local tree = '# Root\n  - A, name=a\n    - AA\n    - AB\n  - B, name=b\n    - BA\n    - BB\n  - C\n    - CA'
for _, mode in ipairs({'right', 'left', 'balanced', 'vertical', 'fishbone'}) do
    for _, style in ipairs({'classic', 'boxed', 'underline'}) do
        local options = {layout=mode, style=style}
        local root = prepare(tree, options)
        local visible = {}
        ast.traverse_visible(root, function(node)
            visible[#visible + 1] = node
            for _, key in ipairs({'x','y','box_width','box_height'}) do
                local value = node[key]
                check(type(value) == 'number' and value == value and math.abs(value) < math.huge, mode..':'..style..':'..key)
            end
            check(node.box_width > 0 and node.box_height > 0, mode..': positive dimensions')
        end)
        for i, a in ipairs(visible) do
            for j = i + 1, #visible do
                local b = visible[j]
                local separated = a.x + a.box_width <= b.x + 0.01 or b.x + b.box_width <= a.x + 0.01
                    or a.y + a.box_height / 2 <= b.y - b.box_height / 2 + 0.01
                    or b.y + b.box_height / 2 <= a.y - a.box_height / 2 + 0.01
                check(separated, mode..':'..style..': overlapping '..a.text..' / '..b.text)
            end
        end
    end
end
for _, mode in ipairs({'right','left','balanced','vertical'}) do
    local options = {layout=mode}
    local root = prepare('# Root\n  - Fold, name=fold, collapsed\n    - SECRET, name=hidden\n  - Visible, name=visible\n\\rel{hidden}{visible}{HIDDEN_REL}\n\\rel{fold}{visible}{VISIBLE_REL}\n\\summary{hidden}{hidden}{HIDDEN_SUM}\n\\summary{fold}{fold}{VISIBLE_SUM}\n\\boundary{hidden}{HIDDEN_BOUNDARY}\n\\boundary{fold}{VISIBLE_BOUNDARY}', options)
    local output = render(root, options)
    for _, hidden in ipairs({'SECRET','HIDDEN_REL','HIDDEN_SUM','HIDDEN_BOUNDARY'}) do
        check(not output:find(hidden,1,true), mode..': suppressed '..hidden)
    end
    for _, visible in ipairs({'VISIBLE_REL','VISIBLE_SUM','VISIBLE_BOUNDARY'}) do
        check(output:find(visible,1,true), mode..': retained '..visible)
    end
    check(ast.named_nodes.fold.folded_count == 1, mode..': folded count')
end
-- A new chart must reset registries, dimensions, options, and styling.
local first = prepare('# First\n  - Old, name=old, color=red, collapsed\n    - Hidden\n  - End, name=ending\n\\rel{old}{ending}{OLD_REL}\n\\summary{old}{ending}{OLD_SUM}\n\\boundary{old}{OLD_BOUNDARY}', {theme='monochrome',style='boxed'})
render(first, {bookmarks=true})
local second = prepare('# Second\n  - Fresh, name=fresh', {})
local second_output = render(second, {})
check(ast.named_nodes.old == nil and ast.named_nodes.ending == nil, 'old names cleared')
check(#ast.relationships == 0 and #ast.summaries == 0 and #ast.boundaries == 0, 'old overlays cleared')
check(not second.children[1].collapsed and second.children[1].style == 'card', 'old state cleared')
check(second.children[1].color ~= 'red', 'old colors cleared')
check(not second_output:find('OLD_',1,true) and not second_output:find('mindchartEmitBookmark',1,true), 'old output options cleared')
-- Bookmark options exclude hidden nodes unless explicitly requested.
local root = prepare('# Root\n  - Fold, collapsed\n    - Hidden\n  - Skip, bookmark=false\n  - Named, bookmark=Custom', {})
local output = render(root, {bookmarks=true})
check(not output:find('{Hidden}',1,true) and not output:find('}{Skip}{',1,true), 'bookmark exclusion')
check(output:find('}{Custom}{',1,true), 'custom bookmark label')
output = render(root, {bookmarks=true,bookmark_collapsed=true})
check(output:find('}{Hidden}{',1,true), 'opt-in hidden bookmark')
output = render(root, {bookmarks=true,bookmark_depth=0})
local _, count = output:gsub('\\mindchartEmitBookmark', '')
check(count == 1, 'bookmark depth limit')

-- Summary brackets and boundaries must enclose complete visible subtrees.
for _, mode in ipairs({'right','left','vertical'}) do
    local root = prepare(tree..'\n\\summary{a}{b}{Span}\n\\boundary{a}{b}{Group}', {layout=mode})
    local boundary = ast.boundaries[1].box
    local summary = ast.summaries[1].bracket
    for _, branch in ipairs({root.children[1], root.children[2]}) do
        ast.traverse_visible(branch, function(node)
            check(boundary.x_min <= node.x and boundary.x_max >= node.x + node.box_width,
                mode..': boundary encloses subtree horizontally')
            check(boundary.y_min <= node.y - node.box_height / 2 and boundary.y_max >= node.y + node.box_height / 2,
                mode..': boundary encloses subtree vertically')
            if mode == 'right' then check(summary.x > node.x + node.box_width, 'summary right of descendants')
            elseif mode == 'left' then check(summary.x < node.x, 'summary left of descendants')
            else check(summary.y < node.y - node.box_height / 2, 'summary below descendants') end
        end)
    end
end
-- Recomputing after folding must discard a previously visible boundary.
local root = prepare('# Root\n  - Fold, name=fold\n    - Child, name=child\n\\boundary{child}{Changing}', {})
check(ast.boundaries[1].box ~= nil, 'initial boundary exists')
ast.named_nodes.fold.collapsed = true
layout.compute(root, {})
check(ast.boundaries[1].box == nil, 'stale hidden boundary discarded')
ast.named_nodes.fold.collapsed = false
layout.compute(root, {})
check(ast.boundaries[1].box ~= nil, 'boundary returns after unfolding')

-- Layout aliases must preserve geometry, not only compile successfully.
for alias, canonical in pairs({mindmap='balanced', down='vertical', org='vertical', tree_down='vertical', ishikawa='fishbone', cause_effect='fishbone'}) do
    local original = prepare(tree, {layout=canonical})
    local expected = {}
    ast.traverse_visible(original, function(node) expected[#expected+1] = {node.x,node.y,node.box_width,node.box_height} end)
    local actual = prepare(tree, {layout=alias})
    local index = 0
    ast.traverse_visible(actual, function(node)
        index = index + 1
        for j, value in ipairs({node.x,node.y,node.box_width,node.box_height}) do
            check(math.abs(value-expected[index][j]) < 0.01, alias..': equivalent geometry')
        end
    end)
end
-- Single-node charts and folded roots are valid inputs in tree layouts.
for _, mode in ipairs({'right','left','balanced','vertical'}) do
    for _, input in ipairs({'# Alone', '# Folded, collapsed\n  - Hidden'}) do
        local root = prepare(input, {layout=mode})
        local count = 0
        ast.traverse_visible(root, function(node)
            count = count + 1
            check(node.box_width > 0 and node.box_height > 0, mode..': positive isolated root')
        end)
        check(count == 1, mode..': exactly one visible node')
        check(not render(root, {}):find('{Hidden}',1,true), mode..': hidden root child absent')
    end
end
-- Relationships use named node anchors and preserve shape transforms.
local root = prepare(tree..'\n\\rel[from_anchor=south,to_anchor=north]{a}{b}{Anchored}', {})
local output = render(root, {scale='0.5'})
check(output:find('(mc_node_'..ast.named_nodes.a.id..'.south)',1,true), 'explicit relationship source anchor')
check(output:find('(mc_node_'..ast.named_nodes.b.id..'.north)',1,true), 'explicit relationship target anchor')
check(output:find('transform shape',1,true) and output:find('scale=0.5',1,true), 'scaled nodes retain shape transform')
for _, failure in ipairs(failures) do print('FAIL: '..failure) end
assert(#failures == 0, #failures..' failures in '..checks..' checks')
print('Cross-feature contracts passed: '..checks)
