local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local horrorEvent = ReplicatedStorage:WaitForChild("HorrorModeEvent")
local coreHitEvent = ReplicatedStorage:WaitForChild("CoreHitEvent")
local core = workspace:WaitForChild("EnemyCore")
local entitySpawn = workspace:WaitForChild("EntitySpawn")
local player = Players.LocalPlayer

local orbsRequired = 5 
local currentOrbs = 0
local isHorrorMode = false

local function GiveFlashlight(character)
	local head = character:WaitForChild("Head", 5)
	if head then
		local flashlight = Instance.new("SpotLight")
		flashlight.Name = "HorrorFlashlight"
		flashlight.Range = 60
		flashlight.Angle = 45
		flashlight.Brightness = 4
		flashlight.Face = Enum.NormalId.Front
		flashlight.Parent = head
	end
end

player.CharacterAdded:Connect(function(newCharacter)
	if isHorrorMode then
		GiveFlashlight(newCharacter)
		player.CameraMode = Enum.CameraMode.LockFirstPerson

		local root = newCharacter:WaitForChild("HumanoidRootPart", 5)
		if root then
			root.CFrame = entitySpawn.CFrame + Vector3.new(0, 5, 0)
		end
	end
end)

-- ENTITY HITS (Listen to EntitySpawner)
coreHitEvent.Event:Connect(function()
	if isHorrorMode then return end

	currentOrbs += 1

	-- Flash effect (does not pause this handler)
	core.BrickColor = BrickColor.new("White")
	task.delay(0.1, function()
		if not isHorrorMode then
			core.BrickColor = BrickColor.new("Really red")
		end
	end)

	if currentOrbs >= orbsRequired then
		isHorrorMode = true

		Lighting.Ambient = Color3.fromRGB(0, 0, 0)
		Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
		Lighting.Brightness = 0
		Lighting.ClockTime = 0

		-- FIX: Make the core wider and place it exactly above the ground level
		core.Size = Vector3.new(20, 1, 20) 
		core.Position = Vector3.new(core.Position.X, 0.5, core.Position.Z)
		core.BrickColor = BrickColor.new("Lime green")
		core.Material = Enum.Material.Neon

		local escapeLight = Instance.new("PointLight")
		escapeLight.Color = Color3.fromRGB(0, 255, 0)
		escapeLight.Range = 40
		escapeLight.Brightness = 3
		escapeLight.Parent = core

		local char = player.Character or player.CharacterAdded:Wait()
		local root = char:WaitForChild("HumanoidRootPart")
		root.CFrame = entitySpawn.CFrame + Vector3.new(0, 5, 0)

		GiveFlashlight(char)
		horrorEvent:Fire()
	end
end)

-- PLAYER ESCAPE (When player touches the transformed core in horror mode)
core.Touched:Connect(function(hit)
	if isHorrorMode then
		if hit.Parent == player.Character then
			local playerHumanoid = hit.Parent:FindFirstChild("Humanoid")
			if playerHumanoid and playerHumanoid.Health > 0 then
				playerHumanoid.WalkSpeed = 0
				isHorrorMode = false

				local playerGui = player:WaitForChild("PlayerGui")
				local victoryGui = playerGui:FindFirstChild("VictoryGui")
				if victoryGui then
					victoryGui.Enabled = true
				end
				print("TRUE VICTORY: You survived your own maze!")
			end
		end
	end
end)