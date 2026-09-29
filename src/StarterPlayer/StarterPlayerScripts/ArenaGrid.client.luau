-- Draws the glowing light-blue grid on the RTS floor and removes it when the horror phase starts
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local horrorEvent = ReplicatedStorage:WaitForChild("HorrorModeEvent")

local CELL = 8 -- Studs between grid lines
local HALF_EXTENT = 160 -- Grid covers -160..160 on X and Z
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

local length = HALF_EXTENT * 2
for offset = -HALF_EXTENT, HALF_EXTENT, CELL do
	MakeLine(Vector3.new(LINE_WIDTH, 0.05, length), Vector3.new(offset, 0.03, 0))
	MakeLine(Vector3.new(length, 0.05, LINE_WIDTH), Vector3.new(0, 0.03, offset))
end
gridFolder.Parent = workspace

horrorEvent.Event:Connect(function()
	gridFolder:Destroy()
end)
