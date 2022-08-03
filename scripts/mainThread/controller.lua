-- Using the Hammerstone Framework
local mod = {
	loadOrder = 10,
}

function mod:onload(controller)
    local eventManager = mjrequire "hammerstone/event/eventManager"
    local eventTypes = mjrequire "hammerstone/event/eventTypes"
    local console = mjrequire "hammerstone-console/console"
    console.controller = controller
    eventManager:bind(eventTypes.init, console.init)
end

return mod