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
    return parser.parse_options(str)
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

    theme.apply(current_ast, current_options)
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

    -- Compute geometric layout
    layout.compute(current_ast, current_options)

    -- Render TikZ commands
    renderer.render(current_ast, current_options)
end

--- Registers a user-defined theme palette.
mindchart.define_theme = theme.define_theme

mindchart.store_font = measure.store_font

--- Shrinks the complete rendered TeX box to the requested limits.
--- @param box_num number
--- @param width number Maximum width in scaled points, zero for unconstrained.
--- @param height number Maximum total height in scaled points, zero for unconstrained.
function mindchart.fit(box_num, width, height)
    if width < 0 or height < 0 then error("mindchart: fit limits must be nonnegative") end
    local box = tex.box[box_num]
    local factor = 1
    if width > 0 and box.width > 0 then factor = math.min(factor, width / box.width) end
    if height > 0 and box.height + box.depth > 0 then
        factor = math.min(factor, height / (box.height + box.depth))
    end
    -- Round down so numerical formatting never enlarges beyond a requested limit.
    factor = math.floor(factor * 65536) / 65536
    local font_size = measure.minimum_font() * (tonumber(current_options.scale) or 1) * factor
    local minimum = tonumber(current_options.min_font_size) or 6
    if font_size < minimum then
        tex.print(string.format("\\PackageWarning{mindchart}{Fitted main-label font %.2fpt is below %.2fpt}%%", font_size, minimum))
    end
    tex.print(string.format("\\mindchartUseFit{%.10f}%%", factor))
end

return mindchart
