-- Menus that start a new round in place (no teleport, so they also work in Studio):
--   Retry     after a game over: the same maze, the escape starts again with full lives
--   PlayAgain after the game ended: back to building, empty arena
--   MainMenu  after the game ended: back to the main menu, empty arena
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerPhase = require(ServerScriptService:WaitForChild("ServerPhase"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local restartRequest = remotes:WaitForChild("RestartRequest")
local roundReset = remotes:WaitForChild("RoundReset")

local TARGETS = {
	Retry = {phase = "Horror", allowedFrom = {GameOver = true}},
	PlayAgain = {phase = "RTS", allowedFrom = {GameOver = true, TrueVictory = true}},
	MainMenu = {phase = "Menu", allowedFrom = {GameOver = true, TrueVictory = true}},
}

local busy = false

restartRequest.OnServerEvent:Connect(function(player, kind)
	local target = typeof(kind) == "string" and TARGETS[kind]
	if not target or busy then return end
	if not target.allowedFrom[ServerPhase.Get()] then return end
	busy = true

	-- Server side first (walls, arena, Hunter listen to this), then the client, then a fresh character
	ServerPhase.Reset(target.phase, player)
	roundReset:FireClient(player, target.phase)
	task.wait(0.3)
	player:LoadCharacter()

	busy = false
end)

Players.PlayerRemoving:Connect(function()
	busy = false
end)
