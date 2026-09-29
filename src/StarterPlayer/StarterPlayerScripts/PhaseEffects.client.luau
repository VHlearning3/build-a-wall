-- World look per phase: the concrete room with red ceiling alarms in the fake victory,
-- thick fog in the horror that thins near the escape zone, and the fog lifting at the true victory.
-- A new round puts everything back the way it was at the start.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local Phases = GameState.Phases

local TweenService = game:GetService("TweenService")

local baseplate = workspace:WaitForChild("Baseplate")
local entitySpawn = workspace:WaitForChild("EntitySpawn")
local core = workspace:WaitForChild("EnemyCore")
local player = game:GetService("Players").LocalPlayer

local HORROR_FOG_DENSITY = 0.75
local CLEAR_FOG_DENSITY = 0.3 -- Right next to the escape zone
local FOG_CLEAR_START = 45 -- Fog starts thinning this far from the escape zone
local FOG_CLEAR_END = 10 -- ...and is thinnest this close

local ROOM_HALF_EXTENT = 160 -- Same area as the RTS grid
local CEILING_Y = 10.5 -- Walls are 10 studs tall, so the ceiling sits right on top of them
local ALARM_SPACING = 32
local ALARM_HALF_EXTENT = 96
local ALARM_COLOR = Color3.fromRGB(255, 25, 15)
local ALARM_PULSE_SPEED = 4 -- Radians per second

local roomFolder = nil
local alarms = {} -- {part, light}
local alarmConnection = nil
local fogConnection = nil
local liftTweens = {}

-- Remember how the world looked at the start, so a new round can put it back
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") -- Overrides the Fog settings when present
local letter = entitySpawn:FindFirstChild("Letter", true)
local startLook = {
	lighting = {
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness,
		ClockTime = Lighting.ClockTime,
		FogColor = Lighting.FogColor,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
	},
	atmosphere = atmosphere and {
		Density = atmosphere.Density,
		Offset = atmosphere.Offset,
		Color = atmosphere.Color,
		Decay = atmosphere.Decay,
		Glare = atmosphere.Glare,
		Haze = atmosphere.Haze,
	},
	baseplate = {Material = baseplate.Material, Color = baseplate.Color},
	spawnPad = {Material = entitySpawn.Material, Color = entitySpawn.Color},
	letterTransparency = letter and letter.TextTransparency,
}

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
	if atmosphere then
		atmosphere.Density = 0.75
		atmosphere.Offset = 0
		atmosphere.Color = Color3.fromRGB(18, 18, 22)
		atmosphere.Decay = Color3.fromRGB(8, 8, 10)
		atmosphere.Glare = 0
		atmosphere.Haze = 3
	end

	-- The fog thins as the player gets close to the escape zone
	local escapeCenter = Vector3.new(core.Position.X, 0, core.Position.Z)
	if fogConnection then
		fogConnection:Disconnect()
	end
	fogConnection = RunService.RenderStepped:Connect(function()
		if not GameState.Is(Phases.Horror) then return end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not atmosphere then return end

		local distance = (Vector3.new(root.Position.X, 0, root.Position.Z) - escapeCenter).Magnitude
		local closeness = math.clamp((FOG_CLEAR_START - distance) / (FOG_CLEAR_START - FOG_CLEAR_END), 0, 1)
		atmosphere.Density = HORROR_FOG_DENSITY + (CLEAR_FOG_DENSITY - HORROR_FOG_DENSITY) * closeness
	end)
end)

-- True victory: the fog lifts and a cold dawn light comes up
GameState.OnPhase(Phases.TrueVictory, function()
	local liftInfo = TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	if atmosphere then
		table.insert(liftTweens, TweenService:Create(atmosphere, liftInfo, {Density = 0.1, Haze = 0.5}))
	end
	table.insert(liftTweens, TweenService:Create(Lighting, liftInfo, {
		OutdoorAmbient = Color3.fromRGB(70, 85, 75),
		Ambient = Color3.fromRGB(35, 45, 40),
		FogEnd = 400,
	}))
	for _, tween in liftTweens do
		tween:Play()
	end
end)

-- New round from the start: back to the bright neon arena
GameState.Resetting:Connect(function(target)
	for _, tween in liftTweens do
		tween:Cancel()
	end
	table.clear(liftTweens)
	if fogConnection then
		fogConnection:Disconnect()
		fogConnection = nil
	end
	if not GameState.IsFullReset(target) then return end

	if alarmConnection then
		alarmConnection:Disconnect()
		alarmConnection = nil
	end
	table.clear(alarms)
	if roomFolder then
		roomFolder:Destroy()
		roomFolder = nil
	end

	for property, value in startLook.lighting do
		Lighting[property] = value
	end
	if atmosphere and startLook.atmosphere then
		for property, value in startLook.atmosphere do
			atmosphere[property] = value
		end
	end
	baseplate.Material = startLook.baseplate.Material
	baseplate.Color = startLook.baseplate.Color
	entitySpawn.Material = startLook.spawnPad.Material
	entitySpawn.Color = startLook.spawnPad.Color
	if letter then
		letter.TextTransparency = startLook.letterTransparency
	end
end)
