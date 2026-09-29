-- Shared game phase for all client scripts:
-- Menu -> RTS -> FakeVictory -> Horror -> TrueVictory (or GameOver)
local GameState = {}

GameState.Phases = {
	Menu = "Menu", -- Main menu, orbs bounce around behind it
	RTS = "RTS",
	FakeVictory = "FakeVictory",
	Horror = "Horror",
	TrueVictory = "TrueVictory",
	GameOver = "GameOver", -- Out of lives in the horror
}

-- Tiny signal that calls listeners in the order they connected
local function NewSignal(runInOwnThread)
	local listeners = {}
	local signal = {}
	function signal:Connect(callback)
		local entry = {callback = callback}
		table.insert(listeners, entry)
		return {
			Disconnect = function()
				local index = table.find(listeners, entry)
				if index then
					table.remove(listeners, index)
				end
			end,
		}
	end
	function signal:Fire(...)
		for _, entry in table.clone(listeners) do
			if runInOwnThread then
				task.spawn(entry.callback, ...)
			else
				entry.callback(...)
			end
		end
	end
	return signal
end

local current = GameState.Phases.Menu

-- Fires with (newPhase, oldPhase). Each listener runs in its own thread, so it may wait.
GameState.Changed = NewSignal(true)

-- Fires with (targetPhase, oldPhase) right before a reset changes the phase, so scripts can clean up.
-- Listeners run one after another and must not wait.
GameState.Resetting = NewSignal(false)

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
	GameState.Changed:Fire(phase, old)
end

-- Starts a new round at an earlier phase: Menu (main menu), RTS (play again) or Horror (try the escape again)
function GameState.Reset(phase)
	assert(GameState.Phases[phase], "Unknown phase: " .. tostring(phase))
	local old = current
	print("[GameState] reset " .. old .. " -> " .. phase)
	GameState.Resetting:Fire(phase, old)
	current = phase
	GameState.Changed:Fire(phase, old)
end

-- True for resets that go back to before the building started
function GameState.IsFullReset(phase)
	return phase == GameState.Phases.Menu or phase == GameState.Phases.RTS
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
