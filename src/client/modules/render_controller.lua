local controller = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local basic_cloner = require(ReplicatedStorage.basic_cloner)

local player = game:GetService("Players").LocalPlayer
local camera = workspace.CurrentCamera

local SANDEVISTAN_COLORS = {
	[1] = Color3.fromRGB(48, 255, 248),
	[2] = Color3.fromRGB(59, 101, 200),
	[3] = Color3.fromRGB(145, 71, 255),
	[4] = Color3.fromRGB(255, 66, 101)
}

--// initialize viewport and camera for effect
function controller:init()
	local viewport_frame = script.Parent.Parent.frame
	local viewport_camera = Instance.new("Camera")
	viewport_camera.CameraType = Enum.CameraType.Scriptable
	viewport_camera.Parent = viewport_frame
	viewport_frame.CurrentCamera = viewport_camera

	self.character = player.Character or player.CharacterAdded:Wait()
	self.viewport_camera = viewport_camera
	self.viewport_frame = viewport_frame
end

local saved_frames = {}
local last_frame = 0

--// update viewport clones and create visual trail effect
function controller:render()
	if self.character and self.clones then
		self.viewport_frame.Visible = true
		--// sync viewport camera with main camera
		self.viewport_camera.CFrame = camera.CFrame
		self.viewport_camera.FieldOfView = camera.FieldOfView

		for name, info in pairs(self.clones) do
			info.model.Parent = self.viewport_frame
			--// update clone parts to match world model
			for _, object in ipairs(info.model:GetChildren()) do
				if object:IsA("BasePart") then
					object.CFrame = info.world_model[object.Name].CFrame
				end
				if object:IsA("Accessory") or object:IsA("Hat") then
					object.Handle.CFrame = info.world_model[object.Name].Handle.CFrame
				end
			end
			--// create clones trail for local player when moving fast enough
			if info.world_model == self.character and (time() - last_frame) > 0.075 then
				last_frame = time()
				if self.character.HumanoidRootPart.AssemblyLinearVelocity.Magnitude > 2 then
					local clone = info.model:Clone()
					clone.Parent = self.viewport_frame
					for _, object in ipairs(clone:GetDescendants()) do
						--// tint clone with sandevistan color
						if object:IsA("BasePart") then
							object.Color = self.sandevistan_color.Value
						end
						if object:IsA("Decal") or object:IsA("Texture") then
							object.Color3 = self.sandevistan_color.Value
						end
						--// remove textures from accessories for effect
						if object:IsA("Accessory") or object:IsA("Hat") then
							object.Handle.Mesh.TextureId = ""
						end
					end
					--// occasionally save current frame for trailing effect
					if math.random() < 0.35 then
						local cframes = {}
						for _, object in ipairs(info.model:GetDescendants()) do
							if object:IsA("BasePart") then
								cframes[object.Name] = object.CFrame
							end
						end
						saved_frames[#saved_frames + 1] = cframes
					end
				end
			end
		end
	end
end

--// start effect by cloning characters and cycling colors
function controller:start()
	self.viewport_frame.Visible = true
	self.clones = basic_cloner:clone_all()

	local color_value = Instance.new("Color3Value")
	color_value.Name = "sandevistan_color"
	color_value.Value = SANDEVISTAN_COLORS[1]
	task.spawn(function()
		local count = 0
		while color_value do
			count += 1
			if count > #SANDEVISTAN_COLORS then
				count = 1
			end
			local tween = TweenService:Create(color_value, TweenInfo.new(0.75), {Value = SANDEVISTAN_COLORS[count]})
			tween:Play()
			tween.Completed:Wait()
		end
	end)
	self.sandevistan_color = color_value
end

--// clean up clones and play fade out trails
function controller:clean()
	for _, object in ipairs(self.viewport_frame:GetChildren()) do
		if not object:IsA("Camera") then
			object:Destroy()
		end
	end
	self.viewport_frame.Visible = false
	self.clones = nil
	self.sandevistan_color:Destroy()

	--// fade out saved trail frames in workspace.effects (afterimages effect)
	task.spawn(function()
		for _, cframes in pairs(saved_frames) do
			local clone = basic_cloner:clone(self.character)
			clone.Parent = workspace.effects
			for _, object in ipairs(clone:GetDescendants()) do
				if object:IsA("BasePart") or object:IsA("Decal") or object:IsA("Texture") then
					if object:IsA("BasePart") then
						object.CFrame = cframes[object.Name]
					end
					local tween = TweenService:Create(object, TweenInfo.new(0.03), {Transparency = 1})
					tween:Play()
					tween.Completed:Connect(function()
						clone:Destroy()
					end)
				end
			end
			task.wait()
		end
		table.clear(saved_frames)
	end)
end

return controller
