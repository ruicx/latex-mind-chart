--[[
  tex/mindchart.lua
  Bootstrap and custom module loader for mindchart.
--]]

-- Register a custom searcher for mindchart modules in ./lua/
table.insert(package.searchers, 2, function(modname)
    if modname:sub(1, 9) == "mindchart" then
        local subpath = modname:gsub("%.", "/")
        local candidates = {
            "./lua/" .. subpath .. ".lua",
            "./lua/" .. subpath .. "/init.lua",
        }
        for _, file_path in ipairs(candidates) do
            local f = io.open(file_path, "r")
            if f then
                f:close()
                return loadfile(file_path)
            end
        end
        return "\n\t[mindchart searcher] not found: " .. modname
    end
    return nil
end)

mindchart = require("mindchart.init")
package.loaded["mindchart"] = mindchart
