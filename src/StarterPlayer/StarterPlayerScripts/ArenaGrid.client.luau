-- Draws the glowing light-blue grid on the RTS floor and removes it when the RTS phase ends
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))
local Phases = GameState.Phases

local CELL = 8 -- Studs between grid lines
local LINE_WIDTH = 0.15
local LINE_COLOR = Color3.fromRGB(120, 200, 255)

local gridFolder = Instance.new("Folder")
gridFolder.Name = "ArenaGrid"

local function MakeLine(size, position)
	local line = Instance.new("Part")
	line.Name = "GridLine"
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false -- Mouse and orb raycasts go straight through
	line.CanTouch = false
	line.CastShadow = false
	line.Material = Enum.Material.Neon
	line.Color = LINE_COLOR
	line.Transparency = 0.55
	line.Size = size
	line.Position = position
	line.Parent = gridFolder
end

-- Covers the arena floor inside the border walls
local halfX, halfZ = ArenaLayout.HALF_X, ArenaLayout.HALF_Z
for x = -halfX, halfX, CELL do
	MakeLine(Vector3.new(LINE_WIDTH, 0.05, halfZ * 2), Vector3.new(x, 0.03, 0))
end
for z = -halfZ, halfZ, CELL do
	MakeLine(Vector3.new(halfX * 2, 0.05, LINE_WIDTH), Vector3.new(0, 0.03, z))
end
gridFolder.Parent = workspace

GameState.OnPhase(Phases.FakeVictory, function()
	gridFolder:Destroy()
end)
