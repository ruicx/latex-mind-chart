--[[
  mindchart/init.lua
  Main coordinator and public API for mindchart.
--]]

local ast = require("mindchart.ast")
local parser = require("mindchart.parser")
local measure = require("mindchart.measure")
local layout = require("mindchart.layout")
local theme = require("mindchart.theme")
local renderer = require("mindchart.renderer")

local mindchart = {}

local current_ast = nil
local current_options = {}

local env_buffer_lines = {}
local env_options_str = ""

--- Parses raw key-value string from LaTeX into a Lua table.
local function parse_options_string(str)
    local opts = {}
    if not str or str == "" then return opts end
    for item in str:gmatch("[^,]+") do
        local k, v = item:match("^%s*([%w%-_]+)%s*=%s*(.-)%s*$")
        if k and v then
            opts[k] = v
        else
            local flag = item:match("^%s*([%w%-_]+)%s*$")
            if flag and flag ~= "" then
                opts[flag] = true
            end
        end
    end
    return opts
end

--- Detects syntax mode: "bracket" or "markdown".
local function detect_syntax(input, opts)
    if opts.syntax == "markdown" or opts.syntax == "md" then
        return "markdown"
    elseif opts.syntax == "bracket" then
        return "bracket"
    end
    -- Auto-detect: if first non-whitespace character is '[', treat as bracket notation
    local first_char = input:match("^%s*(%S)")
    if first_char == "[" then
        return "bracket"
    else
        return "markdown"
    end
end

--- Called at \begin{mindchart}[opts] to start recording raw input buffer lines.
--- This preserves exact spaces and indentation without TeX catcode interference.
--- @param opt_str string
function mindchart.start_env(opt_str)
    env_buffer_lines = {}
    env_options_str = opt_str or ""

    luatexbase.add_to_callback("process_input_buffer", function(line)
        local prefix, suffix = line:match("^(.-)\\end%s*%{%s*mindchart%s*%}(.*)$")
        if prefix then
            if prefix:match("%S") then
                table.insert(env_buffer_lines, prefix)
            end
            luatexbase.remove_from_callback("process_input_buffer", "mindchart_buffer")
            return "\\end{mindchart}" .. suffix
        end
        table.insert(env_buffer_lines, line)
        return "%"
    end, "mindchart_buffer")
end

--- Called at \end{mindchart} to finalize and execute the environment.
function mindchart.finish_env()
    local raw_input = table.concat(env_buffer_lines, "\n")
    mindchart.prepare(raw_input, env_options_str)
end

--- Step 1: Prepares AST from raw input and kicks off measurement in TeX.
--- @param raw_input string
--- @param opt_str string
function mindchart.prepare(raw_input, opt_str)
    current_options = parse_options_string(opt_str)
    local syntax = detect_syntax(raw_input, current_options)

    if syntax == "markdown" then
        current_ast = parser.parse_markdown(raw_input)
    else
        current_ast = parser.parse_bracket(raw_input)
    end

    if not current_ast then
        texio.write_nl("mindchart error: failed to parse tree input.")
        return
    end

    measure.init(current_ast, current_options)
    measure.emit_measurement_commands(current_options)
end

--- Step 2: Stores measured dimensions from TeX box.
--- @param id number
--- @param box_num number
--- @param is_multiline boolean|nil
function mindchart.store_dim(id, box_num, is_multiline)
    measure.store_dim(id, box_num, is_multiline)
end

--- Step 3: Executes layout algorithms and renders TikZ graphic.
function mindchart.render()
    if not current_ast then return end

    -- Apply theme styling and color propagation
    theme.apply(current_ast, current_options)

    -- Compute geometric layout
    layout.compute(current_ast, current_options)

    -- Render TikZ commands
    renderer.render(current_ast, current_options)
end

return mindchart
