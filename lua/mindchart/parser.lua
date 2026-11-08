--[[
  mindchart/parser.lua
  Parses bracket-notation hierarchical mind map input into an AST.
  Respects TeX grouping braces '{' and '}' so that LaTeX macros, math formulas,
  and formatting within node labels are preserved intact.
--]]

local ast = require("mindchart.ast")

local parser = {}

--- Trims leading and trailing whitespace from a string.
local function trim(s)
    return s:match("^%s*(.-)%s*$") or ""
end

--- Parses option string (e.g. "color=red, side=left") into a key-value table.
--- @param opt_str string
--- @return table
local function parse_options(opt_str)
    local opts = {}
    if not opt_str or opt_str == "" then return opts end

    -- Split by comma outside of braces
    local tokens = {}
    local current = {}
    local brace_level = 0
    for i = 1, #opt_str do
        local c = opt_str:sub(i, i)
        if c == "{" then
            brace_level = brace_level + 1
            table.insert(current, c)
        elseif c == "}" then
            if brace_level > 0 then brace_level = brace_level - 1 end
            table.insert(current, c)
        elseif c == "," and brace_level == 0 then
            table.insert(tokens, table.concat(current))
            current = {}
        else
            table.insert(current, c)
        end
    end
    if #current > 0 then
        table.insert(tokens, table.concat(current))
    end

    for _, tok in ipairs(tokens) do
        tok = trim(tok)
        local key, val = tok:match("^([%w%-_]+)%s*=%s*(.-)$")
        if key and val then
            -- Strip outer braces from val if present
            val = val:match("^{?(.-)}?$") or val
            opts[key] = trim(val)
        elseif tok ~= "" then
            -- Flag option
            opts[tok] = true
        end
    end
    return opts
end
parser.parse_options = parse_options

--- Separates node declaration into text and options.
--- E.g., "Central Topic, color=red, side=left" -> text: "Central Topic", options: {color="red", side="left"}
--- Respects braces '{...}' and math mode '$...$'.
local function parse_node_declaration(decl)
    decl = trim(decl)
    local brace_level = 0
    local in_math = false
    local text_parts = {}
    local opt_start = nil

    local i = 1
    local len = #decl
    while i <= len do
        local c = decl:sub(i, i)
        if c == "$" and (i == 1 or decl:sub(i - 1, i - 1) ~= "\\") then
            in_math = not in_math
            table.insert(text_parts, c)
        elseif c == "{" and not in_math then
            brace_level = brace_level + 1
            table.insert(text_parts, c)
        elseif c == "}" and not in_math then
            if brace_level > 0 then brace_level = brace_level - 1 end
            table.insert(text_parts, c)
        elseif c == "," and brace_level == 0 and not in_math then
            -- Check if what follows resembles key=value or a known flag option
            local rest = decl:sub(i + 1)
            local flag = rest:match("^%s*([%w%-_]+)%s*$") or rest:match("^%s*([%w%-_]+)%s*,")
            if rest:match("^%s*[%w%-_]+%s*=") or (flag and (flag == "collapsed" or flag == "folded" or flag == "left" or flag == "right")) then
                opt_start = i + 1
                break
            else
                table.insert(text_parts, c)
            end
        else
            table.insert(text_parts, c)
        end
        i = i + 1
    end

    local text = trim(table.concat(text_parts))
    local options = {}
    if opt_start then
        options = parse_options(decl:sub(opt_start))
    end

    -- If text itself is enclosed in an outer pair of braces, e.g. "{Foo, bar}", strip outer braces
    local stripped = text:match("^{([^{}]+)}$")
    if stripped then
        text = stripped
    end

    -- Clean up newlines and spaces around explicit '\\'
    text = text:gsub("[\r\n]+", " ")
    text = text:gsub("%s*\\\\%s*", "\\\\")

    return text, options
end

--- Parses TeX commands like \summary[opts]{from}{to}{label} and \rel[opts]{from}{to}{label}.
local function parse_command_invocations(input)
    local summaries = {}
    local relationships = {}

    -- Helper to extract balanced { ... }
    local function extract_arg(str, start_pos)
        local i = start_pos
        local len = #str
        while i <= len and str:sub(i, i):match("%s") do i = i + 1 end
        if i > len or str:sub(i, i) ~= "{" then return nil, start_pos end

        local depth = 0
        local content = {}
        local j = i
        while j <= len do
            local c = str:sub(j, j)
            if c == "{" then
                depth = depth + 1
                if depth > 1 then table.insert(content, c) end
            elseif c == "}" then
                depth = depth - 1
                if depth == 0 then
                    return table.concat(content), j + 1
                else
                    table.insert(content, c)
                end
            else
                table.insert(content, c)
            end
            j = j + 1
        end
        return nil, start_pos
    end

    -- Helper to extract optional [ ... ]
    local function extract_opt(str, start_pos)
        local i = start_pos
        local len = #str
        while i <= len and str:sub(i, i):match("%s") do i = i + 1 end
        if i > len or str:sub(i, i) ~= "[" then return nil, start_pos end

        local depth = 0
        local content = {}
        local j = i
        while j <= len do
            local c = str:sub(j, j)
            if c == "[" then
                depth = depth + 1
                if depth > 1 then table.insert(content, c) end
            elseif c == "]" then
                depth = depth - 1
                if depth == 0 then
                    return table.concat(content), j + 1
                else
                    table.insert(content, c)
                end
            else
                table.insert(content, c)
            end
            j = j + 1
        end
        return nil, start_pos
    end

    -- Scan for \summary, \rel, and \boundary
    local summaries = {}
    local relationships = {}
    local boundaries = {}

    local pos = 1
    local len = #input
    while pos <= len do
        local s_sum, e_sum = input:find("\\summary", pos, true)
        local s_rel, e_rel = input:find("\\rel", pos, true)
        local s_bnd, e_bnd = input:find("\\boundary", pos, true)

        local next_cmd = nil
        local cmd_type = nil
        local cmd_end = nil

        local function check(s, e, t)
            if s and (not next_cmd or s < next_cmd) then
                next_cmd = s
                cmd_type = t
                cmd_end = e
            end
        end

        check(s_sum, e_sum, "summary")
        check(s_rel, e_rel, "rel")
        check(s_bnd, e_bnd, "boundary")

        if not next_cmd then break end

        local cur = cmd_end + 1
        local opt_str, next_pos = extract_opt(input, cur)
        cur = next_pos
        local opts = parse_options(opt_str or "")

        local arg1, p1 = extract_arg(input, cur)
        local arg2, p2 = extract_arg(input, p1)
        local arg3, p3 = extract_arg(input, p2)

        if cmd_type == "boundary" then
            if arg1 then
                local b_from, b_to, b_title, next_cur
                if arg3 then
                    b_from = trim(arg1)
                    b_to = trim(arg2)
                    b_title = trim(arg3)
                    next_cur = p3
                elseif arg2 then
                    if opts.to then
                        b_from = trim(arg1)
                        b_to = trim(opts.to)
                        b_title = trim(arg2)
                    else
                        b_from = trim(arg1)
                        b_to = trim(arg1)
                        b_title = trim(arg2)
                    end
                    next_cur = p2
                else
                    b_from = trim(arg1)
                    b_to = trim(opts.to or arg1)
                    b_title = trim(opts.title or "")
                    next_cur = p1
                end

                if opts.title and b_title == "" then
                    b_title = trim(opts.title)
                end

                table.insert(boundaries, {
                    from = b_from,
                    to = b_to,
                    title = b_title,
                    options = opts,
                })
                pos = next_cur
            else
                pos = cmd_end + 1
            end
        else
            if arg1 and arg2 then
                if cmd_type == "summary" then
                    table.insert(summaries, {
                        from = trim(arg1),
                        to = trim(arg2),
                        text = trim(arg3 or ""),
                        options = opts,
                    })
                elseif cmd_type == "rel" then
                    table.insert(relationships, {
                        from = trim(arg1),
                        to = trim(arg2),
                        text = trim(arg3 or ""),
                        options = opts,
                    })
                end
                pos = p3 or p2
            else
                pos = cmd_end + 1
            end
        end
    end

    return summaries, relationships, boundaries
end

--- Parses bracket notation string into an AST tree.
--- Example: "[Root [Child 1 [Grandchild 1]] [Child 2, color=blue]]"
--- Also detects \summary and \rel overlay declarations.
--- @param input string
--- @return table|nil The root Node of the AST.
function parser.parse_bracket(input)
    if not input or input == "" then return nil end

    ast.reset_counter()

    -- Extract summaries, relationships, and boundaries first
    local raw_summaries, raw_rels, raw_boundaries = parse_command_invocations(input)

    local stack = {}
    local root = nil
    local current_decl = {}
    local brace_level = 0
    local in_node = false

    local len = #input
    local i = 1

    while i <= len do
        -- If we encounter a backslash command like \summary or \rel outside any node text, skip it
        if not in_node and input:sub(i, i) == "\\" then
            -- Find end of line or next bracket
            local next_bracket = input:find("[", i + 1, true)
            if next_bracket then
                i = next_bracket - 1
            else
                break
            end
        end

        local c = input:sub(i, i)

        if c == "{" then
            brace_level = brace_level + 1
            if in_node then table.insert(current_decl, c) end
        elseif c == "}" then
            if brace_level > 0 then brace_level = brace_level - 1 end
            if in_node then table.insert(current_decl, c) end
        elseif c == "[" and brace_level == 0 then
            -- If we were accumulating text for the parent node, finalize parent's declaration
            if in_node and #current_decl > 0 and #stack > 0 then
                local parent_node = stack[#stack]
                if parent_node.text == "" then
                    local text, opts = parse_node_declaration(table.concat(current_decl))
                    parent_node.text = text
                    for k, v in pairs(opts) do parent_node.options[k] = v end
                    ast.init_badges_and_tags(parent_node)
                    if opts.name or opts.id then
                        local n = opts.name or opts.id
                        ast.named_nodes[n] = parent_node
                        parent_node.name = n
                    end
                end
                current_decl = {}
            end

            -- Create a new node
            local new_node = ast.new_node("", {})
            if #stack > 0 then
                ast.add_child(stack[#stack], new_node)
            else
                root = new_node
            end
            table.insert(stack, new_node)
            in_node = true
            current_decl = {}

        elseif c == "]" and brace_level == 0 then
            if in_node and #stack > 0 then
                local node = stack[#stack]
                -- If this node's text hasn't been set yet, set it from current_decl
                if node.text == "" and #current_decl > 0 then
                    local text, opts = parse_node_declaration(table.concat(current_decl))
                    node.text = text
                    for k, v in pairs(opts) do node.options[k] = v end
                    ast.init_badges_and_tags(node)
                    if opts.name or opts.id then
                        local n = opts.name or opts.id
                        ast.named_nodes[n] = node
                        node.name = n
                    end
                end
                table.remove(stack)
                current_decl = {}
                if #stack == 0 then
                    in_node = false
                    -- Stop parsing tree once root node is closed
                    if root then
                        break
                    end
                end
            end
        else
            if in_node then
                table.insert(current_decl, c)
            end
        end

        i = i + 1
    end

    -- Process summaries, relationships, and boundaries
    local function process_overlays(summaries, rels, boundaries)
        for _, s in ipairs(summaries) do
            local s_node = ast.new_node(s.text, s.options)
            s_node.is_summary = true
            s_node.style = s.options.style or "card"
            s.node = s_node
            table.insert(ast.summaries, s)
        end

        for _, r in ipairs(rels) do
            table.insert(ast.relationships, r)
        end

        if boundaries then
            for _, b in ipairs(boundaries) do
                if b.title and b.title ~= "" then
                    local b_node = ast.new_node(b.title, b.options)
                    b_node.is_boundary = true
                    b_node.style = "badge"
                    b.node = b_node
                end
                table.insert(ast.boundaries, b)
            end
        end
    end

    process_overlays(raw_summaries, raw_rels, raw_boundaries)

    return root
end

--- Parses markdown-style indented list or heading notation into an AST.
--- Supports:
---   # Root Heading
---     - Branch 1, name=b1
---       - Subtopic 1.1
---     - Branch 2
--- Also supports pure bullets (- / * / + / 1.), pure headings (## / ###), or unadorned indented text.
--- @param input string
--- @return table|nil Root node of AST
function parser.parse_markdown(input)
    if not input or input == "" then return nil end

    ast.reset_counter()

    -- Extract overlays (\summary, \rel, and \boundary)
    local raw_summaries, raw_rels, raw_boundaries = parse_command_invocations(input)

    local root = nil
    -- Stack items: { node = Node, indent = number, heading_level = number }
    local stack = {}

    -- Helper to process overlays
    local function process_overlays(summaries, rels, boundaries)
        for _, s in ipairs(summaries) do
            local s_node = ast.new_node(s.text, s.options)
            s_node.is_summary = true
            s_node.style = s.options.style or "card"
            s.node = s_node
            table.insert(ast.summaries, s)
        end

        for _, r in ipairs(rels) do
            table.insert(ast.relationships, r)
        end

        if boundaries then
            for _, b in ipairs(boundaries) do
                if b.title and b.title ~= "" then
                    local b_node = ast.new_node(b.title, b.options)
                    b_node.is_boundary = true
                    b_node.style = "badge"
                    b.node = b_node
                end
                table.insert(ast.boundaries, b)
            end
        end
    end

    -- Pre-process lines to handle trailing '\\' line continuation
    local raw_lines = {}
    for raw_line in input:gmatch("[^\r\n]+") do
        table.insert(raw_lines, raw_line)
    end

    local lines = {}
    local line_idx = 1
    while line_idx <= #raw_lines do
        local cur_line = raw_lines[line_idx]
        local trimmed = trim(cur_line)
        if not trimmed:match("^%%") and not trimmed:match("^\\summary") and not trimmed:match("^\\rel") and not trimmed:match("^\\boundary") then
            while cur_line:match("\\\\%s*$") and line_idx < #raw_lines do
                local next_line = raw_lines[line_idx + 1]
                local next_trimmed = trim(next_line)
                if next_trimmed == "" or next_trimmed:match("^%%") or next_trimmed:match("^\\summary") or next_trimmed:match("^\\rel") or next_trimmed:match("^\\boundary") then
                    break
                end
                local is_new_bullet = next_trimmed:match("^[%-%*%+]%s+") or next_trimmed:match("^%d+[%.)]%s+") or next_trimmed:match("^#+%s*")
                if is_new_bullet then
                    break
                end
                local base = cur_line:match("^(.-)%s*\\\\%s*$")
                cur_line = base .. "\\\\" .. next_trimmed
                line_idx = line_idx + 1
            end
        end
        table.insert(lines, cur_line)
        line_idx = line_idx + 1
    end

    for _, raw_line in ipairs(lines) do
        if raw_line:match("%S") then
            -- Expand tabs to 4 spaces
            local line = raw_line:gsub("\t", "    ")
            local indent_str = line:match("^(%s*)")
            local indent = #indent_str
            local trimmed = trim(line)

            -- Skip TeX comments or overlay command lines (already extracted)
            if not trimmed:match("^%%") and not trimmed:match("^\\summary") and not trimmed:match("^\\rel") and not trimmed:match("^\\boundary") then
                -- Determine if line is a markdown heading (#...) or bullet list item
                local hashes, h_content = trimmed:match("^(#+)%s*(.*)$")
                local h_level = hashes and #hashes or 0
                local decl = nil

                if h_level > 0 then
                    decl = h_content
                else
                    -- Check for list bullet: '-', '*', '+', or '1.', '2.', etc.
                    local bullet, b_content = trimmed:match("^([%-%*%+])%s+(.*)$")
                    if not bullet then
                        bullet, b_content = trimmed:match("^(%d+[%.)])%s+(.*)$")
                    end

                    if bullet then
                        decl = b_content
                    else
                        decl = trimmed
                    end
                end

                if decl and decl ~= "" then
                    local text, opts = parse_node_declaration(decl)
                    local new_node = ast.new_node(text, opts)
                    if opts.name or opts.id then
                        local n = opts.name or opts.id
                        ast.named_nodes[n] = new_node
                        new_node.name = n
                    end

                    if not root then
                        root = new_node
                        table.insert(stack, { node = new_node, indent = indent, heading_level = h_level })
                    else
                        if h_level > 0 then
                            -- Heading mode: find closest ancestor with smaller heading level
                            while #stack > 1 and stack[#stack].heading_level >= h_level do
                                table.remove(stack)
                            end
                            local parent = stack[#stack].node
                            ast.add_child(parent, new_node)
                            table.insert(stack, { node = new_node, indent = indent, heading_level = h_level })
                        else
                            -- Indented / bullet mode
                            if #stack == 1 then
                                -- Only root on stack; new node must be a child of root
                                local parent = stack[1].node
                                ast.add_child(parent, new_node)
                                table.insert(stack, { node = new_node, indent = indent, heading_level = 0 })
                            else
                                local top_indent = stack[#stack].indent
                                if indent > top_indent then
                                    -- Indented deeper: child of the current top node
                                    local parent = stack[#stack].node
                                    ast.add_child(parent, new_node)
                                    table.insert(stack, { node = new_node, indent = indent, heading_level = 0 })
                                elseif indent == top_indent then
                                    -- Same indent: sibling of current top node
                                    table.remove(stack)
                                    local parent = stack[#stack].node
                                    ast.add_child(parent, new_node)
                                    table.insert(stack, { node = new_node, indent = indent, heading_level = 0 })
                                else
                                    -- Dedented: pop until stack node has indent < current indent
                                    while #stack > 1 and stack[#stack].indent > indent do
                                        table.remove(stack)
                                    end
                                    if #stack > 1 and stack[#stack].indent == indent then
                                        table.remove(stack)
                                    end
                                    local parent = stack[#stack].node
                                    ast.add_child(parent, new_node)
                                    table.insert(stack, { node = new_node, indent = indent, heading_level = 0 })
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    process_overlays(raw_summaries, raw_rels, raw_boundaries)

    return root
end

return parser
