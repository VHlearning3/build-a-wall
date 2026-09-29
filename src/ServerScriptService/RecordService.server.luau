-- Escape records, level unlocks and badges. Saves each player's best escape time per level, the number
-- of escapes (HunterAI reads Wins to make the Hunter faster) and the highest unlocked level.
-- Player attributes set here: Wins, UnlockedLevel, BestEscape (current level), LastEscape, NewRecord.
local BadgeService = game:GetService("BadgeService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerPhase = require(ServerScriptService:WaitForChild("ServerPhase"))
local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))
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

local records = {} -- [player] = {bests = {[levelKey] = seconds}, wins = number, unlocked = number}
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

local function LevelKey()
	return tostring(ArenaLayout.LevelIndex())
end

local function Publish(player)
	local record = records[player]
	if not record then return end
	player:SetAttribute("Wins", record.wins)
	-- Every level is open while testing in Studio (not saved)
	player:SetAttribute("UnlockedLevel", if RunService:IsStudio() then ArenaLayout.LEVEL_COUNT else record.unlocked)
	player:SetAttribute("BestEscape", record.bests[LevelKey()])
end

workspace:GetAttributeChangedSignal("Level"):Connect(function()
	for player in records do
		Publish(player)
	end
end)

local function Load(player)
	records[player] = {bests = {}, wins = 0, unlocked = 1}
	if store then
		local ok, data = WithRetries(function()
			return store:GetAsync("Player_" .. player.UserId)
		end)
		if ok and type(data) == "table" then
			local bests = {}
			if type(data.bests) == "table" then
				for key, value in data.bests do
					bests[tostring(key)] = tonumber(value)
				end
			elseif tonumber(data.best) then
				bests["1"] = tonumber(data.best) -- Saved before there were levels
			end
			records[player] = {
				bests = bests,
				wins = tonumber(data.wins) or 0,
				unlocked = math.clamp(tonumber(data.unlocked) or 1, 1, ArenaLayout.LEVEL_COUNT),
			}
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
			local bests = type(old.bests) == "table" and old.bests or {}
			for key, value in record.bests do
				local oldValue = tonumber(bests[key])
				bests[key] = if oldValue then math.min(oldValue, value) else value
			end
			return {
				bests = bests,
				wins = math.max(tonumber(old.wins) or 0, record.wins),
				unlocked = math.max(tonumber(old.unlocked) or 1, record.unlocked),
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
		local key = LevelKey()
		local newRecord = record.bests[key] == nil or escapeTime < record.bests[key]
		if newRecord then
			record.bests[key] = escapeTime
		end
		record.wins += 1
		record.unlocked = math.clamp(math.max(record.unlocked, ArenaLayout.LevelIndex() + 1), 1, ArenaLayout.LEVEL_COUNT)
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
