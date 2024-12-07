#!/usr/bin/env luajit

local function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end

local args = { ... }

local paramFile = io.open(args[1], "r")
local cruncher = io.open(args[2], "r")
local outputFile = io.open(args[3], "a")

local code = cruncher:read("*a")
io.close(cruncher)

local run = (loadstring or load)(code)

::next::
local params = split(paramFile:read("*l"))
if params then
    local ok, runOutput = pcall(run, (table.unpack or unpack)(params))
    if not ok then
        print(runOutput)
    else
        local outputLine = ""
        for i, v in ipairs(runOutput) do
            outputLine = outputLine .. tostring(v) .. " "
        end
        outputLine = outputLine .. "\n"
        outputFile:write(outputLine)
        outputFile:flush()
    end
    goto next
end
paramFile:close()
outputFile:close()
