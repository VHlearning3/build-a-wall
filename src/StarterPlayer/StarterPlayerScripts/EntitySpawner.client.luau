local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local Phases = GameState.Phases

local spawnPoint = workspace:WaitForChild("EntitySpawn")
local coreHitEvent = ReplicatedStorage:WaitForChild("CoreHitEvent") -- Uusi signaali osumille

local isRTSMode = true
local entities = {}
local moveSpeed = 20
local entitySize = 5 -- Kasvatettu koko (oli 3)
local maxDistance = 250 -- Orbs farther than this from the spawn are destroyed
local maxLifetime = 60 -- Seconds before a stuck orb is destroyed

local orbsFolder = Instance.new("Folder")
orbsFolder.Name = "EnergyOrbs"
orbsFolder.Parent = workspace

-- Orbs only bounce off the player's pieces (and the maze border) and only score on the core;
-- everything else (other orbs, the frozen character, the hidden SpawnLocation) is ignored
local raycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = {
	workspace:WaitForChild("RTSWalls"),
	workspace:WaitForChild("EnemyCore"),
}
raycastParams.FilterType = Enum.RaycastFilterType.Include

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

task.spawn(function()
	while isRTSMode do
		SpawnEntity()
		task.wait(3)
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	if not isRTSMode then return end

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
				if result.Instance.Name == "EnemyCore" then
					coreHitEvent:Fire() -- Lähetetään viesti GameManagerille
					orb:Destroy() -- Tuhotaan pallo
					entities[i] = nil -- Poistetaan listalta
				else
					-- Muussa tapauksessa (seinät) kimpoaa normaalisti
					local reflectDir = dir - (2 * dir:Dot(result.Normal) * result.Normal)
					entityData.dir = Vector3.new(reflectDir.X, 0, reflectDir.Z).Unit
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

-- Orbs stop as soon as the RTS phase ends
GameState.Changed:Connect(function(newPhase)
	if newPhase == Phases.RTS then return end
	isRTSMode = false
	orbsFolder:ClearAllChildren()
	entities = {}
end)
