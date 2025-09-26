local NinjaQuestUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local function createCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function createStroke(parent, thickness, color)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 1
	stroke.Color = color or Color3.fromRGB(100, 100, 100)
	stroke.Parent = parent
	return stroke
end

local function createGlow(parent, size, transparency)
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.Size = UDim2.new(1, size or 20, 1, size or 20)
	glow.Position = UDim2.new(0, -(size or 20) / 2, 0, -(size or 20) / 2)
	glow.BackgroundTransparency = 1
	glow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
	glow.ImageColor3 = Color3.fromRGB(100, 50, 200)
	glow.ImageTransparency = transparency or 0.85
	glow.ZIndex = parent.ZIndex - 1
	glow.Parent = parent
	return glow
end

function NinjaQuestUI.init(parent, baseY)
	local questRoot = Instance.new("Frame")
	questRoot.Name = "NinjaQuestUIRoot"
	questRoot.Size = UDim2.fromScale(1, 1)
	questRoot.BackgroundTransparency = 1
	questRoot.ZIndex = 5
	questRoot.Parent = parent

	local previewCard = Instance.new("Frame")
	previewCard.Name = "CharacterPreview"
	previewCard.BackgroundTransparency = 0.1
	previewCard.Size = UDim2.new(0.49, -20, 0.74, 0)
	previewCard.Position = UDim2.fromOffset(20, baseY + 80)
	previewCard.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	previewCard.BorderSizePixel = 0
	previewCard.ZIndex = 5
	previewCard.Parent = questRoot
	createCorner(previewCard, 12)
	createStroke(previewCard, 2, Color3.fromRGB(60, 60, 80))
	createGlow(previewCard, 24, 0.94)

	local previewHeader = Instance.new("Frame")
	previewHeader.Size = UDim2.new(1, 0, 0, 45)
	previewHeader.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	previewHeader.BackgroundTransparency = 0.3
	previewHeader.BorderSizePixel = 0
	previewHeader.ZIndex = 6
	previewHeader.Parent = previewCard
	createCorner(previewHeader, 12)

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Size = UDim2.new(1, -20, 1, 0)
	headerTitle.Position = UDim2.new(0, 20, 0, 0)
	headerTitle.BackgroundTransparency = 1
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Text = "🎭 Character Preview"
	headerTitle.Font = Enum.Font.GothamBold
	headerTitle.TextScaled = true
	headerTitle.TextColor3 = Color3.fromRGB(220, 180, 100)
	headerTitle.ZIndex = 7
	headerTitle.Parent = previewHeader

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "QuestCloseButton"
	closeButton.Size = UDim2.new(0, 32, 0, 32)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -20, 0, 16)
	closeButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
	closeButton.BackgroundTransparency = 0
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextScaled = true
	closeButton.Text = "X"
	closeButton.AutoButtonColor = true
	closeButton.ZIndex = 8
	closeButton.BorderSizePixel = 0
	closeButton.Parent = previewHeader
	createCorner(closeButton, 10)

	local emoteContainer = Instance.new("ScrollingFrame")
	emoteContainer.Name = "EmoteButtonRow"
	emoteContainer.Size = UDim2.new(1, -20, 0, 46)
	emoteContainer.Position = UDim2.new(0, 10, 0, 55)
	emoteContainer.BackgroundTransparency = 1
	emoteContainer.ZIndex = 6
	emoteContainer.ScrollingDirection = Enum.ScrollingDirection.X
	emoteContainer.AutomaticCanvasSize = Enum.AutomaticSize.X
	emoteContainer.CanvasSize = UDim2.new(0, 0, 0, 46)
	emoteContainer.ScrollBarThickness = 4
	emoteContainer.ClipsDescendants = true
	emoteContainer.Parent = previewCard

	local emoteLayout = Instance.new("UIListLayout")
	emoteLayout.FillDirection = Enum.FillDirection.Horizontal
	emoteLayout.Padding = UDim.new(0, 8)
	emoteLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	emoteLayout.SortOrder = Enum.SortOrder.LayoutOrder
	emoteLayout.Parent = emoteContainer

	local function createEmoteButton(text, icon)
		local btn = Instance.new("TextButton")
		btn.Name = text .. "Button"
		btn.Size = UDim2.new(0, 110, 0, 40)
		btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		btn.BackgroundTransparency = 0.2
		btn.TextColor3 = Color3.fromRGB(200, 200, 220)
		btn.Font = Enum.Font.GothamSemibold
		btn.TextScaled = true
		btn.AutoButtonColor = true
		btn.Text = (icon or "⚫") .. " " .. text
		btn.BorderSizePixel = 0
		btn.ZIndex = 8
		btn.Parent = emoteContainer
		createCorner(btn, 8)
		createStroke(btn, 1, Color3.fromRGB(60, 60, 80))

		local glow = Instance.new("Frame")
		glow.Size = UDim2.new(1, 4, 1, 4)
		glow.Position = UDim2.new(0, -2, 0, -2)
		glow.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
		glow.BackgroundTransparency = 0.9
		glow.BorderSizePixel = 0
		glow.ZIndex = 7
		glow.Parent = btn
		createCorner(glow, 10)

		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(80, 50, 120)
			btn.BackgroundTransparency = 0.1
			glow.BackgroundTransparency = 0.7
		end)

		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
			btn.BackgroundTransparency = 0.2
			glow.BackgroundTransparency = 0.9
		end)

		return btn
	end

	local viewportContainer = Instance.new("Frame")
	viewportContainer.Size = UDim2.new(1, -10, 1, -115)
	viewportContainer.Position = UDim2.new(0, 5, 0, 105)
	viewportContainer.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
	viewportContainer.BackgroundTransparency = 0.3
	viewportContainer.BorderSizePixel = 0
	viewportContainer.ZIndex = 6
	viewportContainer.Parent = previewCard
	createCorner(viewportContainer, 8)
	createStroke(viewportContainer, 1, Color3.fromRGB(40, 40, 60))

	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, -4, 1, -4)
	viewport.Position = UDim2.new(0, 2, 0, 2)
	viewport.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
	viewport.BackgroundTransparency = 0.2
	viewport.BorderSizePixel = 0
	viewport.ZIndex = 7
	viewport.Active = true
	viewport.Selectable = false
	viewport.Parent = viewportContainer
	createCorner(viewport, 6)

	local controlsLabel = Instance.new("TextLabel")
	controlsLabel.Size = UDim2.new(1, -10, 0, 25)
	controlsLabel.Position = UDim2.new(0, 5, 1, -30)
	controlsLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	controlsLabel.BackgroundTransparency = 0.3
	controlsLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
	controlsLabel.Font = Enum.Font.Gotham
	controlsLabel.TextScaled = true
	controlsLabel.Text = "🖱️ Drag to rotate • 🖲️ Scroll to zoom"
	controlsLabel.ZIndex = 8
	controlsLabel.BorderSizePixel = 0
	controlsLabel.Parent = previewCard
	createCorner(controlsLabel, 6)

	-- Orbitable viewport state
	local vpWorld, vpModel, vpCam, vpHumanoid, currentEmoteTrack
	local orbit = {
		yaw = math.pi,
		pitch = 0.1,
		dist = 10,
		min = 4,
		max = 40,
		center = Vector3.new(),
		dragging = false,
	}

	local function updateVPCamera()
		if not vpCam then
			return
		end

		local dir = CFrame.fromEulerAnglesYXZ(orbit.pitch, orbit.yaw, 0).LookVector
		local camPos = orbit.center - dir * orbit.dist
		vpCam.CFrame = CFrame.new(camPos, orbit.center)
	end

	local function setControlsDefault()
		controlsLabel.Text = "🖱️ Drag to rotate • 🖲️ Scroll to zoom"
		controlsLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
	end

	local function hookViewportControls()
		viewport.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				orbit.dragging = true
				controlsLabel.Text = "🔄 Rotating character..."
				controlsLabel.TextColor3 = Color3.fromRGB(100, 200, 150)
			end
		end)

		viewport.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				orbit.dragging = false
				setControlsDefault()
			end
		end)

		viewport.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement and orbit.dragging then
				local d = input.Delta
				orbit.yaw -= d.X * 0.01
				orbit.pitch = math.clamp(orbit.pitch - d.Y * 0.01, -1.2, 1.2)
				updateVPCamera()
			elseif input.UserInputType == Enum.UserInputType.MouseWheel then
				local scroll = input.Position.Z
				orbit.dist = math.clamp(orbit.dist - scroll * 1.5, orbit.min, orbit.max)
				updateVPCamera()
				controlsLabel.Text = "🔍 Zooming... Distance: " .. math.floor(orbit.dist)
				controlsLabel.TextColor3 = Color3.fromRGB(100, 200, 150)
				task.delay(0.5, function()
					if controlsLabel.Parent then
						setControlsDefault()
					end
				end)
			end
		end)
	end

	local function clearChildren(p)
		for _, c in ipairs(p:GetChildren()) do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
	end

	local function stopEmote()
		if currentEmoteTrack then
			currentEmoteTrack:Stop(0.1)
			currentEmoteTrack:Destroy()
			currentEmoteTrack = nil
		end
	end

	local NINJA_EMOTES = {
		Idle = {id = "rbxassetid://507766388", icon = "🧘", desc = "Meditation"},
		Bow = {id = "rbxassetid://507770239", icon = "🙇", desc = "Honor Bow"},
		Strike = {id = "rbxassetid://507770453", icon = "👊", desc = "Strike Pose"},
		Stealth = {id = "rbxassetid://507771019", icon = "🥷", desc = "Shadow Dance"},
		Victory = {id = "rbxassetid://507770818", icon = "🎉", desc = "Mission Complete"},
		Focus = {id = "rbxassetid://507770677", icon = "⚡", desc = "Inner Focus"},
	}

	local function playEmote(emoteName)
		local emoteData = NINJA_EMOTES[emoteName]
		if not (vpHumanoid and emoteData) then
			return
		end

		stopEmote()

		local anim = Instance.new("Animation")
		anim.AnimationId = emoteData.id
		currentEmoteTrack = vpHumanoid:LoadAnimation(anim)
		currentEmoteTrack.Looped = emoteName == "Idle" or emoteName == "Stealth"
		currentEmoteTrack:Play(0.1)

		headerTitle.Text = "🎭 " .. emoteData.desc .. " - " .. emoteData.icon
		task.delay(2, function()
			if headerTitle.Parent then
				headerTitle.Text = "🎭 Character Preview"
			end
		end)
	end

	local function wireEmoteButtons()
		local emoteOrder = {"Idle", "Bow", "Strike", "Stealth", "Victory", "Focus"}
		for _, emoteName in ipairs(emoteOrder) do
			local emoteData = NINJA_EMOTES[emoteName]
			local btn = createEmoteButton(emoteData.desc, emoteData.icon)
			btn.MouseButton1Click:Connect(function()
				task.spawn(function()
					playEmote(emoteName)
				end)
			end)
		end
	end

	local questController = {}
	questController.root = questRoot
	questController.closeButton = closeButton

	local function setVisible(visible)
		questRoot.Visible = visible and true or false
	end

	function questController:setVisible(visible)
		setVisible(visible)
	end

	function questController:isVisible()
		return questRoot.Visible
	end

	local function buildCharacterPreview(personaType)
		clearChildren(viewport)
		stopEmote()

		if viewport.CurrentCamera then
			viewport.CurrentCamera:Destroy()
			viewport.CurrentCamera = nil
		end

		vpWorld, vpModel, vpCam, vpHumanoid = nil, nil, nil, nil

		vpWorld = Instance.new("WorldModel")
		vpWorld.Parent = viewport

		local desc
		if personaType == "Ninja" then
			local hdFolder = ReplicatedStorage:FindFirstChild("HumanoidDescriptions")
				or ReplicatedStorage:FindFirstChild("HumanoidDescription")
			local hd = hdFolder and hdFolder:FindFirstChild("Ninja")
			if hd then
				desc = hd:Clone()
				headerTitle.Text = "🥷 Ninja Master Preview"
			end
		else
			local ok, hd = pcall(function()
				return Players:GetHumanoidDescriptionFromUserId(Players.LocalPlayer.UserId)
			end)
			if ok then
				desc = hd
				headerTitle.Text = "🎭 " .. Players.LocalPlayer.DisplayName .. "'s Avatar"
			end
		end

		if not desc then
			headerTitle.Text = "❌ Preview Unavailable"
			return
		end

		vpModel = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		vpModel:PivotTo(CFrame.new(0, 0, 0))

		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync({ vpModel })
			end)
		end)

		vpModel.Parent = vpWorld
		vpHumanoid = vpModel:FindFirstChildOfClass("Humanoid")

		local _, size = vpModel:GetBoundingBox()
		local radius = math.max(size.X, size.Y, size.Z)
		orbit.center = Vector3.new(0, size.Y * 0.5, 0)
		orbit.dist = math.clamp(radius * 1.8, 6, 20)
		orbit.min = math.max(3, radius * 0.8)
		orbit.max = radius * 4
		orbit.pitch = 0.15
		orbit.yaw = math.pi

		vpCam = Instance.new("Camera")
		vpCam.Parent = viewport
		viewport.CurrentCamera = vpCam
		updateVPCamera()

		if not viewport:GetAttribute("_controlsHooked") then
			hookViewportControls()
			viewport:SetAttribute("_controlsHooked", true)
		end

		task.delay(0.1, function()
			playEmote("Idle")
		end)
	end

	wireEmoteButtons()

	questController.buildCharacterPreview = buildCharacterPreview

	closeButton.MouseButton1Click:Connect(function()
		stopEmote()
		setVisible(false)
	end)

	return questController
end

return NinjaQuestUI
