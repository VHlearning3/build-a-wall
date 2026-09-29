local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

local GameState = require(game.ReplicatedStorage:WaitForChild("GameState"))
local BuildPieces = require(game.ReplicatedStorage:WaitForChild("BuildPieces"))
local placePieceRemote = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlacePiece")

local gui = script.Parent

local isBuildingMode = false
local currentRotation = 0
local gridSize = BuildPieces.GRID_SIZE -- Palikat lukittuvat ruudukkoon 2 studin tarkkuudella

-- The server owns the walls folder and the walls in it (so the Hunter sees the maze)
local wallsFolder = workspace:WaitForChild("RTSWalls")
mouse.TargetFilter = wallsFolder -- Taikasana: hiiri osuu nyt aina maahan seinien läpi!

-- Same keep-clear rule as the server, so the preview can turn red
local keepClear = {workspace:WaitForChild("EntitySpawn").Position, workspace:WaitForChild("EnemyCore").Position}
local BLOCKED_COLOR = BrickColor.new("Really red")

local buildOptions = BuildPieces.Pieces
local selectedOptionIndex = 1
local previewPart = nil

-------------------------------------------------------------------------
-- BUILD MENU UI
-------------------------------------------------------------------------
local ACCENT = Color3.fromRGB(0, 220, 255)
local ACTIVE = Color3.fromRGB(110, 255, 140)
local PANEL = Color3.fromRGB(8, 14, 30)
local TITLE_FONT = Font.fromEnum(Enum.Font.GothamBlack)
local BODY_FONT = Font.fromEnum(Enum.Font.GothamBold)
local HINT_FONT = Font.fromEnum(Enum.Font.Code)

local function Round(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function Stroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function Label(parent, text, font, color, size, position)
	local label = Instance.new("TextLabel")
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

gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

-- Shrinks the whole menu on small screens
local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function UpdateScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.clamp(math.min(viewport.X / 1100, viewport.Y / 700), 0.55, 1.25)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
UpdateScale()

-- Bottom bar
local bar = Instance.new("Frame")
bar.Name = "BuildBar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -24)
bar.Size = UDim2.fromOffset(560, 128)
bar.BackgroundColor3 = PANEL
bar.BackgroundTransparency = 0.15
bar.Parent = gui
Round(bar, 14)
Stroke(bar, ACCENT, 2, 0.15)

local barGradient = Instance.new("UIGradient")
barGradient.Rotation = 90
barGradient.Color = ColorSequence.new(Color3.fromRGB(30, 60, 110), Color3.fromRGB(255, 255, 255))
barGradient.Parent = bar

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.Parent = bar

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.Padding = UDim.new(0, 10)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = bar

-- Build mode toggle
local toggle = Instance.new("TextButton")
toggle.Name = "BuildWallButton"
toggle.LayoutOrder = 0
toggle.Size = UDim2.fromOffset(120, 104)
toggle.BackgroundColor3 = Color3.fromRGB(14, 30, 55)
toggle.AutoButtonColor = false
toggle.Text = ""
toggle.Parent = bar
Round(toggle, 10)
local toggleStroke = Stroke(toggle, ACCENT, 2)
local toggleTitle = Label(toggle, "BUILD", TITLE_FONT, ACCENT, UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 22))
local toggleHint = Label(toggle, "[B]", HINT_FONT, Color3.fromRGB(150, 190, 220), UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 64))

-- Divider
local divider = Instance.new("Frame")
divider.LayoutOrder = 1
divider.Size = UDim2.fromOffset(2, 90)
divider.BackgroundColor3 = ACCENT
divider.BackgroundTransparency = 0.6
divider.BorderSizePixel = 0
divider.Parent = bar

-- Piece slots
local slots = {}
for index, option in buildOptions do
	local slot = Instance.new("TextButton")
	slot.Name = option.name .. "Slot"
	slot.LayoutOrder = 1 + index
	slot.Size = UDim2.fromOffset(120, 104)
	slot.BackgroundColor3 = Color3.fromRGB(14, 22, 40)
	slot.AutoButtonColor = false
	slot.Text = ""
	slot.Parent = bar
	Round(slot, 10)
	local stroke = Stroke(slot, option.color.Color, 1.5, 0.6)

	local slotScale = Instance.new("UIScale")
	slotScale.Parent = slot

	-- Key badge
	local badge = Label(slot, tostring(index), HINT_FONT, PANEL, UDim2.fromOffset(20, 20), UDim2.fromOffset(6, 6))
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = option.color.Color
	Round(badge, 5)

	-- Swatch shaped like the piece seen from above
	local footprint = Vector2.new(option.size.X, option.size.Z)
	local longest = math.max(footprint.X, footprint.Y)
	local swatch = Instance.new("Frame")
	swatch.AnchorPoint = Vector2.new(0.5, 0.5)
	swatch.Position = UDim2.new(0.5, 0, 0, 44)
	swatch.Size = UDim2.fromOffset(math.max(8, 56 * footprint.X / longest), math.max(8, 44 * footprint.Y / longest))
	swatch.BackgroundColor3 = option.color.Color
	swatch.BorderSizePixel = 0
	swatch.Parent = slot
	Round(swatch, 3)
	Stroke(swatch, Color3.new(1, 1, 1), 1, 0.5)

	Label(slot, string.upper(option.name), BODY_FONT, Color3.fromRGB(225, 240, 255), UDim2.new(1, -12, 0, 16), UDim2.new(0, 6, 1, -26))

	slots[index] = {button = slot, stroke = stroke, scale = slotScale}
end

-- Controls hint above the bar
local hint = Label(gui, "LMB PLACE  |  R ROTATE  |  1 2 3 PIECE  |  B EXIT", HINT_FONT, Color3.fromRGB(170, 220, 255), UDim2.fromOffset(560, 18), UDim2.new(0.5, 0, 1, -178))
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.TextStrokeTransparency = 0.4

-- Core hit counter at the top
local coreHud = Instance.new("Frame")
coreHud.Name = "CoreHud"
coreHud.AnchorPoint = Vector2.new(0.5, 0)
coreHud.Position = UDim2.new(0.5, 0, 0, 16)
coreHud.Size = UDim2.fromOffset(300, 62)
coreHud.BackgroundColor3 = PANEL
coreHud.BackgroundTransparency = 0.15
coreHud.Parent = gui
Round(coreHud, 12)
Stroke(coreHud, Color3.fromRGB(255, 60, 60), 2, 0.2)
Label(coreHud, "ENEMY CORE", TITLE_FONT, Color3.fromRGB(255, 90, 90), UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 6))

local pips = {}
local core = workspace:WaitForChild("EnemyCore")
local hitsRequired = core:GetAttribute("HitsRequired") or 5
for i = 1, hitsRequired do
	local pip = Instance.new("Frame")
	local width = (280 - (hitsRequired - 1) * 6) / hitsRequired
	pip.Size = UDim2.fromOffset(width, 16)
	pip.Position = UDim2.fromOffset(10 + (i - 1) * (width + 6), 34)
	pip.BackgroundColor3 = Color3.fromRGB(60, 20, 25)
	pip.BorderSizePixel = 0
	pip.Parent = coreHud
	Round(pip, 4)
	pips[i] = pip
end

local function UpdateCoreHud()
	local hits = core:GetAttribute("Hits") or 0
	for i, pip in pips do
		pip.BackgroundColor3 = if i <= hits then Color3.fromRGB(255, 50, 50) else Color3.fromRGB(60, 20, 25)
	end
end
core:GetAttributeChangedSignal("Hits"):Connect(UpdateCoreHud)
UpdateCoreHud()

local function RefreshMenu()
	toggleTitle.Text = if isBuildingMode then "BUILDING" else "BUILD"
	toggleTitle.TextColor3 = if isBuildingMode then ACTIVE else ACCENT
	toggleStroke.Color = if isBuildingMode then ACTIVE else ACCENT
	toggle.BackgroundColor3 = if isBuildingMode then Color3.fromRGB(16, 50, 30) else Color3.fromRGB(14, 30, 55)
	toggleHint.Text = if isBuildingMode then "[B] EXIT" else "[B]"
	hint.Visible = isBuildingMode

	for index, slot in slots do
		local selected = isBuildingMode and index == selectedOptionIndex
		slot.stroke.Thickness = if selected then 3 else 1.5
		slot.stroke.Transparency = if selected then 0 else 0.6
		slot.button.BackgroundColor3 = if selected then Color3.fromRGB(28, 40, 66) else Color3.fromRGB(14, 22, 40)
		TweenService:Create(slot.scale, TweenInfo.new(0.12), {Scale = if selected then 1.06 else 1}):Play()
	end
end

local function SetBuildingMode(on)
	isBuildingMode = on
	RefreshMenu()
end

local function SelectOption(index)
	selectedOptionIndex = index
	SetBuildingMode(true)
end

toggle.MouseButton1Click:Connect(function()
	SetBuildingMode(not isBuildingMode)
end)

for index, slot in slots do
	slot.button.MouseButton1Click:Connect(function()
		SelectOption(index)
	end)
	slot.button.MouseEnter:Connect(function()
		if not (isBuildingMode and index == selectedOptionIndex) then
			TweenService:Create(slot.scale, TweenInfo.new(0.1), {Scale = 1.03}):Play()
		end
	end)
	slot.button.MouseLeave:Connect(RefreshMenu)
end

RefreshMenu()

-------------------------------------------------------------------------
-- PLACEMENT
-------------------------------------------------------------------------

-- MATEMATIIKKA: Pakottaa sijainnin osumaan ruudukkoon
local function SnapToGrid(pos)
	return Vector3.new(
		math.floor(pos.X / gridSize + 0.5) * gridSize,
		pos.Y,
		math.floor(pos.Z / gridSize + 0.5) * gridSize
	)
end

local function IsBlocked(position, size)
	if math.abs(position.X) > BuildPieces.ARENA_HALF_EXTENT or math.abs(position.Z) > BuildPieces.ARENA_HALF_EXTENT then
		return true
	end
	local reach = BuildPieces.KEEP_CLEAR_RADIUS + math.max(size.X, size.Z) / 2
	for _, spot in keepClear do
		if Vector3.new(position.X - spot.X, 0, position.Z - spot.Z).Magnitude < reach then
			return true
		end
	end
	return false
end

local function UpdatePreview()
	if not isBuildingMode then
		if previewPart then
			previewPart:Destroy()
			previewPart = nil
		end
		return
	end

	if not previewPart then
		previewPart = Instance.new("Part")
		previewPart.Name = "GhostPreview"
		previewPart.Anchored = true
		previewPart.CanCollide = false
		previewPart.CanQuery = false -- Orb raycasts ignore the ghost preview
		previewPart.CanTouch = false
		previewPart.Transparency = 0.5
		previewPart.Material = Enum.Material.Neon
		previewPart.Parent = wallsFolder
	end

	local currentOption = buildOptions[selectedOptionIndex]
	previewPart.Size = currentOption.size
	previewPart.BrickColor = currentOption.color

	if mouse.Target and mouse.Target.Name == "Baseplate" then
		-- Lasketaan tarkka Y-korkeus, jotta palikka istuu aina maassa
		local targetY = mouse.Target.Position.Y + (mouse.Target.Size.Y / 2) + (currentOption.size.Y / 2)
		local rawPos = Vector3.new(mouse.Hit.Position.X, targetY, mouse.Hit.Position.Z)

		-- Napsautetaan ruudukkoon!
		local snappedPos = SnapToGrid(rawPos)

		previewPart.CFrame = CFrame.new(snappedPos) * CFrame.Angles(0, math.rad(currentRotation), 0)
		previewPart.Parent = wallsFolder

		if IsBlocked(snappedPos, currentOption.size) then
			previewPart.BrickColor = BLOCKED_COLOR
		end
	else
		previewPart.Parent = nil
	end
end

RunService.RenderStepped:Connect(UpdatePreview)

-- The server checks the same rules and creates the real piece
local function PlacePiece()
	if isBuildingMode and previewPart and previewPart.Parent == wallsFolder then
		if IsBlocked(previewPart.Position, previewPart.Size) then return end
		placePieceRemote:FireServer(selectedOptionIndex, previewPart.Position, currentRotation)
	end
end

-- gameProcessed is true when the click lands on the menu, so menu clicks never place a piece
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not GameState.Is(GameState.Phases.RTS) then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		PlacePiece()
	elseif input.KeyCode == Enum.KeyCode.B then
		SetBuildingMode(not isBuildingMode)
	elseif input.KeyCode == Enum.KeyCode.R and isBuildingMode then
		currentRotation = (currentRotation + 90) % 360
	else
		for index, option in buildOptions do
			if input.KeyCode == option.key then
				SelectOption(index)
			end
		end
	end
end)

-- The RTS phase is over: hide the build UI (the server turns the walls into concrete)
GameState.OnPhase(GameState.Phases.FakeVictory, function()
	gui.Enabled = false
	isBuildingMode = false

	if previewPart then
		previewPart:Destroy()
		previewPart = nil
	end
end)
