-- Main menu (a cheerful building game, so the twist stays a surprise), the "how to play" card
-- that opens every round, and floating labels over the spawn pad and the core while building
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local SoundFx = require(ReplicatedStorage:WaitForChild("SoundFx"))
local Phases = GameState.Phases

local player = Players.LocalPlayer

local CUTE_FONT = Font.fromEnum(Enum.Font.FredokaOne)
local BODY_FONT = Font.fromEnum(Enum.Font.GothamMedium)
local ORANGE = Color3.fromRGB(255, 150, 40)
local CYAN = Color3.fromRGB(0, 220, 255)
local PANEL = Color3.fromRGB(10, 18, 40)
local INTRO_SECONDS = 9

local gui = Instance.new("ScreenGui")
gui.Name = "MainMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

local function Corner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function Stroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function Label(parent, text, font, color, size, position)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Text = text
	label.FontFace = font
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Size = size
	label.Position = position
	label.Parent = parent
	return label
end

local function BigButton(parent, text, color, position, size)
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color
	button.Text = text
	button.FontFace = CUTE_FONT
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.AutoButtonColor = true
	button.Parent = parent
	Corner(button, 16)
	Stroke(button, Color3.new(1, 1, 1), 3)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.18, 0)
	padding.PaddingBottom = UDim.new(0.18, 0)
	padding.Parent = button

	-- A little bounce on hover
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), {Scale = 1.06}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), {Scale = 1}):Play()
	end)
	return button
end

-- Keeps the menu readable on phones and big screens alike
local function FitToScreen(frame)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = frame.Size.X.Offset / frame.Size.Y.Offset
	ratio.Parent = frame
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(frame.Size.X.Offset, frame.Size.Y.Offset)
	sizeLimit.Parent = frame
	frame.Size = UDim2.fromScale(0.9, 0.9)
end

-------------------------------------------------------------------------
-- MAIN MENU
-------------------------------------------------------------------------
local menu = Instance.new("Frame")
menu.Name = "Menu"
menu.AnchorPoint = Vector2.new(0.5, 0.5)
menu.Position = UDim2.fromScale(0.5, 0.5)
menu.Size = UDim2.fromOffset(560, 470)
menu.BackgroundColor3 = PANEL
menu.BackgroundTransparency = 0.1
menu.Parent = gui
Corner(menu, 24)
Stroke(menu, CYAN, 3)
FitToScreen(menu)

local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new(Color3.fromRGB(40, 90, 170), Color3.fromRGB(255, 255, 255))
gradient.Parent = menu

local title = Label(menu, "BUILD A WALL", CUTE_FONT, ORANGE, UDim2.fromScale(0.86, 0.2), UDim2.fromScale(0.5, 0.16))
local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.fromRGB(90, 30, 0)
titleStroke.Thickness = 3
titleStroke.Parent = title
Label(menu, "Bounce the orbs. Break the core!", CUTE_FONT, CYAN, UDim2.fromScale(0.8, 0.07), UDim2.fromScale(0.5, 0.31))

local playButton = BigButton(menu, "PLAY", ORANGE, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.55, 0.17))
local howButton = BigButton(menu, "HOW TO PLAY", Color3.fromRGB(40, 150, 220), UDim2.fromScale(0.5, 0.7), UDim2.fromScale(0.55, 0.12))

Label(menu, "This game contains flashing lights.", BODY_FONT, Color3.fromRGB(190, 200, 215), UDim2.fromScale(0.8, 0.04), UDim2.fromScale(0.5, 0.9))

-- Gentle bob of the title
task.spawn(function()
	while true do
		TweenService:Create(title, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {Rotation = 2}):Play()
		task.wait(1.2)
		TweenService:Create(title, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {Rotation = -2}):Play()
		task.wait(1.2)
	end
end)

-------------------------------------------------------------------------
-- HOW TO PLAY card (from the menu, and at the start of every round)
-------------------------------------------------------------------------
local card = Instance.new("Frame")
card.Name = "HowToPlay"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.45)
card.Size = UDim2.fromOffset(560, 330)
card.BackgroundColor3 = PANEL
card.BackgroundTransparency = 0.08
card.Visible = false
card.Parent = gui
Corner(card, 20)
Stroke(card, ORANGE, 3)
FitToScreen(card)

Label(card, "HOW TO PLAY", CUTE_FONT, ORANGE, UDim2.fromScale(0.8, 0.13), UDim2.fromScale(0.5, 0.12))
local steps = {
	"1.  Blue orbs fly out of the S pad and bounce off walls.",
	"2.  Build walls, towers and bumps to steer them.",
	"3.  Hit the red ENEMY CORE 5 times to clear the level!",
	"B build   R rotate   Right-click remove   Wheel zoom",
}
for index, text in steps do
	local line = Label(card, text, BODY_FONT, if index == 4 then Color3.fromRGB(160, 200, 230) else Color3.fromRGB(235, 245, 255),
		UDim2.fromScale(0.86, 0.085), UDim2.fromScale(0.5, 0.26 + index * 0.12))
	line.TextXAlignment = Enum.TextXAlignment.Left
	local sameSize = Instance.new("UITextSizeConstraint")
	sameSize.MaxTextSize = 20 -- All steps the same size on big screens
	sameSize.Parent = line
end
local gotIt = BigButton(card, "GOT IT", ORANGE, UDim2.fromScale(0.5, 0.86), UDim2.fromScale(0.4, 0.16))

local cardToken = 0
local function ShowCard(autoHideSeconds)
	cardToken += 1
	local token = cardToken
	card.Visible = true
	if autoHideSeconds then
		task.delay(autoHideSeconds, function()
			if token == cardToken then
				card.Visible = false
			end
		end)
	end
end

gotIt.MouseButton1Click:Connect(function()
	SoundFx.Play("UiClick", {volume = 0.4})
	card.Visible = false
	if GameState.Is(Phases.Menu) then
		menu.Visible = true
	end
end)

howButton.MouseButton1Click:Connect(function()
	SoundFx.Play("UiClick", {volume = 0.4})
	menu.Visible = false
	ShowCard(nil)
end)

playButton.MouseButton1Click:Connect(function()
	SoundFx.Play("UiClick", {volume = 0.4})
	if GameState.Is(Phases.Menu) then
		GameState.Set(Phases.RTS)
	end
end)

-------------------------------------------------------------------------
-- FLOATING LABELS over the spawn pad and the core while building
-------------------------------------------------------------------------
local function WorldLabel(adornee, text, color, height)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PhaseLabel"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.FontFace = CUTE_FONT
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	billboard.Parent = gui
	return billboard
end

local worldLabels = {
	WorldLabel(workspace:WaitForChild("EnemyCore"), "ENEMY CORE", Color3.fromRGB(255, 90, 90), 12),
	WorldLabel(workspace:WaitForChild("EntitySpawn"), "ORBS START HERE", CYAN, 6),
}

-------------------------------------------------------------------------
-- PHASES
-------------------------------------------------------------------------
local function Refresh(phase)
	menu.Visible = phase == Phases.Menu
	for _, label in worldLabels do
		label.Enabled = phase == Phases.RTS
	end
	if phase ~= Phases.Menu and phase ~= Phases.RTS then
		card.Visible = false
	end
end

GameState.Changed:Connect(function(newPhase)
	Refresh(newPhase)
	if newPhase == Phases.RTS then
		ShowCard(INTRO_SECONDS) -- The orbs are already flying behind it
	end
end)
Refresh(GameState.Get())
