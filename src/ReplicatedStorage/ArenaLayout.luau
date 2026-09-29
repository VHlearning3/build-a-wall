-- The current level's layout, shared by the server (builds it) and the client (camera, grid, preview).
-- The server picks the level with workspace attribute "Level"; every field of the current level in
-- Levels can be read straight from here (ArenaLayout.HALF_X, ArenaLayout.MAZE, ...).
local Levels = require(script.Parent:WaitForChild("Levels"))

local ArenaLayout = {}

ArenaLayout.WALL_HEIGHT = 10
ArenaLayout.WALL_THICKNESS = 2
ArenaLayout.CORE_HEIGHT = 8 -- Centre height of a 16-stud core ball
ArenaLayout.LEVEL_COUNT = #Levels

function ArenaLayout.LevelIndex()
	local index = workspace:GetAttribute("Level")
	if typeof(index) == "number" and Levels[index] then
		return index
	end
	return 1
end

function ArenaLayout.Level()
	return Levels[ArenaLayout.LevelIndex()]
end

function ArenaLayout.GetLevel(index)
	return Levels[index]
end

-- Border walls around the play area, same rectangle format as MAZE
function ArenaLayout.Border()
	local level = ArenaLayout.Level()
	local x, z, t = level.HALF_X, level.HALF_Z, ArenaLayout.WALL_THICKNESS
	return {
		{-x - t, x + t, z, z + t}, -- Back (behind the spawn)
		{-x - t, x + t, -z - t, -z}, -- Front
		{-x - t, -x, -z, z}, -- Left
		{x, x + t, -z, z}, -- Right
	}
end

-- Places no piece may be built on: the spawn pad, every core and every battery pickup
function ArenaLayout.KeepClearSpots()
	local level = ArenaLayout.Level()
	local spots = {level.SPAWN_POSITION}
	for _, core in level.CORES do
		table.insert(spots, core.position)
	end
	if level.BATTERY then
		for _, pickup in level.BATTERY.PICKUPS do
			table.insert(spots, pickup)
		end
	end
	return spots
end

-- The Hunter closest to a position (levels can have several: Hunter, Hunter2, ...), or nil
function ArenaLayout.NearestHunter(position)
	local nearest, nearestDistance = nil, math.huge
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and child.Name:match("^Hunter%d*$") then
			local root = child:FindFirstChild("HumanoidRootPart")
			if root then
				local distance = (root.Position - position).Magnitude
				if distance < nearestDistance then
					nearest, nearestDistance = root, distance
				end
			end
		end
	end
	return nearest, nearestDistance
end

function ArenaLayout.TotalHits()
	local total = 0
	for _, core in ArenaLayout.Level().CORES do
		total += core.hits
	end
	return total
end

-- Anything else (HALF_X, MAZE, BUDGET, ...) comes from the current level
setmetatable(ArenaLayout, {
	__index = function(_, key)
		return ArenaLayout.Level()[key]
	end,
})

return ArenaLayout
