-- Music and ambience per phase: upbeat building music, a glitch and siren at the fake victory,
-- drone music and a heartbeat that speeds up as the Hunter gets close in the horror
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local SoundFx = require(ReplicatedStorage:WaitForChild("SoundFx"))
local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))
local Phases = GameState.Phases

local player = Players.LocalPlayer

local RTS_VOLUME = 0.35
local HORROR_VOLUME = 0.45
local HEARTBEAT_FAR = 60 -- Studs: silent heartbeat beyond this
local HEARTBEAT_NEAR = 10 -- Studs: loudest and fastest heartbeat

local rtsMusic = SoundFx.Loop("RtsMusic", nil, RTS_VOLUME)
local horrorMusic = SoundFx.Loop("HorrorMusic", nil, 0)
local siren = SoundFx.Loop("Siren", nil, 0.45)
local heartbeat = SoundFx.Loop("Heartbeat", nil, 0)

local function Fade(sound, volume, seconds)
	TweenService:Create(sound, TweenInfo.new(seconds), {Volume = volume}):Play()
end

rtsMusic:Play()

GameState.OnPhase(Phases.FakeVictory, function()
	rtsMusic:Stop() -- Hard cut: the music dying is part of the twist
	SoundFx.Play("Glitch", {volume = 0.8})
	task.delay(0.6, function()
		if GameState.Is(Phases.FakeVictory) then
			siren:Play()
		end
	end)
end)

local heartbeatConnection = nil

GameState.OnPhase(Phases.Horror, function()
	Fade(siren, 0, 1.5)
	task.delay(1.5, function()
		siren:Stop()
	end)
	rtsMusic:Stop()
	horrorMusic:Play()
	Fade(horrorMusic, HORROR_VOLUME, 4)

	heartbeat:Play()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
	end
	heartbeatConnection = RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hunterRoot, distance = if root then ArenaLayout.NearestHunter(root.Position) else nil
		if not root or not hunterRoot then
			heartbeat.Volume = 0
			return
		end
		local fear = math.clamp((HEARTBEAT_FAR - distance) / (HEARTBEAT_FAR - HEARTBEAT_NEAR), 0, 1)
		heartbeat.Volume = fear * 0.9
		heartbeat.PlaybackSpeed = 0.85 + fear * 0.7
		horrorMusic.Volume = HORROR_VOLUME * (1 - fear * 0.5) -- The heartbeat takes over when it is close
	end)
end)

local function EndHorrorAudio()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	Fade(heartbeat, 0, 1)
	Fade(horrorMusic, 0, 3)
	Fade(siren, 0, 0.5)
end

local roundToken = 0

GameState.OnPhase(Phases.TrueVictory, function()
	EndHorrorAudio()
	-- The building music comes back, slower and quieter: calm after the storm
	local token = roundToken
	task.delay(2, function()
		if token ~= roundToken then return end
		rtsMusic.PlaybackSpeed = 0.85
		rtsMusic.Volume = 0
		rtsMusic:Play()
		Fade(rtsMusic, 0.25, 4)
	end)
end)

GameState.OnPhase(Phases.GameOver, function()
	EndHorrorAudio()
	SoundFx.Play("Growl", {volume = 0.9, speed = 0.8})
end)

-- Any reset: stop the horror sounds; a new round from the start brings the building music back
GameState.Resetting:Connect(function(target)
	roundToken += 1
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	for _, sound in {horrorMusic, siren, heartbeat} do
		sound:Stop()
		sound.Volume = 0
	end
	siren.Volume = 0.45
	if GameState.IsFullReset(target) then
		rtsMusic.PlaybackSpeed = 1
		rtsMusic.Volume = RTS_VOLUME
		if not rtsMusic.IsPlaying then
			rtsMusic:Play()
		end
	else
		rtsMusic:Stop()
	end
end)
