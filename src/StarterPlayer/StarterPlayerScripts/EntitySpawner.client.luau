local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")

local TweenService = game:GetService("TweenService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local SoundFx = require(ReplicatedStorage:WaitForChild("SoundFx"))
local Phases = GameState.Phases

local spawnPoint = workspace:WaitForChild("EntitySpawn")
local coreHitEvent = ReplicatedStorage:WaitForChild("CoreHitEvent") -- Uusi signaali osumille

local entities = {}
local moveSpeed = 20
local entitySize = 5 -- Kasvatettu koko (oli 3)
local maxDistance = 250 -- Orbs farther than this from the spawn are destroyed
local maxLifetime = 90 -- Seconds before a stuck orb is destroyed

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
	orb.BrickColor = BrickColor.new("Cyan")
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
		if IsActive() then
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
			-- Destroy escaped or stuck orbs
			local distance = (orb.Position - spawnPoint.Position).Magnitude
			if distance > maxDistance or os.clock() - entityData.born > maxLifetime then
				orb:Destroy()
				entities[i] = nil
				continue
			end

			local dir = entityData.dir
			local stepDistance = moveSpeed * deltaTime
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
					SoundFx.Play("OrbBounce", {parent = orb, volume = 0.35, speed = 0.9 + math.random() * 0.4})
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

-- Orbs vanish when the building ends, and a new round starts with a clean arena
GameState.Changed:Connect(function(newPhase, oldPhase)
	if newPhase ~= Phases.RTS or oldPhase ~= Phases.Menu then
		ClearOrbs()
	end
end)
GameState.Resetting:Connect(ClearOrbs)
