-- Main menu (a cheerful building game, so the twist stays a surprise), the "how to play" card
-- that opens every round, and floating labels over the spawn pad and the core while building
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local SoundFx = require(ReplicatedStorage:WaitForChild("SoundFx"))
local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))
local selectLevel = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SelectLevel")
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
menu.Size = UDim2.fromOffset(560, 560)
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

local title = Label(menu, "BUILD A WALL", CUTE_FONT, ORANGE, UDim2.fromScale(0.86, 0.17), UDim2.fromScale(0.5, 0.13))
local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.fromRGB(90, 30, 0)
titleStroke.Thickness = 3
titleStroke.Parent = title
Label(menu, "Bounce the orbs. Break the core!", CUTE_FONT, CYAN, UDim2.fromScale(0.8, 0.06), UDim2.fromScale(0.5, 0.25))

-- Level picker: < LEVEL 2  Bumper Hall >
local levelName = Label(menu, "", CUTE_FONT, Color3.new(1, 1, 1), UDim2.fromScale(0.6, 0.07), UDim2.fromScale(0.5, 0.37))
local levelInfo = Label(menu, "", BODY_FONT, Color3.fromRGB(180, 205, 230), UDim2.fromScale(0.62, 0.04), UDim2.fromScale(0.5, 0.44))
local previousButton = BigButton(menu, "<", Color3.fromRGB(40, 60, 110), UDim2.fromScale(0.12, 0.4), UDim2.fromScale(0.1, 0.1))
previousButton.Name = "PreviousLevel"
local nextButton = BigButton(menu, ">", Color3.fromRGB(40, 60, 110), UDim2.fromScale(0.88, 0.4), UDim2.fromScale(0.1, 0.1))
nextButton.Name = "NextLevel"

local playButton = BigButton(menu, "PLAY", ORANGE, UDim2.fromScale(0.5, 0.6), UDim2.fromScale(0.55, 0.14))
playButton.Name = "PlayButton"
local howButton = BigButton(menu, "HOW TO PLAY", Color3.fromRGB(40, 150, 220), UDim2.fromScale(0.5, 0.77), UDim2.fromScale(0.55, 0.1))
howButton.Name = "HowToPlayButton"

Label(menu, "This game contains flashing lights.", BODY_FONT, Color3.fromRGB(190, 200, 215), UDim2.fromScale(0.8, 0.035), UDim2.fromScale(0.5, 0.92))

local shownLevel = ArenaLayout.LevelIndex() -- The one on screen; may be locked

local function Unlocked()
	return player:GetAttribute("UnlockedLevel") or 1
end

local function RefreshLevel()
	local level = ArenaLayout.GetLevel(shownLevel)
	local locked = shownLevel > Unlocked()
	levelName.Text = "LEVEL " .. shownLevel .. "  " .. level.NAME
	levelInfo.Text = if locked then "Locked: escape level " .. (shownLevel - 1) .. " first." else level.DESCRIPTION
	levelName.TextColor3 = if locked then Color3.fromRGB(130, 140, 160) else Color3.new(1, 1, 1)
	playButton.Text = if locked then "LOCKED" else "PLAY"
	playButton.BackgroundColor3 = if locked then Color3.fromRGB(90, 90, 100) else ORANGE
	previousButton.Visible = shownLevel > 1
	nextButton.Visible = shownLevel < ArenaLayout.LEVEL_COUNT
end

local function ShowLevel(index)
	shownLevel = math.clamp(index, 1, ArenaLayout.LEVEL_COUNT)
	RefreshLevel()
	if shownLevel <= Unlocked() and shownLevel ~= ArenaLayout.LevelIndex() then
		selectLevel:FireServer(shownLevel) -- The arena behind the menu switches to it
	end
end

previousButton.MouseButton1Click:Connect(function()
	SoundFx.Play("UiClick", {volume = 0.4})
	ShowLevel(shownLevel - 1)
end)
nextButton.MouseButton1Click:Connect(function()
	SoundFx.Play("UiClick", {volume = 0.4})
	ShowLevel(shownLevel + 1)
end)
player:GetAttributeChangedSignal("UnlockedLevel"):Connect(RefreshLevel)
workspace:GetAttributeChangedSignal("Level"):Connect(function()
	-- The level can also change from the end screen (NEXT LEVEL)
	if ArenaLayout.LevelIndex() <= Unlocked() then
		shownLevel = ArenaLayout.LevelIndex()
	end
	RefreshLevel()
end)
RefreshLevel()

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
	"2.  Build walls and towers to steer them. Boosters speed them up!",
	"3.  Hit the red ENEMY CORE 5 times to clear the level!",
	"B build   R rotate   Right-click remove   Wheel zoom",
}
for index, text in steps do
	local line = Label(card, text, BODY_FONT, if index == 4 then Color3.fromRGB(160, 200, 230) else Color3.fromRGB(235, 245, 255),
		UDim2.fromScale(0.86, 0.08), UDim2.fromScale(0.5, 0.23 + index * 0.11))
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
	-- Only once the arena behind the menu is the level on screen
	if GameState.Is(Phases.Menu) and shownLevel <= Unlocked() and shownLevel == ArenaLayout.LevelIndex() then
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

-- Levels with more cores put the extra ones in the arena folder
local arena = workspace:WaitForChild("Arena")
arena.ChildAdded:Connect(function(child)
	if child:IsA("BasePart") and child.Name:match("^EnemyCore%d") then
		local label = WorldLabel(child, "ENEMY CORE", Color3.fromRGB(255, 90, 90), 12)
		label.Enabled = GameState.Is(Phases.RTS)
		table.insert(worldLabels, label)
		child.Destroying:Once(function()
			local index = table.find(worldLabels, label)
			if index then
				table.remove(worldLabels, index)
			end
			label:Destroy()
		end)
	end
end)

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
