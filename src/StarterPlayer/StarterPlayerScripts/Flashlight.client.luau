-- First-person hand holding a flashlight, shown from the fake victory onwards.
-- It flickers when the Hunter is close, and on levels with a BATTERY it runs down and needs pickups.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))
local SoundFx = require(ReplicatedStorage:WaitForChild("SoundFx"))
local Phases = GameState.Phases

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Where the hand sits relative to the camera (right, down, forward)
local HOLD_OFFSET = CFrame.new(0.75, -0.8, -1.5) * CFrame.Angles(math.rad(4), math.rad(6), 0)
local BOB_SPEED = 9
local BOB_AMOUNT = 0.05

-- Beam settings per phase
local BEAM = {
	[Phases.FakeVictory] = {range = 40, angle = 55, brightness = 2.5},
	[Phases.Horror] = {range = 45, angle = 28, brightness = 1.4}, -- Narrow and dim
	[Phases.TrueVictory] = {range = 45, angle = 28, brightness = 1.4},
}

local viewmodel = nil
local beam = nil
local renderConnection = nil

local function MakePart(name, size, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = viewmodel
	return part
end

local function SkinColor()
	local character = player.Character
	local bodyColors = character and character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		return bodyColors.RightArmColor3
	end
	return Color3.fromRGB(234, 184, 146)
end

local function BuildViewmodel()
	viewmodel = Instance.new("Model")
	viewmodel.Name = "FlashlightViewmodel"

	local arm = MakePart("Arm", Vector3.new(0.45, 0.45, 1.6), SkinColor(), Enum.Material.SmoothPlastic)
	local body = MakePart("Body", Vector3.new(0.28, 0.28, 1.0), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
	local head = MakePart("Head", Vector3.new(0.36, 0.36, 0.25), Color3.fromRGB(45, 45, 48), Enum.Material.Metal)
	local lens = MakePart("Lens", Vector3.new(0.3, 0.3, 0.05), Color3.fromRGB(255, 244, 214), Enum.Material.Neon)

	beam = Instance.new("SpotLight")
	beam.Name = "Beam"
	beam.Face = Enum.NormalId.Front
	beam.Color = Color3.fromRGB(255, 240, 210)
	beam.Shadows = true
	beam.Parent = lens

	-- Faint spill so the hand itself is visible in the dark
	local spill = Instance.new("PointLight")
	spill.Name = "Spill"
	spill.Color = Color3.fromRGB(255, 240, 210)
	spill.Range = 3
	spill.Brightness = 0.6
	spill.Parent = head

	viewmodel.PrimaryPart = body
	viewmodel.Parent = workspace -- Lights under the Camera do not render; this model only exists on this client

	-- Offsets of each part from the flashlight body
	local layout = {
		{arm, CFrame.new(0.05, -0.2, 0.75)},
		{body, CFrame.new()},
		{head, CFrame.new(0, 0, -0.62)},
		{lens, CFrame.new(0, 0, -0.76)},
	}

	renderConnection = RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local speed = root and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude or 0
		local bobScale = math.clamp(speed / 16, 0, 1)
		local t = os.clock() * BOB_SPEED
		local bob = CFrame.new(math.sin(t) * BOB_AMOUNT * bobScale, math.abs(math.cos(t)) * BOB_AMOUNT * bobScale, 0)

		local base = camera.CFrame * HOLD_OFFSET * bob
		for _, entry in layout do
			entry[1].CFrame = base * entry[2]
		end
	end)
end

local baseBrightness = 0

local function ApplyBeam(phase)
	local settings = BEAM[phase]
	if not settings then return end
	if not viewmodel then
		BuildViewmodel()
	end
	beam.Range = settings.range
	beam.Angle = settings.angle
	beam.Brightness = settings.brightness
	baseBrightness = settings.brightness
end

local function RemoveViewmodel()
	if viewmodel then
		renderConnection:Disconnect()
		viewmodel:Destroy()
		viewmodel = nil
		beam = nil
	end
end

GameState.Changed:Connect(function(newPhase)
	ApplyBeam(newPhase)
end)

-- Rebuild after a respawn so the arm keeps the right skin colour
player.CharacterAdded:Connect(function()
	if viewmodel then
		RemoveViewmodel()
		task.wait() -- Let BodyColors load
		ApplyBeam(GameState.Get())
	end
end)

-- A new round from the start puts the flashlight away
GameState.Resetting:Connect(function(target)
	if GameState.IsFullReset(target) then
		RemoveViewmodel()
	end
end)

-------------------------------------------------------------------------
-- BATTERY (levels with BATTERY): drains in the horror, glowing cells refill it
-------------------------------------------------------------------------
local PICKUP_REACH = 4
local battery = 1 -- 0..1
local pickupsFolder = nil

local batteryGui = Instance.new("ScreenGui")
batteryGui.Name = "BatteryGui"
batteryGui.ResetOnSpawn = false
batteryGui.IgnoreGuiInset = true
batteryGui.Enabled = false
batteryGui.Parent = player:WaitForChild("PlayerGui")

local batteryFrame = Instance.new("Frame")
batteryFrame.AnchorPoint = Vector2.new(0, 1)
batteryFrame.Position = UDim2.new(0, 24, 1, -24)
batteryFrame.Size = UDim2.fromOffset(200, 26)
batteryFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
batteryFrame.BackgroundTransparency = 0.3
batteryFrame.Parent = batteryGui
local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(200, 200, 200)
frameStroke.Thickness = 2
frameStroke.Parent = batteryFrame
local batteryFill = Instance.new("Frame")
batteryFill.BorderSizePixel = 0
batteryFill.Position = UDim2.fromOffset(3, 3)
batteryFill.Parent = batteryFrame
local batteryLabel = Instance.new("TextLabel")
batteryLabel.BackgroundTransparency = 1
batteryLabel.Size = UDim2.fromScale(1, 1)
batteryLabel.Text = "BATTERY"
batteryLabel.FontFace = Font.fromEnum(Enum.Font.GothamBlack)
batteryLabel.TextColor3 = Color3.new(1, 1, 1)
batteryLabel.TextStrokeTransparency = 0.4
batteryLabel.TextSize = 14
batteryLabel.ZIndex = 2
batteryLabel.Parent = batteryFrame

local function UpdateBatteryBar()
	batteryFill.Size = UDim2.new(battery, -6 * battery, 1, -6)
	batteryFill.BackgroundColor3 = if battery > 0.5 then Color3.fromRGB(120, 255, 120)
		elseif battery > 0.2 then Color3.fromRGB(255, 210, 60)
		else Color3.fromRGB(255, 60, 60)
end

local function RemovePickups()
	if pickupsFolder then
		pickupsFolder:Destroy()
		pickupsFolder = nil
	end
end

local function MakePickups(config)
	RemovePickups()
	pickupsFolder = Instance.new("Folder")
	pickupsFolder.Name = "BatteryPickups"
	for index, position in config.PICKUPS do
		local cell = Instance.new("Part")
		cell.Name = "Battery" .. index
		cell.Anchored = true
		cell.CanCollide = false
		cell.CanQuery = false
		cell.CanTouch = false
		cell.Material = Enum.Material.Neon
		cell.Color = Color3.fromRGB(255, 220, 60)
		cell.Size = Vector3.new(0.8, 1.6, 0.8)
		cell.Position = position + Vector3.new(0, 2, 0)
		cell.Parent = pickupsFolder
		local glow = Instance.new("PointLight")
		glow.Color = cell.Color
		glow.Range = 8
		glow.Brightness = 1.5
		glow.Parent = cell
	end
	pickupsFolder.Parent = workspace
end

GameState.OnPhase(Phases.Horror, function()
	local config = ArenaLayout.BATTERY
	battery = 1
	batteryGui.Enabled = config ~= nil
	if config then
		MakePickups(config) -- Also fresh ones when the escape is retried
		UpdateBatteryBar()
	else
		RemovePickups()
	end
end)

GameState.Changed:Connect(function(newPhase)
	if newPhase ~= Phases.Horror then
		batteryGui.Enabled = false
	end
end)

GameState.Resetting:Connect(function(target)
	if GameState.IsFullReset(target) then
		RemovePickups()
	end
end)

-------------------------------------------------------------------------
-- BEAM each frame: battery, flicker when the Hunter is close
-------------------------------------------------------------------------
local FLICKER_RANGE = 35
local flickerUntil = 0
RunService.Heartbeat:Connect(function(deltaTime)
	if not beam or not GameState.Is(Phases.Horror) then return end
	local now = os.clock()

	-- Battery drain and pickups
	local config = ArenaLayout.BATTERY
	local power = 1
	if config then
		battery = math.max(battery - deltaTime / config.DRAIN_SECONDS, 0)
		if pickupsFolder then
			local here = camera.CFrame.Position
			for _, cell in pickupsFolder:GetChildren() do
				cell.CFrame = cell.CFrame * CFrame.Angles(0, deltaTime * 2, 0)
				if (Vector3.new(cell.Position.X - here.X, 0, cell.Position.Z - here.Z)).Magnitude < PICKUP_REACH then
					battery = math.min(battery + config.REFILL, 1)
					SoundFx.Play("UiClick", {volume = 0.6, speed = 1.4})
					cell:Destroy()
				end
			end
		end
		UpdateBatteryBar()
		power = if battery <= 0 then 0.04 else 0.25 + battery * 0.75
		beam.Range = if battery <= 0 then 8 else 20 + battery * 25
	end

	if now < flickerUntil then
		beam.Brightness = baseBrightness * power * (if math.random() < 0.5 then 0.05 else 0.4)
		return
	end
	beam.Brightness = baseBrightness * power

	local chance = 0.002 -- Rare random flicker
	if config and battery < 0.2 then
		chance += 0.03 -- An almost empty battery flickers a lot
	end
	local hunterRoot, distance = ArenaLayout.NearestHunter(camera.CFrame.Position)
	if hunterRoot and distance < FLICKER_RANGE then
		chance += (1 - distance / FLICKER_RANGE) * 0.05
	end
	if math.random() < chance then
		flickerUntil = now + 0.05 + math.random() * 0.25
	end
end)
