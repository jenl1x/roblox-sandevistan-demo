

-- Discord: @jenl1x
-- Roblox: D1661

--[[
 Cyberpunk Sandevistan viewport effect system

 Core idea:
 We do NOT modify real character rendering.
 Instead we replicate character into ViewportFrame and manually sync transforms.

 This avoids:
 - physics overhead
 - network replication cost
 - workspace clutter

 Features:
 - viewport character cloning
 - animated afterimages
 - dynamic color cycling
 - camera synchronization
 - frame-based trail system
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
	FRAME_INTERVAL = 0.075, -- how often we allow trail spawning (prevents spam + performance spikes)
	MIN_SPEED = 2, -- velocity threshold so idle players don't generate VFX
	SAVE_FRAME_CHANCE = 0.35, -- randomness introduces natural-looking trail variation
	FADE_TIME = 0.03,
	MAX_SAVED_FRAMES = 15, -- prevents memory leak from infinite table growth
	MAX_DISTANCE = 250, -- culling to avoid rendering distant characters
}

local SANDEVISTAN_COLORS = {
	Color3.fromRGB(48, 255, 248),
	Color3.fromRGB(59, 101, 200),
	Color3.fromRGB(145, 71, 255),
	Color3.fromRGB(255, 66, 101)
}

local saved_frames = {}
local last_frame = 0

--// viewport setup
function controller:init()
	-- viewportFrame acts as isolated render space (like mini workspace)
	local viewport_frame = script.Parent.Parent.frame

	-- Scriptable camera is required because ViewportFrame does NOT use workspace camera
	local viewport_camera = Instance.new("Camera")
	viewport_camera.CameraType = Enum.CameraType.Scriptable
	viewport_camera.Parent = viewport_frame

	viewport_frame.CurrentCamera = viewport_camera

	self.character = player.Character or player.CharacterAdded:Wait()

	self.viewport_camera = viewport_camera
	self.viewport_frame = viewport_frame

	self.connections = {}
end

--// we search world model descendants because accessories are nested deeply
function controller:get_world_object(world_model: Model, object_name: string)
	local object = world_model:FindFirstChild(object_name, true)
	return object -- nil-safe return, avoids extra branch overhead
end

--// camera sync MUST happen every frame otherwise viewport lags behind real camera
function controller:update_camera()
	self.viewport_camera.CFrame = camera.CFrame
	self.viewport_camera.FieldOfView = camera.FieldOfView
end

--// distance culling reduces unnecessary clone updates
function controller:is_visible(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local distance = (camera.CFrame.Position - root.Position).Magnitude
	return distance <= SETTINGS.MAX_DISTANCE
end

--// color application is separated so both viewport clones and workspace trails reuse same logic
function controller:apply_effect_color(model: Model)
	for _, object in ipairs(model:GetDescendants()) do

		-- BasePart defines physical visual body of character
		if object:IsA("BasePart") then
			object.Color = self.sandevistan_color.Value
			object.Material = Enum.Material.Neon -- neon amplifies cyberpunk look under lighting
		end

		-- Decals must match color or they break visual consistency
		if object:IsA("Decal") or object:IsA("Texture") then
			object.Color3 = self.sandevistan_color.Value
		end

		-- Accessories often carry textures that break effect, so we strip them
		if object:IsA("Accessory") or object:IsA("Hat") then
			local handle = object:FindFirstChild("Handle")
			if handle then
				local mesh = handle:FindFirstChildOfClass("SpecialMesh")
				if mesh then
					mesh.TextureId = "" -- removing texture prevents “old Roblox look”
				end
			end
		end
	end
end

--// stores snapshot of character state for delayed ghost rendering
function controller:save_frame(model: Model)
	-- limit table size to avoid memory growth during long runs
	if #saved_frames >= SETTINGS.MAX_SAVED_FRAMES then
		table.remove(saved_frames, 1)
	end

	local cframes = {}

	-- we store by object name (fast but assumes no duplicates in rig)
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			cframes[object.Name] = object.CFrame
		end
	end

	table.insert(saved_frames, cframes)
end

--// creates fast ephemeral clone (used as visual “pop” effect)
function controller:create_trail(info: CloneData)
	local clone = info.model:Clone()
	clone.Parent = self.viewport_frame

	-- immediate effect application avoids visible frame delay
	self:apply_effect_color(clone)

	-- randomness makes trail feel organic instead of machine-perfect
	if math.random() < SETTINGS.SAVE_FRAME_CHANCE then
		self:save_frame(info.model)
	end

	-- short lifespan prevents viewport memory accumulation
	task.delay(0.15, function()
		if clone then clone:Destroy() end
	end)
end

--// sync viewport clone to real character transform state
function controller:update_clone(info: CloneData)
	if not self:is_visible(info.world_model) then
		info.model.Parent = nil
		return
	end

	info.model.Parent = self.viewport_frame

	for _, object in ipairs(info.model:GetDescendants()) do

		-- we manually assign CFrame because ViewportFrame does not simulate physics
		if object:IsA("BasePart") then
			local world_object = self:get_world_object(info.world_model, object.Name)
			if world_object then
				object.CFrame = world_object.CFrame
			end
		end

		-- accessory sync must target Handle because Accessories are attachments-based
		if object:IsA("Accessory") or object:IsA("Hat") then
			local world_object = self:get_world_object(info.world_model, object.Name)
			if world_object and world_object:FindFirstChild("Handle") then
				object.Handle.CFrame = world_object.Handle.CFrame
			end
		end
	end
end

--// main render loop
function controller:render()
	if not self.character or not self.clones then return end

	self.viewport_frame.Visible = true

	-- camera sync is mandatory each frame or viewport becomes visually detached
	self:update_camera()

	for _, info: CloneData in pairs(self.clones) do
		self:update_clone(info)

		-- only local player generates effect to avoid network replication
		if info.world_model == self.character then
			local root = self.character:FindFirstChild("HumanoidRootPart")
			if root then
				local velocity = root.AssemblyLinearVelocity.Magnitude

				-- speed-based triggering prevents idle spam
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

--// color animation loop (cyberpunk palette cycling)
function controller:start_color_cycle()
	local i = 0

	task.spawn(function()
		while self.sandevistan_color do
			i += 1
			if i > #SANDEVISTAN_COLORS then i = 1 end

			-- tweening avoids instant color snapping (important for visual smoothness)
			local tween = TweenService:Create(
				self.sandevistan_color,
				TweenInfo.new(0.75),
				{Value = SANDEVISTAN_COLORS[i]}
			)

			tween:Play()
			tween.Completed:Wait()
		end
	end)
end

--// system startup
function controller:start()
	self.viewport_frame.Visible = true

	self.clones = basic_cloner:clone_all()

	local color_value = Instance.new("Color3Value")
	color_value.Name = "sandevistan_color"
	color_value.Value = SANDEVISTAN_COLORS[1]

	self.sandevistan_color = color_value

	self:start_color_cycle()

	-- RenderStepped ensures sync with frame rendering pipeline
	self.connections.render = RunService.RenderStepped:Connect(function()
		self:render()
	end)
end

--// replay saved frames as world-space ghost afterimages
function controller:render_saved_frames()
	task.spawn(function()

		for _, cframes in pairs(saved_frames) do
			local clone = basic_cloner:clone(self.character)
			clone.Parent = workspace.effects

			self:apply_effect_color(clone)

			for _, object in ipairs(clone:GetDescendants()) do

				-- restore position snapshot first
				if object:IsA("BasePart") and cframes[object.Name] then
					object.CFrame = cframes[object.Name]
				end

				-- fade out gives “ghost dissipation” effect
				if object:IsA("BasePart") or object:IsA("Decal") or object:IsA("Texture") then
					local tween = TweenService:Create(
						object,
						TweenInfo.new(SETTINGS.FADE_TIME),
						{Transparency = 1}
					)

					tween:Play()
				end
			end

			task.delay(SETTINGS.FADE_TIME, function()
				if clone then clone:Destroy() end
			end)

			task.wait()
		end

		table.clear(saved_frames)
	end)
end

--// cleanup connections to avoid memory leaks
function controller:disconnect()
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end

	table.clear(self.connections)
end

--// full cleanup
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
