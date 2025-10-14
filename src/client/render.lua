local CollectionService = game:GetService("CollectionService")

local TAG_NAME = "sandevistan_activated"

--// initialize controller
local controller = require(script.controller)
controller:init()

local conn

--// listen for tag added to start controller and rendering
CollectionService:GetInstanceAddedSignal(TAG_NAME):Connect(function(object)
	if conn then
		conn:Disconnect()
	end
	controller:start()
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		--// updates every client frame
		controller:render()
	end)
end)

--// listen for tag removed to stop controller and clean up
CollectionService:GetInstanceRemovedSignal(TAG_NAME):Connect(function(object)
	if conn then
		conn:Disconnect()
	end
	controller:clean()
end)
