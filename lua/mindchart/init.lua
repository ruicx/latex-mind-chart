--[[
  mindchart/init.lua
  Main coordinator and public API for mindchart.
--]]

local parser = require("mindchart.parser")
local measure = require("mindchart.measure")
local layout = require("mindchart.layout")
local theme = require("mindchart.theme")
local renderer = require("mindchart.renderer")

local mindchart = {}

local current_ast = nil
local current_options = {}

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

--- Step 1: Prepares AST from raw input and kicks off measurement in TeX.
--- @param raw_input string
--- @param opt_str string
function mindchart.prepare(raw_input, opt_str)
    current_options = parse_options_string(opt_str)
    current_ast = parser.parse_bracket(raw_input)

    if not current_ast then
        texio.write_nl("mindchart error: failed to parse tree input.")
        return
    end

    measure.init(current_ast)
    measure.emit_measurement_commands()
end

--- Step 2: Stores measured dimensions from TeX box.
--- @param id number
--- @param box_num number
function mindchart.store_dim(id, box_num)
    measure.store_dim(id, box_num)
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
