local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")

local TweenService = game:GetService("TweenService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))
local SoundFx = require(ReplicatedStorage:WaitForChild("SoundFx"))
local Phases = GameState.Phases

local spawnPoint = workspace:WaitForChild("EntitySpawn")
local coreHitEvent = ReplicatedStorage:WaitForChild("CoreHitEvent") -- Uusi signaali osumille

local entities = {}
local moveSpeed = 20
local entitySize = 5 -- Kasvatettu koko (oli 3)
local MENU_MAX_ORBS = 6 -- Just a few orbs behind the main menu
local maxLifetime = 150 -- Seconds before a stuck orb is destroyed (long levels need time)
local BOOST_SECONDS = 3 -- Bouncing off a Booster makes an orb fast for this long (a new bounce starts it again)
local BOOST_SPEED_FACTOR = 2
local ORB_COLOR = BrickColor.new("Cyan")
local BOOSTED_COLOR = BrickColor.new("Hot pink")

local orbsFolder = Instance.new("Folder")
orbsFolder.Name = "EnergyOrbs"
orbsFolder.Parent = workspace

-- Orbs only bounce off the player's pieces (and the maze border) and only score on the core;
-- everything else (other orbs, the frozen character, the hidden SpawnLocation) is ignored
local raycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = {
	workspace:WaitForChild("RTSWalls"),
	workspace:WaitForChild("Arena"),
	workspace:WaitForChild("EnemyCore"),
}
raycastParams.FilterType = Enum.RaycastFilterType.Include

-- A quick expanding flash where an orb bounces
local function Spark(position)
	local spark = Instance.new("Part")
	spark.Name = "Spark"
	spark.Shape = Enum.PartType.Ball
	spark.Anchored = true
	spark.CanCollide = false
	spark.CanQuery = false
	spark.CanTouch = false
	spark.CastShadow = false
	spark.Material = Enum.Material.Neon
	spark.Color = Color3.fromRGB(200, 255, 255)
	spark.Size = Vector3.new(1, 1, 1)
	spark.Position = position
	spark.Parent = orbsFolder
	local tween = TweenService:Create(spark, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(5, 5, 5),
		Transparency = 1,
	})
	tween.Completed:Once(function()
		spark:Destroy()
	end)
	tween:Play()
end

local function SpawnEntity()
	local orb = Instance.new("Part")
	orb.Name = "EnergyOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(entitySize, entitySize, entitySize)
	orb.BrickColor = ORB_COLOR
	orb.Material = Enum.Material.Neon
	orb.Position = spawnPoint.Position + Vector3.new(0, entitySize/2, 0)

	orb.Anchored = true
	orb.CanCollide = false
	orb.Parent = orbsFolder

	local randomAngle = math.rad(math.random(-45, 45))
	local direction = Vector3.new(math.sin(randomAngle), 0, math.cos(randomAngle)).Unit

	table.insert(entities, {model = orb, dir = direction, born = os.clock()})
end

-- Orbs fly in the main menu (as a backdrop) and in the RTS phase
local function IsActive()
	return GameState.Is(Phases.Menu) or GameState.Is(Phases.RTS)
end

task.spawn(function()
	while true do
		local menuFull = GameState.Is(Phases.Menu) and #orbsFolder:GetChildren() >= MENU_MAX_ORBS
		if IsActive() and not menuFull then
			SpawnEntity()
		end
		task.wait(2.5)
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	if not IsActive() then return end

	for i, entityData in pairs(entities) do
		local orb = entityData.model
		if orb and orb.Parent then
			-- Destroy orbs that got outside the arena (should not happen) or are stuck
			local outside = math.abs(orb.Position.X) > ArenaLayout.HALF_X + 10 or math.abs(orb.Position.Z) > ArenaLayout.HALF_Z + 10
			if outside or os.clock() - entityData.born > maxLifetime then
				orb:Destroy()
				entities[i] = nil
				continue
			end

			local dir = entityData.dir
			local boosted = entityData.boostUntil and os.clock() < entityData.boostUntil
			if not boosted and entityData.boostUntil then
				entityData.boostUntil = nil
				orb.BrickColor = ORB_COLOR
			end
			local stepDistance = moveSpeed * (if boosted then BOOST_SPEED_FACTOR else 1) * deltaTime
			local result = workspace:Raycast(orb.Position, dir * (stepDistance + (entitySize/2)), raycastParams)

			if result then
				-- TARKISTETAAN, ONKO OSUMA YTIMEEN
				if result.Instance.Name:match("^EnemyCore") then
					coreHitEvent:Fire(result.Instance) -- Lähetetään viesti GameManagerille
					orb:Destroy() -- Tuhotaan pallo
					entities[i] = nil -- Poistetaan listalta
				else
					-- Muussa tapauksessa (seinät) kimpoaa normaalisti
					local reflectDir = dir - (2 * dir:Dot(result.Normal) * result.Normal)
					entityData.dir = Vector3.new(reflectDir.X, 0, reflectDir.Z).Unit
					Spark(result.Position)
					if result.Instance.Name == "Booster" then
						entityData.boostUntil = os.clock() + BOOST_SECONDS
						orb.BrickColor = BOOSTED_COLOR
						SoundFx.Play("OrbBounce", {parent = orb, volume = 0.5, speed = 1.6})
					else
						SoundFx.Play("OrbBounce", {parent = orb, volume = 0.35, speed = 0.9 + math.random() * 0.4})
					end
				end
			else
				-- Liikutaan eteenpäin
				orb.Position = orb.Position + (dir * stepDistance)
			end
		else
			entities[i] = nil
		end
	end
end)

local function ClearOrbs()
	orbsFolder:ClearAllChildren()
	entities = {}
end

-- Every round starts with an empty arena and the first orb right away; orbs vanish when the building ends
GameState.Changed:Connect(function(newPhase)
	ClearOrbs()
	if newPhase == Phases.RTS then
		SpawnEntity()
	end
end)
GameState.Resetting:Connect(ClearOrbs)
workspace:GetAttributeChangedSignal("Level"):Connect(ClearOrbs)
