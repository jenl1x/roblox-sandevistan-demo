--// controller module code for Sandevistan ability.

local sandevistan_controller = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local TAG_NAME = "sandevistan_activated"
local DEFAULT_GRAVITY = workspace.Gravity

local assets = ReplicatedStorage.assets
local request = ReplicatedStorage.requests.toggle

local player = game:GetService("Players").LocalPlayer
local character = script.Parent.Parent
local humanoid = character:WaitForChild("Humanoid")

local camera = workspace.CurrentCamera

--// create quick flash effect on screen
function create_flash()
	local flash = assets.flash:Clone()
	flash.Parent = player.PlayerGui

	local tween1 = TweenService:Create(flash.Frame, TweenInfo.new(0.05), {BackgroundTransparency = 0})
	tween1:Play()
	tween1.Completed:Connect(function()
		local tween2 = TweenService:Create(flash.Frame, TweenInfo.new(0.05), {BackgroundTransparency = 1})
		tween2:Play()
		tween2.Completed:Wait()
		flash:Destroy()
	end)
end

--// add visual and sound effects when ability activates
function add_effects()
	assets.sound:Play()
	
	create_flash()
	TweenService:Create(camera, TweenInfo.new(0.075), {FieldOfView = 50}):Play()
	
	local screen_effect = assets.screen_effect:Clone()
	screen_effect.Parent = Lighting
end

--// remove effects when ability deactivates
function remove_effects()
	create_flash()
	TweenService:Create(camera, TweenInfo.new(0.075), {FieldOfView = 70}):Play()
	Lighting.screen_effect:Destroy()
end

--// activate sandevistan ability and change player state
function sandevistan_controller:activate()
	player:AddTag(TAG_NAME)
	request:FireServer(true)

	--// increase gravity and walk speed
	workspace.Gravity = 130
	humanoid.WalkSpeed = 25

	add_effects()
end

--// deactivate ability and reset player state
function sandevistan_controller:deactivate()
	remove_effects()
	task.delay(0.05, function()
		player:RemoveTag(TAG_NAME)
		request:FireServer()

		workspace.Gravity = DEFAULT_GRAVITY
		humanoid.WalkSpeed = 16
	end)
end

return sandevistan_controller
