-- World look per phase: the concrete room with red ceiling alarms in the fake victory
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local Phases = GameState.Phases

local baseplate = workspace:WaitForChild("Baseplate")
local entitySpawn = workspace:WaitForChild("EntitySpawn")

local ROOM_HALF_EXTENT = 160 -- Same area as the RTS grid
local CEILING_Y = 10.5 -- Walls are 10 studs tall, so the ceiling sits right on top of them
local ALARM_SPACING = 32
local ALARM_HALF_EXTENT = 96
local ALARM_COLOR = Color3.fromRGB(255, 25, 15)
local ALARM_PULSE_SPEED = 4 -- Radians per second

local roomFolder = nil
local alarms = {} -- {part, light}
local alarmConnection = nil

local function MakeAlarm(position, castShadows)
	local lamp = Instance.new("Part")
	lamp.Name = "AlarmLight"
	lamp.Anchored = true
	lamp.CanCollide = false
	lamp.CanQuery = false
	lamp.CastShadow = false
	lamp.Material = Enum.Material.Neon
	lamp.Color = ALARM_COLOR
	lamp.Size = Vector3.new(2, 0.4, 2)
	lamp.Position = position
	lamp.Parent = roomFolder

	local light = Instance.new("PointLight")
	light.Color = ALARM_COLOR
	light.Range = 40
	light.Shadows = castShadows -- Only a few shadow-casting lights, they are expensive
	light.Parent = lamp

	table.insert(alarms, {part = lamp, light = light})
end

local function BuildRoom()
	roomFolder = Instance.new("Folder")
	roomFolder.Name = "ConcreteRoom"

	local ceiling = Instance.new("Part")
	ceiling.Name = "Ceiling"
	ceiling.Anchored = true
	ceiling.CanQuery = false
	ceiling.Material = Enum.Material.Concrete
	ceiling.Color = Color3.fromRGB(45, 45, 48)
	ceiling.Size = Vector3.new(ROOM_HALF_EXTENT * 2, 1, ROOM_HALF_EXTENT * 2)
	ceiling.Position = Vector3.new(0, CEILING_Y + 0.5, 0)
	ceiling.Parent = roomFolder

	-- One alarm right above the spawn pad, the rest on a grid
	local spawnPos = entitySpawn.Position
	MakeAlarm(Vector3.new(spawnPos.X, CEILING_Y - 0.2, spawnPos.Z), true)
	for x = -ALARM_HALF_EXTENT, ALARM_HALF_EXTENT, ALARM_SPACING do
		for z = -ALARM_HALF_EXTENT, ALARM_HALF_EXTENT, ALARM_SPACING do
			MakeAlarm(Vector3.new(x, CEILING_Y - 0.2, z), false)
		end
	end

	roomFolder.Parent = workspace
end

local function StartAlarms()
	alarmConnection = RunService.RenderStepped:Connect(function()
		local pulse = (math.sin(os.clock() * ALARM_PULSE_SPEED) + 1) / 2 -- 0..1
		for _, alarm in alarms do
			alarm.light.Brightness = 0.5 + pulse * 6
			alarm.part.Transparency = 0.6 - pulse * 0.6
		end
	end)
end

local function StopAlarms()
	if alarmConnection then
		alarmConnection:Disconnect()
		alarmConnection = nil
	end
	for _, alarm in alarms do
		alarm.light.Enabled = false
		alarm.part.Material = Enum.Material.SmoothPlastic
		alarm.part.Color = Color3.fromRGB(40, 10, 10)
		alarm.part.Transparency = 0
	end
end

GameState.OnPhase(Phases.FakeVictory, function()
	Lighting.Ambient = Color3.fromRGB(0, 0, 0)
	Lighting.OutdoorAmbient = Color3.fromRGB(12, 8, 8)
	Lighting.Brightness = 0
	Lighting.ClockTime = 0

	baseplate.Material = Enum.Material.Concrete
	baseplate.Color = Color3.fromRGB(55, 55, 58)

	-- The spawn pad stops glowing but stays a faint landmark
	entitySpawn.Material = Enum.Material.SmoothPlastic
	entitySpawn.Color = Color3.fromRGB(20, 40, 90)
	local letter = entitySpawn:FindFirstChild("Letter", true)
	if letter then
		letter.TextTransparency = 0.7
	end

	BuildRoom()
	StartAlarms()
end)

GameState.OnPhase(Phases.Horror, function()
	StopAlarms()

	-- Thick dark fog: you only see what the flashlight hits
	Lighting.OutdoorAmbient = Color3.fromRGB(4, 4, 6)
	Lighting.FogColor = Color3.fromRGB(6, 6, 8)
	Lighting.FogStart = 0
	Lighting.FogEnd = 45
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") -- Overrides the Fog settings when present
	if atmosphere then
		atmosphere.Density = 0.75
		atmosphere.Offset = 0
		atmosphere.Color = Color3.fromRGB(18, 18, 22)
		atmosphere.Decay = Color3.fromRGB(8, 8, 10)
		atmosphere.Glare = 0
		atmosphere.Haze = 3
	end
end)
