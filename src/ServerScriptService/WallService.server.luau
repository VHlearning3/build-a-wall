-- Places and removes the player's maze pieces on the server so the Hunter's pathfinding and physics see them.
-- Rules: a piece budget, no overlaps, nothing on the spawn pad or core, and the way from the spawn to the
-- core must stay open (otherwise the horror escape would be impossible).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BuildPieces = require(ReplicatedStorage:WaitForChild("BuildPieces"))
local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))
local ServerPhase = require(ServerScriptService:WaitForChild("ServerPhase"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local placePiece = remotes:WaitForChild("PlacePiece")
local removePiece = remotes:WaitForChild("RemovePiece")
local baseplate = workspace:WaitForChild("Baseplate")

local MIN_SECONDS_BETWEEN_ACTIONS = 0.1
local CELL = 2 -- Path check grid, in studs
local CLEARANCE = 1 -- Studs kept free next to blocking walls so a character fits through

local wallsFolder = Instance.new("Folder")
wallsFolder.Name = "RTSWalls"
wallsFolder.Parent = workspace

local lastActionTime = {}

local function Snap(value)
	return math.floor(value / BuildPieces.GRID_SIZE + 0.5) * BuildPieces.GRID_SIZE
end

local function RectOf(position, footprint)
	return {
		position.X - footprint.X / 2, position.X + footprint.X / 2,
		position.Z - footprint.Z / 2, position.Z + footprint.Z / 2,
	}
end

local function IsNearKeepClear(position, footprint)
	local reach = BuildPieces.KEEP_CLEAR_RADIUS + math.max(footprint.X, footprint.Z) / 2
	for _, spot in ArenaLayout.KeepClearSpots() do
		if Vector3.new(position.X - spot.X, 0, position.Z - spot.Z).Magnitude < reach then
			return true
		end
	end
	-- Nothing inside the circle a spinning bumper sweeps
	for _, bumper in ArenaLayout.BUMPERS do
		local sweep = bumper.length / 2 + 1 + math.max(footprint.X, footprint.Z) / 2
		if Vector3.new(position.X - bumper.position.X, 0, position.Z - bumper.position.Z).Magnitude < sweep then
			return true
		end
	end
	return false
end

local function IsInsideArena(rect)
	return rect[1] >= -ArenaLayout.HALF_X and rect[2] <= ArenaLayout.HALF_X
		and rect[3] >= -ArenaLayout.HALF_Z and rect[4] <= ArenaLayout.HALF_Z
end

-- Exact overlap test with a probe shaped like the piece (works for turned pieces too)
local probe = Instance.new("Part")
probe.Name = "OverlapProbe"
probe.Anchored = true
probe.CanCollide = false
probe.CanQuery = false
probe.CanTouch = false
probe.Transparency = 1

local function Overlaps(cframe, size)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {wallsFolder, workspace:WaitForChild("Arena")}
	probe.Size = Vector3.new(size.X - 0.2, 1, size.Z - 0.2) -- Touching edges is fine
	probe.CFrame = CFrame.new(cframe.Position.X, 1, cframe.Position.Z) * cframe.Rotation
	probe.Parent = workspace
	local hits = workspace:GetPartsInPart(probe, params)
	probe.Parent = nil
	for _, hit in hits do
		if hit.CanCollide then
			return true
		end
	end
	return false
end

-- Flood fill over a 2-stud grid: can a character still walk from the spawn to the core?
-- extraPiece is an optional {cframe, size} for the piece about to be placed
local function EscapePathExists(extraPiece)
	local columns = math.floor(ArenaLayout.HALF_X * 2 / CELL)
	local rows = math.floor(ArenaLayout.HALF_Z * 2 / CELL)
	local blocked = {}

	local function Block(rect)
		local xMin, xMax = rect[1] - CLEARANCE, rect[2] + CLEARANCE
		local zMin, zMax = rect[3] - CLEARANCE, rect[4] + CLEARANCE
		for column = 1, columns do
			local x = -ArenaLayout.HALF_X + (column - 0.5) * CELL
			if x > xMin and x < xMax then
				for row = 1, rows do
					local z = -ArenaLayout.HALF_Z + (row - 0.5) * CELL
					if z > zMin and z < zMax then
						blocked[column * 1000 + row] = true
					end
				end
			end
		end
	end

	for _, rect in ArenaLayout.MAZE do
		Block(rect)
	end
	for _, bumper in ArenaLayout.BUMPERS do
		-- In the horror a bumper stands still along the X axis
		local p = bumper.position
		Block({p.X - bumper.length / 2, p.X + bumper.length / 2, p.Z - 1, p.Z + 1})
	end
	-- Pieces may be turned, so test each cell against the turned shape
	local function BlockPiece(cframe, size)
		local footprint = BuildPieces.Footprint(size, math.deg(select(2, cframe:ToOrientation())))
		local xMin, xMax = cframe.Position.X - footprint.X / 2 - CLEARANCE, cframe.Position.X + footprint.X / 2 + CLEARANCE
		local zMin, zMax = cframe.Position.Z - footprint.Z / 2 - CLEARANCE, cframe.Position.Z + footprint.Z / 2 + CLEARANCE
		for column = 1, columns do
			local x = -ArenaLayout.HALF_X + (column - 0.5) * CELL
			if x > xMin and x < xMax then
				for row = 1, rows do
					local z = -ArenaLayout.HALF_Z + (row - 0.5) * CELL
					if z > zMin and z < zMax and BuildPieces.Covers(cframe, size, Vector3.new(x, 0, z), CLEARANCE) then
						blocked[column * 1000 + row] = true
					end
				end
			end
		end
	end
	for _, part in wallsFolder:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("BlocksWalking") then
			BlockPiece(part.CFrame, part.Size)
		end
	end
	if extraPiece then
		BlockPiece(extraPiece.cframe, extraPiece.size)
	end

	local function CellAt(position)
		local column = math.clamp(math.floor((position.X + ArenaLayout.HALF_X) / CELL) + 1, 1, columns)
		local row = math.clamp(math.floor((position.Z + ArenaLayout.HALF_Z) / CELL) + 1, 1, rows)
		return column, row
	end

	local startColumn, startRow = CellAt(ArenaLayout.SPAWN_POSITION)
	local goalColumn, goalRow = CellAt(ArenaLayout.ESCAPE_POSITION)
	local visited = {[startColumn * 1000 + startRow] = true}
	local queue = {{startColumn, startRow}}
	local head = 1
	while head <= #queue do
		local column, row = queue[head][1], queue[head][2]
		head += 1
		if column == goalColumn and row == goalRow then
			return true
		end
		for _, step in {{1, 0}, {-1, 0}, {0, 1}, {0, -1}} do
			local nextColumn, nextRow = column + step[1], row + step[2]
			local key = nextColumn * 1000 + nextRow
			if nextColumn >= 1 and nextColumn <= columns and nextRow >= 1 and nextRow <= rows
				and not visited[key] and not blocked[key] then
				visited[key] = true
				table.insert(queue, {nextColumn, nextRow})
			end
		end
	end
	return false
end

local function CheckLevelRoute()
	if not EscapePathExists(nil) then
		warn("Level " .. ArenaLayout.LevelIndex() .. ": the prebuilt maze has no way from the spawn to the escape")
	end
end
CheckLevelRoute()

local function Refuse(player, reason)
	placePiece:FireClient(player, reason)
end

placePiece.OnServerEvent:Connect(function(player, pieceIndex, position, rotation)
	if not ServerPhase.Is("RTS") then return end

	-- Validate everything the client sent
	if typeof(pieceIndex) ~= "number" or typeof(position) ~= "Vector3" or typeof(rotation) ~= "number" then return end
	local piece = BuildPieces.Pieces[pieceIndex]
	if not piece then return end
	if position.X ~= position.X or position.Z ~= position.Z then return end -- NaN
	if rotation % BuildPieces.ROTATION_STEP ~= 0 then return end
	rotation %= 360

	local now = os.clock()
	if lastActionTime[player] and now - lastActionTime[player] < MIN_SECONDS_BETWEEN_ACTIONS then return end
	lastActionTime[player] = now

	if #wallsFolder:GetChildren() >= ArenaLayout.BUDGET then
		return Refuse(player, "No pieces left. Right-click a piece to remove it.")
	end

	local footprint = BuildPieces.Footprint(piece.size, rotation)
	local floorY = baseplate.Position.Y + baseplate.Size.Y / 2
	local snapped = Vector3.new(Snap(position.X), floorY + piece.size.Y / 2, Snap(position.Z))
	local rect = RectOf(snapped, footprint)
	local cframe = CFrame.new(snapped) * CFrame.Angles(0, math.rad(rotation), 0)

	if not IsInsideArena(rect) then return Refuse(player, "Build inside the arena.") end
	if IsNearKeepClear(snapped, footprint) then return Refuse(player, "Keep the spawn pad, the cores and the bumpers clear.") end
	if Overlaps(cframe, piece.size) then return Refuse(player, "Something is already there.") end
	if piece.blocksWalking and not EscapePathExists({cframe = cframe, size = piece.size}) then
		return Refuse(player, "That would seal the way to the core.")
	end

	local part = Instance.new("Part")
	part.Name = piece.name
	part.Size = piece.size
	part.Shape = piece.shape or Enum.PartType.Block
	part.Anchored = true
	part.BrickColor = piece.color
	part.Material = Enum.Material.Neon
	part.CFrame = cframe
	part:SetAttribute("BlocksWalking", piece.blocksWalking)
	part:SetAttribute("Rotation", rotation)
	part.Parent = wallsFolder
end)

removePiece.OnServerEvent:Connect(function(player, part)
	if not ServerPhase.Is("RTS") then return end
	if typeof(part) ~= "Instance" or part.Parent ~= wallsFolder then return end

	local now = os.clock()
	if lastActionTime[player] and now - lastActionTime[player] < MIN_SECONDS_BETWEEN_ACTIONS then return end
	lastActionTime[player] = now

	part:Destroy()
end)

-- A new level starts with an empty arena
workspace:GetAttributeChangedSignal("Level"):Connect(function()
	wallsFolder:ClearAllChildren()
	CheckLevelRoute()
end)

ServerPhase.Changed:Connect(function(phase, _, isReset)
	-- A new round from the start clears the arena
	if isReset and (phase == "Menu" or phase == "RTS") then
		wallsFolder:ClearAllChildren()
		return
	end

	-- The neon maze turns into dark concrete when the fake victory starts
	if phase ~= "FakeVictory" then return end
	for _, part in wallsFolder:GetChildren() do
		if part:IsA("BasePart") then
			part.Material = Enum.Material.Concrete
			part.BrickColor = BrickColor.new("Dark stone grey")
		end
	end
end)
