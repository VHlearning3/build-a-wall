local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local Phases = GameState.Phases

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))

-- Asetukset
local cameraSpeed = 60 -- Kuinka nopeasti RTS-kamera liikkuu
local MIN_HEIGHT, MAX_HEIGHT = 30, 140
local ZOOM_STEP = 10 -- Studs per mouse wheel notch
local RTS_START = Vector3.new(0, 110, 5) -- High enough to see both the spawn and the core
local rtsCameraPosition = RTS_START

local function ClampCamera()
	rtsCameraPosition = Vector3.new(
		math.clamp(rtsCameraPosition.X, -ArenaLayout.HALF_X, ArenaLayout.HALF_X),
		math.clamp(rtsCameraPosition.Y, MIN_HEIGHT, MAX_HEIGHT),
		math.clamp(rtsCameraPosition.Z, -ArenaLayout.HALF_Z, ArenaLayout.HALF_Z)
	)
end

-- World studs per screen pixel at the current height, for dragging with a finger
local function StudsPerPixel()
	local halfHeight = rtsCameraPosition.Y * math.tan(math.rad(camera.FieldOfView / 2))
	return halfHeight * 2 / camera.ViewportSize.Y
end

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if not GameState.Is(Phases.RTS) then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel and not gameProcessed then
		rtsCameraPosition -= Vector3.new(0, input.Position.Z * ZOOM_STEP, 0)
	elseif input.UserInputType == Enum.UserInputType.Touch and not gameProcessed then
		-- Drag to move: the ground follows the finger
		rtsCameraPosition -= Vector3.new(input.Delta.X, 0, input.Delta.Y) * StudsPerPixel()
	end
	ClampCamera()
end)

local lastPinchScale = 1
UserInputService.TouchPinch:Connect(function(_, scale, _, state, gameProcessed)
	if gameProcessed or not GameState.Is(Phases.RTS) then return end
	if state == Enum.UserInputState.Begin then
		lastPinchScale = 1
	end
	rtsCameraPosition = Vector3.new(rtsCameraPosition.X, rtsCameraPosition.Y * lastPinchScale / scale, rtsCameraPosition.Z)
	lastPinchScale = scale
	ClampCamera()
end)

-- The default movement controls (keyboard and the mobile thumbstick) are only on in the horror.
-- With the newer input action system there is no PlayerModule; then WalkSpeed 0 alone keeps the player still.
local controls = nil
task.spawn(function()
	local playerModuleScript = player:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")
	if not playerModuleScript then return end
	local ok, playerModule = pcall(require, playerModuleScript)
	if ok then
		controls = playerModule:GetControls()
		if not GameState.Is(Phases.Horror) then
			controls:Disable()
		end
	end
end)

-- Movement per phase: frozen during RTS and the fake victory, free in the horror
local function ApplyMovement(character)
	if controls then
		if GameState.Is(Phases.Horror) then
			controls:Enable()
		else
			controls:Disable()
		end
	end

	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	if GameState.Is(Phases.Horror) then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
	else
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
end

local function FollowCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end

	-- Look straight ahead instead of keeping the top-down RTS angle
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if head and root then
		camera.CFrame = CFrame.lookAt(head.Position, head.Position + root.CFrame.LookVector)
	end
end

-- Main menu: a slow sweep over the arena while the orbs bounce around
local function UpdateMenuCamera()
	camera.CameraType = Enum.CameraType.Scriptable
	local t = os.clock() * 0.08
	local eye = Vector3.new(math.sin(t) * 60, 75, math.cos(t) * 90)
	camera.CFrame = CFrame.lookAt(eye, Vector3.new(0, 0, 0))
end

-- Pääsilmukka RTS-kameran liikuttamiseen
local function UpdateRTSCamera(deltaTime)
	if GameState.Is(Phases.Menu) then
		UpdateMenuCamera()
		return
	end
	if not GameState.Is(Phases.RTS) then return end

	-- Pakotetaan kamera Scriptable-tilaan
	camera.CameraType = Enum.CameraType.Scriptable

	local moveVector = Vector3.new(0, 0, 0)

	-- Luetaan WASD-näppäimet
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector += Vector3.new(0, 0, -1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector += Vector3.new(0, 0, 1) end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector += Vector3.new(-1, 0, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector += Vector3.new(1, 0, 0) end

	if moveVector.Magnitude > 0 then
		moveVector = moveVector.Unit
	end

	-- Päivitetään kameran sijaintia (faster when zoomed out)
	rtsCameraPosition += moveVector * cameraSpeed * (rtsCameraPosition.Y / 80) * deltaTime
	ClampCamera()

	-- Asetetaan kameran sijainti ja käännetään sitä X-akselilla tarkalleen 90 astetta alaspäin
	camera.CFrame = CFrame.new(rtsCameraPosition) * CFrame.Angles(math.rad(-90), 0, 0)
end

RunService.RenderStepped:Connect(UpdateRTSCamera)

-- Fake victory: snap into first person, still frozen
GameState.OnPhase(Phases.FakeVictory, function()
	local character = player.Character or player.CharacterAdded:Wait()
	ApplyMovement(character)
	-- Deferred so GameManager has already teleported the player onto the spawn pad
	task.defer(FollowCharacter, character)
end)

-- Horror: first person and free to move
GameState.OnPhase(Phases.Horror, function()
	local character = player.Character or player.CharacterAdded:Wait()
	FollowCharacter(character)
	ApplyMovement(character)
	print("CONTAINMENT BREACH: Horror mode activated!")
end)

-- The game has ended: hold the last view and free the mouse so the end screen buttons can be clicked
local function FreezeViewForMenu()
	player.CameraMode = Enum.CameraMode.Classic
	local lastView = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = lastView
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end
GameState.OnPhase(Phases.TrueVictory, FreezeViewForMenu)
GameState.OnPhase(Phases.GameOver, FreezeViewForMenu)

-- Respawns keep the rules of the current phase
local function OnCharacter(character)
	ApplyMovement(character)
	if GameState.Is(Phases.FakeVictory) or GameState.Is(Phases.Horror) then
		FollowCharacter(character)
	end
end

player.CharacterAdded:Connect(OnCharacter)
if player.Character then
	task.spawn(OnCharacter, player.Character)
end

-- A new round from the start: back to the overhead camera
GameState.Resetting:Connect(function(target)
	if GameState.IsFullReset(target) then
		rtsCameraPosition = RTS_START
		player.CameraMode = Enum.CameraMode.Classic
		if controls then
			controls:Disable()
		end
	end
end)
