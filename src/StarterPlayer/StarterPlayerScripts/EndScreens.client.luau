-- Lives counter during the horror, and the true victory / game over screens with Play again
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local Phases = GameState.Phases

local player = Players.LocalPlayer
local playAgain = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlayAgain")

local TITLE_FONT = Font.fromEnum(Enum.Font.GothamBlack)
local BODY_FONT = Font.fromEnum(Enum.Font.GothamMedium)

local gui = Instance.new("ScreenGui")
gui.Name = "EndScreens"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local function Label(parent, text, font, color, size, position)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Text = text
	label.FontFace = font
	label.TextColor3 = color
	label.TextScaled = true
	label.Size = size
	label.Position = position
	label.Parent = parent
	return label
end

-------------------------------------------------------------------------
-- LIVES during the horror
-------------------------------------------------------------------------
local livesLabel = Label(gui, "", TITLE_FONT, Color3.fromRGB(255, 70, 70), UDim2.fromOffset(220, 26), UDim2.new(0, 130, 0, 70))
livesLabel.TextXAlignment = Enum.TextXAlignment.Left
livesLabel.TextTransparency = 0.2
livesLabel.Visible = false

local function UpdateLives()
	local lives = player:GetAttribute("LivesLeft") or 0
	livesLabel.Text = "LIVES  " .. string.rep("● ", lives) .. string.rep("○ ", math.max(3 - lives, 0))
end
player:GetAttributeChangedSignal("LivesLeft"):Connect(UpdateLives)
UpdateLives()

GameState.Changed:Connect(function(newPhase)
	livesLabel.Visible = newPhase == Phases.Horror
end)

-------------------------------------------------------------------------
-- END SCREENS
-------------------------------------------------------------------------
local function FormatTime(seconds)
	seconds = math.floor(seconds)
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function ShowEndScreen(title, titleColor, subtitle, tint)
	local screen = Instance.new("Frame")
	screen.Size = UDim2.fromScale(1, 1)
	screen.BackgroundColor3 = tint
	screen.BackgroundTransparency = 1
	screen.BorderSizePixel = 0
	screen.Parent = gui

	local titleLabel = Label(screen, title, TITLE_FONT, titleColor, UDim2.fromScale(0.8, 0.1), UDim2.fromScale(0.5, 0.38))
	local subtitleLabel = Label(screen, subtitle, BODY_FONT, Color3.fromRGB(220, 230, 225), UDim2.fromScale(0.6, 0.04), UDim2.fromScale(0.5, 0.48))

	local startTime = player:GetAttribute("HorrorStartTime")
	local survived = startTime and FormatTime(os.clock() - startTime) or "-"
	local livesUsed = 3 - (player:GetAttribute("LivesLeft") or 0)
	local stats = Label(screen, "Time in the dark: " .. survived .. "    Deaths: " .. livesUsed, BODY_FONT,
		Color3.fromRGB(170, 185, 180), UDim2.fromScale(0.5, 0.03), UDim2.fromScale(0.5, 0.54))

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.66)
	button.Size = UDim2.fromOffset(260, 60)
	button.BackgroundColor3 = Color3.fromRGB(15, 25, 20)
	button.Text = "PLAY AGAIN"
	button.FontFace = TITLE_FONT
	button.TextColor3 = titleColor
	button.TextSize = 26
	button.AutoButtonColor = true
	button.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = titleColor
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button

	local note = Label(screen, "", BODY_FONT, Color3.fromRGB(200, 200, 200), UDim2.fromScale(0.6, 0.025), UDim2.fromScale(0.5, 0.74))

	button.MouseButton1Click:Connect(function()
		button.Text = "LOADING..."
		button.Active = false
		playAgain:FireServer()
	end)
	playAgain.OnClientEvent:Connect(function(status)
		if status == "failed" then
			button.Text = "PLAY AGAIN"
			button.Active = true
			note.Text = "Play again works in the published game. In Studio, stop and press Play."
		end
	end)

	-- Slow, calm fade in
	for _, element in {titleLabel, subtitleLabel, stats, note} do
		element.TextTransparency = 1
		TweenService:Create(element, TweenInfo.new(2.5), {TextTransparency = 0}):Play()
	end
	button.Visible = false
	TweenService:Create(screen, TweenInfo.new(2.5), {BackgroundTransparency = 0.35}):Play()
	task.delay(2, function()
		button.Visible = true
	end)
end

GameState.OnPhase(Phases.TrueVictory, function()
	ShowEndScreen("TRUE VICTORY: YOU SURVIVED", Color3.fromRGB(120, 255, 150),
		"You escaped the maze you built.", Color3.fromRGB(5, 25, 12))
end)

GameState.OnPhase(Phases.GameOver, function()
	ShowEndScreen("THE HUNTER GOT YOU", Color3.fromRGB(255, 60, 60),
		"Your own maze became your grave.", Color3.fromRGB(25, 0, 0))
end)
