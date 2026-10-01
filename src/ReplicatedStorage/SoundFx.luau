-- All sounds in one place. Only Roblox-licensed music (APM), Pro Sound Effects and built-in Roblox
-- sounds, so everything plays in the published game. Swap an id here to change a sound everywhere.
local SoundService = game:GetService("SoundService")

local SoundFx = {}

SoundFx.Ids = {
	-- Music
	RtsMusic = "rbxassetid://1836320928", -- APM "Energy Consumption"
	HorrorMusic = "rbxassetid://1843867314", -- APM "Tension Repeat Drones 29"
	-- Fake victory
	Siren = "rbxassetid://9119661709", -- Pro Sound Effects submarine alarm
	Glitch = "rbxassetid://9119582410", -- Pro Sound Effects static glitch
	-- Horror
	Growl = "rbxassetid://9113980319", -- Pro Sound Effects creature growl
	Heartbeat = "rbxassetid://139481207162657",
	Footstep = "rbxassetid://87061775498714",
	-- Game feel (built-in Roblox sounds)
	PiecePlaced = "rbxassetid://16480580213", -- Roblox pinball 8-bit blip: short arcade sound
	PieceRemoved = "rbxasset://sounds/switch.wav",
	Refused = "rbxasset://sounds/button.wav",
	CoreHit = "rbxasset://sounds/impact_explosion_03.mp3",
	UiClick = "rbxasset://sounds/clickfast.wav",
}

-- Plays a one-shot sound. With options.parent (a part) it is 3D, otherwise it plays flat.
function SoundFx.Play(name, options)
	options = options or {}
	local sound = Instance.new("Sound")
	local id = SoundFx.Ids[name]
	sound.SoundId = if type(id) == "table" then id[math.random(#id)] else id
	sound.Volume = options.volume or 0.5
	sound.PlaybackSpeed = options.speed or 1
	if options.parent then
		sound.RollOffMaxDistance = options.maxDistance or 120
		sound.Parent = options.parent
	else
		sound.Parent = SoundService
	end
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(15, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
	return sound
end

-- Creates a looping sound that the caller starts, stops and fades
function SoundFx.Loop(name, parent, volume)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = SoundFx.Ids[name]
	sound.Looped = true
	sound.Volume = volume or 0.5
	sound.Parent = parent or SoundService
	return sound
end

return SoundFx
