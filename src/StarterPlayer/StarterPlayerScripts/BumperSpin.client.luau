-- Spins the level's bumper bars while building (only on this client, where the orbs fly).
-- When the building ends they snap back to where the server has them, so the player and the
-- Hunter bump into the same walls in the horror.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local Phases = GameState.Phases

local arena = workspace:WaitForChild("Arena")

local homes = {} -- [bar] = CFrame the server placed it at

local function Bars()
	local folder = arena:FindFirstChild("Bumpers")
	local bars = {}
	if folder then
		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") and part:GetAttribute("SpinSpeed") then
				table.insert(bars, part)
			end
		end
	end
	return bars
end

RunService.RenderStepped:Connect(function()
	if not (GameState.Is(Phases.Menu) or GameState.Is(Phases.RTS)) then return end
	local now = os.clock()
	for _, bar in Bars() do
		local home = homes[bar]
		if not home then
			home = bar.CFrame
			homes[bar] = home
			bar.Destroying:Once(function()
				homes[bar] = nil
			end)
		end
		bar.CFrame = home * CFrame.Angles(0, now * bar:GetAttribute("SpinSpeed"), 0)
	end
end)

GameState.OnPhase(Phases.FakeVictory, function()
	for bar, home in homes do
		if bar.Parent then
			bar.CFrame = home
		end
	end
end)
