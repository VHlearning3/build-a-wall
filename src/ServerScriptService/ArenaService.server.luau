-- Builds the walled arena and the prebuilt maze from ArenaLayout, and turns them to concrete with the player's walls
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))
local ServerPhase = require(ServerScriptService:WaitForChild("ServerPhase"))

local RTS_COLOR = Color3.fromRGB(40, 55, 80) -- Dark steel blue: clearly part of the level, not a player piece
local TRIM_COLOR = Color3.fromRGB(150, 185, 235) -- Pale steel, so level walls never look like the cyan Tower piece
local TRIM_WIDTH = 0.5

local arena = Instance.new("Folder")
arena.Name = "Arena"

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

arena.Parent = workspace

ServerPhase.Changed:Connect(function(phase)
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
end)
