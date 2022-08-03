--- Hammerstone Console: consoleUI.lua
--- This file contains all the logic behind the console.
--- @author earmuffs

--- Found a bug? Have a suggestion? Please notify me on Discord at earmuffs#3820. Thanks!

local consoleUI = {
	name = "Hammerstone Console",
	view = nil,
	parent = nil,
	icon = "icon_console",

    input = "",

    caretPosition = 0,
    isAutofillVisible = false,
}


-- Base
local gameState = mjrequire "hammerstone/state/gameState"

local eventManager = mjrequire "mainThread/eventManager"
local keyMapping = mjrequire "mainThread/keyMapping"
local audio = mjrequire "mainThread/audio"
--local actionUI = mjrequire "mainThread/ui/actionUI"

local uiStandardButton = mjrequire "mainThread/ui/uiCommon/uiStandardButton"
local uiScrollView = mjrequire "mainThread/ui/uiCommon/uiScrollView"
local uiCommon = mjrequire "mainThread/ui/uiCommon/uiCommon"
local uiObjectGrid = mjrequire "mainThread/ui/uiCommon/uiObjectGrid"

local timer = mjrequire "common/timer"
local model = mjrequire "common/model"
local gameObject = mjrequire "common/gameObject"


-- Math
local lev = mjrequire "hammerstone-console/levenshtein"
local mjm = mjrequire "common/mjm"
local vec2 = mjm.vec2
local vec3 = mjm.vec3
local vec4 = mjm.vec4


-- Globals
local backgroundWidth = 1140
local backgroundHeight = 640
local backgroundSize = vec2(backgroundWidth, backgroundHeight)

local fontSize = 16
local fontSizeLarge = 24
local consoleFont = Font(uiCommon.consoleFontName, fontSize)
local consoleFontLarge = Font(uiCommon.consoleFontName, fontSizeLarge)


---------------------------------------------------------------------------------
-- [[ Utils ]]
---------------------------------------------------------------------------------

-- WARNING: Empty items are thrown away
-- split("this is a ") returns { "this", "is", "a" }
function split(text, sep)
    text = tostring(text)
    local t = {}
    if sep == nil then sep = "%s" end
    for str in string.gmatch(text, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

-- https://stackoverflow.com/a/28665686
function splitTokens(text)
    local tokens = {}
    local e = 0
    while true do
        local b = e+1
        b = string.find(text, "%S", b)
        if b == nil then break end
        if string.sub(text, b, b) == "'" then
            e = string.find(text, "'", b+1)
            b = b+1
        elseif string.sub(text, b, b) == '"' then
            e = string.find(text, '"', b+1)
            b = b+1
        else
            e = string.find(text, "%s", b+1)
        end
        if e == nil then e = #text+1 end
        table.insert(tokens, text:sub(b,e-1))
    end
    return tokens
end

function join(arr, sep)
    local text = ""
    if sep == nil then
        sep = ""
    end
    for i,str in ipairs(arr) do
        if i == #arr then
            text = text .. str
        else
            text = text .. str .. sep
        end
    end
    return text
end

function startsWith(text, match)
    text = tostring(text)
    if #text < #match then return false end
    return string.sub(text, 1, #match) == match
end

function endsWith(text, match)
    text = tostring(text)
    if #text < #match then return false end
    return string.sub(text, #text - #match + 1) == match
end

function padLeft(text, char, length)
    text = tostring(text)
    local str = ""
    for i = 1, length - #text do str = str .. char end
    return str .. text
end

function padRight(text, char, length)
    text = tostring(text)
    local str = ""
    for i = 1, length - #text do str = str .. char end
    return text .. str
end

function padCenter(textA, char, textB, length)
    textA = tostring(textA)
    textB = tostring(textB)
    local str = ""
    for i = 1, (length - #textA - #textB) do str = str .. char end
    return textA .. str .. textB
end

function clamp(value, min, max)
    return math.min(math.max(value, min), max)
end

function consoleUI:utils()
    return {
        padLeft = padLeft,
        padRight = padRight,
        padCenter = padCenter,
        startsWith = startsWith,
        endsWith = endsWith,
        join = join,
        split = split,
        clamp = clamp,
    }
end


---------------------------------------------------------------------------------
-- [[ Setup ]]
---------------------------------------------------------------------------------

local loaded = false
local functionQueue = {}

local backgroundView = nil
local scrollView = nil
local scrollViewIndex = 0
local inputView = nil
local caretTimer = nil
local autofillColorView = nil
local autofillView = nil
local bottomStatusView = nil


function consoleUI:init(console)

    -- Fix some things based on resolution
    loadDisplayResolutionFixes()

    -- Main View
    self.view = View.new(console.view)
    self.view.size = backgroundSize
    self.view.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    self.view.hidden = true

    local scaleToUse = backgroundSize.x * 0.5

    -- Background View
    backgroundView = ModelView.new(self.view)
    backgroundView:setModel(model:modelIndexForName("ui_bg_lg_16x9"))
    backgroundView.scale3D = vec3(scaleToUse, scaleToUse, scaleToUse)
    backgroundView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    backgroundView.size = backgroundSize
    backgroundView.baseOffset = vec3(0, 0, 50) -- Move it in front of other UI

    -- Close Button
    local closeButton = uiStandardButton:create(backgroundView, vec2(50,50), uiStandardButton.types.markerLike)
    closeButton.relativePosition = ViewPosition(MJPositionInnerRight, MJPositionAbove)
    closeButton.baseOffset = vec3(30, -20, 0)
    uiStandardButton:setIconModel(closeButton, "icon_cross")
    uiStandardButton:setClickFunction(closeButton, function()
        consoleUI.hide()
    end)

    -- Inset background
    local backgroundScale = backgroundWidth / backgroundHeight
    local insetScale = 4.0 / 3.0
    local insetScaleCorrection = insetScale / backgroundScale
    insetView = ModelView.new(backgroundView)
    insetView:setModel(model:modelIndexForName("ui_inset_lg_4x3"))
    insetView.scale3D = vec3(scaleToUse, scaleToUse * insetScaleCorrection, scaleToUse) 
    insetView.size = backgroundSize
    insetView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)

    -- Scrollview
    scrollView = uiScrollView:create(insetView, backgroundSize - vec2(50, 70), MJPositionInnerLeft)
    scrollView.baseOffset = vec3(0,8,0)

    -- Input field
    inputView = TextView.new(insetView)
    inputView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    inputView.baseOffset = vec3(25,16,0)
    inputView.font = consoleFont
    inputView.color = vec4(1.0,1.0,1.0,1.0)
    setInputText("")

    -- Autofill view
    local autofillViewHeight = fontSize * 1.4 * 8 -- 8 items
    autofillColorView = ModelView.new(backgroundView)
    autofillColorView:setModel(model:modelIndexForName("ui_bg_lg_16x9"))
    
    local autofillScale = (backgroundSize.x / 2) / autofillViewHeight
    local autofillScaleCorrection = (16.0 / 9.0) / autofillScale
    autofillColorView.scale3D = vec3(1, autofillScaleCorrection, 1) * scaleToUse / 2
    autofillColorView.size = vec2(backgroundSize.x / 2, autofillViewHeight)
    autofillColorView.baseOffset = vec3(0, -(backgroundSize.y + autofillViewHeight) / 2, 1)
    autofillColorView.hidden = true

    autofillView = uiScrollView:create(autofillColorView, autofillColorView.size - vec2(6, 6), MJPositionInnerLeft)

    -- Bottom box
    --bottomStatusView = ModelView.new(backgroundView)
    --bottomStatusView:setModel(model:modelIndexForName("ui_bg_lg_16x9"))
    --bottomStatusView.scale3D = vec3(scaleToUse, scaleToUse, scaleToUse) / 5
    --bottomStatusView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    --bottomStatusView.size = backgroundSize
    --bottomStatusView.baseOffset = vec3(backgroundSize.x / 2, -backgroundSize.y / 2, 0)

    loadKeyMap()
    runQueue()
end

local function getEvenOddColor(i)
    -- TODO: make this look good somehow
    if i % 2 == 1 then
        return vec4(0.0, 0.0, 0.0, 0.0)
    else
        return vec4(0.0, 0.0, 0.0, 0.0)
    end
end

function sendLine(margin, text, color, _fontSize)

    -- Small exception for newline efficiency
    if #tostring(text) == 0 then
        local rowView = ColorView.new(scrollView)
        rowView.color = getEvenOddColor(scrollViewIndex)
        rowView.size = vec2(scrollView.size.x - 50, (_fontSize or fontSize) * 1.4)
        rowView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)

        scrollViewIndex = scrollViewIndex + 1
        uiScrollView:insertRow(scrollView, rowView, nil)
        uiScrollView:scrollToVisible(scrollView, scrollViewIndex, rowView)
        return
    end

    for _,line in ipairs(split(tostring(text), '\n')) do
        local rowView = ColorView.new(scrollView)
        rowView.color = getEvenOddColor(scrollViewIndex)
        rowView.size = vec2(scrollView.size.x - 50, (_fontSize or fontSize) * 1.4)
        rowView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    
        local commandTextView = TextView.new(rowView)
        commandTextView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
        commandTextView.baseOffset = vec3(0,0,0)
        commandTextView.font = (_fontSize == fontSize) and consoleFont or consoleFontLarge
        commandTextView.color = color or consoleUI.console.textColor
        commandTextView.text = margin .. line
    
        scrollViewIndex = scrollViewIndex + 1
        uiScrollView:insertRow(scrollView, rowView, nil)
        uiScrollView:scrollToVisible(scrollView, scrollViewIndex, rowView)
    end
end


---------------------------------------------------------------------------------
-- [[ Events ]]
---------------------------------------------------------------------------------

local keyMap = nil

function loadKeyMap()
    keyMapping.addMapping("textEntry", "delete", keyMapping.keyCodes.delete, nil)
    keyMapping.addMapping("textEntry", "tab", keyMapping.keyCodes.tab, nil)

    keyMap = {
        [keyMapping:getMappingIndex("textEntry", "send")] = function(isDown, isRepeat) if isDown and not isRepeat then sendCommand() return true end end,
        [keyMapping:getMappingIndex("textEntry", "backspace")] = function(isDown, isRepeat) if isDown then deletePressed(false) end end,
        [keyMapping:getMappingIndex("textEntry", "delete")] = function(isDown, isRepeat) if isDown then deletePressed(true) end end,
        [keyMapping:getMappingIndex("textEntry", "prevCommand")] = function(isDown, isRepeat) if isDown then nextCommand(false) end end, -- Up
        [keyMapping:getMappingIndex("textEntry", "nextCommand")] = function(isDown, isRepeat) if isDown then nextCommand(true) end end, -- Down
        [keyMapping:getMappingIndex("textEntry", "tab")] = function(isDown, isRepeat) if isDown and not isRepeat then autofill(false) end end,
        [keyMapping:getMappingIndex("menu", "back")] = function(isDown, isRepeat) if isDown and not isRepeat then cancel() end end, -- Esc
        [keyMapping:getMappingIndex("menu", "left")] = function(isDown, isRepeat) if isDown then nextArrow(false) end end,
        [keyMapping:getMappingIndex("menu", "right")] = function(isDown, isRepeat) if isDown then nextArrow(true) end end,
    }
end

local function keyChanged(isDown, mapIndexes, isRepeat)
    for i,mapIndex in ipairs(mapIndexes) do
        if keyMap[mapIndex]  then
            return keyMap[mapIndex](isDown, isRepeat)
        end
    end
end


---------------------------------------------------------------------------------
-- Console
---------------------------------------------------------------------------------

local historySelectedIndex = 0
local autofillSelectedIndex = 0
local autofillTabPressed = false
local currentAutofillItems = {}
local currentCaret = ""
local caretUpdateSpeed = 0.8
local caretUpdateTime = 0

local inputMax = 100 + 5 -- I don't know why it's 5 less
local inputMargin = 3
local inputOffset = inputMax / 2.0
local caretDisplayPosition = 0

local autofillPositionOffset = 140
local autofillPositionMultiplier = 0.583

local autofillDelayTimer = nil


-- TODO: Fix this garbage to add margin
function setInputText(text, updateAutofill)
    local caret = consoleUI.caretPosition
    
    --consoleUI.console:clear()

    -- Inject caret
    text = string.sub(text, 1, caret) .. currentCaret .. string.sub(text, caret + 1)

    -- Calculate the anchor
    local diff = caret - inputOffset
    local threshold = inputMax / 2 - inputMargin

    if diff > threshold then
        inputOffset = inputOffset + (diff - threshold)
    elseif diff < (-threshold) then
        inputOffset = inputOffset + (diff + threshold)
    end
    
    -- Create start and stop indexes for the final result substring
    local start = (inputOffset + 1) - (threshold)
    local stop  = (inputOffset + 1) + (threshold)
    local max = math.max(#text, inputMax)
    local min = math.min(max - inputMax, 1)
    start = math.max(start, min)
    stop = math.min(stop, max)

    caretDisplayPosition = caret - start

    --consoleUI.console:printValues(10, "offset:", inputOffset, "diff:", diff, "threshold:", threshold)
    --consoleUI.console:printValues(10, "min:", min, "max:", max)
    --consoleUI.console:printValues(10, "start:", start, "stop:", stop)

    -- Final substring
    text = string.sub(text, start, stop)

    --consoleUI.console:printValues(10, "#text:", #text)

    inputView.text = "hammerstone> " .. text

    -- Delay timers for autofill, otherwise holding a key can jitter game for large custom fields
    if updateAutofill then
        if autofillDelayTimer ~= nil then
            timer:removeTimer(autofillDelayTimer)
        end

        autofillDelayTimer = timer:addCallbackTimer(0.1, function(id)
            getAutofill()
        end)
    end
end

function sendCommand()
    if scrollView ~= nil then
        local command = consoleUI.input

        -- If an autofill option is selected, autofill instead of sending
        if autofillSelectedIndex ~= 0 then
            autofill(true)
            return
        end

        consoleUI.input = ""
        setInputText("", true)
        sendLine("", "hammerstone> " .. command, nil, fontSize)
        table.insert(consoleUI.console.history, 1, command)
        historySelectedIndex = 0
        consoleUI.caretPosition = 0

        if #command == 0 then
            audio:playUISound("audio/sounds/ui/stone2.wav")
            return
        end

        -- Execute command
        local tokens = splitTokens(command)
        local params = {}
        local paramCount = 1

        function findCommand(level, lastToken, arr)

            local token = tokens[level]

            if level == #tokens then
                if arr[token] then
                    return arr[token]["_f"]
                end
            end

            -- Check for a subcommand
            for k,v in pairs(arr) do
                if (k == token) then
                    return findCommand(level+1, nil, v)
                end
            end

            -- Check for a parameter
            for k,v in pairs(arr) do

                function a()
                    if v["_alias"] then
                        params[v["_alias"]] = token
                    else
                        params["param" .. paramCount] = token
                    end
                    paramCount = paramCount + 1
                    if level == #tokens then
                        return v["_f"]
                    else
                        return findCommand(level+1, k, v)
                    end
                end

                local boolDict = {["true"] = true, ["false"] = false}

                if (k == "number" and type(tonumber(token)) == "number") then
                    return a()
                elseif k == "bool" and boolDict[token] ~= nil then
                    return a()
                elseif k == "custom" then
                    return a()
                elseif k == "string" then
                    return a()
                end
            end
        end

        local func = findCommand(1, nil, consoleUI.console.commands)

        if func then
            audio:playUISound("audio/sounds/ui/stone2.wav")
            func(consoleUI.console, params)
        else
            audio:playUISound("audio/sounds/ui/cancel.wav")
            consoleUI:print("Not a command.")
        end
    end
end

function deletePressed(next)
    local caret = consoleUI.caretPosition
    if next then
        if caret >= #consoleUI.input then return end
        consoleUI.input = string.sub(consoleUI.input, 1, caret) .. string.sub(consoleUI.input, caret + 2, #consoleUI.input + 1)
    else
        if caret < 1 then return end
        consoleUI.input = string.sub(consoleUI.input, 1, caret - 1) .. string.sub(consoleUI.input, caret + 1, #consoleUI.input + 1)
        consoleUI.caretPosition = consoleUI.caretPosition - 1
    end

    resetCaret()
    setInputText(consoleUI.input, true)
    audio:playUISound("audio/sounds/ui/stone6.wav")
end

function nextCommand(next)
    -- Autofill option selector
    if consoleUI.isAutofillVisible then
        if next then
            autofillSelectedIndex = autofillSelectedIndex + 1
            if autofillSelectedIndex == (#currentAutofillItems + 1) then autofillSelectedIndex = 1 end
        else
            autofillSelectedIndex = autofillSelectedIndex - 1
            if autofillSelectedIndex <= 0 then autofillSelectedIndex = #currentAutofillItems end
        end
        autofillSelectedEnabled = true
        updateAutofill()
    else
        if #consoleUI.console.history == 0 then
            return
        end

        if next then
            historySelectedIndex = clamp(historySelectedIndex - 1, 1, #consoleUI.console.history)
        else
            historySelectedIndex = clamp(historySelectedIndex + 1, 1, #consoleUI.console.history)
        end
        consoleUI.input = consoleUI.console.history[historySelectedIndex]
        setInputText(consoleUI.input, true)
        resetCaretPosition()
        resetCaret()
    end
end

function caretUpdate(dt)
    if caretUpdateTime > caretUpdateSpeed then
        caretUpdateTime = caretUpdateTime - caretUpdateSpeed

        local emptyCaret = ""
        for i = 1, #consoleUI.console.caret do emptyCaret = emptyCaret .. " " end

        if currentCaret == emptyCaret then
            currentCaret = consoleUI.console.caret
        else
            currentCaret = emptyCaret
        end

        setInputText(consoleUI.input, false)
    else
        caretUpdateTime = caretUpdateTime + dt
    end

    -- Make the autofill box follow the caret
    local offset = autofillColorView.baseOffset
    local caretLocation = caretDisplayPosition + #currentCaret
    local caretPosition = caretLocation * fontSize * autofillPositionMultiplier
    offset.x = -backgroundSize.x / 4.0 + autofillPositionOffset + caretPosition
    offset.x = math.min(offset.x, backgroundSize.x / 4)
    autofillColorView.baseOffset = offset
end

function resetCaret()
    caretUpdateTime = 0
    currentCaret = consoleUI.console.caret
    setInputText(consoleUI.input, false)
end

function resetCaretPosition()
    consoleUI.caretPosition = #consoleUI.input
    setInputText(consoleUI.input, false)
end

function nextArrow(next)
    if next then
        consoleUI.caretPosition = clamp(consoleUI.caretPosition + 1, 0, #consoleUI.input)
    else
        consoleUI.caretPosition = clamp(consoleUI.caretPosition - 1, 0, #consoleUI.input)
    end
    resetCaret()
    setInputText(consoleUI.input, false)
end

function cancel()
    if (consoleUI.isAutofillVisible) then
        clearAutofill()
    else
        consoleUI.hide()
    end
end

function consoleTextEntry(text) -- Text input
    if consoleUI.input == nil then consoleUI.input = "" end
    local caret = consoleUI.caretPosition
    consoleUI.input = string.sub(consoleUI.input, 1, caret) .. text .. string.sub(consoleUI.input, caret + 1, #consoleUI.input + 1)
    consoleUI.caretPosition = caret + #text
    caretUpdateTime = 0
    setInputText(consoleUI.input, true)
    resetCaret()
    audio:playUISound("audio/sounds/ui/stone5.wav")
end

function getAutofill()

    local autofillItems = {}
    local command = consoleUI.input
    local tokens = splitTokens(command)

    -- Clear the autofill view if no text exists
    if #command == 0 then
        clearAutofill()
        return
    end

    -- Fix to instantly see all available commands
    if string.sub(command, #command) == " " then
        table.insert(tokens, "")
    end

    function getCommands(level, arr)
        if level == #tokens or arr == nil then -- Return on last token
            return arr
        end

        local token = tokens[level]
        local subCommand = getCommands(level+1, arr[token])

        if subCommand ~= nil then return subCommand end

        local boolDict = {["true"] = true, ["false"] = false}

        if type(tonumber(token)) == "number" then
            return getCommands(level+1, arr["number"])
        elseif boolDict[token] ~= nil then
            return getCommands(level+1, arr["bool"])
        else
            if arr["string"] then
                return getCommands(level+1, arr["string"])
            else
                return getCommands(level+1, arr["custom"])
            end
        end
    end

    autofillObject = getCommands(1, consoleUI.console.commands)

    if autofillObject == nil or type(autofillObject) == "function" then
        autofillSelectedIndex = 0
        currentAutofillItems = {}
        updateAutofill()
        return
    end

    -- Display items
    for k,v in pairs(autofillObject) do
        if k == "number" then
            if v._alias then
                table.insert(autofillItems, v._alias .. " <number>")
            else
                table.insert(autofillItems, "<number>")
            end
        elseif k == "string" then
            if v._alias then
                table.insert(autofillItems, v._alias .. " <string>")
            else
                table.insert(autofillItems, "<string>")
            end
        elseif k == "bool" then
            if v._alias then
                table.insert(autofillItems, v._alias .. " <bool>")
            else
                table.insert(autofillItems, "<bool>")
            end
        elseif k == "custom" then
            local dataset = {}
            if type(v._autocomplete) == "function" then
                dataset = v._autocomplete()
            else
                dataset = v._autocomplete
            end
            for _,item in ipairs(dataset) do
                table.insert(autofillItems, item)
            end
        else
            if k ~= "_f" and k ~= "_alias" and k ~= "_autocomplete" then
                table.insert(autofillItems, k)
            end
        end
    end

    -- Sort them based on input command proximity
    function levSort(str, arr)
        if type(arr[1]) == "table" then
            table.sort(arr, function(a,b)
                return lev:lev(str, a[1]) < lev:lev(str, b[1])
            end)
        
            -- Make sure exact matches are first
            for i = 1, #arr do
                local s = arr[i][1]
                if str == string.sub(s, 1, #str) then
                    table.insert(arr, 1, table.remove(arr, i))
                end
            end
        else
            table.sort(arr, function(a,b)
                return lev:lev(str, a) < lev:lev(str, b)
            end)
        
            -- Make sure exact matches are first
            for i = 1, #arr do
                local s = arr[i]
                if str == string.sub(s, 1, #str) then
                    table.insert(arr, 1, table.remove(arr, i))
                end
            end
        end
    end

    if #autofillItems > 0 then
        levSort(tokens[#tokens], autofillItems)
    end

    -- Display them in the autofill view
    autofillSelectedIndex = 0
    currentAutofillItems = autofillItems
    updateAutofill()
end

function updateAutofill()

    if autofillView == nil then
        return
    end

    if #currentAutofillItems == 0 then
        clearAutofill()
        return
    end

    uiScrollView:removeAllRows(autofillView)
    consoleUI.isAutofillVisible = true

    local selectedView = nil

    for i, item in ipairs(currentAutofillItems) do

        if type(item) == "table" then
            item = item[1]
        end

        local rowView = ColorView.new(autofillView)
        local backgroundColor = vec4(1.0,1.0,1.0,0.02)
        if i % 2 == 1 then
            backgroundColor = vec4(0.0,0.0,0.0,0.02)
        end

        if autofillSelectedIndex == i then
            backgroundColor = vec4(0.2,0.5,0.9,1.0)
            selectedView = rowView
        end

        if selectedView == nil then
            selectedView = rowView
        end

        rowView.color = backgroundColor
        rowView.size = vec2(autofillView.size.x - 20, 22)
        rowView.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionBottom)
    
        local autofillText = TextView.new(rowView)
        autofillText.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionCenter)
        autofillText.baseOffset = vec3(5,0,0)
        autofillText.font = consoleFont
        autofillText.text = item

        if endsWith(item, "<number>") then
            autofillText.color = vec4(0.32, 0.6,  1.0,  1.0)
        elseif endsWith(item, "<string>") then
            autofillText.color = vec4(0.89, 0.32, 1.0,  1.0)
        elseif endsWith(item, "<bool>") then
            autofillText.color = vec4(1.0,  0.52, 0.21, 1.0)
        else
            autofillText.color = vec4(1.0,1.0,1.0,1.0)
        end
    
        uiScrollView:insertRow(autofillView, rowView, nil)
    end

    autofillColorView.hidden = false

    if selectedView ~= nil then
        uiScrollView:scrollToVisible(autofillView, autofillSelectedIndex, selectedView)
    end
end

function clearAutofill()
    if autofillView ~= nil then
        uiScrollView:removeAllRows(autofillView)
        autofillColorView.hidden = true
    end
    consoleUI.isAutofillVisible = false
end

function autofill(refresh)
    if not consoleUI.isAutofillVisible then
        return
    end

    local selected = math.max(autofillSelectedIndex, 1)
    local newToken = currentAutofillItems[selected]
    
    -- Make sure custom fields support different values
    if type(newToken) == "table" then
        newToken = newToken[2]
    end
    
    local offsetCaretPosition = 0

    if endsWith(newToken, "<string>") then
        newToken = "\"\""
        offsetCaretPosition = -1
    elseif endsWith(newToken, "<number>") then
        newToken = ""
    elseif endsWith(newToken, "<bool>") then
        newToken = ""
    end

    --if type(newToken) == "string" and #split(newToken, " ") > 1 then
    --    newToken = "\"" .. newToken .. "\""
    --end 

    local command = consoleUI.input
    local tokens = splitTokens(command)

    -- Fix for space not registering as empty token
    if string.sub(command, #command) == " " then
        table.insert(tokens, "")
    end

    tokens[#tokens] = newToken
    local newCommand = ""

    for i,v in ipairs(tokens) do
        if i > 1 then newCommand = newCommand .. " " end
        if #split(tostring(v)) > 1 then
            newCommand = newCommand .. "\"" .. v .. "\""
        else
            newCommand = newCommand .. v
        end
    end
    
    if refresh and autofillTabPressed then
        newCommand = newCommand .. " "
        autofillTabPressed = false
    else
        autofillTabPressed = true -- TODO: Weird stuff here to fix
    end

    consoleUI.input = newCommand
    setInputText(newCommand, false)
    consoleUI.caretPosition = #consoleUI.input + offsetCaretPosition
    setInputText(consoleUI.input, refresh)
end


---------------------------------------------------------------------------------
-- Functions
---------------------------------------------------------------------------------

function runQueue()
    for _,item in ipairs(functionQueue) do
        item.func(unpack(item.args))
    end
    loaded = true
end

function consoleUI:clearLines()
    if loaded then
        scrollViewIndex = 0
        uiScrollView:removeAllRows(scrollView)
    end
end

function consoleUI:print(text, color)
    if loaded then
        sendLine(consoleUI.console.margin, text, color, fontSize)
    else
        table.insert(functionQueue, {
            func = sendLine,
            args = { consoleUI.console.margin, text, color, fontSize }
        })
    end
end

function consoleUI:printTitle(text, color)
    if loaded then
        sendLine(consoleUI.console.marginLarge, text, color, fontSizeLarge)
    else
        table.insert(functionQueue, {
            func = sendTitleLine,
            args = { consoleUI.console.marginLarge, text, color, fontSizeLarge }
        })
    end
end

function consoleUI:printValues(columnWidth, ...)
    local line = ""
    for i = 1, select("#",...) do
        line = line .. padRight(select(i,...), " ", columnWidth)
    end

    if loaded then
        sendLine("", line, nil, fontSize)
    else
        table.insert(functionQueue, {
            func = sendLine,
            args = { "", line, nil, fontSize }
        })
    end
end

function consoleUI:addCommand(path, params, func)

    table.insert(consoleUI.console.commandPaths, path)

    local tokens = split(path, " ")
    local customIndex = 1

    function add(level, alias, arr)

        local token = tokens[level]
        local alias = nil
        local subtoken = split(token, ":")

        if #subtoken == 2 then
            token = subtoken[1]
            alias = subtoken[2]
        end

        if arr[token] == nil then
            arr[token] = {}
        end

        if alias then arr[token]["_alias"] = alias end

        if token == "custom" then
            arr[token]["_autocomplete"] = params[customIndex]
            customIndex = customIndex + 1
        end

        if level == #tokens then
            arr[token]._f = func
            return
        end

        add(level+1, alias, arr[token])
    end

    add(1, nil, consoleUI.console.commands)
end

function consoleUI:onClick()
    consoleUI:show()
end

function consoleUI:show()

    -- Pause the game
    if consoleUI.console.autopause then
        gameState.world:startTemporaryPauseForPopup()
    end

    -- Start text
    eventManager:setTextEntryListener(consoleTextEntry, keyChanged)
    timer:addUpdateTimer(function(dt, timerID)
        caretTimer = timerID
        caretUpdate(dt)
    end)
end

function consoleUI:hide()
    gameState.world:endTemporaryPauseForPopup()
    eventManager:setTextEntryListener(nil)
    consoleUI.view.hidden = true
    timer:removeTimer(caretTimer)
end

-- TODO: The heck even is this? Figure it out in the future. Probably based on UI screenSize.
function loadDisplayResolutionFixes()

    local resData = consoleUI.console.controller:getCurrentScreenResolutionIndexAndMode()
    local resolutions = consoleUI.console.controller:getSupportedScreenResolutionList()
    --mj:log(resolutions)
    --mj:log(resData)

    local resolution = resolutions[resData.screenResolutionIndex]
    local x = resolution.x
    local y = resolution.y

    local types = {
        [1] = {
            { 2560, 1440 },
            { 1920, 1440 },
            { 1680, 1050 },
            { 1600, 1024 },
            { 1600,  900 },
            { 1440,  900 },
            { 1280, 1024 },
            { 1080,  960 },
        },
        [2] = {
            { 1920, 1200 },
            { 1920, 1080 },
            { 1600, 1200 },
        },
        [3] = {
            { 1366,  768 },
            { 1360,  768 },
            { 1280,  800 },
        },
        [4] = {
            { 1280,  800 },
        },
    }

    local values = {
        [1] = {
            inputMax = 100 + 5,
            autofillPositionOffset = 140,
            autofillPositionMultiplier = 0.583,
        },
        [2] = {
            inputMax = 93 + 5,
            autofillPositionOffset = 145,
            autofillPositionMultiplier = 0.63,
        },
        [3] = {
            inputMax = 105 + 5,
            autofillPositionOffset = 135,
            autofillPositionMultiplier = 0.56,
        },
        [4] = {
            inputMax = 105 + 5,
            autofillPositionOffset = 140,
            autofillPositionMultiplier = 0.583,
        },
    }

    for i,_ in ipairs(types) do
        for _,v in ipairs(types[i]) do
            if v[1] == x and v[2] == y then
                inputMax = values[i].inputMax
                autofillPositionOffset = values[i].autofillPositionOffset
                autofillPositionMultiplier = values[i].autofillPositionMultiplier
                mj:log("Loaded fix for resolution " .. v[1] .. "x" .. v[2] .. ".")
                return
            end
        end
    end

    mj:log("No fix found for resolution " .. v[1] .. "x" .. v[2] .. ".")
end

return consoleUI