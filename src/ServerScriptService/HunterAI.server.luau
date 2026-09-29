-- The Hunter: hidden until the horror phase, then chases the player through the maze on the server
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerPhase = require(ServerScriptService:WaitForChild("ServerPhase"))
local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))
local SoundFx = require(ReplicatedStorage:WaitForChild("SoundFx"))

local hunter = workspace:WaitForChild("Hunter")
local humanoid = hunter:WaitForChild("Humanoid")
local rootPart = hunter:WaitForChild("HumanoidRootPart")

local BASE_SPEED = 11 -- The player walks at 16, so running away works
local SPEED_PER_WIN = 0.8 -- Each escape makes the next Hunter a little faster
local MAX_SPEED = 15
local STALK_SPEED_FACTOR = 0.55 -- Slow creeping while it has not found the player yet
local CHASE_RANGE = 28 -- Starts chasing when it sees the player this close
local CLOSE_RANGE = 14 -- ...or when the player is this close, seen or not
local LOSE_TRACK_SECONDS = 5 -- Goes back to stalking after not seeing the player this long
local REPATH_SECONDS = 0.5
local STEP_SECONDS = 0.1
local WAYPOINT_REACHED = 3
local RESPAWN_GRACE_SECONDS = 3
local LAIR_DISTANCE_BEHIND_ESCAPE = 14

local EYE_COLOR = Color3.fromRGB(255, 0, 0)

local hunting = false
local huntGeneration = 0 -- Bumped every hunt so loops from an earlier round stop
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
-- PLACEMENT: the lair is a free spot just beyond the escape zone, seen from the spawn pad
-------------------------------------------------------------------------
local function LairCentre()
	local escape = ArenaLayout.ESCAPE_POSITION
	local away = Vector3.new(escape.X - ArenaLayout.SPAWN_POSITION.X, 0, escape.Z - ArenaLayout.SPAWN_POSITION.Z)
	away = if away.Magnitude > 0 then away.Unit else Vector3.new(0, 0, -1)
	local lair = escape + away * LAIR_DISTANCE_BEHIND_ESCAPE
	local margin = 4
	return Vector3.new(
		math.clamp(lair.X, -ArenaLayout.HALF_X + margin, ArenaLayout.HALF_X - margin),
		3,
		math.clamp(lair.Z, -ArenaLayout.HALF_Z + margin, ArenaLayout.HALF_Z - margin)
	)
end

local function FindSpawnSpot()
	local centre = LairCentre()
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = {hunter, workspace:FindFirstChild("Baseplate")}

	for ring = 0, 6 do
		for angle = 0, 315, 45 do
			local offset = Vector3.zero
			if ring > 0 then
				offset = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(Vector3.new(0, 0, ring * 6))
			end
			local spot = centre + offset
			local blocked = workspace:GetPartBoundsInBox(CFrame.new(spot), Vector3.new(4, 5, 4), overlap)
			if #blocked == 0 then
				return spot
			end
		end
	end
	return centre
end

local function PlaceAtSpawn()
	local spot = FindSpawnSpot()
	local spawnPad = ArenaLayout.SPAWN_POSITION
	hunter:PivotTo(CFrame.lookAt(spot, Vector3.new(spawnPad.X, spot.Y, spawnPad.Z)))
	humanoid:MoveTo(spot)
end

-------------------------------------------------------------------------
-- HUNT: wait in the lair, creep towards the player, then chase once it sees them
-------------------------------------------------------------------------
local function GetTarget()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local targetHumanoid = character and character:FindFirstChildOfClass("Humanoid")
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		if targetHumanoid and targetRoot and targetHumanoid.Health > 0 then
			return targetRoot, player
		end
	end
	return nil, nil
end

local function HasLineOfSight(targetRoot)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {hunter, targetRoot.Parent}
	local direction = targetRoot.Position - rootPart.Position
	return workspace:Raycast(rootPart.Position, direction, params) == nil
end

local function ChaseSpeed(player)
	local wins = player and player:GetAttribute("Wins") or 0
	return math.min(BASE_SPEED + wins * SPEED_PER_WIN, MAX_SPEED)
end

local function Growl()
	SoundFx.Play("Growl", {parent = hunter:FindFirstChild("Head") or rootPart, volume = 1, speed = 0.75 + math.random() * 0.15, maxDistance = 90})
end

local function HuntLoop(generation)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false, -- Ei anneta sen hyppiä muurien yli
		WaypointSpacing = 4,
	})
	local waypoints = {}
	local waypointIndex = 0
	local lastPathTime = 0
	local chasing = not ArenaLayout.HUNTER_STALKS -- Some levels skip the creeping
	local lastSeen = 0
	local stalkGoal = nil
	local nextGrowl = 0

	local function FollowPathTo(goal, repathSeconds)
		if os.clock() - lastPathTime > repathSeconds or waypointIndex > #waypoints then
			lastPathTime = os.clock()
			local ok = pcall(function()
				path:ComputeAsync(rootPart.Position, goal)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				waypoints = path:GetWaypoints()
				waypointIndex = 2
			else
				waypoints = {}
				humanoid:MoveTo(goal) -- Estää jumiutumisen
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

	while hunting and generation == huntGeneration do
		local targetRoot, player = GetTarget()
		if targetRoot and os.clock() >= graceUntil then
			local distance = (targetRoot.Position - rootPart.Position).Magnitude
			local canSee = HasLineOfSight(targetRoot)
			if canSee then
				lastSeen = os.clock()
			end

			-- Decide between stalking and chasing
			if not chasing and ((canSee and distance < CHASE_RANGE) or distance < CLOSE_RANGE) then
				chasing = true
				Growl()
				nextGrowl = os.clock() + 8 + math.random() * 6
			elseif chasing and ArenaLayout.HUNTER_STALKS and not canSee and distance > CHASE_RANGE * 1.5 and os.clock() - lastSeen > LOSE_TRACK_SECONDS then
				chasing = false
				stalkGoal = nil
			end

			local fullSpeed = ChaseSpeed(player)
			if chasing then
				humanoid.WalkSpeed = fullSpeed
				if os.clock() > nextGrowl then
					Growl()
					nextGrowl = os.clock() + 8 + math.random() * 6
				end
				if canSee then
					-- Straight at the player when nothing is in the way
					waypoints = {}
					humanoid:MoveTo(targetRoot.Position)
				else
					FollowPathTo(targetRoot.Position, REPATH_SECONDS)
				end
			else
				-- Creep towards somewhere near the player, not exactly at them
				humanoid.WalkSpeed = fullSpeed * STALK_SPEED_FACTOR
				if not stalkGoal or (Vector3.new(stalkGoal.X - rootPart.Position.X, 0, stalkGoal.Z - rootPart.Position.Z)).Magnitude < 6 then
					local offset = Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))
					stalkGoal = targetRoot.Position + offset
					lastPathTime = 0
				end
				FollowPathTo(stalkGoal, 2)
			end
		else
			humanoid:MoveTo(rootPart.Position)
		end
		task.wait(STEP_SECONDS)
	end
	humanoid:MoveTo(rootPart.Position)
end

-- Heavy footsteps you can hear through the walls before you see it
local function FootstepLoop(generation)
	while hunting and generation == huntGeneration do
		local speed = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z).Magnitude
		if speed > 1 then
			SoundFx.Play("Footstep", {parent = rootPart, volume = 0.9, speed = 0.6 + math.random() * 0.1, maxDistance = 70})
			task.wait(math.clamp(5 / speed, 0.28, 0.8))
		else
			task.wait(0.2)
		end
	end
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
for _, part in hunter:GetDescendants() do
	if part:IsA("BasePart") then
		part.Touched:Connect(OnTouched)
	end
end

-- Hidden and idle until the horror
hunter.Parent = ServerStorage

ServerPhase.Changed:Connect(function(phase)
	if phase == "Horror" then
		-- Also runs again when the player retries the escape
		hunting = false
		huntGeneration += 1
		hunter.Parent = workspace
		PlaceAtSpawn()
		rootPart:SetNetworkOwner(nil) -- The server moves the Hunter
		graceUntil = os.clock() + ArenaLayout.HUNTER_LAIR_WAIT
		hunting = true
		print("The Hunter is loose...")
		task.spawn(HuntLoop, huntGeneration)
		task.spawn(FootstepLoop, huntGeneration)
	elseif phase == "TrueVictory" or phase == "GameOver" then
		hunting = false
		humanoid:MoveTo(rootPart.Position)
		print("The Hunter stops. The game is over.")
	elseif phase == "Menu" or phase == "RTS" then
		-- A new round from the start: back into hiding
		hunting = false
		huntGeneration += 1
		hunter.Parent = ServerStorage
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
