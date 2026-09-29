-- Server copy of the game phase. The client runs the game and reports each phase change;
-- the server only accepts moves forward (RTS -> FakeVictory -> Horror -> TrueVictory or GameOver).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local phaseReport = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PhaseReport")

local ORDER = {RTS = 1, FakeVictory = 2, Horror = 3, TrueVictory = 4, GameOver = 4} -- The last two both end the game

local ServerPhase = {}

local current = "RTS"
local changed = Instance.new("BindableEvent")

-- Fires with (newPhase, player)
ServerPhase.Changed = changed.Event

function ServerPhase.Get()
	return current
end

function ServerPhase.Is(phase)
	return current == phase
end

phaseReport.OnServerEvent:Connect(function(player, phase)
	if typeof(phase) ~= "string" or not ORDER[phase] then return end
	if ORDER[phase] <= ORDER[current] then return end

	current = phase
	print("[ServerPhase] " .. phase .. " (reported by " .. player.Name .. ")")
	changed:Fire(phase, player)
end)

-- The game is built for one player; start over when everyone has left
Players.PlayerRemoving:Connect(function()
	if #Players:GetPlayers() <= 1 then
		current = "RTS"
	end
end)

return ServerPhase
