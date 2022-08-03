--- Hammerstone Console: commands.lua
--- This file contains a list of commands available by default. This might grow in the future.
--- @author earmuffs

--- Found a bug? Have a suggestion? Please notify me on Discord at earmuffs#3820. Thanks!

-- Base
local typeMaps = mjrequire "common/typeMaps"
local resource = mjrequire "common/resource"

-- Math
local lev = mjrequire "hammerstone-console/levenshtein"
local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec3 = mjm.vec3
local vec4 = mjm.vec4

commands = {}


function commands:load(console)

    console.addCommand(self, { "h", "help" }, {}, function(c, params)
        c:newline()
        c:print("Enter \"help list\" for a list of commands.")
        c:newline()
    end)

    console.addCommand(self, "help list", {}, function(c, params)
        c:newline()
        c:print("Available commands:")
        c:newline()
        for _,v in pairs(c.commandPaths) do
            c:print(v)
        end
        c:newline()
    end)

    console.addCommand(self, "history list", {}, function(c, params)
        c:newline()
        c:print("History:")
        c:newline()
        for _,v in pairs(c.history) do
            c:print(v)
        end
        c:newline()
    end)

    console.addCommand(self, "clear", {}, function(c, params)
        c:clear()
    end)

    console.addCommand(self, "ping", {}, function(c, params)
        c:print("pong")
    end)

    console.addCommand(self, "version", {}, function(c, params)
        c:newline()
        c:print(console.name .. " [v" .. console.version .. "]")
        c:newline()
    end)

    console.addCommand(self, "mod list", {}, function(c, params)
        local modManager = mjrequire "common/modManager"
        local i = 1

        c:newline()
        c:print("App Mods:")
        for k,v in pairs(modManager.modInfosByTypeByDirName.app) do
            local enabled = ""
            for _,m in pairs(modManager.enabledModDirNamesAndVersionsByType.app) do
                if m.name == k then
                    enabled = "[enabled]"
                end
            end
            
            local line =
                c.utils.padRight(i, " ", 3) ..
                c.utils.padRight(enabled, " ", 12) ..
                c.utils.padRight(v.version or "", " ", 8) ..
                c.utils.padRight(v.name, " ", 38) ..
                c.utils.padRight("(" .. k .. ")", " ", 28) ..
                c.utils.padRight("by " .. v.developer, " ", 24)

            c:print(line)
            i = i + 1
        end
        c:newline()
        c:print("World Mods:")
        for k,v in pairs(modManager.modInfosByTypeByDirName.world) do
            local enabled = ""
            for _,m in pairs(modManager.enabledModDirNamesAndVersionsByType.world) do
                if m.name == k then
                    enabled = "[enabled]"
                end
            end

            local line =
                c.utils.padRight(i, " ", 3) ..
                c.utils.padRight(enabled, " ", 12) ..
                c.utils.padRight(v.version or "", " ", 8) ..
                c.utils.padRight(v.name, " ", 38) ..
                c.utils.padRight("(" .. k .. ")", " ", 28) ..
                c.utils.padRight("by " .. v.developer, " ", 24)

            c:print(line)
            i = i + 1
        end
        c:newline()
        c:print("Enter \"mod number:id\" for more info.")
    end)

    console.addCommand(self, "mod number:id", {}, function(c, params)
        local modManager = mjrequire "common/modManager"

        function display(mod)
            c:newline()
            c:printTitle(mod.name)
            if mod.type == "world" then 
                c:print("World mod by " .. mod.developer, vec4(1.0,1.0,1.0,0.6))
            else
                c:print("App mod by "   .. mod.developer, vec4(1.0,1.0,1.0,0.6))
            end
            c:newline()
            for _,v in ipairs(c.utils.split(mod.description, "\n")) do
                c:print(v)
            end
            c:newline()
            c:print(c.utils.padRight("Directory:", " ", 16) .. mod.directory)
            c:print(c.utils.padRight("Is Local:",  " ", 16) .. tostring(mod.isLocal))
            c:print(c.utils.padRight("Steam URL:", " ", 16) .. (mod.steamURL or "-"))
            c:newline()
        end

        local i = 1

        for k,v in pairs(modManager.modInfosByTypeByDirName.app) do
            if i == params.id then
                display(v)
            end
            i = i + 1
        end

        for k,v in pairs(modManager.modInfosByTypeByDirName.world) do
            if i == tonumber(params.id) then
                display(v)
            end
            i = i + 1
        end
    end)

    console.addCommand(self, "autopause bool", {}, function(c, params)
        console.autopause = params.param1
    end)

    console.addCommand(self, "caret", {}, function(c, params)
        c:newline()
        c:print("Set the console's cursor to a different text.")
        c:newline()
        c:printValues(16, "Current:", console.caret)
        c:printValues(16, "Usage:", "caret <string>")
        c:newline()
    end)

    console.addCommand(self, "caret string:symbol", {}, function(c, params)
        console.caret = params.symbol
    end)

    console.addCommand(self, "example bool:flag string:alias number:count", {}, function(c, params)
        c:newline()
        c:printValues(16, "flag:", params.flag)
        c:printValues(16, "alias:", params.alias)
        c:printValues(16, "count:", params.count)
        c:newline()
    end)

    console.addCommand(self, "example bool:flag", {}, function(c, params)
        c:newline()
        c:printValues(16, "flag:", params.flag)
        c:newline()
    end)

    console.addCommand(self, "example string:alias", {}, function(c, params)
        c:newline()
        c:printValues(16, "alias:", params.alias)
        c:newline()
    end)

    console.addCommand(self, "example number:count", {}, function(c, params)
        c:newline()
        c:printValues(16, "count:", params.count)
        c:newline()
    end)


    --[[
        
    -- No idea how to make this work, or even if I should. Under investigation.

    console.addCommand(self, "lua string", function(c, params)

        local code = params.param1
        local chunk = loadstring(code)
        
        if chunk then
            setfenv(chunk, console.env)
            local success, error = pcall(chunk)

            if success then
                c:print("Line ran successfully.")
                return
            end
        end

        c:error("Line failed to run:\n" .. error)
    end)

    ]]


    -- Targets

    console.addCommand(self, {"target", "targets"}, {}, function(c, params)
        c:newline()
        c:print("Selected Targets:")
        for i,object in ipairs(c.targets) do
            if object ~= nil then
                local type = gameObject.types[object.objectTypeIndex]
                --mj:log(" Object: ", object)
                --mj:log(" Type: ", type)
                if type.key == "sapien" then
                    -- If this is a Sapien
                    local state = object.sharedState
                    local gender = state.isFemale and "Female" or "Male"
                    c:printValues(12, i, state.name, gender)
                else
                    -- If this is an object
                    c:printValues(12, i, type.name, "Stored: " .. tostring(object.stored))
                end
            else
                c:error("No object selected.")
            end
        end
        c:newline()
    end)


    -- Resources

    console.addCommand(self, "resource list", {}, function(c, params)
        c:print("Resources:")
        for _,v in pairs(resource.validTypes) do
            c:printValues(50, v.plural, "(id: " .. v.key .. ")")
        end
    end)
end

return commands