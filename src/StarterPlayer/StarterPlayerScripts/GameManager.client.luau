-- Game director: moves the game through RTS -> FakeVictory -> Horror -> TrueVictory
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local Phases = GameState.Phases

local coreHitEvent = ReplicatedStorage:WaitForChild("CoreHitEvent")
local core = workspace:WaitForChild("EnemyCore")
local entitySpawn = workspace:WaitForChild("EntitySpawn")
local player = Players.LocalPlayer

local ORBS_REQUIRED = 5
local FAKE_VICTORY_SECONDS = 4

local currentOrbs = 0

local function GiveFlashlight(character)
	local head = character:WaitForChild("Head", 5)
	if head and not head:FindFirstChild("HorrorFlashlight") then
		local flashlight = Instance.new("SpotLight")
		flashlight.Name = "HorrorFlashlight"
		flashlight.Range = 60
		flashlight.Angle = 45
		flashlight.Brightness = 4
		flashlight.Face = Enum.NormalId.Front
		flashlight.Parent = head
	end
end

local function TeleportToSpawn(character)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root then
		root.CFrame = entitySpawn.CFrame + Vector3.new(0, 5, 0)
	end
end

-------------------------------------------------------------------------
-- RTS: count orbs that reach the core
-------------------------------------------------------------------------
coreHitEvent.Event:Connect(function()
	if not GameState.Is(Phases.RTS) then return end

	currentOrbs += 1

	-- Flash effect (does not pause this handler)
	core.BrickColor = BrickColor.new("White")
	task.delay(0.1, function()
		if GameState.Is(Phases.RTS) then
			core.BrickColor = BrickColor.new("Really red")
		end
	end)

	if currentOrbs >= ORBS_REQUIRED then
		GameState.Set(Phases.FakeVictory)
	end
end)

-------------------------------------------------------------------------
-- FAKE VICTORY: short pause before the horror starts
-------------------------------------------------------------------------
GameState.OnPhase(Phases.FakeVictory, function()
	local character = player.Character or player.CharacterAdded:Wait()
	TeleportToSpawn(character)

	task.delay(FAKE_VICTORY_SECONDS, function()
		if GameState.Is(Phases.FakeVictory) then
			GameState.Set(Phases.Horror)
		end
	end)
end)

-------------------------------------------------------------------------
-- HORROR: darkness, flashlight, escape pad at the core
-------------------------------------------------------------------------
GameState.OnPhase(Phases.Horror, function()
	Lighting.Ambient = Color3.fromRGB(0, 0, 0)
	Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
	Lighting.Brightness = 0
	Lighting.ClockTime = 0

	-- Escape pad at the core (step 6 replaces this with a separate EscapeZone)
	core.Size = Vector3.new(20, 1, 20)
	core.Position = Vector3.new(core.Position.X, 0.5, core.Position.Z)
	core.BrickColor = BrickColor.new("Lime green")
	core.Material = Enum.Material.Neon

	local escapeLight = Instance.new("PointLight")
	escapeLight.Color = Color3.fromRGB(0, 255, 0)
	escapeLight.Range = 40
	escapeLight.Brightness = 3
	escapeLight.Parent = core

	local character = player.Character or player.CharacterAdded:Wait()
	GiveFlashlight(character)
end)

-- Respawning during the horror keeps the flashlight and starts again at the spawn pad
player.CharacterAdded:Connect(function(newCharacter)
	if GameState.Is(Phases.Horror) then
		GiveFlashlight(newCharacter)
		TeleportToSpawn(newCharacter)
	end
end)

-------------------------------------------------------------------------
-- TRUE VICTORY: player reaches the escape pad
-------------------------------------------------------------------------
core.Touched:Connect(function(hit)
	if not GameState.Is(Phases.Horror) then return end
	if hit.Parent ~= player.Character then return end

	local playerHumanoid = hit.Parent:FindFirstChild("Humanoid")
	if playerHumanoid and playerHumanoid.Health > 0 then
		GameState.Set(Phases.TrueVictory)
	end
end)

GameState.OnPhase(Phases.TrueVictory, function()
	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
	end

	local victoryGui = player:WaitForChild("PlayerGui"):FindFirstChild("VictoryGui")
	if victoryGui then
		victoryGui.Enabled = true
	end
	print("TRUE VICTORY: You survived your own maze!")
end)
