local ActionUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local HapticService = game:GetService("HapticService")

local Abilities = require(ReplicatedStorage.ClientModules.Abilities)
local CombatController = require(ReplicatedStorage.ClientModules.CombatController)
local GameSettings = require(ReplicatedStorage.GameSettings)

-- UI Configuration (Expanded with more options)
local UI_CONFIG = {
	-- Colors (Improved with better contrast and themes)
	COMBAT_COLOR = Color3.fromRGB(200, 40, 40),     -- Deeper red for combat
	ABILITY_COLOR = Color3.fromRGB(50, 150, 220),   -- Brighter blue for abilities
	MOVEMENT_COLOR = Color3.fromRGB(140, 160, 0),   -- Adjusted yellow-green
	JUMP_COLOR = Color3.fromRGB(60, 210, 120),      -- Vibrant green for jump
	BACKGROUND_COLOR = Color3.fromRGB(30, 30, 30),  -- Dark background for better contrast
	TEXT_COLOR = Color3.fromRGB(255, 255, 255),     -- White text
	KEYBIND_COLOR = Color3.fromRGB(200, 200, 200),  -- Light gray for keybinds
	DISABLED_COLOR = Color3.fromRGB(100, 100, 100), -- Gray for disabled states

	-- Gradients
	GRADIENT_OFFSET = Vector2.new(0, 0.3),

	-- Animation
	PRESS_SCALE = 0.92,
	HOVER_SCALE = 1.08,
	TWEEN_TIME = 0.12,  -- Slightly faster for snappier feel
	BOUNCE_EASING = Enum.EasingStyle.Bounce,

	-- Layout
        BUTTON_SIZE = UDim2.new(0, 110, 0, 90),
        MOBILE_BUTTON_SIZE = UDim2.new(0, 90, 0, 70),
        JUMP_BUTTON_SIZE = UDim2.new(0, 130, 0, 110),
        MOBILE_JUMP_SIZE = UDim2.new(0, 110, 0, 90),
        PADDING = UDim.new(0, 12),
        CORNER_RADIUS = UDim.new(0, 16),  -- Softer corners

        -- Responsive scaling
        SCALE_REFERENCE_MIN_AXIS = 1080,
        SCALE_MIN = 0.7,
        SCALE_MAX = 1.25,

	-- Platform visibility
	SHOW_ON_DESKTOP = true,
	SHOW_DESKTOP_JUMP = true,

	-- New: Feedback options
	ENABLE_HAPTICS = true,
	ENABLE_SOUNDS = true,
	BUTTON_SOUND_ID = "rbxassetid://9112860835",  -- Example click sound
	JUMP_SOUND_ID = "rbxassetid://9112860835",    -- Example jump sound

	-- New: Cooldown visuals
	COOLDOWN_OVERLAY_COLOR = Color3.fromRGB(0, 0, 0),
	COOLDOWN_OVERLAY_TRANSPARENCY = 0.6,
}

local FAN_CONFIG = {
        START_ANGLE = math.rad(215),
        END_ANGLE = math.rad(305),
        OUTER_START_ANGLE = math.rad(185),
        OUTER_END_ANGLE = math.rad(300),
        MOBILE_RADIUS = 180,
        DESKTOP_RADIUS = 230,
        OUTER_RADIUS_OFFSET = 60,
        MOBILE_OUTER_RADIUS_OFFSET = 50,
        JUMP_MARGIN = 90,
        MOBILE_JUMP_MARGIN = 70,
        DESKTOP_JUMP_MARGIN = 95,
        TOGGLE_MARGIN = 36,
        MOBILE_TOGGLE_MARGIN = 30,
        DESKTOP_TOGGLE_MARGIN = 40,
        MIN_HORIZONTAL_MARGIN = 18,
        MOBILE_MIN_HORIZONTAL_MARGIN = 14,
        OUTER_MIN_HORIZONTAL_MARGIN = 28,
        MOBILE_OUTER_MIN_HORIZONTAL_MARGIN = 22,
        VERTICAL_SHIFT = 12,
        MOBILE_VERTICAL_SHIFT = 10,
        OUTER_VERTICAL_SHIFT = 44,
        MOBILE_OUTER_VERTICAL_SHIFT = 36,
        ANIMATION_TIME = 0.28,
        SPEED_BOOST = 5,  -- Slightly increased
        TOGGLE_SIZE = UDim2.new(0, 52, 0, 52),
        MOBILE_TOGGLE_SIZE = UDim2.new(0, 44, 0, 44),
}

-- Button definitions (Added icons placeholders, you can replace with actual ImageIds)
local BUTTON_DEFINITIONS = {
        -- Jump (Priority 1)
        {name = "JumpButton", text = "JUMP", icon = "rbxassetid://1234567890", action = "Jump", category = "jump", keybind = "Space", priority = 1},

	-- Combat (Red, grouped together)
	{name = "PunchButton", text = "PUNCH", icon = "rbxassetid://1234567890", action = "Punch", category = "combat", keybind = "E/T", priority = 2},
	{name = "KickButton", text = "KICK", icon = "rbxassetid://1234567890", action = "Kick", category = "combat", keybind = "Q", priority = 3},

	-- Movement (Yellow-green, grouped)
	{name = "RollButton", text = "ROLL", icon = "rbxassetid://1234567890", action = "Roll", category = "movement", keybind = "R", priority = 4},
	{name = "CrouchButton", text = "CROUCH", icon = "rbxassetid://1234567890", action = "Crouch", category = "movement", keybind = "C", priority = 5},
	{name = "SlideButton", text = "SLIDE", icon = "rbxassetid://1234567890", action = "Slide", category = "movement", keybind = "Ctrl", priority = 6},

	-- Abilities (Blue, grouped)
	{name = "TossButton", text = "TOSS", icon = "rbxassetid://1234567890", action = "Toss", category = "ability", keybind = "F", priority = 7},
	{name = "StarButton", text = "STAR", icon = "rbxassetid://1234567890", action = "Star", category = "ability", keybind = "G", priority = 8},
	{name = "RainButton", text = "RAIN", icon = "rbxassetid://1234567890", action = "Rain", category = "ability", keybind = "Z", priority = 9},
	{name = "BeastButton", text = "BEAST", icon = "rbxassetid://1234567890", action = "Beast", category = "ability", keybind = "B", priority = 10},
        {name = "DragonButton", text = "DRAGON", icon = "rbxassetid://1234567890", action = "Dragon", category = "ability", keybind = "X", priority = 11},
}

local ABILITY_FAN_ORDER = {
        DragonButton = 1,
        BeastButton = 2,
        StarButton = 3,
        TossButton = 4,
}

-- Global variables (Added cooldown tracking)
local customJumpEnabled = false
local jumpRequestConnection = nil
local jumpActionBound = false
local jumpActionName = "ActionUI_CustomJump"
local lastJumpTime = 0
local forceActionsVisible = false

local currentActionsFrame = nil
local jumpButtonRef = nil
local toggleButtonRef = nil
local fanButtons = {}
local fanOpen = true
local defaultWalkSpeed = nil
local speedBoostApplied = false
local characterAddedConnection = nil
local viewportConnection = nil

local buttonConnections = {}
local inputConnections = {}
local deviceChangeConnections = {}
local cooldowns = {}  -- New: Table to track cooldowns {buttonName = {endTime = tick, duration = seconds}}
local touchGuiConnections = {}

local updateFanLayout
local updateToggleVisual
local applySpeedState
local setFanOpen
local ensureCharacterTracking
local performCustomJump
local playButtonSound
local triggerHapticFeedback
local updateCooldownVisuals

local currentUIScale = 1

local MOVEMENT_REMOTE_NAME = "MovementModeEvent"
local MOVEMENT_MODES = GameSettings.movementModes or {RunDance = "RunDance", Battle = "Battle"}
local RUN_MODE = MOVEMENT_MODES.RunDance or "RunDance"
local BATTLE_MODE = MOVEMENT_MODES.Battle or "Battle"
local movementModeRemote = ReplicatedStorage:FindFirstChild(MOVEMENT_REMOTE_NAME)
local remoteMissingWarned = false
local lastSentMode = nil
local currentMovementMode = BATTLE_MODE
local statsAddedConnection = nil
local levelChangedConnection = nil

local function round(value)
        return math.floor(value + 0.5)
end

local function updateUIScale()
        local camera = workspace.CurrentCamera
        if not camera then
                currentUIScale = 1
                return currentUIScale
        end

        local minAxis = math.min(camera.ViewportSize.X, camera.ViewportSize.Y)
        local reference = UI_CONFIG.SCALE_REFERENCE_MIN_AXIS or 1080
        local minScale = UI_CONFIG.SCALE_MIN or 0.75
        local maxScale = UI_CONFIG.SCALE_MAX or 1.35
        local scale = minAxis / reference
        currentUIScale = math.clamp(scale, minScale, maxScale)
        return currentUIScale
end

local function scaleNumber(value)
        return round(value * currentUIScale)
end

local function scaleUDim2(size)
        if not size then
                return nil
        end
        return UDim2.new(
                size.X.Scale,
                round(size.X.Offset * currentUIScale),
                size.Y.Scale,
                round(size.Y.Offset * currentUIScale)
        )
end

local function scaleUDim(udim)
        if not udim then
                return nil
        end
        return UDim.new(
                udim.Scale,
                round(udim.Offset * currentUIScale)
        )
end

local function getJumpMargin(mobileLayout)
        local baseMargin
        if mobileLayout then
                baseMargin = FAN_CONFIG.MOBILE_JUMP_MARGIN or FAN_CONFIG.JUMP_MARGIN or 0
        else
                baseMargin = FAN_CONFIG.DESKTOP_JUMP_MARGIN or FAN_CONFIG.JUMP_MARGIN or 0
        end
        return scaleNumber(baseMargin)
end

local function getToggleMargin(mobileLayout)
        local baseMargin
        if mobileLayout then
                baseMargin = FAN_CONFIG.MOBILE_TOGGLE_MARGIN or FAN_CONFIG.TOGGLE_MARGIN or 0
        else
                baseMargin = FAN_CONFIG.DESKTOP_TOGGLE_MARGIN or FAN_CONFIG.TOGGLE_MARGIN or 0
        end
        return scaleNumber(baseMargin)
end

local function getToggleSize(mobileLayout)
        local baseSize = mobileLayout and (FAN_CONFIG.MOBILE_TOGGLE_SIZE or FAN_CONFIG.TOGGLE_SIZE) or FAN_CONFIG.TOGGLE_SIZE
        return scaleUDim2(baseSize)
end

local function getFanRadius(mobileLayout)
        local baseRadius = mobileLayout and FAN_CONFIG.MOBILE_RADIUS or FAN_CONFIG.DESKTOP_RADIUS
        return scaleNumber(baseRadius or 0)
end

local function getOuterFanRadius(baseRadius, mobileLayout)
        local offset
        if mobileLayout then
                offset = FAN_CONFIG.MOBILE_OUTER_RADIUS_OFFSET or FAN_CONFIG.OUTER_RADIUS_OFFSET or 0
        else
                offset = FAN_CONFIG.OUTER_RADIUS_OFFSET or 0
        end
        return baseRadius + scaleNumber(offset or 0)
end

local function getHorizontalMargin(mobileLayout, isOuter)
        local baseMargin
        if isOuter then
                if mobileLayout then
                        baseMargin = FAN_CONFIG.MOBILE_OUTER_MIN_HORIZONTAL_MARGIN
                                or FAN_CONFIG.OUTER_MIN_HORIZONTAL_MARGIN
                                or FAN_CONFIG.MIN_HORIZONTAL_MARGIN
                else
                        baseMargin = FAN_CONFIG.OUTER_MIN_HORIZONTAL_MARGIN or FAN_CONFIG.MIN_HORIZONTAL_MARGIN
                end
        else
                if mobileLayout then
                        baseMargin = FAN_CONFIG.MOBILE_MIN_HORIZONTAL_MARGIN or FAN_CONFIG.MIN_HORIZONTAL_MARGIN
                else
                        baseMargin = FAN_CONFIG.MIN_HORIZONTAL_MARGIN
                end
        end
        return scaleNumber(baseMargin or 0)
end

local function getVerticalShift(mobileLayout, isOuter)
        local baseShift
        if isOuter then
                if mobileLayout then
                        baseShift = FAN_CONFIG.MOBILE_OUTER_VERTICAL_SHIFT
                                or FAN_CONFIG.OUTER_VERTICAL_SHIFT
                                or FAN_CONFIG.VERTICAL_SHIFT
                else
                        baseShift = FAN_CONFIG.OUTER_VERTICAL_SHIFT or FAN_CONFIG.VERTICAL_SHIFT
                end
        else
                if mobileLayout then
                        baseShift = FAN_CONFIG.MOBILE_VERTICAL_SHIFT or FAN_CONFIG.VERTICAL_SHIFT
                else
                        baseShift = FAN_CONFIG.VERTICAL_SHIFT
                end
        end
        return -scaleNumber(baseShift or 0)
end

local function computeFanAngles(count, startAngle, endAngle)
        local angles = {}
        if count <= 0 then
                return angles
        end

        if count == 1 then
                angles[1] = (startAngle + endAngle) * 0.5
        else
                local step = (endAngle - startAngle) / (count - 1)
                for index = 1, count do
                        angles[index] = startAngle + (index - 1) * step
                end
        end

        return angles
end

local function computeHorizontalShift(angles, radius, margin)
        if not angles or #angles == 0 then
                return 0
        end

        local maxCos
        for _, angle in ipairs(angles) do
                local cosValue = math.cos(angle)
                if not maxCos or cosValue > maxCos then
                        maxCos = cosValue
                end
        end

        local effectiveMargin = margin or 0
        if maxCos and maxCos > 0 then
                return -(maxCos * radius + effectiveMargin)
        end

        return -effectiveMargin
end

local function updateFanExtents(angles, radius, shiftX, shiftY, extents)
        if not angles or #angles == 0 or not extents then
                return
        end

        for _, angle in ipairs(angles) do
                local offsetX = math.cos(angle) * radius + (shiftX or 0)
                local offsetY = math.sin(angle) * radius + (shiftY or 0)
                if offsetX < extents.minX then
                        extents.minX = offsetX
                end
                if offsetX > extents.maxX then
                        extents.maxX = offsetX
                end
                if offsetY < extents.minY then
                        extents.minY = offsetY
                end
                if offsetY > extents.maxY then
                        extents.maxY = offsetY
                end
        end
end

local function isMobile()
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function isDesktop()
	if UserInputService.KeyboardEnabled or UserInputService.GamepadEnabled then
		return true
	end
	return not UserInputService.TouchEnabled
end

local function shouldUseMobileLayout()
        return isMobile() or forceActionsVisible
end

local function shouldOverrideDefaultJump()
        return isMobile()
end

local function registerConnection(container, connection)
        if connection then
                table.insert(container, connection)
        end
	return connection
end

local function disconnectConnections(container)
	for index = #container, 1, -1 do
		local connection = container[index]
		if connection then
			connection:Disconnect()
		end
		container[index] = nil
	end
end

local function setJumpButtonEnabled(enabled)
        if not game:IsLoaded() then
                game.Loaded:Wait()
        end

	local attempts = 0
	local success = false
	local lastError

	repeat
		attempts += 1
		success, lastError = pcall(function()
			StarterGui:SetCore("JumpButtonEnabled", enabled)
		end)
		if success then
			break
		end
		task.wait(0.1 * attempts)
	until success or attempts >= 5

        if not success and lastError then
                warn("ActionUI failed to toggle JumpButtonEnabled:", lastError)
        end
end

local function applyTouchJumpVisibility(frame, visible)
        if not frame then
                return
        end

        local jumpButton = frame:FindFirstChild("JumpButton")
        if jumpButton then
                jumpButton.Visible = visible
                jumpButton.Active = visible
        end
end

local function monitorTouchControlFrame(frame, visible)
        if not frame then
                return
        end

        applyTouchJumpVisibility(frame, visible)
        registerConnection(touchGuiConnections, frame.ChildAdded:Connect(function(child)
                if child.Name == "JumpButton" then
                        applyTouchJumpVisibility(frame, visible)
                end
        end))
end

local function monitorTouchGui(touchGui, visible)
        if not touchGui then
                return
        end

        monitorTouchControlFrame(touchGui:FindFirstChild("TouchControlFrame"), visible)
        registerConnection(touchGuiConnections, touchGui.ChildAdded:Connect(function(child)
                if child.Name == "TouchControlFrame" then
                        monitorTouchControlFrame(child, visible)
                end
        end))
end

local function enforceTouchJumpVisibility(visible)
        disconnectConnections(touchGuiConnections)

        local player = Players.LocalPlayer
        if not player then
                return
        end

        local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:FindFirstChild("PlayerGui")
        if not playerGui then
                task.delay(0.2, function()
                        enforceTouchJumpVisibility(visible)
                end)
                return
        end

        for _, child in ipairs(playerGui:GetChildren()) do
                if child.Name == "TouchGui" then
                        monitorTouchGui(child, visible)
                end
        end

        registerConnection(touchGuiConnections, playerGui.ChildAdded:Connect(function(child)
                if child.Name == "TouchGui" then
                        monitorTouchGui(child, visible)
                end
        end))
end

local function bindJumpOverride()
        if jumpActionBound then
                return
        end

	ContextActionService:BindAction(jumpActionName, function(_, inputState)
		if inputState == Enum.UserInputState.Begin and customJumpEnabled then
			performCustomJump()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

	if jumpRequestConnection then
		jumpRequestConnection:Disconnect()
	end

	jumpRequestConnection = UserInputService.JumpRequest:Connect(function()
		if customJumpEnabled and (os.clock() - lastJumpTime) > 0.05 then
			performCustomJump()
		end
	end)

	jumpActionBound = true
end

local function unbindJumpOverride()
        if jumpActionBound then
                ContextActionService:UnbindAction(jumpActionName)
                jumpActionBound = false
        end

        if jumpRequestConnection then
                jumpRequestConnection:Disconnect()
                jumpRequestConnection = nil
        end
end

local function characterHasSpawned()
        local player = Players.LocalPlayer
        if not player then
                return false
        end

        local character = player.Character
        if not character or not character.Parent then
                return false
        end

        return character:FindFirstChild("HumanoidRootPart") ~= nil
end

local function shouldDisplayActions()
        if not forceActionsVisible and not characterHasSpawned() then
                return false
        end

        if shouldUseMobileLayout() then
                return true
        end

        if UI_CONFIG.SHOW_ON_DESKTOP then
		return isDesktop()
	end

	return false
end

local function getHumanoid()
        local player = Players.LocalPlayer
        if not player then
                return nil
        end

	local character = player.Character
	if not character then
		return nil
	end

        return character:FindFirstChildOfClass("Humanoid")
end

local function resolveMovementRemote()
        if movementModeRemote then
                return movementModeRemote
        end

        local ok, remote = pcall(function()
                return ReplicatedStorage:WaitForChild(MOVEMENT_REMOTE_NAME, 5)
        end)

        if ok and remote then
                movementModeRemote = remote
        elseif not remoteMissingWarned then
                warn("MovementModeEvent remote not found; movement speed sync disabled")
                remoteMissingWarned = true
        end

        return movementModeRemote
end

local function sendMovementMode(mode, force)
        if not mode then
                return
        end

        local remote = resolveMovementRemote()
        if not remote then
                return
        end

        if force or mode ~= lastSentMode then
                lastSentMode = mode
                remote:FireServer(mode)
        end
end

local function getPlayerStats()
        local player = Players.LocalPlayer
        if not player then
                return nil
        end

        return player:FindFirstChild("Stats")
end

local function getCurrentLevel()
        local stats = getPlayerStats()
        local levelValue = stats and stats:FindFirstChild("Level")
        if levelValue then
                return levelValue.Value
        end
        return 1
end

local function calculateSpeedForMode(level, mode)
        if GameSettings.movementSpeedForMode then
                return GameSettings.movementSpeedForMode(level, mode)
        end

        local baseSpeed = GameSettings.movementSpeed(level)
        local runSpeed = baseSpeed + (GameSettings.runSpeedBonus or 0)

        if mode == RUN_MODE then
                return runSpeed
        elseif mode == BATTLE_MODE then
                return math.max(0, runSpeed - (GameSettings.battleSpeedPenalty or 0))
        end

        return runSpeed
end

local function putAwayWeapons()
        local player = Players.LocalPlayer
        if not player then
                return
        end

        local character = player.Character
        if not character then
                return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
                humanoid:UnequipTools()
        end
end

local function createGradient(color)
        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, color),
                ColorSequenceKeypoint.new(1, Color3.new(color.R * 0.65, color.G * 0.65, color.B * 0.65))
	}
	gradient.Offset = UI_CONFIG.GRADIENT_OFFSET
	return gradient
end

local function createButtonShadow()
        local shadow = Instance.new("Frame")
        shadow.Name = "Shadow"
        shadow.AnchorPoint = Vector2.new(0.5, 0.5)
        local shadowOffset = scaleNumber(4)
        shadow.Position = UDim2.new(0.5, shadowOffset, 0.5, shadowOffset)
        shadow.Size = UDim2.new(1, shadowOffset, 1, shadowOffset)
        shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        shadow.BackgroundTransparency = 0.75
        shadow.ZIndex = -1

        local shadowCorner = Instance.new("UICorner")
        shadowCorner.CornerRadius = scaleUDim(UI_CONFIG.CORNER_RADIUS)
        shadowCorner.Parent = shadow

        return shadow
end

local function createFanToggleButton()
        local toggle = Instance.new("TextButton")
        toggle.Name = "FanToggle"
        toggle.Text = ""
        toggle.AutoButtonColor = true
        toggle.BackgroundTransparency = 0.15
        toggle.BackgroundColor3 = UI_CONFIG.BACKGROUND_COLOR
        toggle.BorderSizePixel = 0
        toggle.AnchorPoint = Vector2.new(0.5, 0.5)
        toggle.ZIndex = 4
        toggle.TextColor3 = UI_CONFIG.TEXT_COLOR
        toggle.TextScaled = true
        toggle.Font = Enum.Font.GothamBold

        toggle.Size = getToggleSize(shouldUseMobileLayout()) or scaleUDim2(FAN_CONFIG.TOGGLE_SIZE)

        local corner = Instance.new("UICorner")
        corner.CornerRadius = scaleUDim(UI_CONFIG.CORNER_RADIUS)
        corner.Parent = toggle

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = math.max(1, scaleNumber(1.5))
        stroke.Color = Color3.fromRGB(80, 80, 80)
        stroke.Transparency = 0.5
        stroke.Parent = toggle

        local shadow = createButtonShadow()
	shadow.Parent = toggle

	return toggle
end

local function createStylizedButton(buttonDef)
	local button = Instance.new("TextButton")
	button.Name = buttonDef.name
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.ZIndex = 2
	button.ClipsDescendants = true  -- Changed to true for cooldown overlay clipping

	local mobileLayout = shouldUseMobileLayout()

        local baseSize
        if buttonDef.category == "jump" then
                baseSize = mobileLayout and UI_CONFIG.MOBILE_JUMP_SIZE or UI_CONFIG.JUMP_BUTTON_SIZE
        else
                baseSize = mobileLayout and UI_CONFIG.MOBILE_BUTTON_SIZE or UI_CONFIG.BUTTON_SIZE
        end
        button.Size = scaleUDim2(baseSize)

	local color = UI_CONFIG.COMBAT_COLOR
	if buttonDef.category == "ability" then
		color = UI_CONFIG.ABILITY_COLOR
	elseif buttonDef.category == "movement" then
		color = UI_CONFIG.MOVEMENT_COLOR
	elseif buttonDef.category == "jump" then
		color = UI_CONFIG.JUMP_COLOR
	end

	button.BackgroundColor3 = color

        local corner = Instance.new("UICorner")
        corner.CornerRadius = scaleUDim(UI_CONFIG.CORNER_RADIUS)
        corner.Parent = button

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = math.max(1, scaleNumber(2))
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Color = color:Lerp(Color3.new(1, 1, 1), 0.4)
        stroke.Transparency = 0.2
        stroke.Parent = button

        local padding = Instance.new("UIPadding")
        local paddingValue = scaleUDim(UI_CONFIG.PADDING)
        padding.PaddingTop = paddingValue
        padding.PaddingBottom = paddingValue
        padding.PaddingLeft = paddingValue
        padding.PaddingRight = paddingValue
        padding.Parent = button

	local gradient = createGradient(color)
	gradient.Parent = button

	local shadow = createButtonShadow()
	shadow.Parent = button

	-- New: Icon (if provided)
	local iconLabel = Instance.new("ImageLabel")
	iconLabel.Name = "Icon"
	iconLabel.Parent = button
	iconLabel.Size = UDim2.new(0.5, 0, 0.5, 0)
	iconLabel.Position = UDim2.new(0.5, 0, 0.25, 0)
	iconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Image = buttonDef.icon or ""
	iconLabel.ZIndex = 3
	iconLabel.ScaleType = Enum.ScaleType.Fit

	-- Text label (adjusted position if icon present)
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "MainText"
	textLabel.Parent = button
	textLabel.Size = UDim2.new(1, 0, 0.3, 0)
	textLabel.Position = UDim2.new(0, 0, buttonDef.icon and 0.65 or 0.35, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = buttonDef.text
	textLabel.TextColor3 = UI_CONFIG.TEXT_COLOR
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.ZIndex = 3
	textLabel.TextWrapped = true

	-- Keybind label
	local keybindLabel = Instance.new("TextLabel")
	keybindLabel.Name = "Keybind"
	keybindLabel.Parent = button
	keybindLabel.Size = UDim2.new(1, 0, 0.25, 0)
	keybindLabel.Position = UDim2.new(0, 0, 0.75, 0)
	keybindLabel.BackgroundTransparency = 1
	keybindLabel.Text = buttonDef.keybind or ""
	keybindLabel.TextColor3 = UI_CONFIG.KEYBIND_COLOR
	keybindLabel.TextScaled = true
	keybindLabel.Font = Enum.Font.Gotham
	keybindLabel.ZIndex = 3
	keybindLabel.TextWrapped = true
	keybindLabel.Visible = not mobileLayout

	-- New: Cooldown overlay
	local cooldownOverlay = Instance.new("Frame")
	cooldownOverlay.Name = "CooldownOverlay"
	cooldownOverlay.Size = UDim2.new(1, 0, 1, 0)
	cooldownOverlay.BackgroundColor3 = UI_CONFIG.COOLDOWN_OVERLAY_COLOR
	cooldownOverlay.BackgroundTransparency = 1  -- Start hidden
	cooldownOverlay.ZIndex = 4
        local cooldownCorner = Instance.new("UICorner")
        cooldownCorner.CornerRadius = scaleUDim(UI_CONFIG.CORNER_RADIUS)
	cooldownCorner.Parent = cooldownOverlay
	local cooldownGradient = Instance.new("UIGradient")
	cooldownGradient.Rotation = 90
	cooldownGradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
		ColorSequenceKeypoint.new(1, Color3.new(1,1,1))
	}
	cooldownGradient.Parent = cooldownOverlay
	cooldownOverlay.Parent = button

	-- New: Cooldown text
	local cooldownText = Instance.new("TextLabel")
	cooldownText.Name = "CooldownText"
	cooldownText.Size = UDim2.new(1, 0, 1, 0)
	cooldownText.BackgroundTransparency = 1
	cooldownText.TextColor3 = UI_CONFIG.TEXT_COLOR
	cooldownText.TextScaled = true
	cooldownText.Font = Enum.Font.GothamBold
	cooldownText.ZIndex = 5
	cooldownText.Visible = false
	cooldownText.Parent = button

	return button
end

local function setupButtonAnimations(button)
        local scaleObject = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
        scaleObject.Scale = 1
        scaleObject.Parent = button

	local function tweenScale(target, duration, easing)
		local tween = TweenService:Create(
			scaleObject,
			TweenInfo.new(duration or UI_CONFIG.TWEEN_TIME, easing or Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{Scale = target}
		)
		tween:Play()
		return tween
	end

	registerConnection(buttonConnections, button.MouseEnter:Connect(function()
		if not shouldUseMobileLayout() then
			tweenScale(UI_CONFIG.HOVER_SCALE)
		end
	end))

	registerConnection(buttonConnections, button.MouseLeave:Connect(function()
		if not shouldUseMobileLayout() then
			tweenScale(1)
		end
	end))

	local function handlePress()
		tweenScale(UI_CONFIG.PRESS_SCALE, 0.08, Enum.EasingStyle.Quad)
	end

	local function handleRelease()
		tweenScale(1, 0.12, UI_CONFIG.BOUNCE_EASING)  -- Added bounce for fun feel
	end

	registerConnection(buttonConnections, button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.Gamepad1 then
			handlePress()
		end
	end))

        registerConnection(buttonConnections, button.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch
                        or input.UserInputType == Enum.UserInputType.Gamepad1 then
                        handleRelease()
                end
        end))
end

local function connectButtonActivation(button, callback)
        if not button or not callback then
                return
        end

        local lastActivation = 0

        local function handleActivation(...)
                local now = os.clock()
                if now - lastActivation < 0.05 then
                        return
                end
                lastActivation = now
                callback(...)
        end

        if button:IsA("GuiButton") then
                if typeof(button.Activated) == "RBXScriptSignal" then
                        registerConnection(buttonConnections, button.Activated:Connect(handleActivation))
                end

                if typeof(button.MouseButton1Click) == "RBXScriptSignal" then
                        registerConnection(buttonConnections, button.MouseButton1Click:Connect(handleActivation))
                end
        end
end

local function playButtonSound(soundId)
        if UI_CONFIG.ENABLE_SOUNDS then
                local sound = Instance.new("Sound")
                sound.SoundId = soundId or UI_CONFIG.BUTTON_SOUND_ID
		sound.Volume = 0.5
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	end
end

local function triggerHapticFeedback()
	if UI_CONFIG.ENABLE_HAPTICS and HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) then
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0.3)
		task.delay(0.1, function()
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0)
		end)
	end
end

local function updateToggleVisual()
	if not toggleButtonRef then
		return
	end

	if #fanButtons == 0 then
		toggleButtonRef.Visible = false
		return
	end

	toggleButtonRef.Visible = true
	toggleButtonRef.Text = fanOpen and "−" or "☰"
end

local function applySpeedState(forceRemote)
        local humanoid = getHumanoid()
        if not humanoid then
                return
        end

        local level = getCurrentLevel()
        defaultWalkSpeed = GameSettings.movementSpeed(level)

        local desiredMode = fanOpen and BATTLE_MODE or RUN_MODE
        local targetSpeed = calculateSpeedForMode(level, desiredMode)

        humanoid.WalkSpeed = targetSpeed
        speedBoostApplied = (desiredMode == RUN_MODE)

        local previousMode = currentMovementMode
        currentMovementMode = desiredMode

        local shouldForce = forceRemote or (previousMode ~= currentMovementMode)
        sendMovementMode(currentMovementMode, shouldForce)
end

local function connectStatListeners()
        local player = Players.LocalPlayer
        if not player then
                return
        end

        if not statsAddedConnection then
                statsAddedConnection = player.ChildAdded:Connect(function(child)
                        if child.Name == "Stats" then
                                if levelChangedConnection then
                                        levelChangedConnection:Disconnect()
                                        levelChangedConnection = nil
                                end
                                connectStatListeners()
                                applySpeedState(true)
                        end
                end)
        end

        local stats = player:FindFirstChild("Stats")
        if not stats then
                return
        end

        local levelValue = stats:FindFirstChild("Level")
        if levelValue and not levelChangedConnection then
                levelChangedConnection = levelValue:GetPropertyChangedSignal("Value"):Connect(function()
                        applySpeedState(true)
                end)
        end

        applySpeedState(true)
end

local function ensureCharacterTracking()
        local player = Players.LocalPlayer
        if not player then
                return
        end

        connectStatListeners()

        if characterAddedConnection then
                return
        end

        characterAddedConnection = player.CharacterAdded:Connect(function()
                defaultWalkSpeed = nil
                speedBoostApplied = false
                task.defer(function()
                        applySpeedState(true)
                end)
        end)

        if player.Character then
                task.defer(function()
                        applySpeedState(true)
                end)
        end
end

local function updateFanLayout(animated)
        if not currentActionsFrame or not jumpButtonRef then
                return
        end

        local mobileLayout = shouldUseMobileLayout()
        local radius = getFanRadius(mobileLayout)
        local jumpSize = jumpButtonRef.Size
        local margin = getJumpMargin(mobileLayout)
        local baseOffsetX = -(jumpSize.X.Offset / 2) - margin
        local baseOffsetY = -(jumpSize.Y.Offset / 2) - margin

        currentActionsFrame.AnchorPoint = Vector2.new(1, 1)
        local edgePadding = scaleNumber(25)
        currentActionsFrame.Position = UDim2.new(1, -edgePadding, 1, -edgePadding)

        local abilityEntries = {}
        local otherEntries = {}

        for _, button in ipairs(fanButtons) do
                if button and button.Parent == currentActionsFrame then
                        local category = button:GetAttribute("ButtonCategory")
                        local priority = button.LayoutOrder or button:GetAttribute("ActionPriority") or 999
                        if category == "ability" then
                                local order = ABILITY_FAN_ORDER[button.Name]
                                if order then
                                        table.insert(abilityEntries, {button = button, order = order})
                                else
                                        table.insert(otherEntries, {button = button, order = priority})
                                end
                        else
                                table.insert(otherEntries, {button = button, order = priority})
                        end
                end
        end

        table.sort(abilityEntries, function(a, b)
                if a.order == b.order then
                        local aPriority = a.button.LayoutOrder or a.button:GetAttribute("ActionPriority") or 999
                        local bPriority = b.button.LayoutOrder or b.button:GetAttribute("ActionPriority") or 999
                        if aPriority == bPriority then
                                return a.button.Name < b.button.Name
                        end
                        return aPriority < bPriority
                end
                return a.order < b.order
        end)

        table.sort(otherEntries, function(a, b)
                if a.order == b.order then
                        return a.button.Name < b.button.Name
                end
                return a.order < b.order
        end)

        local abilityButtons = {}
        for _, entry in ipairs(abilityEntries) do
                table.insert(abilityButtons, entry.button)
        end

        local innerButtons = {}
        for _, entry in ipairs(otherEntries) do
                table.insert(innerButtons, entry.button)
        end

        local innerAngles = computeFanAngles(#innerButtons, FAN_CONFIG.START_ANGLE, FAN_CONFIG.END_ANGLE)
        local outerStart = FAN_CONFIG.OUTER_START_ANGLE or FAN_CONFIG.START_ANGLE
        local outerEnd = FAN_CONFIG.OUTER_END_ANGLE or FAN_CONFIG.END_ANGLE
        local abilityAngles = computeFanAngles(#abilityButtons, outerStart, outerEnd)

        local abilityRadius = radius
        if #abilityButtons > 0 then
                abilityRadius = getOuterFanRadius(radius, mobileLayout)
        end

        local innerMargin = getHorizontalMargin(mobileLayout, false)
        local abilityMargin = getHorizontalMargin(mobileLayout, true)
        local innerShiftX = computeHorizontalShift(innerAngles, radius, innerMargin)
        local abilityShiftX = computeHorizontalShift(abilityAngles, abilityRadius, abilityMargin)

        local innerShiftY = getVerticalShift(mobileLayout, false)
        local abilityShiftY = getVerticalShift(mobileLayout, true)

        local extents = {minX = 0, maxX = 0, minY = 0, maxY = 0}
        updateFanExtents(innerAngles, radius, innerShiftX, innerShiftY, extents)
        updateFanExtents(abilityAngles, abilityRadius, abilityShiftX, abilityShiftY, extents)

        local maxRadius = math.max(radius, abilityRadius)
        local extraPadding = scaleNumber(20)
        local horizontalExtent = math.max(maxRadius, math.abs(extents.minX), math.abs(extents.maxX))
        local verticalExtent = math.max(maxRadius, math.abs(extents.minY), math.abs(extents.maxY))
        local frameWidth = jumpSize.X.Offset + margin * 2 + horizontalExtent + extraPadding
        local frameHeight = jumpSize.Y.Offset + margin * 2 + verticalExtent + extraPadding
        currentActionsFrame.Size = UDim2.new(0, frameWidth, 0, frameHeight)
        currentActionsFrame.ClipsDescendants = false

        local layoutIndex = 0
        local function layoutGroup(buttons, angles, targetRadius, shiftX, shiftY)
                if #buttons == 0 then
                        return
                end

                local openShiftX = fanOpen and (shiftX or 0) or 0
                local openShiftY = fanOpen and (shiftY or 0) or 0

                for idx, button in ipairs(buttons) do
                        layoutIndex += 1
                        button.AnchorPoint = Vector2.new(0.5, 0.5)
                        local angle = angles[idx] or angles[1] or 0
                        local deltaX = fanOpen and math.cos(angle) * targetRadius or 0
                        local deltaY = fanOpen and math.sin(angle) * targetRadius or 0
                        deltaX += openShiftX
                        deltaY += openShiftY
                        local targetPosition = UDim2.new(1, baseOffsetX + deltaX, 1, baseOffsetY + deltaY)

                        if animated then
                                button.Visible = true
                                local tween = TweenService:Create(button, TweenInfo.new(FAN_CONFIG.ANIMATION_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                        Position = targetPosition,
                                        Rotation = fanOpen and 0 or 5 * (layoutIndex % 2 == 0 and 1 or -1),
                                })
                                tween:Play()
                                if not fanOpen then
                                        tween.Completed:Connect(function()
                                                if not fanOpen then
                                                        button.Visible = false
                                                end
                                        end)
                                end
                        else
                                button.Position = targetPosition
                                button.Rotation = 0
                                button.Visible = fanOpen
                        end
                end
        end

        layoutGroup(innerButtons, innerAngles, radius, innerShiftX, innerShiftY)
        layoutGroup(abilityButtons, abilityAngles, abilityRadius, abilityShiftX, abilityShiftY)

        if toggleButtonRef then
                local toggleSize = getToggleSize(mobileLayout)
                if toggleSize then
                        toggleButtonRef.Size = toggleSize
                else
                        toggleSize = toggleButtonRef.Size
                end
                local toggleMargin = getToggleMargin(mobileLayout)
                local toggleOffsetX = -(jumpSize.X.Offset / 2) - margin - (toggleSize.X.Offset / 2) - toggleMargin
                local toggleOffsetY = -(jumpSize.Y.Offset / 2)
                toggleButtonRef.Position = UDim2.new(1, toggleOffsetX, 1, toggleOffsetY)
                toggleButtonRef.Visible = #fanButtons > 0
        end

        if not fanOpen and not animated then
                for _, button in ipairs(fanButtons) do
                        button.Visible = false
                end
        end
end

local function setFanOpen(state, animated)
        local targetState = state ~= false
        local shouldAnimate = animated ~= false
        local stateChanged = fanOpen ~= targetState

        if stateChanged then
                fanOpen = targetState
                if not fanOpen then
                        putAwayWeapons()
                end
        end

        updateToggleVisual()
        updateFanLayout(shouldAnimate)
        applySpeedState(stateChanged)

        return fanOpen
end

local function performCustomJump()
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		lastJumpTime = os.clock()

		-- Enhanced: Add particle effect or custom boost
		-- Example: local particles = Instance.new("ParticleEmitter") ... 

		playButtonSound(UI_CONFIG.JUMP_SOUND_ID)
		triggerHapticFeedback()

		print("Custom jump performed!")
	end
end

local function disableDefaultJump()
	if customJumpEnabled then
		return
	end

        customJumpEnabled = true

        if isMobile() or forceActionsVisible then
                setJumpButtonEnabled(false)
                enforceTouchJumpVisibility(false)
        end

        bindJumpOverride()

	print("Default jump disabled - using custom jump system")
end

local function enableDefaultJump()
	if not customJumpEnabled then
		return
	end

        unbindJumpOverride()

        if isMobile() or forceActionsVisible then
                enforceTouchJumpVisibility(true)
                setJumpButtonEnabled(true)
        else
                enforceTouchJumpVisibility(true)
        end

        customJumpEnabled = false
	print("Default jump restored")
end

local function updateCooldownVisuals()
	for buttonName, cooldown in pairs(cooldowns) do
		local button = currentActionsFrame and currentActionsFrame:FindFirstChild(buttonName)
		if button then
			local overlay = button:FindFirstChild("CooldownOverlay")
			local text = button:FindFirstChild("CooldownText")
			local remaining = cooldown.endTime - tick()
			if remaining > 0 then
				local progress = remaining / cooldown.duration
				overlay.BackgroundTransparency = UI_CONFIG.COOLDOWN_OVERLAY_TRANSPARENCY
				overlay.Size = UDim2.new(1, 0, progress, 0)
				text.Text = math.ceil(remaining)
				text.Visible = true
				button.AutoButtonColor = false
				button.BackgroundColor3 = UI_CONFIG.DISABLED_COLOR
			else
				overlay.BackgroundTransparency = 1
				overlay.Size = UDim2.new(1, 0, 1, 0)
				text.Visible = false
				button.AutoButtonColor = true
				button.BackgroundColor3 = button:GetAttribute("OriginalColor") or UI_CONFIG.COMBAT_COLOR  -- Restore original
				cooldowns[buttonName] = nil
			end
		end
	end
end

local function startCooldown(buttonName, duration)
	cooldowns[buttonName] = {endTime = tick() + duration, duration = duration}
end

local function ensureActions()
	local player = Players.LocalPlayer
	if not player then
		return nil
	end

	local gui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)
	if not gui then
		warn("ActionUI could not locate PlayerGui")
		return nil
	end

	local screenGui = gui:FindFirstChild("ScreenGui")

        if not shouldDisplayActions() then
                disconnectConnections(buttonConnections)
                if screenGui then
                        local existingActions = screenGui:FindFirstChild("Actions")
                        if existingActions then
                                existingActions:Destroy()
                        end
                end

                fanOpen = true
                speedBoostApplied = false
                defaultWalkSpeed = nil
                applySpeedState(true)
                currentActionsFrame = nil
                jumpButtonRef = nil
                toggleButtonRef = nil
                table.clear(fanButtons)
                table.clear(cooldowns)

		return nil
	end

	disconnectConnections(buttonConnections)

	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "ScreenGui"
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.Parent = gui
	end

	local existing = screenGui:FindFirstChild("Actions")
	if existing then
		existing:Destroy()
	end

        updateUIScale()

        local actions = Instance.new("Frame")
        actions.Name = "Actions"
        actions.BackgroundTransparency = 1
        actions.AnchorPoint = Vector2.new(1, 1)
        local actionInset = scaleNumber(20)
        actions.Position = UDim2.new(1, -actionInset, 1, -actionInset)
        actions.ClipsDescendants = false
        actions.Parent = screenGui

	currentActionsFrame = actions
	jumpButtonRef = nil
	toggleButtonRef = nil
	table.clear(fanButtons)
	table.clear(cooldowns)

	local sortedButtons = {}
	for _, buttonDef in ipairs(BUTTON_DEFINITIONS) do
		table.insert(sortedButtons, buttonDef)
	end
	table.sort(sortedButtons, function(a, b)
		return (a.priority or 999) < (b.priority or 999)
	end)

	local mobileLayout = shouldUseMobileLayout()
	local allowJumpButton = mobileLayout

	if not allowJumpButton and UI_CONFIG.SHOW_ON_DESKTOP and UI_CONFIG.SHOW_DESKTOP_JUMP and isDesktop() then
		allowJumpButton = true
	end

        for _, buttonDef in ipairs(sortedButtons) do
                local isJumpButton = buttonDef.category == "jump"
                if not (isJumpButton and not allowJumpButton) then
                        local button = createStylizedButton(buttonDef)
                        button:SetAttribute("OriginalColor", button.BackgroundColor3)
                        button:SetAttribute("ButtonCategory", buttonDef.category or "misc")
                        button:SetAttribute("ActionPriority", buttonDef.priority or 999)
                        button.LayoutOrder = buttonDef.priority or 999
                        button.AnchorPoint = Vector2.new(0.5, 0.5)
                        button.Parent = actions
                        setupButtonAnimations(button)

                        if isJumpButton then
				jumpButtonRef = button
			else
				table.insert(fanButtons, button)
			end
		end
	end

        if jumpButtonRef then
                local margin = getJumpMargin(mobileLayout)
                local jumpSize = jumpButtonRef.Size
                jumpButtonRef.Position = UDim2.new(
                        1,
                        -(jumpSize.X.Offset / 2) - margin,
			1,
			-(jumpSize.Y.Offset / 2) - margin
		)
	end

	for _, button in ipairs(fanButtons) do
		if jumpButtonRef then
			button.Position = jumpButtonRef.Position
		else
			button.Position = UDim2.new(1, -button.Size.X.Offset / 2, 1, -button.Size.Y.Offset / 2)
		end
	end

        if #fanButtons > 0 then
                toggleButtonRef = createFanToggleButton()
                toggleButtonRef.Parent = actions
                connectButtonActivation(toggleButtonRef, function()
                        setFanOpen(not fanOpen)
                        playButtonSound()
                        triggerHapticFeedback()
                end)
        end

	setFanOpen(fanOpen, false)

	return actions
end

function ActionUI.init()
        updateUIScale()
        ensureCharacterTracking()

        local actions = ensureActions()

        if actions and shouldOverrideDefaultJump() then
                disableDefaultJump()
        else
                enableDefaultJump()
        end

	if actions then
		-- Combat actions
		local actionMap = {
			PunchButton = {func = CombatController.perform, param = "Punch", cooldown = 1},  -- Example cooldown
			KickButton = {func = CombatController.perform, param = "Kick", cooldown = 2},
			RollButton = {func = CombatController.perform, param = "Roll", cooldown = 3},
			CrouchButton = {func = CombatController.perform, param = "Crouch", cooldown = 0},  -- No cooldown
			SlideButton = {func = CombatController.perform, param = "Slide", cooldown = 4},
		}

                for buttonName, data in pairs(actionMap) do
                        local btn = actions:FindFirstChild(buttonName)
                        if btn then
                                connectButtonActivation(btn, function()
                                        if cooldowns[buttonName] then return end
                                        data.func(data.param)
                                        playButtonSound()
                                        triggerHapticFeedback()
                                        if data.cooldown > 0 then
                                                startCooldown(buttonName, data.cooldown)
                                        end
                                end)
                        end
                end

                -- Jump
                local jumpBtn = actions:FindFirstChild("JumpButton")
                if jumpBtn then
                        connectButtonActivation(jumpBtn, performCustomJump)
                end

                -- Abilities (with example cooldowns)
                local abilityMap = {
			TossButton = {func = Abilities.Toss, cooldown = 5},
			StarButton = {func = Abilities.Star, cooldown = 10},
			RainButton = {func = Abilities.Rain, cooldown = 15},
			BeastButton = {func = Abilities.Beast, cooldown = 20},
			DragonButton = {func = Abilities.Dragon, cooldown = 25},
		}

                for buttonName, data in pairs(abilityMap) do
                        local btn = actions:FindFirstChild(buttonName)
                        if btn then
                                connectButtonActivation(btn, function()
                                        if cooldowns[buttonName] then return end
                                        data.func()
                                        playButtonSound()
                                        triggerHapticFeedback()
                                        if data.cooldown > 0 then
                                                startCooldown(buttonName, data.cooldown)
                                        end
                                end)
                        end
                end
        end

	-- Keybinds (updated to check cooldowns)
	local abilityKeybinds = {
		[Enum.KeyCode.F] = {func = Abilities.Toss, button = "TossButton"},
		[Enum.KeyCode.G] = {func = Abilities.Star, button = "StarButton"},
		[Enum.KeyCode.Z] = {func = Abilities.Rain, button = "RainButton"},
		[Enum.KeyCode.B] = {func = Abilities.Beast, button = "BeastButton"},
		[Enum.KeyCode.X] = {func = Abilities.Dragon, button = "DragonButton"},
	}

	local combatKeybinds = {
		[Enum.KeyCode.E] = {func = CombatController.perform, param = "Punch", button = "PunchButton"},
		[Enum.KeyCode.T] = {func = CombatController.perform, param = "Punch", button = "PunchButton"},
		[Enum.KeyCode.Q] = {func = CombatController.perform, param = "Kick", button = "KickButton"},
		[Enum.KeyCode.R] = {func = CombatController.perform, param = "Roll", button = "RollButton"},
		[Enum.KeyCode.C] = {func = CombatController.perform, param = "Crouch", button = "CrouchButton"},
		[Enum.KeyCode.LeftControl] = {func = CombatController.perform, param = "Slide", button = "SlideButton"},
		[Enum.KeyCode.Space] = {func = performCustomJump, button = "JumpButton"},
	}

	local ignoredInputKeys = {
		[Enum.KeyCode.W] = true,
		[Enum.KeyCode.A] = true,
		[Enum.KeyCode.S] = true,
		[Enum.KeyCode.D] = true,
		[Enum.KeyCode.LeftShift] = true,
		[Enum.KeyCode.Up] = true,
		[Enum.KeyCode.Down] = true,
		[Enum.KeyCode.Left] = true,
		[Enum.KeyCode.Right] = true,
		[Enum.KeyCode.Tab] = true,
		[Enum.KeyCode.Escape] = true,
		[Enum.KeyCode.Return] = true,
	}

	local debugInputLogging = false
	local LOG_TOGGLE_KEY = Enum.KeyCode.F8

	disconnectConnections(inputConnections)

	registerConnection(inputConnections, UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == LOG_TOGGLE_KEY then
			debugInputLogging = not debugInputLogging
			warn("Raw input logging " .. (debugInputLogging and "enabled" or "disabled"))
			return
		end

		if processed then return end

		local data
		if abilityKeybinds[input.KeyCode] then
			data = abilityKeybinds[input.KeyCode]
		elseif combatKeybinds[input.KeyCode] then
			data = combatKeybinds[input.KeyCode]
		end

                if data then
                        if cooldowns[data.button] then return end
                        if data.param then
                                data.func(data.param)
                        else
                                data.func()
                        end
                        -- No cooldown start here, assume handled in func or button
                        return
                end

                if input.KeyCode == Enum.KeyCode.Minus or input.KeyCode == Enum.KeyCode.KeypadMinus then
                        setFanOpen(not fanOpen)
                        playButtonSound()
                        triggerHapticFeedback()
                        return
                end

                if debugInputLogging and not ignoredInputKeys[input.KeyCode] then
                        print("Unmapped key pressed:", input.KeyCode.Name)
                end
        end))

	-- Auto-resize
	local camera = workspace.CurrentCamera
	if camera and (not viewportConnection or not viewportConnection.Connected) then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			task.delay(0.1, ActionUI.init)
		end)
	end

	-- Device changes
	if #deviceChangeConnections == 0 then
		registerConnection(deviceChangeConnections, UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(function()
			task.defer(ActionUI.init)
		end))
		registerConnection(deviceChangeConnections, UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(function()
			task.defer(ActionUI.init)
		end))
		registerConnection(deviceChangeConnections, UserInputService:GetPropertyChangedSignal("GamepadEnabled"):Connect(function()
			task.defer(ActionUI.init)
		end))
		registerConnection(deviceChangeConnections, UserInputService.LastInputTypeChanged:Connect(function()
			task.defer(ActionUI.init)
		end))
		registerConnection(deviceChangeConnections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			if viewportConnection then
				viewportConnection:Disconnect()
				viewportConnection = nil
			end
			task.defer(ActionUI.init)
		end))
	end

	-- New: Cooldown update loop
	if not RunService:IsClient() then return end
	registerConnection(buttonConnections, RunService.RenderStepped:Connect(updateCooldownVisuals))
end

function ActionUI.toggleFanOpen(animated)
	return setFanOpen(not fanOpen, animated)
end

function ActionUI.setFanOpen(open, animated)
	return setFanOpen(open, animated)
end

function ActionUI.isFanOpen()
	return fanOpen
end

function ActionUI.toggleJumpMode()
	if customJumpEnabled then
		enableDefaultJump()
	else
		disableDefaultJump()
	end
	return customJumpEnabled
end

function ActionUI.addButton(name, text, category, callback, keybind, priority, icon, cooldown)
	table.insert(BUTTON_DEFINITIONS, {
		name = name,
		text = text,
		icon = icon,
		action = text:lower(),
		category = category,
		keybind = keybind,
		priority = priority or 999
	})

	ActionUI.init()

	local player = Players.LocalPlayer
	local gui = player.PlayerGui
	local screenGui = gui:FindFirstChild("ScreenGui")
	local actions = screenGui and screenGui:FindFirstChild("Actions")
        if actions then
                local button = actions:FindFirstChild(name)
                if button and callback then
                        connectButtonActivation(button, function()
                                if cooldowns[name] then return end
                                callback()
                                playButtonSound()
                                triggerHapticFeedback()
                                if cooldown and cooldown > 0 then
                                        startCooldown(name, cooldown)
                                end
                        end)
                end
        end
end

function ActionUI.setCustomJumpLogic(jumpFunction)
	if typeof(jumpFunction) == "function" then
		performCustomJump = function(...)
			lastJumpTime = os.clock()
			jumpFunction(...)
		end
	end
end

function ActionUI.setForceActionsVisible(enabled)
	forceActionsVisible = not not enabled
	ActionUI.init()
	return forceActionsVisible
end

function ActionUI.isForceActionsVisible()
	return forceActionsVisible
end

-- New: Function to start cooldown from external scripts
function ActionUI.startCooldown(buttonName, duration)
        startCooldown(buttonName, duration)
end

return ActionUI
