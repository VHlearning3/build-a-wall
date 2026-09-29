-- Game director: moves the game through Menu -> RTS -> FakeVictory -> Horror -> TrueVictory (or GameOver)
-- and cleans up its part of the world when a round is reset
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local SoundFx = require(ReplicatedStorage:WaitForChild("SoundFx"))
local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))
local Phases = GameState.Phases

local coreHitEvent = ReplicatedStorage:WaitForChild("CoreHitEvent")
local core = workspace:WaitForChild("EnemyCore")
local player = Players.LocalPlayer

local FAKE_VICTORY_SECONDS = 5

-- The server follows along (walls, Hunter)
local phaseReport = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PhaseReport")
GameState.Changed:Connect(function(newPhase)
	phaseReport:FireServer(newPhase)
end)

-- Every core of the current level: EnemyCore, plus EnemyCore2... inside the arena on some levels
local function Cores()
	local cores = {core}
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		for _, child in arena:GetChildren() do
			if child:IsA("BasePart") and child.Name:match("^EnemyCore%d") then
				table.insert(cores, child)
			end
		end
		table.sort(cores, function(a, b)
			return a.Name < b.Name
		end)
	end
	return cores
end

-- Hits per core; the build menu HUD reads the totals from EnemyCore's attributes
local hitsByCore = {}

local function CountedHits()
	local total = 0
	for index, coreData in ArenaLayout.CORES do
		total += math.min(hitsByCore[index] or 0, coreData.hits)
	end
	return total
end

local function ResetHits()
	table.clear(hitsByCore)
	core:SetAttribute("HitsRequired", ArenaLayout.TotalHits())
	core:SetAttribute("Hits", 0)
end
ResetHits()
workspace:GetAttributeChangedSignal("Level"):Connect(ResetHits)

-- Stand on the spawn pad facing the maze and the escape
local function TeleportToSpawn(character)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root then
		local standAt = ArenaLayout.SPAWN_POSITION + Vector3.new(0, 3.5, 0)
		local escape = ArenaLayout.ESCAPE_POSITION
		root.CFrame = CFrame.lookAt(standAt, Vector3.new(escape.X, standAt.Y, escape.Z))
	end
end

-------------------------------------------------------------------------
-- RTS: count orbs that reach the cores
-------------------------------------------------------------------------
coreHitEvent.Event:Connect(function(hitCore)
	if not GameState.Is(Phases.RTS) then return end
	hitCore = if typeof(hitCore) == "Instance" then hitCore else core

	local cores = Cores()
	local index = table.find(cores, hitCore) or 1
	hitsByCore[index] = (hitsByCore[index] or 0) + 1
	core:SetAttribute("Hits", CountedHits())

	-- Flash, shake and boom (does not pause this handler)
	hitCore.BrickColor = BrickColor.new("White")
	task.delay(0.1, function()
		if GameState.Is(Phases.RTS) then
			hitCore.BrickColor = BrickColor.new("Really red")
		end
	end)
	SoundFx.Play("CoreHit", {parent = hitCore, volume = 0.6, maxDistance = 300})
	task.spawn(function()
		local home = hitCore.CFrame
		for shake = 1, 8 do
			local strength = (9 - shake) * 0.12
			hitCore.CFrame = home * CFrame.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, (math.random() - 0.5) * strength)
			task.wait(0.03)
		end
		hitCore.CFrame = home
	end)

	if CountedHits() >= ArenaLayout.TotalHits() then
		GameState.Set(Phases.FakeVictory)
	end
end)

-------------------------------------------------------------------------
-- FAKE VICTORY: short pause before the horror starts
-------------------------------------------------------------------------
GameState.OnPhase(Phases.FakeVictory, function()
	-- The cores are "destroyed": hide them and their glow
	for _, eachCore in Cores() do
		eachCore.Transparency = 1
		eachCore.CanCollide = false
		local coreGlow = eachCore:FindFirstChild("CoreGlow")
		if coreGlow then
			coreGlow.Enabled = false
		end
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

local escapeCenter = Vector3.zero -- Set from the level when the horror starts
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

local function StopVictoryCheck()
	if victoryConnection then
		victoryConnection:Disconnect()
		victoryConnection = nil
	end
end

GameState.OnPhase(Phases.Horror, function()
	local escape = ArenaLayout.ESCAPE_POSITION
	escapeCenter = Vector3.new(escape.X, 0, escape.Z)

	-- A retry keeps the zone that is already there
	if not workspace:FindFirstChild("EscapeZone") then
		BuildEscapeZone()
	end

	-- Escaped when the player stands on the zone (checked every frame, more reliable than Touched)
	StopVictoryCheck()
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
	StopVictoryCheck()
	print("GAME OVER: The Hunter got you.")
end)

-------------------------------------------------------------------------
-- TRUE VICTORY: the player made it out
-------------------------------------------------------------------------
GameState.OnPhase(Phases.TrueVictory, function()
	StopVictoryCheck()

	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
	print("TRUE VICTORY: You survived your own maze!")
end)

-------------------------------------------------------------------------
-- RESET: try again (back to the horror) or a whole new round
-------------------------------------------------------------------------

-- The server decides when a new round starts (after a menu button) and tells us where to begin
ReplicatedStorage.Remotes:WaitForChild("RoundReset").OnClientEvent:Connect(function(target)
	if typeof(target) == "string" and Phases[target] then
		GameState.Reset(target)
	end
end)

GameState.Resetting:Connect(function(target)
	StopVictoryCheck()
	player:SetAttribute("LivesLeft", LIVES)

	if GameState.IsFullReset(target) then
		ResetHits()
		core.CFrame = CFrame.new(ArenaLayout.CORES[1].position + Vector3.new(0, ArenaLayout.CORE_HEIGHT, 0))
		for _, eachCore in Cores() do
			eachCore.Transparency = 0
			eachCore.CanCollide = true
			eachCore.BrickColor = BrickColor.new("Really red")
			local coreGlow = eachCore:FindFirstChild("CoreGlow")
			if coreGlow then
				coreGlow.Enabled = true
			end
		end
		local zone = workspace:FindFirstChild("EscapeZone")
		if zone then
			zone:Destroy()
		end
	end
end)
