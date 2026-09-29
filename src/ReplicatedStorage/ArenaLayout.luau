-- The walled arena and its prebuilt concrete maze, shared by the server (builds it) and the client (camera, grid)
local ArenaLayout = {}

-- Inner play area: X from -HALF_X to HALF_X, Z from -HALF_Z to HALF_Z
ArenaLayout.HALF_X = 64
ArenaLayout.HALF_Z = 96
ArenaLayout.WALL_HEIGHT = 10
ArenaLayout.WALL_THICKNESS = 2

-- Must match EntitySpawn and EnemyCore in Workspace
ArenaLayout.SPAWN_POSITION = Vector3.new(0, 0, 70)
ArenaLayout.CORE_POSITION = Vector3.new(0, 0, -70)

-- Maze barriers as {xMin, xMax, zMin, zMax}. They zig-zag so the way from the spawn to the core
-- goes left, right, then left again; the player's own pieces add to it.
ArenaLayout.MAZE = {
	{-64, -26, 39, 41}, -- Row 1, gap on the middle-left (-26..-2)
	{-2, 64, 39, 41},
	{-64, 26, 4, 6}, -- Row 2, gap on the right (26..64)
	{-38, 64, -31, -29}, -- Row 3, gap on the left (-64..-38)
	{36, 44, 58, 66}, -- Small blocks
	{-44, -36, -58, -50},
	{-20, -12, 18, 26},
	{12, 20, -16, -8},
}

-- Border walls around the play area, same format
function ArenaLayout.Border()
	local x, z, t = ArenaLayout.HALF_X, ArenaLayout.HALF_Z, ArenaLayout.WALL_THICKNESS
	return {
		{-x - t, x + t, z, z + t}, -- Back (behind the spawn)
		{-x - t, x + t, -z - t, -z}, -- Front (behind the core)
		{-x - t, -x, -z, z}, -- Left
		{x, x + t, -z, z}, -- Right
	}
end

return ArenaLayout
