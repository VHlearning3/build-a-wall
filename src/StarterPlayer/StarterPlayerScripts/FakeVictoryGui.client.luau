-- Glitchy "LEVEL CLEARED" and red breach warning during the fake victory
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local Phases = GameState.Phases

local player = Players.LocalPlayer

local TITLE = "LEVEL CLEARED"
local WARNING = "- ERROR: BREACH DETECTED -"
local GLITCH_CHARS = { "#", "%", "&", "@", "!", "?", "/", "\\", "_", "0", "1", "X" }
local WARNING_DELAY = 1.2 -- Seconds after the title before the warning shows

local gui = nil
local running = false

local function MakeLabel(parent, text, color, zIndex)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.Arcade)
	label.ZIndex = zIndex
	label.Parent = parent
	return label
end

local function Corrupt(text, amount)
	local chars = string.split(text, "")
	for i, c in chars do
		if c ~= " " and math.random() < amount then
			chars[i] = GLITCH_CHARS[math.random(#GLITCH_CHARS)]
		end
	end
	return table.concat(chars)
end

local function Show()
	gui = Instance.new("ScreenGui")
	gui.Name = "FakeVictoryGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Hard cut from the RTS view: start black and fade in
	local blackout = Instance.new("Frame")
	blackout.Size = UDim2.fromScale(1, 1)
	blackout.BackgroundColor3 = Color3.new(0, 0, 0)
	blackout.BorderSizePixel = 0
	blackout.ZIndex = 20
	blackout.Parent = gui
	TweenService:Create(blackout, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()

	local titleFrame = Instance.new("Frame")
	titleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	titleFrame.Position = UDim2.fromScale(0.5, 0.42)
	titleFrame.Size = UDim2.fromScale(0.8, 0.16)
	titleFrame.BackgroundTransparency = 1
	titleFrame.Parent = gui

	-- Red and cyan copies behind the white text give a split-colour glitch
	local red = MakeLabel(titleFrame, TITLE, Color3.fromRGB(255, 30, 60), 1)
	local cyan = MakeLabel(titleFrame, TITLE, Color3.fromRGB(0, 255, 240), 1)
	local main = MakeLabel(titleFrame, TITLE, Color3.fromRGB(240, 255, 240), 2)
	red.TextTransparency = 0.25
	cyan.TextTransparency = 0.25

	local warning = MakeLabel(gui, WARNING, Color3.fromRGB(255, 35, 35), 3)
	warning.FontFace = Font.fromEnum(Enum.Font.Code)
	warning.Position = UDim2.fromScale(0.5, 0.82)
	warning.Size = UDim2.fromScale(0.7, 0.06)
	warning.Visible = false

	running = true
	local startTime = os.clock()

	task.spawn(function()
		while running do
			local elapsed = os.clock() - startTime
			-- The glitch gets worse the longer the text stays up
			local intensity = math.clamp(0.15 + elapsed * 0.12, 0, 0.7)

			local jitter = math.floor(4 + intensity * 14)
			red.Position = UDim2.new(0.5, math.random(-jitter, jitter), 0.5, math.random(-2, 2))
			cyan.Position = UDim2.new(0.5, math.random(-jitter, jitter), 0.5, math.random(-2, 2))

			if math.random() < intensity * 0.5 then
				main.Text = Corrupt(TITLE, intensity * 0.4)
				main.Position = UDim2.new(0.5, math.random(-jitter, jitter), 0.5, 0)
			else
				main.Text = TITLE
				main.Position = UDim2.fromScale(0.5, 0.5)
			end
			main.Visible = math.random() > intensity * 0.15

			if elapsed > WARNING_DELAY then
				-- Blink the warning
				warning.Visible = math.floor(elapsed * 2.5) % 2 == 0
				if math.random() < 0.1 then
					warning.Text = Corrupt(WARNING, 0.15)
				else
					warning.Text = WARNING
				end
			end

			task.wait(0.05)
		end
	end)
end

local function Hide()
	running = false
	if gui then
		gui:Destroy()
		gui = nil
	end
end

GameState.OnPhase(Phases.FakeVictory, Show)
GameState.Changed:Connect(function(newPhase)
	if newPhase ~= Phases.FakeVictory then
		Hide()
	end
end)
