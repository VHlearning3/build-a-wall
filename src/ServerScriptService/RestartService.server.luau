-- Level choice and menus that start a new round in place (no teleport, so they also work in Studio):
--   SelectLevel(n) in the main menu: switch to an unlocked level
--   Retry     after a game over: the same maze, the escape starts again with full lives
--   PlayAgain after the game ended: back to building the same level, empty arena
--   NextLevel after a true victory: the next level, building, empty arena
--   MainMenu  after the game ended: back to the main menu, empty arena
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerPhase = require(ServerScriptService:WaitForChild("ServerPhase"))
local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local restartRequest = remotes:WaitForChild("RestartRequest")
local roundReset = remotes:WaitForChild("RoundReset")
local selectLevel = remotes:WaitForChild("SelectLevel")

local TARGETS = {
	Retry = {phase = "Horror", allowedFrom = {GameOver = true}},
	PlayAgain = {phase = "RTS", allowedFrom = {GameOver = true, TrueVictory = true}},
	NextLevel = {phase = "RTS", allowedFrom = {TrueVictory = true}, nextLevel = true},
	MainMenu = {phase = "Menu", allowedFrom = {GameOver = true, TrueVictory = true}},
}

local busy = false

local function IsUnlocked(player, level)
	return level >= 1 and level <= ArenaLayout.LEVEL_COUNT and level <= (player:GetAttribute("UnlockedLevel") or 1)
end

selectLevel.OnServerEvent:Connect(function(player, level)
	if typeof(level) ~= "number" or level ~= math.floor(level) then return end
	if not ServerPhase.Is("Menu") or busy then return end
	if not IsUnlocked(player, level) then return end
	workspace:SetAttribute("Level", level) -- ArenaService and WallService rebuild for it
end)

restartRequest.OnServerEvent:Connect(function(player, kind)
	local target = typeof(kind) == "string" and TARGETS[kind]
	if not target or busy then return end
	if not target.allowedFrom[ServerPhase.Get()] then return end
	if target.nextLevel then
		local nextLevel = ArenaLayout.LevelIndex() + 1
		if not IsUnlocked(player, nextLevel) then return end
		workspace:SetAttribute("Level", nextLevel)
	end
	busy = true

	-- Server side first (walls, arena, Hunter listen to this), then the client, then a fresh character
	ServerPhase.Reset(target.phase, player)
	roundReset:FireClient(player, target.phase)
	task.wait(0.3)
	player:LoadCharacter()

	busy = false
end)
