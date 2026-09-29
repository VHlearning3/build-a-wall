local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

local gui = script.Parent
local buildWallButton = gui:WaitForChild("BuildWallButton")

local isBuildingMode = false
local currentRotation = 0
local gridSize = 2 -- Palikat lukittuvat ruudukkoon 2 studin tarkkuudella

-- LUODAAN KANSIO SEINILLE (Hiiri ohittaa tämän kansion, joten voit rakentaa seinien viereen helposti)
local wallsFolder = workspace:FindFirstChild("RTSWalls")
if not wallsFolder then
	wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "RTSWalls"
	wallsFolder.Parent = workspace
end
mouse.TargetFilter = wallsFolder -- Taikasana: hiiri osuu nyt aina maahan seinien läpi!

local buildOptions = {
	{name = "Wall", size = Vector3.new(12, 10, 2), color = BrickColor.new("Neon orange")},
	{name = "Tower", size = Vector3.new(4, 10, 4), color = BrickColor.new("Cyan")},
	{name = "Floor Obstacle", size = Vector3.new(10, 2, 10), color = BrickColor.new("Magenta")}
}
local selectedOptionIndex = 1
local previewPart = nil

-- MATEMATIIKKA: Pakottaa sijainnin osumaan ruudukkoon
local function SnapToGrid(pos)
	return Vector3.new(
		math.floor(pos.X / gridSize + 0.5) * gridSize,
		pos.Y,
		math.floor(pos.Z / gridSize + 0.5) * gridSize
	)
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
	else
		previewPart.Parent = nil
	end
end

RunService.RenderStepped:Connect(UpdatePreview)

buildWallButton.MouseButton1Click:Connect(function()
	isBuildingMode = not isBuildingMode
	if isBuildingMode then
		buildWallButton.Text = "BUILD MODE\n(1,2,3 Switch | R Rotate)"
		buildWallButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
	else
		buildWallButton.Text = "Build a wall"
		buildWallButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	end
end)

mouse.Button1Down:Connect(function()
	if isBuildingMode and previewPart and previewPart.Parent == wallsFolder then
		local newWall = Instance.new("Part")
		newWall.Name = "Wall"
		newWall.Size = previewPart.Size
		newWall.Anchored = true
		newWall.BrickColor = previewPart.BrickColor
		newWall.Material = Enum.Material.Neon
		newWall.CFrame = previewPart.CFrame
		newWall.Parent = wallsFolder -- Varsinainen seinä menee kansioon
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if isBuildingMode then
		if input.KeyCode == Enum.KeyCode.R then
			currentRotation = (currentRotation + 90) % 360
		elseif input.KeyCode == Enum.KeyCode.One then
			selectedOptionIndex = 1
		elseif input.KeyCode == Enum.KeyCode.Two then
			selectedOptionIndex = 2
		elseif input.KeyCode == Enum.KeyCode.Three then
			selectedOptionIndex = 3
		end
	end
end)

local GameState = require(game.ReplicatedStorage:WaitForChild("GameState"))

-- The RTS phase is over: hide the build UI and turn the neon walls into concrete
GameState.OnPhase(GameState.Phases.FakeVictory, function()
	gui.Enabled = false
	isBuildingMode = false

	if previewPart then
		previewPart:Destroy()
		previewPart = nil
	end

	-- Muutetaan nyt kansion sisällä olevat seinät
	for _, part in pairs(wallsFolder:GetChildren()) do
		if part:IsA("Part") and part.Material == Enum.Material.Neon then
			part.Material = Enum.Material.Concrete
			part.BrickColor = BrickColor.new("Dark stone grey")
		end
	end
end)
