-- Game director: moves the game through RTS -> FakeVictory -> Horror -> TrueVictory
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local Phases = GameState.Phases

local coreHitEvent = ReplicatedStorage:WaitForChild("CoreHitEvent")
local core = workspace:WaitForChild("EnemyCore")
local entitySpawn = workspace:WaitForChild("EntitySpawn")
local player = Players.LocalPlayer

local ORBS_REQUIRED = 5
local FAKE_VICTORY_SECONDS = 5

local currentOrbs = 0

-- The server follows along (walls, Hunter)
local phaseReport = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PhaseReport")
GameState.Changed:Connect(function(newPhase)
	phaseReport:FireServer(newPhase)
end)

-- The build menu HUD reads these
core:SetAttribute("HitsRequired", ORBS_REQUIRED)
core:SetAttribute("Hits", 0)

-- Stand on the spawn pad facing the maze and the old core
local function TeleportToSpawn(character)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root then
		local standAt = entitySpawn.Position + Vector3.new(0, 3, 0)
		local lookAt = Vector3.new(core.Position.X, standAt.Y, core.Position.Z)
		root.CFrame = CFrame.lookAt(standAt, lookAt)
	end
end

-------------------------------------------------------------------------
-- RTS: count orbs that reach the core
-------------------------------------------------------------------------
coreHitEvent.Event:Connect(function()
	if not GameState.Is(Phases.RTS) then return end

	currentOrbs += 1
	core:SetAttribute("Hits", currentOrbs)

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
	-- The core is "destroyed": hide it and its glow
	core.Transparency = 1
	core.CanCollide = false
	local coreGlow = core:FindFirstChild("CoreGlow")
	if coreGlow then
		coreGlow.Enabled = false
	end

	local character = player.Character or player.CharacterAdded:Wait()
	TeleportToSpawn(character)

	task.delay(FAKE_VICTORY_SECONDS, function()
		if GameState.Is(Phases.FakeVictory) then
			GameState.Set(Phases.Horror)
		end
	end)
end)

-------------------------------------------------------------------------
-- HORROR: escape pad at the core (lighting lives in PhaseEffects, flashlight in Flashlight)
-------------------------------------------------------------------------
GameState.OnPhase(Phases.Horror, function()
	-- Escape pad at the core (step 6 replaces this with a separate EscapeZone)
	core.Transparency = 0
	core.Size = Vector3.new(20, 1, 20)
	core.Position = Vector3.new(core.Position.X, 0.5, core.Position.Z)
	core.BrickColor = BrickColor.new("Lime green")
	core.Material = Enum.Material.Neon

	local escapeLight = Instance.new("PointLight")
	escapeLight.Color = Color3.fromRGB(0, 255, 0)
	escapeLight.Range = 40
	escapeLight.Brightness = 3
	escapeLight.Parent = core
end)

-- Respawning during the horror starts again at the spawn pad
player.CharacterAdded:Connect(function(newCharacter)
	if GameState.Is(Phases.Horror) then
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
