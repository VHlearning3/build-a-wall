-- Shared game phase for all client scripts: RTS -> FakeVictory -> Horror -> TrueVictory
local GameState = {}

GameState.Phases = {
	RTS = "RTS",
	FakeVictory = "FakeVictory",
	Horror = "Horror",
	TrueVictory = "TrueVictory",
}

local current = GameState.Phases.RTS
local changed = Instance.new("BindableEvent")

-- Fires with (newPhase, oldPhase)
GameState.Changed = changed.Event

function GameState.Get()
	return current
end

function GameState.Is(phase)
	return current == phase
end

function GameState.Set(phase)
	assert(GameState.Phases[phase], "Unknown phase: " .. tostring(phase))
	if phase == current then return end

	local old = current
	current = phase
	print("[GameState] " .. old .. " -> " .. phase)
	changed:Fire(phase, old)
end

-- Runs callback every time the game enters the phase (right away if it is already active)
function GameState.OnPhase(phase, callback)
	assert(GameState.Phases[phase], "Unknown phase: " .. tostring(phase))
	if current == phase then
		task.spawn(callback)
	end
	return GameState.Changed:Connect(function(newPhase)
		if newPhase == phase then
			callback()
		end
	end)
end

return GameState
