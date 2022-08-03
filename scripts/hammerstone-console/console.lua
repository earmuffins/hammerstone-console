--- Hammerstone Console: console.lua
--- This file contains everything you need to create and deploy commands.
--- @author earmuffs

--- Found a bug? Have a suggestion? Please notify me on Discord at earmuffs#3820. Thanks!

local eventManager = mjrequire "hammerstone/event/eventManager"
local eventTypes = mjrequire "hammerstone/event/eventTypes"
local uiManager = mjrequire "hammerstone/ui/uiManager"

local consoleUI = mjrequire "hammerstone-console/consoleUI"
local commands = mjrequire "hammerstone-console/commands"

local mjm = mjrequire "common/mjm"
local vec4 = mjm.vec4

local console = {
    name = "Hammerstone Console",
    version = "0.1",
    debug = false,

    utils = {},

    targets = {},
    commandPaths = {},
    commands = {},
    history = {},

    textColor  = vec4(0.9, 0.9,  0.9,  1.0),
    warnColor  = vec4(1.0, 0.9,  0.0,  1.0),
    errorColor = vec4(1.0, 0.24, 0.11, 1.0),
    infoColor  = vec4(0.0, 0.78, 1.0,  1.0),

    margin = " ",
    marginLarge = "",
    caret = "_",
    autopause = true,

    --env = {}
}


---------------------------------------------------------------------------------
--[[ Console Functions ]]
---------------------------------------------------------------------------------

---addCommand(path, func)
---@param path string
---@param func function
---Example:
---addCommand("help list", function(c, params) c:print("This is some help.") end)
---
---Adds a command (or multiple) to the Hammerstone console.
function console:addCommand(path, params, func)
    if type(path) == "table" then
        for _,v in ipairs(path) do
            consoleUI:addCommand(v, params, func)
        end
    else
        consoleUI:addCommand(path, params, func)
    end
end

---clear()
---
---Clears the console.
function console:clear()
    consoleUI:clearLines()
end

---newline()
---
---Outputs a blank line to the Hammerstone console.
function console:newline()
    consoleUI:print("")
end

---print(text, (Optional) color)
---@param text string
---@param color vec4
---Example:
---print("Hello World!", vec4(1.0, 0.0, 0.0, 1.0))
---
---Prints to the Hammerstone console.
function console:print(text, color)
    consoleUI:print(text, color)
end

---warn(text)
---@param text string
---Example:
---warn("This function is experimental.")
--- 
---Output: WARNING: This function is experimental.
---
---Prints a warning message to the Hammerstone console.
function console:warn(text)
    consoleUI:print("WARNING: " .. text, console.warnColor)
end

---warn(text)
---@param text string
---Example:
---error("Function could not run.")
---
---Output: ERROR: Function could not run.
---
---Prints an error message to the Hammerstone console.
function console:error(text)
    consoleUI:print("ERROR: " .. text, console.errorColor)
end

---info(text)
---@param text string
---Example:
---info("You can enter \\\"help list\\\" to see all commands.")
---
---Output: INFO: You can enter \"help list\" to see all commands..
---
---Prints an info message to the Hammerstone console.
function console:info(text)
    consoleUI:print("INFO: " .. text, console.infoColor)
end

---printTitle(text, (Optional) color)
---@param text string
---@param color vec4
---Example:
---printTitle("Hello World!", vec4(1.0, 0.0, 0.0, 1.0))
---
---Prints a title to the Hammerstone console.
function console:printTitle(text, color)
    consoleUI:printTitle(text, color)
end

---printValues(columnWidth, ...)
---@param columnWidth number
---@vararg string
---Example:
---printValues(16, "Key", "ValueA", "ValueB")
---
---Prints a table row to the Hammerstone console.
function console:printValues(columnWidth, ...)
    consoleUI:printValues(columnWidth, ...)
end


---------------------------------------------------------------------------------
--[[  Console Init Functions ]]
---------------------------------------------------------------------------------

local function loadEnv()
    -- Someday
end

local function loadUtils()
    console.utils = consoleUI:utils()
    if console.debug then
        mj:log("\nConsole Utils: ", console.utils)
        local arr = console.utils.split("this is a brown dog")
        mj:log("\n",
            "startsWith: ", console.utils.startsWith("this is a brown dog", "this is"), "\n",
            "endsWith:   ", console.utils.endsWith("this is a brown dog", "brown dog"), "\n",
            "split:      ", console.utils.split("this is a brown dog"), "\n",
            "join:       ", console.utils.join(arr, " "), "\n",
            "padLeft:    ", "key" .. console.utils.padLeft("value", " ", 16), "\n",
            "padRight:   ", console.utils.padRight("key", " ", 16) .. "value", "\n",
            "padCenter:  ", console.utils.padCenter("key", " ", "value", 16), "\n"
        )
    end
end

local function loadPresetCommands()
    commands:load(console)
    if console.debug then
        mj:log("\nConsole Commands: \n\n", console.commands)
    end
end

function console:init()
    mj:log("Initializing Hammerstone Console...")

    consoleUI.console = console

    uiManager:registerManageElement(consoleUI);

    loadEnv()
    loadUtils()
    loadPresetCommands()

    mj:log("Initialized Hammerstone Console.")
end

return console