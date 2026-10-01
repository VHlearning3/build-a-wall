-- Build pieces and placement rules shared by the client build menu and the server that places them
local BuildPieces = {
	GRID_SIZE = 2, -- Pieces snap to a 2-stud grid
	ROTATION_STEP = 45, -- Pieces turn in 45-degree steps
	KEEP_CLEAR_RADIUS = 7, -- No pieces this close to the spawn pad or the core

	Pieces = {
		{name = "Wall", size = Vector3.new(12, 10, 2), color = BrickColor.new("Neon orange"), key = Enum.KeyCode.One, blocksWalking = true},
		{name = "Tower", size = Vector3.new(6, 10, 6), color = BrickColor.new("Cyan"), key = Enum.KeyCode.Two, blocksWalking = true},
		-- A round bumper: orbs that bounce off it get a speed boost and turn pink (EntitySpawner)
		{name = "Booster", size = Vector3.new(6, 6, 6), shape = Enum.PartType.Ball, color = BrickColor.new("Lime green"), key = Enum.KeyCode.Three, blocksWalking = true},
	},
}

-- Size of the axis-aligned box around a piece on the ground after turning it by "rotation" degrees
function BuildPieces.Footprint(size, rotation)
	local angle = math.rad(rotation)
	local cos, sin = math.abs(math.cos(angle)), math.abs(math.sin(angle))
	return Vector3.new(size.X * cos + size.Z * sin, size.Y, size.X * sin + size.Z * cos)
end

-- True when a point on the ground is inside a (turned) piece, grown by "margin" studs on every side
function BuildPieces.Covers(cframe, size, point, margin)
	local localPoint = cframe:PointToObjectSpace(Vector3.new(point.X, cframe.Position.Y, point.Z))
	return math.abs(localPoint.X) < size.X / 2 + margin and math.abs(localPoint.Z) < size.Z / 2 + margin
end

return BuildPieces
