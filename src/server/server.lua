local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFAULT_WALK_SPEED = 16
local SPEED_DIVISOR = 8

--// listen to toggle event from client
ReplicatedStorage.requests.toggle.OnServerEvent:Connect(function(player, toggle)
	for _, alive in ipairs(workspace:GetChildren()) do
		if alive ~= player.Character then
			local humanoid = alive:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				--// adjust animation and walk speed based on toggle
				for _, anim_track in ipairs(humanoid.Animator:GetPlayingAnimationTracks()) do
					anim_track:AdjustSpeed(toggle and anim_track.Speed / SPEED_DIVISOR or 1)
				end
				humanoid.WalkSpeed = toggle and (DEFAULT_WALK_SPEED / SPEED_DIVISOR) or DEFAULT_WALK_SPEED
			end
		end
	end
end)

--// basic code to make all npcs move forward loop
for _, npc in ipairs(workspace:GetChildren()) do
	if npc.Name:find("npc") then
		local hrp = npc.HumanoidRootPart
		local humanoid = npc.Humanoid
		local animator = humanoid.Animator

		--// remove network ownership for server control
		hrp:SetNetworkOwner(nil)

		local anim = animator:LoadAnimation(ReplicatedStorage.assets.npc_walk)
		anim:Play()

		task.spawn(function()
			while true do
				humanoid:Move(hrp.CFrame.LookVector)
				task.wait(0.1)
			end
		end)
	end
end
