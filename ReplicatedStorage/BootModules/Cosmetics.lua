local NinjaCosmetics = {}

-- ═══════════════════════════════════════════════════════════════
--                        CORE SERVICES
-- ═══════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")

-- ═══════════════════════════════════════════════════════════════
--                      CONFIGURATION
-- ═══════════════════════════════════════════════════════════════
local GameSettings = require(ReplicatedStorage.GameSettings)
local DEFAULT_SLOT_COUNT = tonumber(GameSettings.maxSlots) or 3

-- Ninja-themed color palette
local NINJA_COLORS = {
	PRIMARY = Color3.fromRGB(15, 15, 25),        -- Deep shadow black
	SECONDARY = Color3.fromRGB(25, 30, 45),      -- Midnight blue
	ACCENT = Color3.fromRGB(200, 150, 50),       -- Golden accent
	SUCCESS = Color3.fromRGB(80, 160, 80),       -- Forest green
	DANGER = Color3.fromRGB(180, 60, 60),        -- Blood red
	TEXT_PRIMARY = Color3.fromRGB(240, 240, 240), -- Almost white
	TEXT_SECONDARY = Color3.fromRGB(200, 200, 200), -- Light gray
	BORDER = Color3.fromRGB(60, 60, 80),         -- Subtle border
	GLOW = Color3.fromRGB(100, 150, 255)         -- Mystical blue glow
}

-- Animation settings
local ANIMATIONS = {
	FADE_TIME = 0.3,
	SCALE_TIME = 0.2,
	HOVER_SCALE = 1.08,
	CLICK_SCALE = 0.92,
	GLOW_PULSE_TIME = 2
}

-- ═══════════════════════════════════════════════════════════════
--                      PRIVATE VARIABLES
-- ═══════════════════════════════════════════════════════════════
local player = Players.LocalPlayer
local personaServiceRF = nil
local personaCache = {}
local currentChoiceType = "Ninja"
local chosenSlot = nil
local selectedPersonaLabel = nil
local levelValue = nil
local fallbackStarterBackpack = nil

-- UI References
local dojoInterface = nil
local slotButtons = {}
local uiBridge = nil
local rootUI = nil
local slotsContainer = nil

-- ═══════════════════════════════════════════════════════════════
--                     UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

-- Enhanced remote function getter with error handling
local function getPersonaRemote()
	if personaServiceRF and personaServiceRF.Parent then
		return personaServiceRF
	end

	personaServiceRF = ReplicatedStorage:FindFirstChild("PersonaServiceRF")
	if not personaServiceRF then
		personaServiceRF = ReplicatedStorage:WaitForChild("PersonaServiceRF", 5)
	end

	if not personaServiceRF then
		warn("🥷 NinjaCosmetics: PersonaServiceRF is missing from the shadows!")
	end

	return personaServiceRF
end

-- Enhanced remote function caller with performance monitoring
local function invokePersonaService(action, data)
	local remote = getPersonaRemote()
	if not remote then
		warn("🥷 NinjaCosmetics: Cannot reach the shadow realm for action:", action)
		return nil
	end

	local startTime = os.clock()
	local success, result = pcall(remote.InvokeServer, remote, action, data)

	if not success then
		warn(string.format("🥷 PersonaService:%s failed with shadow error: %s", tostring(action), tostring(result)))
		return nil
	end

	local executionTime = os.clock() - startTime
	if executionTime > 1 then
		warn(string.format("🥷 PersonaService:%s took %.3fs - the shadows are slow today", tostring(action), executionTime))
	end

	return result
end

-- Enhanced persona data sanitizer
local function sanitizePersonaData(data)
	local result = {}
	local slots = nil

	-- Extract slots data
	if typeof(data) == "table" then
		for key, value in pairs(data) do
			if key == "slots" and typeof(value) == "table" then
				slots = value
			elseif key ~= "slots" then
				result[key] = value
			end
		end

		-- Fallback: look for numeric keys as slots
		if not slots then
			for key, value in pairs(data) do
				local slotIndex = tonumber(key)
				if slotIndex then
					slots = slots or {}
					slots[slotIndex] = value
				end
			end
		end
	end

	result.slots = slots or {}

	-- Determine slot count
	local slotCount = tonumber(result.slotCount) or (typeof(data) == "table" and tonumber(data.slotCount))
	if not slotCount then
		local highestSlot = 0
		for key in pairs(result.slots) do
			local index = tonumber(key)
			if index and index > highestSlot then
				highestSlot = index
			end
		end
		slotCount = highestSlot
	end

	slotCount = math.max(slotCount or 0, 0)
	if slotCount == 0 and DEFAULT_SLOT_COUNT > 0 then
		slotCount = DEFAULT_SLOT_COUNT
	end

	result.slotCount = slotCount
	return result
end

-- ═══════════════════════════════════════════════════════════════
--                    PERSONA MANAGEMENT
-- ═══════════════════════════════════════════════════════════════

local function getPersonaDescription(personaType)
	if personaType == "Ninja" then
		local descriptionsFolder = ReplicatedStorage:FindFirstChild("HumanoidDescriptions") 
			or ReplicatedStorage:FindFirstChild("HumanoidDescription")
		local ninjaDescription = descriptionsFolder and descriptionsFolder:FindFirstChild("Ninja")
		return ninjaDescription and ninjaDescription:Clone()
	else
		local success, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		return success and description
	end
end

local function describeSelectedPersona()
	local personaType = currentChoiceType or "Ninja"
	local slotText = nil

	if chosenSlot and personaCache and personaCache.slots then
		local slotData = personaCache.slots[chosenSlot]
		if slotData then
			personaType = slotData.type or personaType
			slotText = slotData.name
		end
	end

	if not slotText or slotText == "" then
		if personaType == "Ninja" then
			slotText = "🥷 Shadow Warrior"
		elseif personaType == "Roblox" then
			slotText = "👤 Avatar Form"
		else
			slotText = personaType or "❓ Unknown"
		end
	end

	local prefix = chosenSlot and (getSlotDisplayName(chosenSlot) .. ": ") or ""
	return string.format("🌟 Active Persona - %s%s", prefix, slotText)
end

local function ensureValidSelection()
	if chosenSlot and personaCache and personaCache.slots and personaCache.slots[chosenSlot] then
		return -- Current selection is valid
	end

	chosenSlot = nil
	if not (personaCache and personaCache.slots) then
		currentChoiceType = currentChoiceType or "Ninja"
		return
	end

	-- Find first available slot
	local maxSlots = tonumber(personaCache.slotCount) or 0
	for slotIndex = 1, maxSlots do
		local slotData = personaCache.slots[slotIndex]
		if slotData ~= nil then
			chosenSlot = slotIndex
			currentChoiceType = slotData.type or currentChoiceType
			break
		end
	end

	if not chosenSlot then
		currentChoiceType = currentChoiceType or "Ninja"
	end
end

local function updateSelectedPersonaLabel()
	if selectedPersonaLabel then
		selectedPersonaLabel.Text = describeSelectedPersona()
	end
end

-- ═══════════════════════════════════════════════════════════════
--                    UI CREATION HELPERS
-- ═══════════════════════════════════════════════════════════════

local function createStyledFrame(parent, size, position, anchorPoint)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position or UDim2.fromScale(0, 0)
	frame.AnchorPoint = anchorPoint or Vector2.new(0, 0)
	frame.BackgroundColor3 = NINJA_COLORS.PRIMARY
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.ZIndex = 11
	frame.Parent = parent

	-- Enhanced glow effect with animation
	local glow = Instance.new("UIStroke")
	glow.Color = NINJA_COLORS.GLOW
	glow.Thickness = 2
	glow.Transparency = 0.5
	glow.Parent = frame

	-- Pulsing glow animation
	task.spawn(function()
		while glow and glow.Parent do
			local pulseTween = TweenService:Create(glow, 
				TweenInfo.new(ANIMATIONS.GLOW_PULSE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{Transparency = 0.2}
			)
			pulseTween:Play()
			task.wait(ANIMATIONS.GLOW_PULSE_TIME * 2)
		end
	end)

	-- Add rounded corners
	local corners = Instance.new("UICorner")
	corners.CornerRadius = UDim.new(0, 16)
	corners.Parent = frame

	-- Add gradient overlay for depth
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 200))
	}
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0.95)
	}
	gradient.Parent = frame

	return frame
end

local DEFAULT_FONT_FAMILY = "GothamSSm"
local DEFAULT_FONT_ASSET = "rbxasset://fonts/families/GothamSSm.json"

local function createNinjaButton(parent, text, size, position, color, onClick)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.Font = Enum.Font.GothamMedium
	button.TextScaled = true
	button.TextColor3 = NINJA_COLORS.TEXT_PRIMARY
	button.BackgroundColor3 = color or NINJA_COLORS.ACCENT
	button.BackgroundTransparency = 0
    button.BorderSizePixel = 0
    button.ZIndex = 12
    button.AutoButtonColor = false
	button.RichText = true
	button.Text = text
	button.FontFace = Font.new(DEFAULT_FONT_ASSET, Enum.FontWeight.Medium, Enum.FontStyle.Normal)
	button.Parent = parent

	-- Add corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	-- Add depth with gradient
	local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 220))
        }
        gradient.Rotation = 90
        gradient.Transparency = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 1)
        }
	gradient.Parent = button

	-- Add stroke for definition
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1
	stroke.Transparency = 0.8
	stroke.Parent = button

	-- Add hover and click animations using UIScale for smooth transitions
	local scale = Instance.new("UIScale")
	scale.Parent = button

	local function tweenScale(targetScale, duration)
		local tween = TweenService:Create(scale, TweenInfo.new(duration, Enum.EasingStyle.Quad), {Scale = targetScale})
		tween:Play()
	end

	button.MouseEnter:Connect(function()
		tweenScale(ANIMATIONS.HOVER_SCALE, ANIMATIONS.SCALE_TIME)
		-- Brighten on hover
		TweenService:Create(button, 
			TweenInfo.new(ANIMATIONS.SCALE_TIME, Enum.EasingStyle.Quad),
			{BackgroundColor3 = Color3.fromRGB(
				math.min(255, button.BackgroundColor3.R * 255 * 1.15),
				math.min(255, button.BackgroundColor3.G * 255 * 1.15),
				math.min(255, button.BackgroundColor3.B * 255 * 1.15)
				)}
		):Play()
	end)

	button.MouseLeave:Connect(function()
		tweenScale(1, ANIMATIONS.SCALE_TIME)
		-- Return to original color
		TweenService:Create(button, 
			TweenInfo.new(ANIMATIONS.SCALE_TIME, Enum.EasingStyle.Quad),
			{BackgroundColor3 = color or NINJA_COLORS.ACCENT}
		):Play()
	end)

	button.MouseButton1Down:Connect(function()
		tweenScale(ANIMATIONS.CLICK_SCALE, ANIMATIONS.SCALE_TIME / 2)
	end)

	button.MouseButton1Up:Connect(function()
		tweenScale(1, ANIMATIONS.SCALE_TIME / 2)
	end)

	if onClick then
		button.MouseButton1Click:Connect(onClick)
	end

	return button
end

-- ═══════════════════════════════════════════════════════════════
--                    CONFIRMATION DIALOG
-- ═══════════════════════════════════════════════════════════════

local function showNinjaConfirmation(message, onConfirm)
	local overlay = Instance.new("TextButton")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.8
	overlay.ZIndex = 300
	overlay.Active = true
	overlay.Modal = true
	overlay.AutoButtonColor = false
	overlay.Text = ""
	overlay.Parent = rootUI

	local dialog = createStyledFrame(overlay, 
		UDim2.fromScale(0.35, 0.3), 
		UDim2.fromScale(0.5, 0.5), 
		Vector2.new(0.5, 0.5)
	)
	dialog.ZIndex = 301

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0.3, 0)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "⚠️ Shadow Council Confirmation"
	title.Font = Enum.Font.GothamMedium
	title.TextScaled = true
	title.TextColor3 = NINJA_COLORS.ACCENT
	title.ZIndex = 302
	title.Parent = dialog

	local messageLabel = Instance.new("TextLabel")
	messageLabel.Size = UDim2.new(1, -20, 0.35, 0)
	messageLabel.Position = UDim2.new(0, 10, 0.3, 0)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = message
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.TextScaled = true
	messageLabel.TextColor3 = NINJA_COLORS.TEXT_PRIMARY
	messageLabel.TextWrapped = true
	messageLabel.ZIndex = 302
	messageLabel.Parent = dialog

	local function closeDialog()
		local tween = TweenService:Create(overlay, 
			TweenInfo.new(ANIMATIONS.FADE_TIME, Enum.EasingStyle.Quad), 
			{BackgroundTransparency = 1}
		)
		tween:Play()
		tween.Completed:Connect(function()
			overlay:Destroy()
		end)
	end

	local buttonContainer = Instance.new("Frame")
	buttonContainer.Name = "ConfirmationButtons"
	buttonContainer.Size = UDim2.new(1, -20, 0, 0)
	buttonContainer.Position = UDim2.new(0, 10, 0.68, 0)
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.ZIndex = dialog.ZIndex + 18
	buttonContainer.AutomaticSize = Enum.AutomaticSize.Y
	buttonContainer.Parent = dialog

	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Vertical
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	buttonLayout.Padding = UDim.new(0, 8)
	buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buttonLayout.Parent = buttonContainer

	local proceedButton = createNinjaButton(buttonContainer, "✅ Proceed", 
		UDim2.new(1, 0, 0, 44), 
		UDim2.new(0, 0, 0, 0), 
		NINJA_COLORS.SUCCESS, 
		function()
			closeDialog()
			if onConfirm then onConfirm() end
		end
	)
	proceedButton.LayoutOrder = 1
	proceedButton.ZIndex = dialog.ZIndex + 2

	local cancelButton = createNinjaButton(buttonContainer, "❌ Cancel", 
		UDim2.new(1, 0, 0, 44), 
		UDim2.new(0, 0, 0, 0), 
		NINJA_COLORS.DANGER, 
		closeDialog
	)
	cancelButton.LayoutOrder = 2
	cancelButton.ZIndex = dialog.ZIndex + 2

end

-- ═══════════════════════════════════════════════════════════════
--                      SLOT MANAGEMENT
-- ═══════════════════════════════════════════════════════════════

local function getPlayerLevel()
	if levelValue and levelValue.Value then
		return levelValue.Value
	end
	local attribute = player:GetAttribute("Level")
	return typeof(attribute) == "number" and attribute or 1
end

local function updateLevelDisplays()
	for slotIndex, slotUI in pairs(slotButtons) do
		if slotUI and slotUI.levelLabel then
			local slotData = personaCache.slots[slotIndex]
			local displayLevel = slotData and slotData.level or getPlayerLevel()
			slotUI.levelLabel.Text = string.format("⭐ Level %d", displayLevel)
		end
	end
end

local function getHighestUsedSlot()
	local highest = 0
	local maxSlots = tonumber(personaCache.slotCount) or 0
	for slotIndex = 1, maxSlots do
		if personaCache.slots[slotIndex] ~= nil then
			highest = slotIndex
		end
	end
	return highest
end

local function getSlotDisplayName(slotIndex)
	if slotIndex == 2 then
		return "persona left"
	elseif slotIndex == 3 then
		return "persona right"
	end

	return string.format("Slot %d", slotIndex)
end

local function preloadPersonaModel(model)
	if not model then return end

	task.spawn(function()
		local success, error = pcall(function()
			ContentProvider:PreloadAsync({model})
		end)
		if not success then
			warn("🥷 Failed to preload persona in the shadows:", error)
		end
	end)
end

local refreshSlotData

local function updateSlotDisplays()
	local highestUsed = math.min(getHighestUsedSlot(), #slotButtons)
	local minimumVisibleSlots = math.min(#slotButtons, 3)
	local visibleSlots = math.max(math.min(highestUsed + 1, #slotButtons), minimumVisibleSlots)

	for slotIndex = 1, #slotButtons do
		local slotData = personaCache.slots[slotIndex]
		local slotUI = slotButtons[slotIndex]

		if not slotUI then continue end

		-- Clear existing viewport content
		if slotUI.viewport then
			slotUI.viewport:ClearAllChildren()
			slotUI.viewport.CurrentCamera = nil
		end

		if slotUI.placeholder then
			slotUI.placeholder.Visible = false
		end

		slotUI.frame.Visible = slotIndex <= visibleSlots
		if slotUI.frame then
			slotUI.frame.Name = getSlotDisplayName(slotIndex)
		end

		if slotIndex <= visibleSlots then
			if slotData then
				-- Slot has saved persona
				slotUI.useButton.Visible = true
				slotUI.clearButton.Visible = true
				slotUI.robloxButton.Visible = false
				slotUI.ninjaButton.Visible = false

				if slotUI.placeholder then 
					slotUI.placeholder.Visible = false 
				end

				-- Create persona preview
				if slotUI.viewport then
					local description = getPersonaDescription(slotData.type)
					if description then
						local world = Instance.new("WorldModel")
						world.Parent = slotUI.viewport

						local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
						model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi, 0))
						model.Parent = world

						preloadPersonaModel(model)

						local camera = Instance.new("Camera")
						camera.CFrame = CFrame.new(Vector3.new(0, 2, 4), Vector3.new(0, 2, 0))
						camera.Parent = slotUI.viewport
						slotUI.viewport.CurrentCamera = camera
					end
				end

				-- Connect clear button
				if not slotUI.clearConnection then
					slotUI.clearConnection = slotUI.clearButton.MouseButton1Click:Connect(function()
						showNinjaConfirmation(
							string.format("🗑️ Remove the shadow warrior from %s?", getSlotDisplayName(slotIndex)),
							function()
								local result = invokePersonaService("clear", {slot = slotIndex})
								if result and result.ok then
									if chosenSlot == slotIndex then
										chosenSlot = nil
									end
									if refreshSlotData then
										refreshSlotData(result)
									end
								else
									warn("🥷 Failed to clear slot:", result and result.err)
								end
							end
						)
					end)
				end
			else
				-- Empty slot
				slotUI.useButton.Visible = false
				slotUI.clearButton.Visible = false
				slotUI.robloxButton.Visible = true
				slotUI.ninjaButton.Visible = true

				if slotUI.clearConnection then
					slotUI.clearConnection:Disconnect()
					slotUI.clearConnection = nil
				end

				if slotUI.placeholder then 
					slotUI.placeholder.Visible = true 
				end
			end
		end
	end

	updateLevelDisplays()
end

refreshSlotData = function(newData)
	personaCache = sanitizePersonaData(newData)
	ensureValidSelection()
	updateSlotDisplays()
	updateSelectedPersonaLabel()
end

-- ═══════════════════════════════════════════════════════════════
--                     CALLBACK HELPERS
-- ═══════════════════════════════════════════════════════════════

local function getUICallback(callbackName)
	if typeof(uiBridge) ~= "table" then return nil end
	local callback = uiBridge[callbackName]
	return typeof(callback) == "function" and callback or nil
end

local function callUICallback(callbackName, ...)
	local callback = getUICallback(callbackName)
	if callback then
		return callback(...)
	end
end

local function getStarterBackpack()
	if typeof(uiBridge) == "table" then
		local fetch = uiBridge.getStarterBackpack
		if typeof(fetch) == "function" then
			return fetch()
		end
		if uiBridge.starterBackpack ~= nil then
			return uiBridge.starterBackpack
		end
	end
	return fallbackStarterBackpack
end

local function triggerTransitionAnimation()
	local tweenCallback = getUICallback("tweenToEnd")
	if tweenCallback then
		tweenCallback()
	end
end

local function applyPersonaToPlayer(personaData)
	if not personaData then return end

	-- Apply inventory data
	if personaData.inventory then
		player:SetAttribute("Inventory", HttpService:JSONEncode(personaData.inventory))
	end

	-- Apply unlocked realms
	local realmsData = personaData.unlockedRealms or personaData.realms
	if realmsData then
		local realmsFolder = player:FindFirstChild("Realms")
		if realmsFolder then
			for realmName, isUnlocked in pairs(realmsData) do
				local realmFlag = realmsFolder:FindFirstChild(realmName)
				if not realmFlag then
					realmFlag = Instance.new("BoolValue")
					realmFlag.Name = realmName
					realmFlag.Parent = realmsFolder
				end
				realmFlag.Value = isUnlocked and true or false
			end
		end
	end

	updateSelectedPersonaLabel()
end

-- ═══════════════════════════════════════════════════════════════
--                      MAIN UI FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

local function showDojoInterface()
	if dojoInterface then 
		dojoInterface.Visible = true 
	end
	callUICallback("showDojoPicker")
	updateSelectedPersonaLabel()
end

local function showLoadoutInterface(personaType)
	if dojoInterface then 
		dojoInterface.Visible = false 
	end

	local showLoadoutCallback = getUICallback("showLoadout")
	if showLoadoutCallback then
		showLoadoutCallback(personaType)
	end

	local buildPreviewCallback = getUICallback("buildCharacterPreview")
	if buildPreviewCallback then
		buildPreviewCallback(personaType)
	end

	local updateBackpackCallback = getUICallback("updateBackpack")
	if updateBackpackCallback then
		local savedInventory = player:GetAttribute("Inventory")
		if typeof(savedInventory) == "string" then
			local success, inventoryData = pcall(HttpService.JSONDecode, HttpService, savedInventory)
			if success then
				updateBackpackCallback(inventoryData)
			end
		else
			local starterBackpack = getStarterBackpack()
			if starterBackpack then
				updateBackpackCallback(starterBackpack)

				-- Listen for inventory changes
				local connection
				connection = player:GetAttributeChangedSignal("Inventory"):Connect(function()
					local newInventory = player:GetAttribute("Inventory")
					if typeof(newInventory) == "string" then
						local success, data = pcall(HttpService.JSONDecode, HttpService, newInventory)
						if success then
							updateBackpackCallback(data)
							if connection then
								connection:Disconnect()
								connection = nil
							end
						end
					end
				end)
			end
		end
	end
end

-- ═══════════════════════════════════════════════════════════════
--                    SLOT BUTTON CREATION
-- ═══════════════════════════════════════════════════════════════

local function createPersonaSlot(parent, slotIndex, size, position, anchorPoint)
	local slotFrame = createStyledFrame(parent, size, position, anchorPoint)

	-- Viewport for persona preview
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.ZIndex = 10
	viewport.Parent = slotFrame

	-- Placeholder image
	local placeholder = Instance.new("ImageLabel")
	placeholder.Size = UDim2.fromScale(0.8, 0.8)
	placeholder.Position = UDim2.fromScale(0.5, 0.5)
	placeholder.AnchorPoint = Vector2.new(0.5, 0.5)
	placeholder.BackgroundTransparency = 1
	placeholder.Image = "rbxassetid://138217463115431"
	placeholder.ImageColor3 = NINJA_COLORS.TEXT_SECONDARY
	placeholder.ScaleType = Enum.ScaleType.Fit
	placeholder.ZIndex = 11
	placeholder.Parent = slotFrame

	-- Level label
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(1, -10, 0, 20)
	levelLabel.Position = UDim2.new(0, 5, 0, 5)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "⭐ Level 1"
	levelLabel.Font = Enum.Font.GothamMedium
	levelLabel.TextSize = 12
	levelLabel.TextColor3 = NINJA_COLORS.ACCENT
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.ZIndex = 12
	levelLabel.Parent = slotFrame

	-- Button container
	local buttonContainer = Instance.new("Frame")
	buttonContainer.Size = UDim2.new(1, -10, 0.4, 0)
	buttonContainer.Position = UDim2.new(0, 5, 0.55, 0)
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.ZIndex = 12
	buttonContainer.Parent = slotFrame

	local corners = Instance.new("UICorner")
	corners.CornerRadius = UDim.new(0, 10)
	corners.Parent = buttonContainer

	-- Create buttons based on slot size
	local isLargeSlot = size.X.Scale >= 0.35
	local buttonSize = isLargeSlot and UDim2.new(0.45, 0, 0.25, 0) or UDim2.new(0.9, 0, 0.3, 0)

	local ninjaButton, robloxButton, useButton, clearButton

	if isLargeSlot then
		ninjaButton = createNinjaButton(buttonContainer, "🥷 Ninja", 
			buttonSize, UDim2.new(0, 0, 0, 0), NINJA_COLORS.SECONDARY)
		robloxButton = createNinjaButton(buttonContainer, "👤 Avatar", 
			buttonSize, UDim2.new(0.55, 0, 0, 0), Color3.fromRGB(80, 120, 200))
		useButton = createNinjaButton(buttonContainer, "⚡ Play", 
			UDim2.new(0.7, 0, 0.25, 0), UDim2.new(0.15, 0, 0.35, 0), NINJA_COLORS.SUCCESS)
		clearButton = createNinjaButton(buttonContainer, "🗑️ Clear", 
			UDim2.new(0.5, 0, 0.2, 0), UDim2.new(0.25, 0, 0.75, 0), NINJA_COLORS.DANGER)
	else
		ninjaButton = createNinjaButton(buttonContainer, "🥷", 
			UDim2.new(0.45, 0, 0.4, 0), UDim2.new(0, 0, 0, 0), NINJA_COLORS.SECONDARY)
		robloxButton = createNinjaButton(buttonContainer, "👤", 
			UDim2.new(0.45, 0, 0.4, 0), UDim2.new(0.55, 0, 0, 0), Color3.fromRGB(80, 120, 200))
		useButton = createNinjaButton(buttonContainer, "⚡", 
			UDim2.new(0.9, 0, 0.25, 0), UDim2.new(0.05, 0, 0.5, 0), NINJA_COLORS.SUCCESS)
		clearButton = createNinjaButton(buttonContainer, "🗑️", 
			UDim2.new(0.4, 0, 0.2, 0), UDim2.new(0.3, 0, 0.8, 0), NINJA_COLORS.DANGER)
	end

	return {
		frame = slotFrame,
		viewport = viewport,
		placeholder = placeholder,
		levelLabel = levelLabel,
		useButton = useButton,
		clearButton = clearButton,
		ninjaButton = ninjaButton,
		robloxButton = robloxButton,
		clearConnection = nil
	}
end

-- ═══════════════════════════════════════════════════════════════
--                      PUBLIC FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

function NinjaCosmetics.getSelectedPersona()
	local personaType = currentChoiceType
	if chosenSlot and personaCache and personaCache.slots then
		local slotData = personaCache.slots[chosenSlot]
		if slotData and slotData.type then 
			personaType = slotData.type 
		end
	end
	return personaType, chosenSlot
end

function NinjaCosmetics.refreshSlots(data)
	refreshSlotData(data)
end

function NinjaCosmetics.showDojoPicker()
	showDojoInterface()
end

function NinjaCosmetics.init(config, rootInterface, bridgeInterface)
	uiBridge = bridgeInterface
	rootUI = rootInterface

	-- Setup fallback inventory
	if typeof(config) == "table" then
		fallbackStarterBackpack = config.inventory or config.starterBackpack
	end

	-- Initialize level tracking
	local statsFolder = player:FindFirstChild("Stats")
	if statsFolder then
		levelValue = statsFolder:FindFirstChild("Level")
		if levelValue then
			levelValue:GetPropertyChangedSignal("Value"):Connect(updateLevelDisplays)
			updateLevelDisplays()
		end
	else
		player.ChildAdded:Connect(function(child)
			if child.Name == "Stats" then
				levelValue = child:FindFirstChild("Level")
				if levelValue then
					levelValue:GetPropertyChangedSignal("Value"):Connect(updateLevelDisplays)
					updateLevelDisplays()
				end
			end
		end)
	end
	player:GetAttributeChangedSignal("Level"):Connect(updateLevelDisplays)

	-- ═══════════════════════════════════════════════════════════════
	--                    MAIN DOJO INTERFACE
	-- ═══════════════════════════════════════════════════════════════

	dojoInterface = Instance.new("Frame")
	dojoInterface.Size = UDim2.fromScale(1, 1)
	dojoInterface.BackgroundTransparency = 1
	dojoInterface.Visible = false
	dojoInterface.ZIndex = 10
	dojoInterface.Parent = rootInterface

	-- Background with ninja aesthetic but transparent for camera scene
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundTransparency = 1
	background.BorderSizePixel = 0
	background.ZIndex = 10
	background.Parent = dojoInterface

	-- Header with ninja branding
	local headerFrame = createStyledFrame(dojoInterface,
		UDim2.new(0, 0, 0, 0),
		UDim2.fromScale(0.5, 0.02),
		Vector2.new(0.5, 0)
	)
	headerFrame.AutomaticSize = Enum.AutomaticSize.XY
	headerFrame.BackgroundTransparency = 0.05

	local headerPadding = Instance.new("UIPadding")
	headerPadding.PaddingTop = UDim.new(0, 15)
	headerPadding.PaddingBottom = UDim.new(0, 15)
	headerPadding.PaddingLeft = UDim.new(0, 20)
	headerPadding.PaddingRight = UDim.new(0, 20)
	headerPadding.Parent = headerFrame

	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, 8)
	headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	headerLayout.Parent = headerFrame

	local dojoTitle = Instance.new("ImageLabel")
	dojoTitle.Size = UDim2.fromOffset(360, 120)
	dojoTitle.Image = "rbxassetid://138217463115431" -- BootUI logo
	dojoTitle.BackgroundTransparency = 1
	dojoTitle.ScaleType = Enum.ScaleType.Fit
	dojoTitle.ZIndex = 12
	dojoTitle.LayoutOrder = 1
	dojoTitle.Parent = headerFrame

	local dojoTitleConstraint = Instance.new("UISizeConstraint")
	dojoTitleConstraint.MaxSize = Vector2.new(360, 120)
	dojoTitleConstraint.Parent = dojoTitle

	local function updateHeaderLayout()
		local headerWidth = headerFrame.AbsoluteSize.X

		if headerWidth < 600 then
			headerLayout.FillDirection = Enum.FillDirection.Vertical
		else
			headerLayout.FillDirection = Enum.FillDirection.Horizontal
		end
	end

	headerFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateHeaderLayout)
	updateHeaderLayout()

	-- Main content panel
	local contentPanel = createStyledFrame(dojoInterface,
		UDim2.fromScale(0.9, 0.8),
		UDim2.fromScale(0.5, 0.55),
		Vector2.new(0.2, 0.2)
	)
	contentPanel.BackgroundTransparency = 0.05
	contentPanel.AnchorPoint = Vector2.new(0.5, 0)

	local function updateContentPanelPosition()
		local headerHeight = headerFrame.AbsoluteSize.Y
		contentPanel.Position = UDim2.new(0.5, 0, 0, headerHeight + 22)
	end

	updateContentPanelPosition()
	headerFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateContentPanelPosition)

	-- Slots container
	slotsContainer = Instance.new("Frame")
	slotsContainer.Size = UDim2.new(1, -20, 0.8, 0)
	slotsContainer.Position = UDim2.new(0, 10, 0, 10)
	slotsContainer.BackgroundTransparency = 1
	slotsContainer.ZIndex = 11
	slotsContainer.Parent = contentPanel

	-- Footer with dojo branding
	local footerFrame = createStyledFrame(contentPanel, 
		UDim2.new(0.9, 0, 0.15, 0), 
		UDim2.fromScale(0.5, 0.9), 
		Vector2.new(0.5, 0.5)
	)
	footerFrame.BackgroundTransparency = 0.05

	local starterDojoImage = Instance.new("ImageLabel")
	starterDojoImage.Size = UDim2.fromScale(0.6, 0.8)
	starterDojoImage.Position = UDim2.fromScale(0.5, 0.5)
	starterDojoImage.AnchorPoint = Vector2.new(0.5, 0.5)
	starterDojoImage.Image = "rbxassetid://137361385013636" -- Starter dojo image
	starterDojoImage.BackgroundTransparency = 1
	starterDojoImage.ScaleType = Enum.ScaleType.Fit
	starterDojoImage.ZIndex = 12
	starterDojoImage.Parent = footerFrame

	-- ═══════════════════════════════════════════════════════════════
	--                      CREATE PERSONA SLOTS
	-- ═══════════════════════════════════════════════════════════════

	-- Initialize persona data
	personaCache = sanitizePersonaData(config.personaData)
	slotButtons = {}

	-- Slot 1: Center (primary/featured slot)
	slotButtons[1] = createPersonaSlot(slotsContainer, 1,
		UDim2.fromScale(0.45, 1),
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5)
	)

	-- Slot 2: Left side
	slotButtons[2] = createPersonaSlot(slotsContainer, 2,
		UDim2.fromScale(0.25, 0.7),
		UDim2.fromScale(0.15, 0.5),
		Vector2.new(0.5, 0.5)
	)

	-- Slot 3: Right side
	slotButtons[3] = createPersonaSlot(slotsContainer, 3,
		UDim2.fromScale(0.25, 0.7),
		UDim2.fromScale(0.85, 0.5),
		Vector2.new(0.5, 0.5)
	)

	-- ═══════════════════════════════════════════════════════════════
	--                    CONNECT SLOT INTERACTIONS
	-- ═══════════════════════════════════════════════════════════════

	for slotIndex, slotUI in pairs(slotButtons) do
		local currentIndex = slotIndex

		-- Use button: Activate selected persona
		slotUI.useButton.MouseButton1Click:Connect(function()
			local result = invokePersonaService("use", {slot = currentIndex})
			if not (result and result.ok) then 
				warn("🥷 Failed to activate shadow warrior from slot", currentIndex, ":", result and result.err)
				return 
			end

			chosenSlot = currentIndex
			currentChoiceType = result.persona and result.persona.type or currentChoiceType
			applyPersonaToPlayer(result.persona)
			triggerTransitionAnimation()
			showLoadoutInterface(result.persona and result.persona.type or currentChoiceType)
			updateSelectedPersonaLabel()
		end)

		-- Ninja button: Save ninja persona to slot
		slotUI.ninjaButton.MouseButton1Click:Connect(function()
			local saveResult = invokePersonaService("save", {slot = currentIndex, type = "Ninja"})
			if saveResult and saveResult.ok then
				refreshSlotData(saveResult)
				local useResult = invokePersonaService("use", {slot = currentIndex})
				if useResult and useResult.ok then
					chosenSlot = currentIndex
					currentChoiceType = "Ninja"
					applyPersonaToPlayer(useResult.persona)
					triggerTransitionAnimation()
					showLoadoutInterface("Ninja")
					updateSelectedPersonaLabel()
				else
					warn("🥷 Failed to activate ninja persona:", useResult and useResult.err)
				end
			else
				warn("🥷 Failed to save ninja persona:", saveResult and saveResult.err)
			end
		end)

		-- Roblox button: Save Roblox avatar to slot
		slotUI.robloxButton.MouseButton1Click:Connect(function()
			local saveResult = invokePersonaService("save", {slot = currentIndex, type = "Roblox"})
			if saveResult and saveResult.ok then
				refreshSlotData(saveResult)
				local useResult = invokePersonaService("use", {slot = currentIndex})
				if useResult and useResult.ok then
					chosenSlot = currentIndex
					currentChoiceType = "Roblox"
					applyPersonaToPlayer(useResult.persona)
					triggerTransitionAnimation()
					showLoadoutInterface("Roblox")
					updateSelectedPersonaLabel()
				else
					warn("🥷 Failed to activate avatar persona:", useResult and useResult.err)
				end
			else
				warn("🥷 Failed to save avatar persona:", saveResult and saveResult.err)
			end
		end)
	end

	-- Initialize UI state
	updateSlotDisplays()
	updateSelectedPersonaLabel()

	-- Add entrance animation
	local entranceTween = TweenService:Create(dojoInterface,
		TweenInfo.new(ANIMATIONS.FADE_TIME * 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = .5}
	)

	dojoInterface.Changed:Connect(function(property)
		if property == "Visible" and dojoInterface.Visible then
			entranceTween:Play()
		end
	end)
end

return NinjaCosmetics
