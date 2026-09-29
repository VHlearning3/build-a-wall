-- Game director: moves the game through RTS -> FakeVictory -> Horror -> TrueVictory
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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
-- HORROR: a flat green EscapeZone over the ruins of the core
-- (lighting lives in PhaseEffects, the flashlight in Flashlight)
-------------------------------------------------------------------------
local ESCAPE_SIZE = 16
local ESCAPE_REACH = ESCAPE_SIZE / 2 -- Standing this close to the centre (flat distance) counts as escaped
local ESCAPE_COLOR = Color3.fromRGB(60, 255, 90)

local escapeCenter = Vector3.new(core.Position.X, 0, core.Position.Z)
local victoryConnection = nil

local function BuildEscapeZone()
	local folder = Instance.new("Folder")
	folder.Name = "EscapeZone"

	local pad = Instance.new("Part")
	pad.Name = "EscapePad"
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanQuery = false
	pad.CastShadow = false
	pad.Material = Enum.Material.Neon
	pad.Color = ESCAPE_COLOR
	pad.Transparency = 0.15
	pad.Size = Vector3.new(ESCAPE_SIZE, 0.2, ESCAPE_SIZE)
	pad.Position = escapeCenter + Vector3.new(0, 0.1, 0)
	pad.Parent = folder

	local light = Instance.new("PointLight")
	light.Name = "EscapeLight"
	light.Color = ESCAPE_COLOR
	light.Range = 55
	light.Brightness = 5
	light.Shadows = true
	light.Parent = pad

	-- Broken concrete pillars: what is left of the core
	local pillars = {
		{Vector3.new(-5, 0, -4), 3.5, 12},
		{Vector3.new(4, 0, -5), 2.2, -20},
		{Vector3.new(5.5, 0, 3.5), 4.2, 8},
		{Vector3.new(-4.5, 0, 5), 1.6, -35},
	}
	for index, pillar in pillars do
		local offset, height, tilt = pillar[1], pillar[2], pillar[3]
		local ruin = Instance.new("Part")
		ruin.Name = "Ruin" .. index
		ruin.Shape = Enum.PartType.Cylinder
		ruin.Anchored = true
		ruin.CanCollide = false -- Never blocks the way out
		ruin.CanQuery = false
		ruin.Material = Enum.Material.Concrete
		ruin.Color = Color3.fromRGB(70, 70, 72)
		ruin.Size = Vector3.new(height, 1.6, 1.6)
		ruin.CFrame = CFrame.new(escapeCenter + offset + Vector3.new(0, height / 2, 0))
			* CFrame.Angles(0, math.rad(tilt * 3), math.rad(90 + tilt))
		ruin.Parent = folder
	end

	folder.Parent = workspace
	return folder
end

GameState.OnPhase(Phases.Horror, function()
	BuildEscapeZone()

	-- Escaped when the player stands on the zone (checked every frame, more reliable than Touched)
	victoryConnection = RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then return end

		local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
		if (flat - escapeCenter).Magnitude <= ESCAPE_REACH then
			GameState.Set(Phases.TrueVictory)
		end
	end)
end)

-- Lives: every death in the horror costs one, the last one ends the game
local LIVES = 3
player:SetAttribute("LivesLeft", LIVES)

GameState.OnPhase(Phases.Horror, function()
	player:SetAttribute("HorrorStartTime", os.clock())
end)

local function WatchDeaths(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end
	humanoid.Died:Connect(function()
		if not GameState.Is(Phases.Horror) then return end
		local livesLeft = math.max((player:GetAttribute("LivesLeft") or LIVES) - 1, 0)
		player:SetAttribute("LivesLeft", livesLeft)
		if livesLeft == 0 then
			GameState.Set(Phases.GameOver)
		end
	end)
end

-- Respawning during the horror starts again at the spawn pad
player.CharacterAdded:Connect(function(newCharacter)
	WatchDeaths(newCharacter)
	if GameState.Is(Phases.Horror) then
		TeleportToSpawn(newCharacter)
	end
end)
if player.Character then
	task.spawn(WatchDeaths, player.Character)
end

GameState.OnPhase(Phases.GameOver, function()
	if victoryConnection then
		victoryConnection:Disconnect()
		victoryConnection = nil
	end
	print("GAME OVER: The Hunter got you.")
end)

-------------------------------------------------------------------------
-- TRUE VICTORY: the player made it out
-------------------------------------------------------------------------
GameState.OnPhase(Phases.TrueVictory, function()
	if victoryConnection then
		victoryConnection:Disconnect()
		victoryConnection = nil
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
	print("TRUE VICTORY: You survived your own maze!")
end)
