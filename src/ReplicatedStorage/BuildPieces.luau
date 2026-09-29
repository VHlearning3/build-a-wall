-- Build pieces and placement rules shared by the client build menu and the server that places them
local BuildPieces = {
	GRID_SIZE = 2, -- Pieces snap to a 2-stud grid
	KEEP_CLEAR_RADIUS = 7, -- No pieces this close to the spawn pad or the core

	Pieces = {
		{name = "Wall", size = Vector3.new(12, 10, 2), color = BrickColor.new("Neon orange"), key = Enum.KeyCode.One, blocksWalking = true},
		{name = "Tower", size = Vector3.new(4, 10, 4), color = BrickColor.new("Cyan"), key = Enum.KeyCode.Two, blocksWalking = true},
		-- A round bumper: orbs that bounce off it get a speed boost and turn pink (EntitySpawner)
		{name = "Booster", size = Vector3.new(6, 6, 6), shape = Enum.PartType.Ball, color = BrickColor.new("Lime green"), key = Enum.KeyCode.Three, blocksWalking = true},
	},
}

-- Footprint size on the ground after rotating by a multiple of 90 degrees
function BuildPieces.Footprint(size, rotation)
	if rotation % 180 == 90 then
		return Vector3.new(size.Z, size.Y, size.X)
	end
	return size
end

return BuildPieces
