-- RTS build menu and piece placement. The server (WallService) owns the real pieces and checks every rule.
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera

local GameState = require(ReplicatedStorage:WaitForChild("GameState"))
local BuildPieces = require(ReplicatedStorage:WaitForChild("BuildPieces"))
local ArenaLayout = require(ReplicatedStorage:WaitForChild("ArenaLayout"))
local SoundFx = require(ReplicatedStorage:WaitForChild("SoundFx"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local placePieceRemote = remotes:WaitForChild("PlacePiece")
local removePieceRemote = remotes:WaitForChild("RemovePiece")

local gui = script.Parent

-- The server owns these folders (so the Hunter sees the maze)
local wallsFolder = workspace:WaitForChild("RTSWalls")
local arena = workspace:WaitForChild("Arena")
local baseplate = workspace:WaitForChild("Baseplate")

local buildOptions = BuildPieces.Pieces
local gridSize = BuildPieces.GRID_SIZE -- Palikat lukittuvat ruudukkoon 2 studin tarkkuudella

local MODE_OFF, MODE_BUILD, MODE_REMOVE = "Off", "Build", "Remove"
local mode = MODE_OFF
local currentRotation = 0
local selectedOptionIndex = 1
local previewPart = nil
local pointerScreen = nil -- Last pointer position on screen, as {x, y, isTouch}

local BLOCKED_COLOR = BrickColor.new("Really red")
local REMOVE_COLOR = Color3.fromRGB(255, 60, 60)

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

local function Button(parent, name, order, width)
	local button = Instance.new("TextButton")
	button.Name = name
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(width, 104)
	button.BackgroundColor3 = Color3.fromRGB(14, 22, 40)
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = parent
	Round(button, 10)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	return button, scale
end

gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

-- Shrinks the whole menu on small screens
local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function UpdateScale()
	local viewport = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(viewport.X / 1200, viewport.Y / 720), 0.5, 1.2)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
UpdateScale()

-- Bottom bar
local bar = Instance.new("Frame")
bar.Name = "BuildBar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -24)
bar.Size = UDim2.fromOffset(780, 128)
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

local function Divider(order)
	local divider = Instance.new("Frame")
	divider.LayoutOrder = order
	divider.Size = UDim2.fromOffset(2, 90)
	divider.BackgroundColor3 = ACCENT
	divider.BackgroundTransparency = 0.6
	divider.BorderSizePixel = 0
	divider.Parent = bar
end

-- Build mode toggle
local toggle = Button(bar, "BuildWallButton", 0, 120)
toggle.BackgroundColor3 = Color3.fromRGB(14, 30, 55)
local toggleStroke = Stroke(toggle, ACCENT, 2)
local toggleTitle = Label(toggle, "BUILD", TITLE_FONT, ACCENT, UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 22))
local toggleHint = Label(toggle, "[B]", HINT_FONT, Color3.fromRGB(150, 190, 220), UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 64))

Divider(1)

-- Piece slots
local slots = {}
for index, option in buildOptions do
	local slot, slotScale = Button(bar, option.name .. "Slot", 1 + index, 120)
	local stroke = Stroke(slot, option.color.Color, 1.5, 0.6)

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
	swatch.Size = if option.shape == Enum.PartType.Ball then UDim2.fromOffset(40, 40)
		else UDim2.fromOffset(math.max(8, 56 * footprint.X / longest), math.max(8, 44 * footprint.Y / longest))
	swatch.BackgroundColor3 = option.color.Color
	swatch.BorderSizePixel = 0
	swatch.Parent = slot
	Round(swatch, if option.shape == Enum.PartType.Ball then 100 else 3)
	Stroke(swatch, Color3.new(1, 1, 1), 1, 0.5)

	Label(slot, string.upper(option.name), BODY_FONT, Color3.fromRGB(225, 240, 255), UDim2.new(1, -12, 0, 16), UDim2.new(0, 6, 1, -26))

	slots[index] = {button = slot, stroke = stroke, scale = slotScale}
end

Divider(10)

-- Rotate and remove (also the touch-friendly way to do R and right-click)
local rotateButton = Button(bar, "RotateButton", 11, 90)
Stroke(rotateButton, ACCENT, 1.5, 0.5)
Label(rotateButton, BuildPieces.ROTATION_STEP .. "°", TITLE_FONT, ACCENT, UDim2.new(1, -16, 0, 40), UDim2.fromOffset(8, 16))
Label(rotateButton, "ROTATE [R]", HINT_FONT, Color3.fromRGB(150, 190, 220), UDim2.new(1, -12, 0, 14), UDim2.new(0, 6, 1, -26))

local removeButton = Button(bar, "RemoveButton", 12, 90)
local removeStroke = Stroke(removeButton, REMOVE_COLOR, 1.5, 0.5)
Label(removeButton, "DEL", TITLE_FONT, REMOVE_COLOR, UDim2.new(1, -16, 0, 40), UDim2.fromOffset(8, 16))
Label(removeButton, "REMOVE [X]", HINT_FONT, Color3.fromRGB(220, 170, 170), UDim2.new(1, -12, 0, 14), UDim2.new(0, 6, 1, -26))

-- Piece budget above the bar, on the right
local budgetLabel = Label(gui, "", TITLE_FONT, Color3.fromRGB(225, 240, 255), UDim2.fromOffset(200, 22), UDim2.new(0.5, 190, 1, -178))
budgetLabel.TextXAlignment = Enum.TextXAlignment.Right
budgetLabel.TextStrokeTransparency = 0.4

-- Controls hint above the bar
local hint = Label(gui, "", HINT_FONT, Color3.fromRGB(170, 220, 255), UDim2.fromOffset(560, 18), UDim2.new(0.5, -110, 1, -176))
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.TextStrokeTransparency = 0.4

-- Short red message when the server refuses a piece
local toast = Label(gui, "", BODY_FONT, Color3.fromRGB(255, 110, 110), UDim2.fromOffset(600, 24), UDim2.new(0.5, 0, 1, -214))
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.TextStrokeTransparency = 0.3
toast.Visible = false
local toastToken = 0
local function ShowToast(text)
	SoundFx.Play("Refused", {volume = 0.4, speed = 0.7})
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.Visible = true
	task.delay(2.2, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end
placePieceRemote.OnClientEvent:Connect(ShowToast)

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

-- One pip per hit needed; the number changes with the level
local function BuildPips()
	for _, pip in pips do
		pip:Destroy()
	end
	table.clear(pips)
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
end
BuildPips()

local function UpdateCoreHud()
	local hits = core:GetAttribute("Hits") or 0
	for i, pip in pips do
		pip.BackgroundColor3 = if i <= hits then Color3.fromRGB(255, 50, 50) else Color3.fromRGB(60, 20, 25)
	end
end
core:GetAttributeChangedSignal("Hits"):Connect(UpdateCoreHud)
core:GetAttributeChangedSignal("HitsRequired"):Connect(function()
	BuildPips()
	UpdateCoreHud()
end)
UpdateCoreHud()

local function PiecesLeft()
	return ArenaLayout.BUDGET - #wallsFolder:GetChildren() + (if previewPart and previewPart.Parent == wallsFolder then 1 else 0)
end

local function UpdateBudget()
	local left = PiecesLeft()
	budgetLabel.Text = "PIECES " .. left .. " / " .. ArenaLayout.BUDGET
	budgetLabel.TextColor3 = if left == 0 then Color3.fromRGB(255, 110, 110) else Color3.fromRGB(225, 240, 255)
end

local function RefreshMenu()
	local building = mode == MODE_BUILD
	toggleTitle.Text = if building then "BUILDING" else "BUILD"
	toggleTitle.TextColor3 = if building then ACTIVE else ACCENT
	toggleStroke.Color = if building then ACTIVE else ACCENT
	toggle.BackgroundColor3 = if building then Color3.fromRGB(16, 50, 30) else Color3.fromRGB(14, 30, 55)
	toggleHint.Text = if building then "[B] EXIT" else "[B]"

	for index, slot in slots do
		local selected = building and index == selectedOptionIndex
		slot.stroke.Thickness = if selected then 3 else 1.5
		slot.stroke.Transparency = if selected then 0 else 0.6
		slot.button.BackgroundColor3 = if selected then Color3.fromRGB(28, 40, 66) else Color3.fromRGB(14, 22, 40)
		TweenService:Create(slot.scale, TweenInfo.new(0.12), {Scale = if selected then 1.06 else 1}):Play()
	end

	local removing = mode == MODE_REMOVE
	removeStroke.Thickness = if removing then 3 else 1.5
	removeStroke.Transparency = if removing then 0 else 0.5
	removeButton.BackgroundColor3 = if removing then Color3.fromRGB(60, 18, 22) else Color3.fromRGB(14, 22, 40)

	local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	if building then
		hint.Text = if touch then "TAP TO PLACE  |  DRAG TO MOVE" else "LMB PLACE  |  RMB REMOVE  |  R ROTATE  |  B EXIT"
	elseif removing then
		hint.Text = if touch then "TAP A PIECE TO REMOVE IT" else "LMB REMOVE  |  X EXIT"
	else
		hint.Text = if touch then "DRAG TO MOVE  |  PINCH TO ZOOM" else "WASD MOVE  |  WHEEL ZOOM  |  B BUILD"
	end
	UpdateBudget()
end

local function SetMode(newMode)
	mode = newMode
	RefreshMenu()
end

local function SelectOption(index)
	SoundFx.Play("UiClick", {volume = 0.3})
	selectedOptionIndex = index
	SetMode(MODE_BUILD)
end

local function Rotate()
	currentRotation = (currentRotation + BuildPieces.ROTATION_STEP) % 360
end

toggle.MouseButton1Click:Connect(function()
	SetMode(if mode == MODE_BUILD then MODE_OFF else MODE_BUILD)
end)
rotateButton.MouseButton1Click:Connect(Rotate)
removeButton.MouseButton1Click:Connect(function()
	SetMode(if mode == MODE_REMOVE then MODE_OFF else MODE_REMOVE)
end)

for index, slot in slots do
	slot.button.MouseButton1Click:Connect(function()
		SelectOption(index)
	end)
	slot.button.MouseEnter:Connect(function()
		if not (mode == MODE_BUILD and index == selectedOptionIndex) then
			TweenService:Create(slot.scale, TweenInfo.new(0.1), {Scale = 1.03}):Play()
		end
	end)
	slot.button.MouseLeave:Connect(RefreshMenu)
end

wallsFolder.ChildAdded:Connect(UpdateBudget)
wallsFolder.ChildRemoved:Connect(function(part)
	UpdateBudget()
	if part.Name ~= "GhostPreview" and GameState.Is(GameState.Phases.RTS) then
		SoundFx.Play("PieceRemoved", {volume = 0.5})
	end
end)
RefreshMenu()

-------------------------------------------------------------------------
-- POINTER: where the mouse or the last tap points in the world
-------------------------------------------------------------------------
local function PointerRay()
	if pointerScreen and pointerScreen.isTouch then
		return camera:ScreenPointToRay(pointerScreen.x, pointerScreen.y)
	end
	local mouseLocation = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
end

local function RaycastPointer(include)
	local ray = PointerRay()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	return workspace:Raycast(ray.Origin, ray.Direction * 500, params)
end

local function PieceUnderPointer()
	local result = RaycastPointer({wallsFolder})
	if result and result.Instance.Parent == wallsFolder and result.Instance ~= previewPart then
		return result.Instance
	end
	return nil
end

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

-- Same checks as the server except the escape path, which only the server runs
-- Probe shaped like the piece for an exact overlap test (works for turned pieces too)
local probe = Instance.new("Part")
probe.Name = "OverlapProbe"
probe.Anchored = true
probe.CanCollide = false
probe.CanQuery = false
probe.CanTouch = false
probe.Transparency = 1

local function IsBlocked(position, footprint)
	if position.X - footprint.X / 2 < -ArenaLayout.HALF_X or position.X + footprint.X / 2 > ArenaLayout.HALF_X
		or position.Z - footprint.Z / 2 < -ArenaLayout.HALF_Z or position.Z + footprint.Z / 2 > ArenaLayout.HALF_Z then
		return true
	end
	local reach = BuildPieces.KEEP_CLEAR_RADIUS + math.max(footprint.X, footprint.Z) / 2
	for _, spot in ArenaLayout.KeepClearSpots() do
		if Vector3.new(position.X - spot.X, 0, position.Z - spot.Z).Magnitude < reach then
			return true
		end
	end
	for _, bumper in ArenaLayout.BUMPERS do
		local sweep = bumper.length / 2 + 1 + math.max(footprint.X, footprint.Z) / 2
		if Vector3.new(position.X - bumper.position.X, 0, position.Z - bumper.position.Z).Magnitude < sweep then
			return true
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {wallsFolder, arena}
	local size = buildOptions[selectedOptionIndex].size
	probe.Size = Vector3.new(size.X - 0.2, 1, size.Z - 0.2) -- Touching edges is fine
	probe.CFrame = CFrame.new(position.X, 1, position.Z) * CFrame.Angles(0, math.rad(currentRotation), 0)
	probe.Parent = workspace
	local hits = workspace:GetPartsInPart(probe, params)
	probe.Parent = nil
	for _, hit in hits do
		if hit ~= previewPart and hit.CanCollide then
			return true
		end
	end
	return PiecesLeft() <= 0
end

local highlight = Instance.new("Highlight")
highlight.FillColor = REMOVE_COLOR
highlight.OutlineColor = REMOVE_COLOR
highlight.FillTransparency = 0.5
highlight.DepthMode = Enum.HighlightDepthMode.Occluded

local function UpdatePreview()
	-- Remove mode: highlight the piece under the pointer
	if mode == MODE_REMOVE then
		highlight.Adornee = PieceUnderPointer()
		highlight.Parent = if highlight.Adornee then workspace else nil
	else
		highlight.Parent = nil
	end

	if mode ~= MODE_BUILD then
		if previewPart then
			previewPart:Destroy()
			previewPart = nil
			UpdateBudget()
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
	end

	local currentOption = buildOptions[selectedOptionIndex]
	previewPart.Shape = currentOption.shape or Enum.PartType.Block
	previewPart.Size = currentOption.size
	previewPart.BrickColor = currentOption.color

	local result = RaycastPointer({baseplate})
	if result then
		-- Lasketaan tarkka Y-korkeus, jotta palikka istuu aina maassa
		local floorY = baseplate.Position.Y + baseplate.Size.Y / 2
		local snappedPos = SnapToGrid(Vector3.new(result.Position.X, floorY + currentOption.size.Y / 2, result.Position.Z))

		previewPart.CFrame = CFrame.new(snappedPos) * CFrame.Angles(0, math.rad(currentRotation), 0)
		previewPart.Parent = wallsFolder

		if IsBlocked(snappedPos, BuildPieces.Footprint(currentOption.size, currentRotation)) then
			previewPart.BrickColor = BLOCKED_COLOR
		end
	else
		previewPart.Parent = nil
	end
end

RunService.RenderStepped:Connect(UpdatePreview)

-- The server checks the same rules and creates the real piece
local function PlacePiece()
	if mode ~= MODE_BUILD or not previewPart or previewPart.Parent ~= wallsFolder then return end
	if PiecesLeft() <= 0 then
		ShowToast("No pieces left. Right-click a piece to remove it.")
		return
	end
	if IsBlocked(previewPart.Position, BuildPieces.Footprint(previewPart.Size, currentRotation)) then return end
	placePieceRemote:FireServer(selectedOptionIndex, previewPart.Position, currentRotation)
end

local function RemovePieceUnderPointer()
	local piece = PieceUnderPointer()
	if piece then
		removePieceRemote:FireServer(piece)
	end
end

-- New pieces pop into place
wallsFolder.ChildAdded:Connect(function(part)
	if not part:IsA("BasePart") or part == previewPart or part.Name == "GhostPreview" then return end
	SoundFx.Play("PiecePlaced", {volume = 0.5, speed = 0.9 + math.random() * 0.2})
	local fullSize = part.Size
	part.Size = fullSize * Vector3.new(0.6, 0.2, 0.6)
	TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = fullSize}):Play()
end)

-------------------------------------------------------------------------
-- INPUT
-------------------------------------------------------------------------
local TAP_MAX_MOVE = 12 -- Pixels a finger may move and still count as a tap
local TAP_MAX_SECONDS = 0.35
local touchStarts = {}

-- gameProcessed is true when the click lands on the menu, so menu clicks never place a piece
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not GameState.Is(GameState.Phases.RTS) then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		pointerScreen = nil
		if mode == MODE_BUILD then
			PlacePiece()
		elseif mode == MODE_REMOVE then
			RemovePieceUnderPointer()
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		pointerScreen = nil
		RemovePieceUnderPointer()
	elseif input.UserInputType == Enum.UserInputType.Touch then
		touchStarts[input] = {position = input.Position, time = os.clock()}
	elseif input.KeyCode == Enum.KeyCode.B then
		SetMode(if mode == MODE_BUILD then MODE_OFF else MODE_BUILD)
	elseif input.KeyCode == Enum.KeyCode.X then
		SetMode(if mode == MODE_REMOVE then MODE_OFF else MODE_REMOVE)
	elseif input.KeyCode == Enum.KeyCode.R then
		Rotate()
	else
		for index, option in buildOptions do
			if input.KeyCode == option.key then
				SelectOption(index)
			end
		end
	end
end)

-- A short tap places (or removes) where the finger was; a drag moves the camera instead (CameraManager)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch and mode == MODE_BUILD then
		pointerScreen = {x = input.Position.X, y = input.Position.Y, isTouch = true}
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Touch then return end
	local start = touchStarts[input]
	touchStarts[input] = nil
	if not start or not GameState.Is(GameState.Phases.RTS) then return end
	if (input.Position - start.position).Magnitude > TAP_MAX_MOVE or os.clock() - start.time > TAP_MAX_SECONDS then return end

	pointerScreen = {x = input.Position.X, y = input.Position.Y, isTouch = true}
	UpdatePreview()
	if mode == MODE_BUILD then
		PlacePiece()
	elseif mode == MODE_REMOVE then
		RemovePieceUnderPointer()
	end
end)

-- The build UI only shows while building (not in the main menu, not after the twist)
local function LeaveBuilding()
	mode = MODE_OFF
	highlight.Parent = nil
	if previewPart then
		previewPart:Destroy()
		previewPart = nil
	end
end

gui.Enabled = GameState.Is(GameState.Phases.RTS)

GameState.Changed:Connect(function(newPhase)
	gui.Enabled = newPhase == GameState.Phases.RTS
	if newPhase == GameState.Phases.RTS then
		RefreshMenu()
		UpdateCoreHud()
	else
		LeaveBuilding()
	end
end)

GameState.Resetting:Connect(LeaveBuilding)
