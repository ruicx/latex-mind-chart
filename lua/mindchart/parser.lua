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

--- Separates node declaration into text and options.
--- E.g., "Central Topic, color=red, side=left" -> text: "Central Topic", options: {color="red", side="left"}
--- If commas exist without '=', they are kept as part of text unless followed by key=val.
local function parse_node_declaration(decl)
    decl = trim(decl)
    local brace_level = 0
    local text_parts = {}
    local opt_start = nil

    local i = 1
    local len = #decl
    while i <= len do
        local c = decl:sub(i, i)
        if c == "{" then
            brace_level = brace_level + 1
            table.insert(text_parts, c)
        elseif c == "}" then
            if brace_level > 0 then brace_level = brace_level - 1 end
            table.insert(text_parts, c)
        elseif c == "," and brace_level == 0 then
            -- Check if what follows resembles key=value
            local rest = decl:sub(i + 1)
            if rest:match("^%s*[%w%-_]+%s*=") or rest:match("^%s*side%s*=") or rest:match("^%s*color%s*=") then
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

    return text, options
end

--- Parses bracket notation string into an AST tree.
--- Example: "[Root [Child 1 [Grandchild 1]] [Child 2, color=blue]]"
--- @param input string
--- @return table|nil The root Node of the AST.
function parser.parse_bracket(input)
    if not input or input == "" then return nil end

    ast.reset_counter()

    local stack = {}
    local root = nil
    local current_decl = {}
    local brace_level = 0
    local in_node = false

    local len = #input
    local i = 1

    while i <= len do
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
                end
                table.remove(stack)
                current_decl = {}
                if #stack == 0 then
                    in_node = false
                end
            end
        else
            if in_node then
                table.insert(current_decl, c)
            end
        end

        i = i + 1
    end

    return root
end

return parser
