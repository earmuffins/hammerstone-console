# Hammerstone Console

Introduces a seamless in-game tool to interface with your mods.

Please be aware that this project is likely to change as it gets polished.

`Hammerstone Framework required.` View on
[Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2840825226) or
[Github](https://github.com/SirLich/hammerstone-framework).

## How to use
Inside the game, the console can be found next to the settings button after opening any menu.

![image](https://user-images.githubusercontent.com/110178856/182709001-7dbeb074-0e9f-4bb5-8513-557e54772197.png)

## Developing your mod
Implementation is quick and easy. Here are a few examples:

```lua
-- Make sure to require the module
local console = mjrequire "hammerstone-console/console"
```

```lua
-- Display some text when a command is entered
console:addCommand("help mymod", {}, function(c, params)
    c:print("Enter \"mymod example\" to see an example.")
end)
```

A full Hammerstone Framework module:
```lua
local console = mjrequire "hammerstone-console/console"

local mod = {}

function mod:init()
    mj:log("Initializing mod...")

    console:print("Resource models loading...")
    console:error("Resource 'granary' could not be loaded!")
    console:warn("This mod is outdated!")
    console:info("Enter \"resmod\" for more info about this mod.")

    console:addCommand("resmod", {}, function(c, params)
        c:print("Created as a test module for the Hammerstone Console.")
    end)
    
    mj:log("Initialized mod.")
end

return mod
```

### Variables
Variables are a way for users to input specific values. If a value with an unexpected type is entered, the command will fail. All values are returned in the params object.

Types of variables:
- **number**: casted int or float
- **string**: text, can be surrounded by quotation marks
- **bool**: true or false
- **custom**: see more in the custom field section
```lua
-- This command uses "number" variables
console:addCommand("add number number", {}, function(c, params)
    c:print(params.param1 + params.param2)
end)

-- Input:  add 2 2
-- Output: 4
```

Accessing variables is straightforward. If an alias is given, it will return with that key (see next example). Otherwise, they return as a list: param1, param2,...

### Aliases
An alias can be added to a variable with the colon character, followed by the alias. This "nickname" can be used to reference the returning params and is displayed in the console when a user is typing.
```lua
console:addCommand("spawn string:object", {}, function(c, params)
    c:print("Spawning a " .. params.object)
    -- Do the spawning
end)

-- Input:  spawn mammoth
-- Output: Spawning a mammoth
```

### Custom variables
Custom variables have set autofill values, displayed in a dropdown. Similar to enums.
```lua
local customData = {
    {
        "Visibility",
        "Move Speed",
        "Carry Weight"
    },
    {
        {"Low", "1"},
        {"Medium", "2"}, -- Custom data can autofill different text
        {"High", "3"}
    }
}

-- This command uses custom variables with simple sets of data
console:addCommand("mymod set custom:key custom:value", customData, function(c, params)
    c:print("Set " .. params.key .. " to " .. params.value)
end)
```

```lua
local resource = mjrequire "common/resource"

-- This command uses a custom variable with a function that runs every time an autofill hint appears
console:addCommand("resource spawn custom:object number:count", {
    function()
        local customData = {}
        for _,v in pairs(resource.validTypes) do
            table.insert(customData, { v.plural, v.key }) -- Display name, value to return
        end
        return customData
    end
}, function(c, params)
    c:print(params.object)
    c:print(params.count)
end)
```



