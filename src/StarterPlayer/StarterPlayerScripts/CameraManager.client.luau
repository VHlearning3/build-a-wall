local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Asetukset
local isRTSMode = true
local cameraSpeed = 40 -- Kuinka nopeasti RTS-kamera liikkuu
local rtsCameraPosition = Vector3.new(0, 40, 40) -- Kameran aloituspaikka

-- Odotetaan, että hahmo on olemassa, jotta voimme pysäyttää sen
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- Pysäytetään hahmo RTS-vaiheen ajaksi asettamalla nopeudet nollaan
humanoid.WalkSpeed = 0
humanoid.JumpPower = 0

-- Pääsilmukka RTS-kameran liikuttamiseen
local function UpdateRTSCamera(deltaTime)
	if not isRTSMode then return end

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

-- Sidotaan kameran päivitys jokaiseen renderöityvään frameen
RunService.RenderStepped:Connect(UpdateRTSCamera)

-------------------------------------------------------------------------
-- TILA VAIHTUU KAUHUKSI
-------------------------------------------------------------------------

local function TriggerHorrorMode()
	if not isRTSMode then return end
	isRTSMode = false

	-- 1. Palautetaan hahmolle normaali liikkumisnopeus
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50

	-- 2. Pakotetaan pelaaja ensimmäiseen persoonaan (First-Person)
	player.CameraMode = Enum.CameraMode.LockFirstPerson

	-- 3. Palautetaan kamera seuraamaan pelaajan hahmoa
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid

	print("CONTAINMENT BREACH: Horror mode aktivoitu!")
end

-------------------------------------------------------------------------
-- TESTAUS (Paina F-näppäintä vaihtaaksesi tilaa)
-------------------------------------------------------------------------

-- Kuunnellaan pelinjohtajan lähettämää signaalia
game.ReplicatedStorage:WaitForChild("HorrorModeEvent").Event:Connect(function()
	TriggerHorrorMode()
end)