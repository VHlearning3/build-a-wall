-- First-person hand holding a flashlight, shown from the fake victory onwards
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
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

-- The flashlight flickers now and then in the horror, and a lot when the Hunter is close
local FLICKER_RANGE = 35
local flickerUntil = 0
RunService.Heartbeat:Connect(function()
	if not beam or not GameState.Is(Phases.Horror) then return end

	local now = os.clock()
	if now < flickerUntil then
		beam.Brightness = baseBrightness * (if math.random() < 0.5 then 0.05 else 0.4)
		return
	end
	beam.Brightness = baseBrightness

	local chance = 0.002 -- Rare random flicker
	local hunter = workspace:FindFirstChild("Hunter")
	local hunterRoot = hunter and hunter:FindFirstChild("HumanoidRootPart")
	if hunterRoot then
		local distance = (hunterRoot.Position - camera.CFrame.Position).Magnitude
		if distance < FLICKER_RANGE then
			chance += (1 - distance / FLICKER_RANGE) * 0.05
		end
	end
	if math.random() < chance then
		flickerUntil = now + 0.05 + math.random() * 0.25
	end
end)
