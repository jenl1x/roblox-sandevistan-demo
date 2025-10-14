local basic_cloner = {}

--// clone character and prepare clone for display
function basic_cloner:clone(character)
	character.Archivable = true

	local clone = character:Clone()
	clone.Humanoid.DisplayDistanceType = "None" --// hide health bar for clone

	--// modify cloned objects for no interaction and stability
	for _, object in ipairs(clone:GetChildren()) do
		if object:IsA("Script") or object:IsA("LocalScript") then
			--// remove scripts from clone
			object:Destroy()
		end
		if object:IsA("BasePart") then
			--// anchor parts and disable collisions
			object.Anchored = true
			object.CanCollide = false
			object.CollisionGroup = "no_collision"
		end
		if object:IsA("Accessory") or object:IsA("Hat") then
			--// anchor accessory handles and disable collisions
			object.Handle.Anchored = true
			object.Handle.CanCollide = false
			object.Handle.CollisionGroup = "no_collision"
		end
	end
	return clone
end

--// clone all characters in workspace with humanoids
function basic_cloner:clone_all()
	local clones = {}
	for _, alive in ipairs(workspace:GetChildren()) do
		if alive:FindFirstChild("Humanoid") then
			--// store clone and original model
			clones[alive.Name] = {
				model = basic_cloner:clone(alive),
				world_model = alive
			}
		end
	end
	return clones
end

return basic_cloner
