-- "Play again": sends the player to a fresh private server of this place, which restarts everything
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local ServerPhase = require(ServerScriptService:WaitForChild("ServerPhase"))

local playAgain = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlayAgain")

local teleporting = {}

playAgain.OnServerEvent:Connect(function(player)
	if not (ServerPhase.Is("TrueVictory") or ServerPhase.Is("GameOver")) then return end
	if teleporting[player] then return end
	teleporting[player] = true

	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ShouldReserveServer = true
		TeleportService:TeleportAsync(game.PlaceId, {player}, options)
	end)

	if not ok then
		-- Teleports do not work in Studio playtests
		warn("Play again failed: " .. tostring(err))
		teleporting[player] = nil
		playAgain:FireClient(player, "failed")
	end
end)
