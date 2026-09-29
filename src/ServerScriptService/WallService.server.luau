-- Places the player's maze pieces on the server so the Hunter's pathfinding and physics see them
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BuildPieces = require(ReplicatedStorage:WaitForChild("BuildPieces"))
local ServerPhase = require(ServerScriptService:WaitForChild("ServerPhase"))

local placePiece = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlacePiece")
local entitySpawn = workspace:WaitForChild("EntitySpawn")
local core = workspace:WaitForChild("EnemyCore")
local baseplate = workspace:WaitForChild("Baseplate")

local MIN_SECONDS_BETWEEN_PLACES = 0.1

local wallsFolder = Instance.new("Folder")
wallsFolder.Name = "RTSWalls"
wallsFolder.Parent = workspace

-- Remember keep-clear spots now, before the core changes shape in the horror phase
local keepClear = {entitySpawn.Position, core.Position}

local lastPlaceTime = {}

local function Snap(value)
	return math.floor(value / BuildPieces.GRID_SIZE + 0.5) * BuildPieces.GRID_SIZE
end

local function IsNearKeepClear(position, size)
	local reach = BuildPieces.KEEP_CLEAR_RADIUS + math.max(size.X, size.Z) / 2
	for _, spot in keepClear do
		local flat = Vector3.new(position.X - spot.X, 0, position.Z - spot.Z)
		if flat.Magnitude < reach then
			return true
		end
	end
	return false
end

placePiece.OnServerEvent:Connect(function(player, pieceIndex, position, rotation)
	if not ServerPhase.Is("RTS") then return end

	-- Validate everything the client sent
	if typeof(pieceIndex) ~= "number" or typeof(position) ~= "Vector3" or typeof(rotation) ~= "number" then return end
	local piece = BuildPieces.Pieces[pieceIndex]
	if not piece then return end
	if position.X ~= position.X or position.Z ~= position.Z then return end -- NaN
	if math.abs(position.X) > BuildPieces.ARENA_HALF_EXTENT or math.abs(position.Z) > BuildPieces.ARENA_HALF_EXTENT then return end
	if rotation % 90 ~= 0 then return end

	local now = os.clock()
	if lastPlaceTime[player] and now - lastPlaceTime[player] < MIN_SECONDS_BETWEEN_PLACES then return end
	if #wallsFolder:GetChildren() >= BuildPieces.MAX_PIECES then return end

	local floorY = baseplate.Position.Y + baseplate.Size.Y / 2
	local snapped = Vector3.new(Snap(position.X), floorY + piece.size.Y / 2, Snap(position.Z))
	if IsNearKeepClear(snapped, piece.size) then return end

	lastPlaceTime[player] = now

	local part = Instance.new("Part")
	part.Name = piece.name
	part.Size = piece.size
	part.Anchored = true
	part.BrickColor = piece.color
	part.Material = Enum.Material.Neon
	part.CFrame = CFrame.new(snapped) * CFrame.Angles(0, math.rad(rotation), 0)
	part.Parent = wallsFolder
end)

-- The neon maze turns into dark concrete when the fake victory starts
ServerPhase.Changed:Connect(function(phase)
	if phase ~= "FakeVictory" then return end
	for _, part in wallsFolder:GetChildren() do
		if part:IsA("BasePart") then
			part.Material = Enum.Material.Concrete
			part.BrickColor = BrickColor.new("Dark stone grey")
		end
	end
end)
