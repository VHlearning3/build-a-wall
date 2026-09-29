local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")

local spawnPoint = workspace:WaitForChild("EntitySpawn")
local horrorEvent = ReplicatedStorage:WaitForChild("HorrorModeEvent")
local coreHitEvent = ReplicatedStorage:WaitForChild("CoreHitEvent") -- Uusi signaali osumille

local isRTSMode = true
local entities = {}
local moveSpeed = 20 
local entitySize = 5 -- Kasvatettu koko (oli 3)

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
	orb.Parent = workspace

	local randomAngle = math.rad(math.random(-45, 45))
	local direction = Vector3.new(math.sin(randomAngle), 0, math.cos(randomAngle)).Unit

	table.insert(entities, {model = orb, dir = direction})
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
			local dir = entityData.dir

			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = {orb, spawnPoint}
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude

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
		end
	end
end)

horrorEvent.Event:Connect(function()
	isRTSMode = false
	for _, entityData in pairs(entities) do
		if entityData.model then
			entityData.model:Destroy()
		end
	end
	entities = {}
end)