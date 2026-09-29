-- Server copy of the game phase. The client runs the game and reports each phase change;
-- the server only accepts moves forward (Menu -> RTS -> FakeVictory -> Horror -> TrueVictory or GameOver).
-- Going back (retry, play again, main menu) only happens through ServerPhase.Reset from RestartService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local phaseReport = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PhaseReport")

local ORDER = {Menu = 0, RTS = 1, FakeVictory = 2, Horror = 3, TrueVictory = 4, GameOver = 4} -- The last two both end the game

local ServerPhase = {}

local current = "Menu"
local changed = Instance.new("BindableEvent")

-- Fires with (newPhase, player, isReset)
ServerPhase.Changed = changed.Event

function ServerPhase.Get()
	return current
end

function ServerPhase.Is(phase)
	return current == phase
end

function ServerPhase.Reset(phase, player)
	assert(ORDER[phase], "Unknown phase: " .. tostring(phase))
	current = phase
	print("[ServerPhase] reset to " .. phase)
	changed:Fire(phase, player, true)
end

phaseReport.OnServerEvent:Connect(function(player, phase)
	if typeof(phase) ~= "string" or not ORDER[phase] then return end
	if ORDER[phase] <= ORDER[current] then return end

	current = phase
	print("[ServerPhase] " .. phase .. " (reported by " .. player.Name .. ")")
	changed:Fire(phase, player, false)
end)

-- The game is built for one player; start over when everyone has left
Players.PlayerRemoving:Connect(function()
	if #Players:GetPlayers() <= 1 then
		current = "Menu"
	end
end)

return ServerPhase
