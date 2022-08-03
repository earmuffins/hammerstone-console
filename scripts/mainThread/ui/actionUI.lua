local mod = {
	loadOrder = 1
}

local consoleUI = mjrequire "hammerstone-console/consoleUI"
local logicInterface = mjrequire "mainThread/logicInterface"

function mod:onload(actionUI)

	-- Set the selection targets
	local super_showObjects = actionUI.showObjects
	function actionUI:showObjects(baseObjectInfo, multiSelectAllObjects, lookAtPos)
		super_showObjects(self, baseObjectInfo, multiSelectAllObjects, lookAtPos)

		consoleUI.console.targets = multiSelectAllObjects
		mj:log(multiSelectAllObjects)
	end

	-- Remove the selection targets
	local super_hide = actionUI.hide
	function actionUI:hide()
		super_hide()

		consoleUI.console.targets = {}
	end
end

return mod