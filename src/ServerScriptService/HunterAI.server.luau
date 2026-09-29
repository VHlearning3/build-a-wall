-- The Hunters: hidden until the horror phase, then hunt the player through the maze on the server.
-- Each level lists its Hunters in HUNTERS (default {"chaser"}):
--   chaser  waits in the lair behind the escape, creeps towards the player, chases on sight
--   guard   patrols around the escape zone and only chases players who come close
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerPhase = require(ServerScriptService:WaitForChild("ServerPhase"))
local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))
local SoundFx = require(ReplicatedStorage:WaitForChild("SoundFx"))

local BASE_SPEED = 11 -- The player walks at 16, so running away works
local SPEED_PER_WIN = 0.8 -- Each escape makes the next Hunter a little faster
local MAX_SPEED = 15
local STALK_SPEED_FACTOR = 0.55 -- Slow creeping while it has not found the player yet
local CHASE_RANGE = 28 -- Starts chasing when it sees the player this close
local CLOSE_RANGE = 14 -- ...or when the player is this close, seen or not
local LOSE_TRACK_SECONDS = 5 -- Goes back to stalking after not seeing the player this long
local GUARD_RADIUS = 18 -- A guard patrols this far around the escape zone
local GUARD_LEASH = 45 -- ...and gives up on players this far from the escape zone
local REPATH_SECONDS = 0.5
local STEP_SECONDS = 0.1
local WAYPOINT_REACHED = 3
local RESPAWN_GRACE_SECONDS = 3
local LAIR_DISTANCE_BEHIND_ESCAPE = 14

local EYE_COLOR = Color3.fromRGB(255, 0, 0)

-- The rig in Workspace is the template for every Hunter
local template = workspace:WaitForChild("Hunter")
template.Parent = ServerStorage
template.Name = "HunterTemplate"

local hunting = false
local huntGeneration = 0 -- Bumped every hunt so loops from an earlier round stop
local hunters = {} -- Hunter objects that exist right now

-------------------------------------------------------------------------
-- SHARED HELPERS
-------------------------------------------------------------------------
local function Flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

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

local function ChaseSpeed(player)
	local wins = player and player:GetAttribute("Wins") or 0
	return math.min(BASE_SPEED + wins * SPEED_PER_WIN, MAX_SPEED)
end

local function ClampToArena(position)
	local margin = 4
	return Vector3.new(
		math.clamp(position.X, -ArenaLayout.HALF_X + margin, ArenaLayout.HALF_X - margin),
		3,
		math.clamp(position.Z, -ArenaLayout.HALF_Z + margin, ArenaLayout.HALF_Z - margin)
	)
end

-- The chaser's lair: just beyond the escape zone, seen from the spawn pad
local function LairCentre()
	local escape = ArenaLayout.ESCAPE_POSITION
	local away = Flat(escape - ArenaLayout.SPAWN_POSITION)
	away = if away.Magnitude > 0 then away.Unit else Vector3.new(0, 0, -1)
	return ClampToArena(escape + away * LAIR_DISTANCE_BEHIND_ESCAPE)
end

-- The guard stands at the side of the escape zone
local function GuardPost()
	local escape = ArenaLayout.ESCAPE_POSITION
	local side = Flat(escape - ArenaLayout.SPAWN_POSITION)
	side = if side.Magnitude > 0 then Vector3.new(-side.Z, 0, side.X).Unit else Vector3.new(1, 0, 0)
	return ClampToArena(escape + side * 10)
end

-------------------------------------------------------------------------
-- ONE HUNTER
-------------------------------------------------------------------------
local function MakeHunter(name, role)
	local model = template:Clone()
	model.Name = name
	local humanoid = model:WaitForChild("Humanoid")
	local rootPart = model:WaitForChild("HumanoidRootPart")
	local hunter = {model = model, role = role, graceUntil = 0}

	-- Look: pitch black body with glowing red eyes
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color = Color3.fromRGB(8, 8, 10)
			part.Material = Enum.Material.SmoothPlastic
			part.Reflectance = 0
		elseif part:IsA("Decal") or part:IsA("FaceControls") then
			part:Destroy()
		end
	end
	local head = model:WaitForChild("Head")
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
		eye.Parent = model
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

	-- Animation: the rig's Animate LocalScript never runs in Workspace, so play walk/idle here
	local animate = model:FindFirstChild("Animate")
	local function AnimationId(stateName)
		local state = animate and animate:FindFirstChild(stateName)
		local animation = state and state:FindFirstChildOfClass("Animation")
		return animation and animation.AnimationId
	end
	local runId = AnimationId("run") or AnimationId("walk")
	local idleId = AnimationId("idle")
	if animate then
		animate:Destroy()
	end
	model.Parent = workspace -- Animations need the model in the world
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
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

	-- Kill on touch
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				if not hunting or os.clock() < hunter.graceUntil then return end
				local character = hit.Parent
				local player = character and Players:GetPlayerFromCharacter(character)
				if not player then return end
				local targetHumanoid = character:FindFirstChildOfClass("Humanoid")
				if targetHumanoid and targetHumanoid.Health > 0 then
					targetHumanoid.Health = 0 -- Pelaaja kuolee
					print("The Hunter caught " .. player.Name .. "!")
				end
			end)
		end
	end

	function hunter.Home()
		return if role == "guard" then GuardPost() else LairCentre()
	end

	-- A free spot near home
	function hunter.PlaceAtHome()
		local centre = hunter.Home()
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = {model, workspace:FindFirstChild("Baseplate")}
		local spot = centre
		for ring = 0, 6 do
			local found = false
			for angle = 0, 315, 45 do
				local offset = if ring > 0 then CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(Vector3.new(0, 0, ring * 6)) else Vector3.zero
				local candidate = centre + offset
				if #workspace:GetPartBoundsInBox(CFrame.new(candidate), Vector3.new(4, 5, 4), overlap) == 0 then
					spot = candidate
					found = true
					break
				end
			end
			if found then break end
		end
		local spawnPad = ArenaLayout.SPAWN_POSITION
		model:PivotTo(CFrame.lookAt(spot, Vector3.new(spawnPad.X, spot.Y, spawnPad.Z)))
		humanoid:MoveTo(spot)
	end

	function hunter.HasLineOfSight(targetRoot)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {model, targetRoot.Parent}
		return workspace:Raycast(rootPart.Position, targetRoot.Position - rootPart.Position, params) == nil
	end

	local function Growl()
		SoundFx.Play("Growl", {parent = head, volume = 1, speed = 0.75 + math.random() * 0.15, maxDistance = 90})
	end

	function hunter.Hunt(generation)
		local path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = false, -- Ei anneta sen hyppiä muurien yli
			WaypointSpacing = 4,
		})
		local waypoints = {}
		local waypointIndex = 0
		local lastPathTime = 0
		local chasing = role == "chaser" and not ArenaLayout.HUNTER_STALKS -- Some levels skip the creeping
		local lastSeen = 0
		local wanderGoal = nil
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
				if Flat(waypoint.Position - rootPart.Position).Magnitude < WAYPOINT_REACHED then
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
			if targetRoot and os.clock() >= hunter.graceUntil then
				local distance = (targetRoot.Position - rootPart.Position).Magnitude
				local canSee = hunter.HasLineOfSight(targetRoot)
				if canSee then
					lastSeen = os.clock()
				end
				local home = hunter.Home()
				local playerFromHome = Flat(targetRoot.Position - home).Magnitude

				-- Decide between wandering and chasing
				if not chasing and ((canSee and distance < CHASE_RANGE) or distance < CLOSE_RANGE)
					and (role ~= "guard" or playerFromHome < GUARD_LEASH) then
					chasing = true
					Growl()
					nextGrowl = os.clock() + 8 + math.random() * 6
				elseif chasing and role == "guard" and playerFromHome > GUARD_LEASH then
					chasing = false -- A guard never leaves its post for long
					wanderGoal = nil
				elseif chasing and role == "chaser" and ArenaLayout.HUNTER_STALKS and not canSee
					and distance > CHASE_RANGE * 1.5 and os.clock() - lastSeen > LOSE_TRACK_SECONDS then
					chasing = false
					wanderGoal = nil
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
					-- Chaser: creep towards somewhere near the player. Guard: patrol around its post.
					humanoid.WalkSpeed = fullSpeed * STALK_SPEED_FACTOR
					if not wanderGoal or Flat(wanderGoal - rootPart.Position).Magnitude < 6 then
						local around = if role == "guard" then home else targetRoot.Position
						local reach = if role == "guard" then GUARD_RADIUS else 15
						wanderGoal = ClampToArena(around + Vector3.new(math.random(-reach, reach), 0, math.random(-reach, reach)))
						lastPathTime = 0
					end
					FollowPathTo(wanderGoal, 2)
				end
			else
				humanoid:MoveTo(rootPart.Position)
			end
			task.wait(STEP_SECONDS)
		end
		humanoid:MoveTo(rootPart.Position)
	end

	-- Heavy footsteps you can hear through the walls before you see it
	function hunter.Footsteps(generation)
		while hunting and generation == huntGeneration do
			local speed = Flat(rootPart.AssemblyLinearVelocity).Magnitude
			if speed > 1 then
				SoundFx.Play("Footstep", {parent = rootPart, volume = 0.9, speed = 0.6 + math.random() * 0.1, maxDistance = 70})
				task.wait(math.clamp(5 / speed, 0.28, 0.8))
			else
				task.wait(0.2)
			end
		end
	end

	function hunter.Start(generation, waitSeconds)
		hunter.PlaceAtHome()
		rootPart:SetNetworkOwner(nil) -- The server moves the Hunter
		hunter.graceUntil = os.clock() + waitSeconds
		task.spawn(hunter.Hunt, generation)
		task.spawn(hunter.Footsteps, generation)
	end

	function hunter.Stop()
		humanoid:MoveTo(rootPart.Position)
	end

	return hunter
end

local function RemoveHunters()
	for _, hunter in hunters do
		hunter.model:Destroy()
	end
	table.clear(hunters)
end

-------------------------------------------------------------------------
-- PHASES
-------------------------------------------------------------------------
ServerPhase.Changed:Connect(function(phase)
	if phase == "Horror" then
		-- Also runs again when the player retries the escape: fresh Hunters
		hunting = false
		huntGeneration += 1
		RemoveHunters()
		for index, role in ArenaLayout.HUNTERS or {"chaser"} do
			table.insert(hunters, MakeHunter(if index == 1 then "Hunter" else "Hunter" .. index, role))
		end
		hunting = true
		for _, hunter in hunters do
			-- The guard is awake from the start; the chaser waits in its lair first
			hunter.Start(huntGeneration, if hunter.role == "guard" then 1 else ArenaLayout.HUNTER_LAIR_WAIT)
		end
		print("The Hunter is loose...")
	elseif phase == "TrueVictory" or phase == "GameOver" then
		hunting = false
		for _, hunter in hunters do
			hunter.Stop()
		end
		print("The Hunter stops. The game is over.")
	elseif phase == "Menu" or phase == "RTS" then
		-- A new round from the start: no Hunters
		hunting = false
		huntGeneration += 1
		RemoveHunters()
	end
end)

-- No spawn camping: after a death every Hunter goes back home and waits a moment
local function WatchPlayer(player)
	player.CharacterAdded:Connect(function()
		if hunting then
			for _, hunter in hunters do
				hunter.graceUntil = os.clock() + RESPAWN_GRACE_SECONDS
				hunter.PlaceAtHome()
			end
		end
	end)
end
Players.PlayerAdded:Connect(WatchPlayer)
for _, player in Players:GetPlayers() do
	WatchPlayer(player)
end
