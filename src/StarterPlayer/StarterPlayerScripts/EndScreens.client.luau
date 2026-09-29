-- Lives counter during the horror, and the end screens:
--   True victory: PLAY AGAIN (build a new maze) or MAIN MENU
--   Game over:    TRY AGAIN (same maze, escape again) or MAIN MENU
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local SoundFx = require(ReplicatedStorage:WaitForChild("SoundFx"))
local Phases = GameState.Phases

local player = Players.LocalPlayer
local restartRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RestartRequest")

local LIVES = 3
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
	livesLabel.Text = "LIVES  " .. string.rep("● ", lives) .. string.rep("○ ", math.max(LIVES - lives, 0))
end
player:GetAttributeChangedSignal("LivesLeft"):Connect(UpdateLives)
UpdateLives()

-------------------------------------------------------------------------
-- END SCREENS
-------------------------------------------------------------------------
local screen = nil

local function FormatTime(seconds)
	if not seconds then return "-" end
	local whole = math.floor(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function HideEndScreen()
	if screen then
		screen:Destroy()
		screen = nil
	end
end

local function MakeButton(parent, name, text, color, position, onClick)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = position
	button.Size = UDim2.fromOffset(240, 58)
	button.BackgroundColor3 = Color3.fromRGB(15, 22, 20)
	button.Text = text
	button.FontFace = TITLE_FONT
	button.TextColor3 = color
	button.TextSize = 24
	button.AutoButtonColor = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	button.MouseButton1Click:Connect(function()
		SoundFx.Play("UiClick", {volume = 0.4})
		onClick(button)
	end)
	return button
end

local function ShowEndScreen(config)
	HideEndScreen()
	screen = Instance.new("Frame")
	screen.Name = "EndScreen"
	screen.Size = UDim2.fromScale(1, 1)
	screen.BackgroundColor3 = config.tint
	screen.BackgroundTransparency = 1
	screen.BorderSizePixel = 0
	screen.Parent = gui

	local texts = {
		Label(screen, config.title, TITLE_FONT, config.color, UDim2.fromScale(0.8, 0.1), UDim2.fromScale(0.5, 0.3)),
		Label(screen, config.subtitle, BODY_FONT, Color3.fromRGB(220, 230, 225), UDim2.fromScale(0.6, 0.04), UDim2.fromScale(0.5, 0.4)),
		Label(screen, config.stats, BODY_FONT, Color3.fromRGB(175, 190, 185), UDim2.fromScale(0.6, 0.032), UDim2.fromScale(0.5, 0.47)),
	}
	if config.record then
		table.insert(texts, Label(screen, config.record, TITLE_FONT, Color3.fromRGB(255, 220, 90), UDim2.fromScale(0.5, 0.035), UDim2.fromScale(0.5, 0.53)))
	end

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.Size = UDim2.fromScale(1, 1)
	buttons.Visible = false
	buttons.Parent = screen

	local function Request(kind, button)
		button.Text = "..."
		for _, other in buttons:GetChildren() do
			if other:IsA("TextButton") then
				other.Active = false
				other.AutoButtonColor = false
			end
		end
		restartRequest:FireServer(kind)
	end
	-- Buttons side by side, centred: {kind, text, color}
	local list = table.clone(config.buttons)
	table.insert(list, {"MainMenu", "MAIN MENU", Color3.fromRGB(200, 210, 220)})
	for index, entry in list do
		local offset = (index - (#list + 1) / 2) * 260
		MakeButton(buttons, entry[1] .. "Button", entry[2], entry[3], UDim2.new(0.5, offset, 0.66, 0), function(button)
			Request(entry[1], button)
		end)
	end

	-- Slow, calm fade in; the buttons come a moment later so nobody skips the screen by accident
	for _, label in texts do
		label.TextTransparency = 1
		TweenService:Create(label, TweenInfo.new(2), {TextTransparency = 0}):Play()
	end
	TweenService:Create(screen, TweenInfo.new(2), {BackgroundTransparency = 0.35}):Play()
	local shownScreen = screen
	task.delay(1.5, function()
		if screen == shownScreen then
			buttons.Visible = true
		end
	end)
end

local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))

-- After a win: the next level if there is one (it is unlocked by winning), and playing this one again
local function NextLevelButtons()
	local green = Color3.fromRGB(120, 255, 150)
	if ArenaLayout.LevelIndex() < ArenaLayout.LEVEL_COUNT then
		return {{"NextLevel", "NEXT LEVEL", green}, {"PlayAgain", "PLAY AGAIN", Color3.fromRGB(170, 230, 190)}}
	end
	return {{"PlayAgain", "PLAY AGAIN", green}}
end

local function DeathsText()
	return "Deaths: " .. (LIVES - (player:GetAttribute("LivesLeft") or 0))
end

GameState.OnPhase(Phases.TrueVictory, function()
	-- The server fills in the record a moment after the victory
	task.wait(0.5)
	local escape = player:GetAttribute("LastEscape")
	local best = player:GetAttribute("BestEscape")
	local wins = player:GetAttribute("Wins") or 1
	ShowEndScreen({
		title = "TRUE VICTORY: YOU SURVIVED",
		subtitle = "You escaped the maze you built.",
		stats = "Escape time: " .. FormatTime(escape) .. "    Best: " .. FormatTime(best) .. "    " .. DeathsText(),
		record = if player:GetAttribute("NewRecord") then "NEW RECORD!  Escapes so far: " .. wins .. ". The Hunter will be faster next time." else "Escapes so far: " .. wins .. ". The Hunter will be faster next time.",
		color = Color3.fromRGB(120, 255, 150),
		tint = Color3.fromRGB(5, 25, 12),
		buttons = NextLevelButtons(),
	})
end)

GameState.OnPhase(Phases.GameOver, function()
	ShowEndScreen({
		title = "THE HUNTER GOT YOU",
		subtitle = "Your own maze became your grave.",
		stats = "Best escape: " .. FormatTime(player:GetAttribute("BestEscape")) .. "    " .. DeathsText(),
		color = Color3.fromRGB(255, 70, 70),
		tint = Color3.fromRGB(25, 0, 0),
		buttons = {{"Retry", "TRY AGAIN", Color3.fromRGB(255, 70, 70)}},
	})
end)

GameState.Changed:Connect(function(newPhase)
	livesLabel.Visible = newPhase == Phases.Horror
end)

GameState.Resetting:Connect(HideEndScreen)
