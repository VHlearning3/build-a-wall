-- Builds the current level from ArenaLayout (border, maze, spinning bumpers, extra cores), moves the
-- spawn pad and the core into place, and turns it all to concrete with the player's walls at the twist
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))
local ServerPhase = require(ServerScriptService:WaitForChild("ServerPhase"))

local RTS_COLOR = Color3.fromRGB(40, 55, 80) -- Dark steel blue: clearly part of the level, not a player piece
local TRIM_COLOR = Color3.fromRGB(150, 185, 235) -- Pale steel, so level walls never look like the cyan Tower piece
local TRIM_WIDTH = 0.5

local arena = nil
local trims = {}

local function MakeWall(name, rect, parent)
	local xMin, xMax, zMin, zMax = rect[1], rect[2], rect[3], rect[4]
	local wall = Instance.new("Part")
	wall.Name = name
	wall.Anchored = true
	wall.Material = Enum.Material.SmoothPlastic
	wall.Color = RTS_COLOR
	wall.Size = Vector3.new(xMax - xMin, ArenaLayout.WALL_HEIGHT, zMax - zMin)
	wall.Position = Vector3.new((xMin + xMax) / 2, ArenaLayout.WALL_HEIGHT / 2, (zMin + zMax) / 2)
	wall.Parent = parent

	-- Thin neon line along the top so the level reads well from the RTS camera
	local trim = Instance.new("Part")
	trim.Name = "Trim"
	trim.Anchored = true
	trim.CanCollide = false
	trim.CanQuery = false
	trim.CanTouch = false
	trim.CastShadow = false
	trim.Material = Enum.Material.Neon
	trim.Color = TRIM_COLOR
	local alongX = wall.Size.X >= wall.Size.Z
	trim.Size = Vector3.new(if alongX then wall.Size.X else TRIM_WIDTH, 0.2, if alongX then TRIM_WIDTH else wall.Size.Z)
	trim.Position = wall.Position + Vector3.new(0, ArenaLayout.WALL_HEIGHT / 2 + 0.1, 0)
	trim.Parent = parent
	table.insert(trims, trim)
end

local entitySpawn = workspace:WaitForChild("EntitySpawn")
local core = workspace:WaitForChild("EnemyCore")
local spawnRotation = entitySpawn.CFrame - entitySpawn.Position

local function MakeBumper(index, bumper, parent)
	local bar = Instance.new("Part")
	bar.Name = "Bumper" .. index
	bar.Anchored = true
	bar.Material = Enum.Material.Neon
	bar.Color = Color3.fromRGB(255, 220, 60)
	bar.Size = Vector3.new(bumper.length, ArenaLayout.WALL_HEIGHT, 2)
	bar.Position = bumper.position + Vector3.new(0, ArenaLayout.WALL_HEIGHT / 2, 0)
	bar:SetAttribute("SpinSpeed", bumper.speed) -- The client spins it while building
	bar.Parent = parent

	local hub = Instance.new("Part")
	hub.Name = "Hub"
	hub.Shape = Enum.PartType.Cylinder
	hub.Anchored = true
	hub.CanQuery = false
	hub.Material = Enum.Material.Neon
	hub.Color = Color3.fromRGB(255, 255, 255)
	hub.Size = Vector3.new(ArenaLayout.WALL_HEIGHT + 0.4, 3, 3)
	hub.CFrame = CFrame.new(bar.Position) * CFrame.Angles(0, 0, math.rad(90))
	hub.Parent = parent
end

-- The first core is the EnemyCore in Workspace; extra cores are copies of it inside the arena
local function PlaceCores(parent)
	local cores = ArenaLayout.CORES
	core.Position = cores[1].position + Vector3.new(0, ArenaLayout.CORE_HEIGHT, 0)
	core.Transparency = 0
	core.CanCollide = true
	for index = 2, #cores do
		local extra = core:Clone()
		extra.Name = "EnemyCore" .. index
		extra.Position = cores[index].position + Vector3.new(0, ArenaLayout.CORE_HEIGHT, 0)
		extra.Parent = parent
	end
end

-- Builds a fresh arena for the current level (also at the start of every new round).
-- The folder itself stays, because client scripts keep a reference to it.
local function BuildArena()
	table.clear(trims)
	if arena then
		arena:ClearAllChildren()
	else
		arena = Instance.new("Folder")
		arena.Name = "Arena"
	end

	entitySpawn.CFrame = CFrame.new(ArenaLayout.SPAWN_POSITION + Vector3.new(0, 0.5, 0)) * spawnRotation

	local border = Instance.new("Folder")
	border.Name = "Border"
	border.Parent = arena
	for index, rect in ArenaLayout.Border() do
		MakeWall("BorderWall" .. index, rect, border)
	end

	local maze = Instance.new("Folder")
	maze.Name = "Maze"
	maze.Parent = arena
	for index, rect in ArenaLayout.MAZE do
		MakeWall("MazeWall" .. index, rect, maze)
	end

	local bumpers = Instance.new("Folder")
	bumpers.Name = "Bumpers"
	bumpers.Parent = arena
	for index, bumper in ArenaLayout.BUMPERS do
		MakeBumper(index, bumper, bumpers)
	end

	PlaceCores(arena)
	arena.Parent = workspace
end

workspace:SetAttribute("Level", ArenaLayout.LevelIndex())
BuildArena()
workspace:GetAttributeChangedSignal("Level"):Connect(BuildArena)

ServerPhase.Changed:Connect(function(phase, _, isReset)
	if isReset and (phase == "Menu" or phase == "RTS") then
		BuildArena()
		return
	end
	if phase ~= "FakeVictory" then return end
	for _, trim in trims do
		trim:Destroy()
	end
	for _, part in arena:GetDescendants() do
		if part:IsA("BasePart") then
			part.Material = Enum.Material.Concrete
			part.Color = Color3.fromRGB(88, 88, 90)
		end
	end
	-- The cores are "destroyed": gone for the Hunter's pathfinding too
	for _, part in {core, table.unpack(arena:GetChildren())} do
		if part:IsA("BasePart") and part.Name:match("^EnemyCore") then
			part.Transparency = 1
			part.CanCollide = false
		end
	end
end)
