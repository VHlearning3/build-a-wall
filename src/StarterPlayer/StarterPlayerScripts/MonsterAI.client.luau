local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local Phases = GameState.Phases

local player = Players.LocalPlayer

-- Haetaan hirviö Workspacesta
local hunter = workspace:WaitForChild("Hunter")
local humanoid = hunter:WaitForChild("Humanoid")
local rootPart = hunter:WaitForChild("HumanoidRootPart")

local isHunting = false

-- Kun ydin tuhotaan, hirviö päästetään irti
GameState.OnPhase(Phases.Horror, function()
	isHunting = true
	-- Voit lisätä hirviölle pelottavan äänen tähän!
	print("The Hunter is loose...")
end)

-- The Hunter stops chasing once the player has escaped
GameState.OnPhase(Phases.TrueVictory, function()
	isHunting = false
	humanoid:MoveTo(rootPart.Position)
end)

-- Reitinhaun pääsilmukka
task.spawn(function()
	while task.wait(0.2) do -- Päivitetään reitti 0.2 sekunnin välein
		if isHunting and player.Character then
			local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")

			if targetRoot then
				-- Luodaan uusi reitti
				local path = PathfindingService:CreatePath({
					AgentRadius = 3, -- Kuinka paljon tilaa hirviö vaatii
					AgentHeight = 5,
					AgentCanJump = false, -- Ei anneta sen hyppiä muurien yli
					WaypointSpacing = 4
				})

				-- Lasketaan reitti hirviön ja pelaajan välille
				local success, errorMessage = pcall(function()
					path:ComputeAsync(rootPart.Position, targetRoot.Position)
				end)

				if success and path.Status == Enum.PathStatus.Success then
					-- Haetaan reittipisteet
					local waypoints = path:GetWaypoints()

					-- Liikutetaan hirviö kohti seuraavaa pistettä (indeksi 2, koska 1 on sen nykyinen sijainti)
					if #waypoints >= 2 then
						humanoid:MoveTo(waypoints[2].Position)
					end
				else
					-- Jos reittiä ei löydy, yritetään kävellä suoraan kohti (estää jumiutumisen)
					humanoid:MoveTo(targetRoot.Position)
				end
			end
		end
	end
end)

-------------------------------------------------------------------------
-- KUOLEMAN LOGIIKKA (Kun hirviö saa pelaajan kiinni)
-------------------------------------------------------------------------
rootPart.Touched:Connect(function(hit)
	if not isHunting then return end

	-- Tarkistetaan osuuko hirviö pelaajan hahmoon
	if hit.Parent == player.Character then
		local playerHumanoid = hit.Parent:FindFirstChild("Humanoid")
		if playerHumanoid and playerHumanoid.Health > 0 then
			playerHumanoid.Health = 0 -- Pelaaja kuolee
			print("The Hunter caught you!")
		end
	end
end)