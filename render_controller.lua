-- Discord: @jenl1x
-- Roblox: D1661

--[[
 Cyberpunk Sandevistan viewport effect system
 
 Features:
 - viewport character cloning
 - animated afterimages
 - dynamic color cycling
 - local rendering optimization
 - camera synchronization
 - effect cleanup system
 - trail interpolation
]]

local controller = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local basic_cloner = require(ReplicatedStorage.basic_cloner)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

type CloneData = {
	model: Model,
	world_model: Model
}

local SETTINGS = {
	FRAME_INTERVAL = 0.075,
	MIN_SPEED = 2,
	SAVE_FRAME_CHANCE = 0.35,
	FADE_TIME = 0.03,
	MAX_SAVED_FRAMES = 15,
	MAX_DISTANCE = 250,
}

local SANDEVISTAN_COLORS = {
	[1] = Color3.fromRGB(48, 255, 248),
	[2] = Color3.fromRGB(59, 101, 200),
	[3] = Color3.fromRGB(145, 71, 255),
	[4] = Color3.fromRGB(255, 66, 101)
}

local saved_frames = {}
local last_frame = 0

--// initialize viewport and camera
function controller:init()
	local viewport_frame = script.Parent.Parent.frame

	local viewport_camera = Instance.new("Camera")
	viewport_camera.CameraType = Enum.CameraType.Scriptable
	viewport_camera.Parent = viewport_frame

	viewport_frame.CurrentCamera = viewport_camera

	self.character = player.Character or player.CharacterAdded:Wait()
	self.viewport_camera = viewport_camera
	self.viewport_frame = viewport_frame
	self.connections = {}
end

--// safely fetch matching object from world model
function controller:get_world_object(world_model: Model, object_name: string)
	local object = world_model:FindFirstChild(object_name, true)

	if not object then
		return nil
	end

	return object
end

--// sync viewport camera with real camera
function controller:update_camera()
	self.viewport_camera.CFrame = camera.CFrame
	self.viewport_camera.FieldOfView = camera.FieldOfView
end

--// determine if character is close enough to render
function controller:is_visible(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")

	if not root then
		return false
	end

	local distance = (camera.CFrame.Position - root.Position).Magnitude

	return distance <= SETTINGS.MAX_DISTANCE
end

--// tint clone for cyberpunk afterimage effect
function controller:apply_effect_color(model: Model)
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			object.Color = self.sandevistan_color.Value
			object.Material = Enum.Material.Neon
		end

		if object:IsA("Decal") or object:IsA("Texture") then
			object.Color3 = self.sandevistan_color.Value
		end

		if object:IsA("Accessory") or object:IsA("Hat") then
			if object:FindFirstChild("Handle") then
				local mesh = object.Handle:FindFirstChildOfClass("SpecialMesh")

				if mesh then
					mesh.TextureId = ""
				end
			end
		end
	end
end

--// save current clone cframes for delayed trail rendering
function controller:save_frame(model: Model)
	if #saved_frames >= SETTINGS.MAX_SAVED_FRAMES then
		table.remove(saved_frames, 1)
	end

	local cframes = {}

	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			cframes[object.Name] = object.CFrame
		end
	end

	saved_frames[#saved_frames + 1] = cframes
end

--// create temporary viewport clone trail
function controller:create_trail(info: CloneData)
	local clone = info.model:Clone()
	clone.Parent = self.viewport_frame

	self:apply_effect_color(clone)

	if math.random() < SETTINGS.SAVE_FRAME_CHANCE then
		self:save_frame(info.model)
	end

	task.delay(0.15, function()
		if clone then
			clone:Destroy()
		end
	end)
end

--// update viewport clone positions
function controller:update_clone(info: CloneData)
	if not self:is_visible(info.world_model) then
		info.model.Parent = nil
		return
	end

	info.model.Parent = self.viewport_frame

	for _, object in ipairs(info.model:GetDescendants()) do
		if object:IsA("BasePart") then
			local world_object = self:get_world_object(info.world_model, object.Name)

			if world_object and world_object:IsA("BasePart") then
				object.CFrame = world_object.CFrame
			end
		end

		if object:IsA("Accessory") or object:IsA("Hat") then
			local world_object = self:get_world_object(info.world_model, object.Name)

			if world_object and world_object:FindFirstChild("Handle") then
				object.Handle.CFrame = world_object.Handle.CFrame
			end
		end
	end
end

--// render viewport effect
function controller:render()
	if not self.character or not self.clones then
		return
	end

	self.viewport_frame.Visible = true

	self:update_camera()

	for _, info: CloneData in pairs(self.clones) do
		self:update_clone(info)

		--// only local character generates afterimages
		if info.world_model == self.character then
			local root = self.character:FindFirstChild("HumanoidRootPart")

			if root then
				local velocity = root.AssemblyLinearVelocity.Magnitude

				--// create afterimage trail while moving fast
				if velocity > SETTINGS.MIN_SPEED then
					if (time() - last_frame) > SETTINGS.FRAME_INTERVAL then
						last_frame = time()

						self:create_trail(info)
					end
				end
			end
		end
	end
end

--// smoothly cycle through sandevistan colors
function controller:start_color_cycle()
	local count = 0

	task.spawn(function()
		while self.sandevistan_color do
			count += 1

			if count > #SANDEVISTAN_COLORS then
				count = 1
			end

			local tween = TweenService:Create(self.sandevistan_color, TweenInfo.new(0.75), {Value = SANDEVISTAN_COLORS[count]})
			tween:Play()
			tween.Completed:Wait()
		end
	end)
end

--// initialize viewport clones and effect state
function controller:start()
	self.viewport_frame.Visible = true

	self.clones = basic_cloner:clone_all()

	local color_value = Instance.new("Color3Value")
	color_value.Name = "sandevistan_color"
	color_value.Value = SANDEVISTAN_COLORS[1]

	self.sandevistan_color = color_value

	self:start_color_cycle()

	self.connections.render = RunService.RenderStepped:Connect(function()
		self:render()
	end)
end

--// render saved afterimages inside workspace
function controller:render_saved_frames()
	task.spawn(function()
		for _, cframes in pairs(saved_frames) do
			local clone = basic_cloner:clone(self.character)

			clone.Parent = workspace.effects

			self:apply_effect_color(clone)

			for _, object in ipairs(clone:GetDescendants()) do
				if object:IsA("BasePart") then
					if cframes[object.Name] then
						object.CFrame = cframes[object.Name]
					end
				end

				if object:IsA("BasePart") or object:IsA("Decal") or object:IsA("Texture") then
					local tween = TweenService:Create(object, TweenInfo.new(SETTINGS.FADE_TIME), {Transparency = 1})
					tween:Play()
				end
			end

			task.delay(SETTINGS.FADE_TIME, function()
				if clone then
					clone:Destroy()
				end
			end)
			task.wait()
		end
		table.clear(saved_frames)
	end)
end

--// disconnect active connections
function controller:disconnect()
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end

	table.clear(self.connections)
end

--// cleanup viewport and effect objects
function controller:clean()
	self:disconnect()

	for _, object in ipairs(self.viewport_frame:GetChildren()) do
		if not object:IsA("Camera") then
			object:Destroy()
		end
	end

	self.viewport_frame.Visible = false

	if self.sandevistan_color then
		self.sandevistan_color:Destroy()
	end

	self:render_saved_frames()

	self.clones = nil
end

return controller
