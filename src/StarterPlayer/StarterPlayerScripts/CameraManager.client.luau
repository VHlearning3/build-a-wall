local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local Phases = GameState.Phases

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Asetukset
local cameraSpeed = 40 -- Kuinka nopeasti RTS-kamera liikkuu
local rtsCameraPosition = Vector3.new(0, 40, 40) -- Kameran aloituspaikka

-- Movement per phase: frozen during RTS and the fake victory, free in the horror
local function ApplyMovement(character)
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
end

-- Pääsilmukka RTS-kameran liikuttamiseen
local function UpdateRTSCamera(deltaTime)
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

	-- Päivitetään kameran sijaintia
	rtsCameraPosition += moveVector * cameraSpeed * deltaTime

	-- Asetetaan kameran sijainti ja käännetään sitä X-akselilla tarkalleen 90 astetta alaspäin
	camera.CFrame = CFrame.new(rtsCameraPosition) * CFrame.Angles(math.rad(-90), 0, 0)
end

RunService.RenderStepped:Connect(UpdateRTSCamera)

-- Fake victory: snap into first person, still frozen
GameState.OnPhase(Phases.FakeVictory, function()
	local character = player.Character or player.CharacterAdded:Wait()
	FollowCharacter(character)
	ApplyMovement(character)
end)

-- Horror: first person and free to move
GameState.OnPhase(Phases.Horror, function()
	local character = player.Character or player.CharacterAdded:Wait()
	FollowCharacter(character)
	ApplyMovement(character)
	print("CONTAINMENT BREACH: Horror mode activated!")
end)

-- Respawns keep the rules of the current phase
local function OnCharacter(character)
	ApplyMovement(character)
	if not GameState.Is(Phases.RTS) then
		FollowCharacter(character)
	end
end

player.CharacterAdded:Connect(OnCharacter)
if player.Character then
	task.spawn(OnCharacter, player.Character)
end
