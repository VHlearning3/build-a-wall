-- Escape records and badges. Saves each player's best escape time and number of escapes;
-- the escape count also makes the Hunter faster next time (HunterAI reads the Wins attribute).
-- Player attributes set here: Wins, BestEscape, LastEscape, NewRecord.
local BadgeService = game:GetService("BadgeService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerPhase = require(ServerScriptService:WaitForChild("ServerPhase"))
local BadgeIds = require(ServerScriptService:WaitForChild("BadgeIds"))

local STORE_NAME = "EscapeRecords_v1"
local RETRIES = 3

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		-- In Studio this needs Game Settings > Security > Enable Studio Access to API Services
		warn("Escape records are not saved: " .. tostring(result))
	end
end

local records = {} -- [player] = {best = seconds or nil, wins = number}
local horrorStart = 0
local deathsThisRun = 0

local function WithRetries(action)
	for attempt = 1, RETRIES do
		local ok, result = pcall(action)
		if ok then
			return true, result
		end
		if attempt < RETRIES then
			task.wait(attempt)
		else
			warn("DataStore call failed: " .. tostring(result))
		end
	end
	return false, nil
end

local function Publish(player)
	local record = records[player]
	if not record then return end
	player:SetAttribute("Wins", record.wins)
	player:SetAttribute("BestEscape", record.best)
end

local function Load(player)
	records[player] = {best = nil, wins = 0}
	if store then
		local ok, data = WithRetries(function()
			return store:GetAsync("Player_" .. player.UserId)
		end)
		if ok and type(data) == "table" then
			records[player] = {best = tonumber(data.best), wins = tonumber(data.wins) or 0}
		end
	end
	Publish(player)
end

local function Save(player)
	local record = records[player]
	if not store or not record then return end
	task.spawn(WithRetries, function()
		store:UpdateAsync("Player_" .. player.UserId, function(old)
			old = type(old) == "table" and old or {}
			local oldBest = tonumber(old.best)
			return {
				best = if oldBest and record.best then math.min(oldBest, record.best) else (record.best or oldBest),
				wins = math.max(tonumber(old.wins) or 0, record.wins),
			}
		end)
	end)
end

local function Award(player, badgeName)
	local badgeId = BadgeIds[badgeName]
	if not badgeId or badgeId == 0 then return end
	task.spawn(function()
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badgeId)
		if ok and not has then
			pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
		end
	end)
end

local function WatchDeaths(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if not humanoid then return end
		humanoid.Died:Connect(function()
			if ServerPhase.Is("Horror") then
				deathsThisRun += 1
			end
		end)
	end)
end

Players.PlayerAdded:Connect(function(player)
	WatchDeaths(player)
	Load(player)
end)
for _, player in Players:GetPlayers() do
	WatchDeaths(player)
	task.spawn(Load, player)
end

Players.PlayerRemoving:Connect(function(player)
	Save(player)
	records[player] = nil
end)

ServerPhase.Changed:Connect(function(phase, player)
	if phase == "FakeVictory" and player then
		Award(player, "LevelCleared")
	elseif phase == "Horror" then
		-- Also restarts the clock when the player retries the escape
		horrorStart = os.clock()
		deathsThisRun = 0
	elseif phase == "TrueVictory" and player then
		local record = records[player]
		if not record then return end
		local escapeTime = math.floor((os.clock() - horrorStart) * 10) / 10
		local newRecord = record.best == nil or escapeTime < record.best
		if newRecord then
			record.best = escapeTime
		end
		record.wins += 1
		player:SetAttribute("LastEscape", escapeTime)
		player:SetAttribute("NewRecord", newRecord)
		Publish(player)
		Save(player)

		Award(player, "Escaped")
		if deathsThisRun == 0 then
			Award(player, "Flawless")
		end
	end
end)
