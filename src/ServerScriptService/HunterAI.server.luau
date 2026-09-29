-- The Hunter: hidden until the horror phase, then chases the player through the maze on the server
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local ServerPhase = require(ServerScriptService:WaitForChild("ServerPhase"))

local hunter = workspace:WaitForChild("Hunter")
local humanoid = hunter:WaitForChild("Humanoid")
local rootPart = hunter:WaitForChild("HumanoidRootPart")
local core = workspace:WaitForChild("EnemyCore")

local WALK_SPEED = 13 -- The player walks at 16, so running away works
local REPATH_SECONDS = 0.5
local STEP_SECONDS = 0.1
local WAYPOINT_REACHED = 3
local RESPAWN_GRACE_SECONDS = 3
local SPAWN_DISTANCE_BEHIND_CORE = 14

local EYE_COLOR = Color3.fromRGB(255, 0, 0)

local coreStart = core.Position -- The core changes shape later, remember where it started
local hunting = false
local graceUntil = 0

-------------------------------------------------------------------------
-- LOOK: pitch black body with glowing red eyes
-------------------------------------------------------------------------
local function DressUp()
	for _, part in hunter:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color = Color3.fromRGB(8, 8, 10)
			part.Material = Enum.Material.SmoothPlastic
			part.Reflectance = 0
		elseif part:IsA("Decal") or part:IsA("FaceControls") then
			part:Destroy()
		end
	end

	local head = hunter:WaitForChild("Head")
	if head:IsA("MeshPart") then
		head.TextureID = "" -- Removes the painted face
	end

	for _, side in {-1, 1} do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.22, 0.22, 0.22)
		eye.Material = Enum.Material.Neon
		eye.Color = EYE_COLOR
		eye.CanCollide = false
		eye.CanQuery = false
		eye.CanTouch = false
		eye.Massless = true
		eye.CFrame = head.CFrame * CFrame.new(side * 0.22, 0.12, -head.Size.Z / 2 + 0.05)
		eye.Parent = hunter

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = eye
		weld.Parent = eye
	end

	local glow = Instance.new("PointLight")
	glow.Name = "EyeGlow"
	glow.Color = EYE_COLOR
	glow.Range = 7
	glow.Brightness = 2
	glow.Parent = head
end

-------------------------------------------------------------------------
-- ANIMATION: the rig's Animate LocalScript never runs in Workspace, so play walk/idle here
-------------------------------------------------------------------------
local function AnimationId(stateName)
	local animate = hunter:FindFirstChild("Animate")
	local state = animate and animate:FindFirstChild(stateName)
	local animation = state and state:FindFirstChildOfClass("Animation")
	return animation and animation.AnimationId
end

local function SetUpAnimations()
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

	local runId = AnimationId("run") or AnimationId("walk")
	local idleId = AnimationId("idle")

	local animate = hunter:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- Only needed it for the animation ids
	end

	local function Load(id, priority)
		if not id then return nil end
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local track = animator:LoadAnimation(animation)
		track.Priority = priority
		track.Looped = true
		return track
	end

	local runTrack = Load(runId, Enum.AnimationPriority.Movement)
	local idleTrack = Load(idleId, Enum.AnimationPriority.Idle)
	if idleTrack then
		idleTrack:Play()
	end

	humanoid.Running:Connect(function(speed)
		if not runTrack then return end
		if speed > 0.5 then
			if not runTrack.IsPlaying then
				runTrack:Play(0.2)
			end
			runTrack:AdjustSpeed(speed / 16)
		elseif runTrack.IsPlaying then
			runTrack:Stop(0.2)
		end
	end)
end

-------------------------------------------------------------------------
-- PLACEMENT: a free spot behind the old core, away from the spawn pad
-------------------------------------------------------------------------
local function FindSpawnSpot()
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = {hunter, workspace:FindFirstChild("Baseplate")}

	for ring = 0, 6 do
		for angle = 0, 315, 45 do
			local offset = Vector3.new(0, 0, -SPAWN_DISTANCE_BEHIND_CORE)
			if ring > 0 then
				offset += CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(Vector3.new(0, 0, ring * 6))
			end
			local spot = Vector3.new(coreStart.X, 3, coreStart.Z) + offset
			local blocked = workspace:GetPartBoundsInBox(CFrame.new(spot), Vector3.new(4, 5, 4), overlap)
			if #blocked == 0 then
				return spot
			end
		end
	end
	return Vector3.new(coreStart.X, 3, coreStart.Z - SPAWN_DISTANCE_BEHIND_CORE)
end

local function PlaceAtSpawn()
	local spot = FindSpawnSpot()
	hunter:PivotTo(CFrame.lookAt(spot, Vector3.new(coreStart.X, spot.Y, coreStart.Z + 100)))
	humanoid:MoveTo(spot)
end

-------------------------------------------------------------------------
-- CHASE
-------------------------------------------------------------------------
local function GetTarget()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local targetHumanoid = character and character:FindFirstChildOfClass("Humanoid")
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		if targetHumanoid and targetRoot and targetHumanoid.Health > 0 then
			return targetRoot
		end
	end
	return nil
end

local function HasLineOfSight(targetRoot)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {hunter, targetRoot.Parent}
	local direction = targetRoot.Position - rootPart.Position
	return workspace:Raycast(rootPart.Position, direction, params) == nil
end

local function ChaseLoop()
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false, -- Ei anneta sen hyppiä muurien yli
		WaypointSpacing = 4,
	})
	local waypoints = {}
	local waypointIndex = 0
	local lastPathTime = 0

	while hunting do
		local targetRoot = GetTarget()
		if targetRoot and os.clock() >= graceUntil then
			if HasLineOfSight(targetRoot) then
				-- Straight at the player when nothing is in the way
				waypoints = {}
				humanoid:MoveTo(targetRoot.Position)
			else
				if os.clock() - lastPathTime > REPATH_SECONDS or waypointIndex > #waypoints then
					lastPathTime = os.clock()
					local ok = pcall(function()
						path:ComputeAsync(rootPart.Position, targetRoot.Position)
					end)
					if ok and path.Status == Enum.PathStatus.Success then
						waypoints = path:GetWaypoints()
						waypointIndex = 2
					else
						waypoints = {}
						humanoid:MoveTo(targetRoot.Position) -- Estää jumiutumisen
					end
				end

				local waypoint = waypoints[waypointIndex]
				if waypoint then
					local flat = Vector3.new(waypoint.Position.X - rootPart.Position.X, 0, waypoint.Position.Z - rootPart.Position.Z)
					if flat.Magnitude < WAYPOINT_REACHED then
						waypointIndex += 1
						waypoint = waypoints[waypointIndex]
					end
					if waypoint then
						humanoid:MoveTo(waypoint.Position)
					end
				end
			end
		else
			humanoid:MoveTo(rootPart.Position)
		end
		task.wait(STEP_SECONDS)
	end
	humanoid:MoveTo(rootPart.Position)
end

-------------------------------------------------------------------------
-- KILL ON TOUCH
-------------------------------------------------------------------------
local function OnTouched(hit)
	if not hunting or os.clock() < graceUntil then return end
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then return end
	local targetHumanoid = character:FindFirstChildOfClass("Humanoid")
	if targetHumanoid and targetHumanoid.Health > 0 then
		targetHumanoid.Health = 0 -- Pelaaja kuolee
		print("The Hunter caught " .. player.Name .. "!")
	end
end

-------------------------------------------------------------------------
-- SETUP AND PHASES
-------------------------------------------------------------------------
DressUp()
SetUpAnimations()
humanoid.WalkSpeed = WALK_SPEED
for _, part in hunter:GetDescendants() do
	if part:IsA("BasePart") then
		part.Touched:Connect(OnTouched)
	end
end

-- Hidden and idle during the RTS phase
hunter.Parent = ServerStorage

ServerPhase.Changed:Connect(function(phase)
	if phase == "Horror" then
		hunter.Parent = workspace
		PlaceAtSpawn()
		rootPart:SetNetworkOwner(nil) -- The server moves the Hunter
		graceUntil = os.clock() + 1
		hunting = true
		print("The Hunter is loose...")
		task.spawn(ChaseLoop)
	elseif phase == "TrueVictory" or phase == "GameOver" then
		hunting = false
		print("The Hunter stops. The game is over.")
	end
end)

-- No spawn camping: after a death the Hunter goes back to its lair and waits a moment
local function WatchPlayer(player)
	player.CharacterAdded:Connect(function()
		if hunting then
			graceUntil = os.clock() + RESPAWN_GRACE_SECONDS
			PlaceAtSpawn()
		end
	end)
end
Players.PlayerAdded:Connect(WatchPlayer)
for _, player in Players:GetPlayers() do
	WatchPlayer(player)
end
