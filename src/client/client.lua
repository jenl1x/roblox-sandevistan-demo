--// client abilities handler

local ability_controller = require(script.sandevistan)

local COOLDOWN = 4

local last_used = time() - COOLDOWN

--// listen for key press to activate ability
game:GetService("UserInputService").InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.E and (time() - last_used) > COOLDOWN then
		ability_controller:activate()
		--// schedule ability deactivation after 3 seconds
		task.delay(3, ability_controller.deactivate)

		last_used = time()
	end
end)
