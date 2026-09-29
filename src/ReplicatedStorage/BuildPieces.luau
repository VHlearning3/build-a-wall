-- Build pieces shared by the client build menu and the server that places them
local BuildPieces = {
	GRID_SIZE = 2, -- Pieces snap to a 2-stud grid
	MAX_PIECES = 150,
	ARENA_HALF_EXTENT = 150, -- Pieces must be placed inside -150..150 on X and Z
	KEEP_CLEAR_RADIUS = 7, -- No pieces this close to the spawn pad or the core, so neither can be walled in

	Pieces = {
		{name = "Wall", size = Vector3.new(12, 10, 2), color = BrickColor.new("Neon orange"), key = Enum.KeyCode.One},
		{name = "Tower", size = Vector3.new(4, 10, 4), color = BrickColor.new("Cyan"), key = Enum.KeyCode.Two},
		{name = "Floor Obstacle", size = Vector3.new(10, 2, 10), color = BrickColor.new("Magenta"), key = Enum.KeyCode.Three},
	},
}

return BuildPieces
