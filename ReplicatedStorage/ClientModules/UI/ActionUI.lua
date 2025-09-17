local ActionUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")

local Abilities = require(ReplicatedStorage.ClientModules.Abilities)
local CombatController = require(ReplicatedStorage.ClientModules.CombatController)

-- UI Configuration
local UI_CONFIG = {
	-- Colors
	COMBAT_COLOR = Color3.fromRGB(220, 50, 47),     -- Red for combat actions
	ABILITY_COLOR = Color3.fromRGB(38, 139, 210),   -- Blue for abilities  
	MOVEMENT_COLOR = Color3.fromRGB(133, 153, 0),   -- Yellow-green for movement
	JUMP_COLOR = Color3.fromRGB(46, 204, 113),      -- Green for jump

	-- Gradients
	GRADIENT_OFFSET = Vector2.new(0, 0.3),

	-- Animation
	PRESS_SCALE = 0.9,
	HOVER_SCALE = 1.05,
	TWEEN_TIME = 0.15,

	-- Layout
	BUTTON_SIZE = UDim2.new(0, 80, 0, 80),
	MOBILE_BUTTON_SIZE = UDim2.new(0, 60, 0, 60),
	JUMP_BUTTON_SIZE = UDim2.new(0, 90, 0, 90),     -- Larger jump button
	MOBILE_JUMP_SIZE = UDim2.new(0, 70, 0, 70),
	PADDING = UDim.new(0, 8),
        CORNER_RADIUS = UDim.new(0, 12),

        -- Platform visibility
        SHOW_ON_DESKTOP = true,
        SHOW_DESKTOP_JUMP = true,
}


local FAN_CONFIG = {
	START_ANGLE = math.rad(210),
	END_ANGLE = math.rad(330),
	MOBILE_RADIUS = 110,
	DESKTOP_RADIUS = 150,
	JUMP_MARGIN = 12,
	TOGGLE_MARGIN = 14,
	ANIMATION_TIME = 0.25,
	SPEED_BOOST = 4,
	TOGGLE_SIZE = UDim2.new(0, 44, 0, 44),
	MOBILE_TOGGLE_SIZE = UDim2.new(0, 36, 0, 36),
}

-- Button definitions with categories and styling
local BUTTON_DEFINITIONS = {
	-- Jump Action (Special green theme) - First for priority positioning
	{name = "JumpButton", text = "JUMP", action = "Jump", category = "jump", keybind = "Space", priority = 1},

	-- Combat Actions (Red theme)
	{name = "PunchButton", text = "PUNCH", action = "Punch", category = "combat", keybind = "E/T", priority = 2},
	{name = "KickButton", text = "KICK", action = "Kick", category = "combat", keybind = "Q", priority = 3},

	-- Movement Actions (Yellow-green theme)
	{name = "RollButton", text = "ROLL", action = "Roll", category = "movement", keybind = "R", priority = 4},
	{name = "CrouchButton", text = "CROUCH", action = "Crouch", category = "movement", keybind = "C", priority = 5},
	{name = "SlideButton", text = "SLIDE", action = "Slide", category = "movement", keybind = "Ctrl", priority = 6},

	-- Abilities (Blue theme)
	{name = "TossButton", text = "TOSS", action = "Toss", category = "ability", keybind = "F", priority = 7},
	{name = "StarButton", text = "STAR", action = "Star", category = "ability", keybind = "G", priority = 8},
	{name = "RainButton", text = "RAIN", action = "Rain", category = "ability", keybind = "Z", priority = 9},
	{name = "BeastButton", text = "BEAST", action = "Beast", category = "ability", keybind = "B", priority = 10},
	{name = "DragonButton", text = "DRAGON", action = "Dragon", category = "ability", keybind = "X", priority = 11},
}

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

local updateFanLayout
local updateToggleVisual
local applySpeedState
local setFanOpen
local ensureCharacterTracking
local performCustomJump

local function isMobile()
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function isDesktop()
        return UserInputService.KeyboardEnabled or UserInputService.GamepadEnabled
end

local function shouldUseMobileLayout()
        return isMobile() or forceActionsVisible
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

-- Determines whether the touch actions UI should be visible/active
local function shouldDisplayActions()
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

local function createGradient(color)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(1, Color3.new(color.R * 0.7, color.G * 0.7, color.B * 0.7))
	}
	gradient.Offset = UI_CONFIG.GRADIENT_OFFSET
	return gradient
end

local function createButtonShadow()
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 3, 0.5, 3)
	shadow.Size = UDim2.new(1, 0, 1, 0)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.7
	shadow.ZIndex = -1

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UI_CONFIG.CORNER_RADIUS
	shadowCorner.Parent = shadow

	return shadow
end

local function createFanToggleButton()
        local toggle = Instance.new("TextButton")
        toggle.Name = "FanToggle"
        toggle.Text = ""
        toggle.AutoButtonColor = true
        toggle.BackgroundTransparency = 0.1
        toggle.BackgroundColor3 = Color3.fromRGB(45, 52, 54)
        toggle.BorderSizePixel = 0
        toggle.AnchorPoint = Vector2.new(0.5, 0.5)
        toggle.ZIndex = 4
        toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggle.TextScaled = true
        toggle.Font = Enum.Font.GothamBold

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UI_CONFIG.CORNER_RADIUS
        corner.Parent = toggle

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
        button.ClipsDescendants = false

        local mobileLayout = shouldUseMobileLayout()

        -- Special sizing for jump button
        if buttonDef.category == "jump" then
                button.Size = mobileLayout and UI_CONFIG.MOBILE_JUMP_SIZE or UI_CONFIG.JUMP_BUTTON_SIZE
        else
                button.Size = mobileLayout and UI_CONFIG.MOBILE_BUTTON_SIZE or UI_CONFIG.BUTTON_SIZE
        end

        -- Colors based on category
        local color = UI_CONFIG.COMBAT_COLOR
        if buttonDef.category == "ability" then
                color = UI_CONFIG.ABILITY_COLOR
        elseif buttonDef.category == "movement" then
                color = UI_CONFIG.MOVEMENT_COLOR
        elseif buttonDef.category == "jump" then
                color = UI_CONFIG.JUMP_COLOR
        end

        button.BackgroundColor3 = color

        -- Corner radius
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UI_CONFIG.CORNER_RADIUS
        corner.Parent = button

        -- Accent border
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 2
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Color = color:Lerp(Color3.new(1, 1, 1), 0.35)
        stroke.Transparency = 0.25
        stroke.Parent = button

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 6)
        padding.PaddingBottom = UDim.new(0, 6)
        padding.PaddingLeft = UDim.new(0, 8)
        padding.PaddingRight = UDim.new(0, 8)
        padding.Parent = button

        -- Gradient
        local gradient = createGradient(color)
        gradient.Parent = button

	-- Shadow
	local shadow = createButtonShadow()
	shadow.Parent = button

	-- Main text label
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "MainText"
	textLabel.Parent = button
	textLabel.Size = UDim2.new(1, 0, 0.6, 0)
	textLabel.Position = UDim2.new(0, 0, 0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = buttonDef.text
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextScaled = true
        textLabel.Font = Enum.Font.GothamBold
        textLabel.ZIndex = 3
        textLabel.TextWrapped = true

        -- Keybind label
        local keybindLabel = Instance.new("TextLabel")
        keybindLabel.Name = "Keybind"
        keybindLabel.Parent = button
	keybindLabel.Size = UDim2.new(1, 0, 0.3, 0)
	keybindLabel.Position = UDim2.new(0, 0, 0.7, 0)
	keybindLabel.BackgroundTransparency = 1
        keybindLabel.Text = buttonDef.keybind or ""
        keybindLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        keybindLabel.TextScaled = true
        keybindLabel.Font = Enum.Font.Gotham
        keybindLabel.ZIndex = 3
        keybindLabel.TextWrapped = true
        keybindLabel.Visible = not mobileLayout
end

local function setupButtonAnimations(button)
        local scaleObject = button:FindFirstChildOfClass("UIScale")
        if not scaleObject then
                scaleObject = Instance.new("UIScale")
                scaleObject.Scale = 1
                scaleObject.Parent = button
        else
                scaleObject.Scale = 1
        end

        local function tweenScale(target, duration)
                local tween = TweenService:Create(
                        scaleObject,
                        TweenInfo.new(duration or UI_CONFIG.TWEEN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
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
                tweenScale(UI_CONFIG.PRESS_SCALE, 0.08)
        end

        local function handleRelease()
                tweenScale(1, 0.12)
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

local function applySpeedState()
        local humanoid = getHumanoid()
        if not humanoid then
                return
        end

        if fanOpen then
                if speedBoostApplied and defaultWalkSpeed then
                        humanoid.WalkSpeed = defaultWalkSpeed
                end
                speedBoostApplied = false
                return
        end

        if not speedBoostApplied then
                defaultWalkSpeed = humanoid.WalkSpeed
        end

        humanoid.WalkSpeed = (defaultWalkSpeed or humanoid.WalkSpeed) + FAN_CONFIG.SPEED_BOOST
        speedBoostApplied = true
end

local function ensureCharacterTracking()
        local player = Players.LocalPlayer
        if not player then
                return
        end

        if characterAddedConnection then
                return
        end

        characterAddedConnection = player.CharacterAdded:Connect(function()
                defaultWalkSpeed = nil
                speedBoostApplied = false
                task.defer(applySpeedState)
        end)

        if player.Character then
                task.defer(applySpeedState)
        end
end

local function updateFanLayout(animated)
        if not currentActionsFrame or not jumpButtonRef then
                return
        end

        local mobileLayout = shouldUseMobileLayout()
        local radius = mobileLayout and FAN_CONFIG.MOBILE_RADIUS or FAN_CONFIG.DESKTOP_RADIUS
        local jumpSize = jumpButtonRef.Size
        local baseOffsetX = -(jumpSize.X.Offset / 2) - FAN_CONFIG.JUMP_MARGIN
        local baseOffsetY = -(jumpSize.Y.Offset / 2) - FAN_CONFIG.JUMP_MARGIN

        currentActionsFrame.AnchorPoint = Vector2.new(1, 1)
        currentActionsFrame.Position = UDim2.new(1, -20, 1, -20)
        local frameWidth = radius + jumpSize.X.Offset + FAN_CONFIG.JUMP_MARGIN * 2
        local frameHeight = radius + jumpSize.Y.Offset + FAN_CONFIG.JUMP_MARGIN * 2
        currentActionsFrame.Size = UDim2.new(0, frameWidth, 0, frameHeight)
        currentActionsFrame.ClipsDescendants = false

        local totalButtons = #fanButtons
        for index, button in ipairs(fanButtons) do
                button.AnchorPoint = Vector2.new(0.5, 0.5)

                local angle
                if totalButtons <= 1 then
                        angle = (FAN_CONFIG.START_ANGLE + FAN_CONFIG.END_ANGLE) * 0.5
                else
                        angle = FAN_CONFIG.START_ANGLE + (index - 1) / (totalButtons - 1) * (FAN_CONFIG.END_ANGLE - FAN_CONFIG.START_ANGLE)
                end

                local deltaX = fanOpen and math.cos(angle) * radius or 0
                local deltaY = fanOpen and math.sin(angle) * radius or 0
                local targetPosition = UDim2.new(1, baseOffsetX + deltaX, 1, baseOffsetY + deltaY)

                if animated then
                        button.Visible = true
                        local tween = TweenService:Create(button, TweenInfo.new(FAN_CONFIG.ANIMATION_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                Position = targetPosition,
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
                        button.Visible = fanOpen
                end
        end

        if toggleButtonRef then
                local toggleSize = mobileLayout and FAN_CONFIG.MOBILE_TOGGLE_SIZE or FAN_CONFIG.TOGGLE_SIZE
                toggleButtonRef.Size = toggleSize
                local toggleOffsetX = -(jumpSize.X.Offset / 2) - FAN_CONFIG.JUMP_MARGIN - (toggleSize.X.Offset / 2) - FAN_CONFIG.TOGGLE_MARGIN
                local toggleOffsetY = -(jumpSize.Y.Offset / 2)
                toggleButtonRef.Position = UDim2.new(1, toggleOffsetX, 1, toggleOffsetY)
                toggleButtonRef.Visible = totalButtons > 0
        end

        if not fanOpen and not animated then
                for _, button in ipairs(fanButtons) do
                        button.Visible = false
                end
        end
end

local function setFanOpen(state, animated)
        local targetState = state ~= false
        local shouldAnimate = animated
        if shouldAnimate == nil then
                shouldAnimate = true
        end

        if fanOpen ~= targetState then
                fanOpen = targetState
        end

        updateToggleVisual()
        updateFanLayout(shouldAnimate)
        applySpeedState()

        return fanOpen
end

-- Custom jump function with enhanced features
local function performCustomJump()
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then return end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end

        -- Enhanced jump logic - you can customize this
        if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
                -- Basic jump
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                lastJumpTime = os.clock()

                -- Optional: Add custom effects, sounds, or enhanced jump mechanics here
                -- Example: Double jump, air dash, particle effects, etc.

                print("Custom jump performed!") -- Debug
	end
end

-- Function to disable default Roblox jump
local function disableDefaultJump()
        if customJumpEnabled then
                return
        end

        customJumpEnabled = true

        if isMobile() or forceActionsVisible then
                setJumpButtonEnabled(false)
        end

        bindJumpOverride()

        print("Default jump disabled - using custom jump system")
end

-- Function to restore default jump
local function enableDefaultJump()
        if not customJumpEnabled then
                return
        end

        unbindJumpOverride()

        if isMobile() or forceActionsVisible then
                setJumpButtonEnabled(true)
        end

        customJumpEnabled = false
        print("Default jump restored")
end

local function ensureActions()
        local player = Players.LocalPlayer
        local gui = player.PlayerGui

        local screenGui = gui:FindFirstChild("ScreenGui")

        if not shouldDisplayActions() then
                disconnectConnections(buttonConnections)
                if screenGui then
                        local existingActions = screenGui:FindFirstChild("Actions")
                        if existingActions then
                                existingActions:Destroy()
                        end
                end

                if speedBoostApplied and defaultWalkSpeed then
                        local humanoid = getHumanoid()
                        if humanoid then
                                humanoid.WalkSpeed = defaultWalkSpeed
                        end
                end
                speedBoostApplied = false
                defaultWalkSpeed = nil
                currentActionsFrame = nil
                jumpButtonRef = nil
                toggleButtonRef = nil
                table.clear(fanButtons)

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

        local actions = Instance.new("Frame")
        actions.Name = "Actions"
        actions.BackgroundTransparency = 1
        actions.AnchorPoint = Vector2.new(1, 1)
        actions.Position = UDim2.new(1, -20, 1, -20)
        actions.ClipsDescendants = false
        actions.Parent = screenGui

        currentActionsFrame = actions
        jumpButtonRef = nil
        toggleButtonRef = nil
        table.clear(fanButtons)

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
                local margin = FAN_CONFIG.JUMP_MARGIN
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
                registerConnection(buttonConnections, toggleButtonRef.Activated:Connect(function()
                        setFanOpen(not fanOpen)
                end))
        else
                toggleButtonRef = nil
        end

        setFanOpen(fanOpen, false)

        return actions
end

function ActionUI.init()
        ensureCharacterTracking()

        local actions = ensureActions()

        if not actions then
                enableDefaultJump()
                disconnectConnections(inputConnections)
                return
        end

        disableDefaultJump()

        -- Combat action connections
        local actionMap = {
                PunchButton = "Punch",
                KickButton = "Kick",
                RollButton = "Roll",
                CrouchButton = "Crouch",
                SlideButton = "Slide",
        }

        for buttonName, action in pairs(actionMap) do
                local btn = actions:FindFirstChild(buttonName)
                if btn then
                        registerConnection(buttonConnections, btn.Activated:Connect(function()
                                CombatController.perform(action)
                        end))
                end
        end

        -- Jump button connection
        local jumpBtn = actions:FindFirstChild("JumpButton")
        if jumpBtn then
                registerConnection(buttonConnections, jumpBtn.Activated:Connect(function()
                        performCustomJump()
                end))
        end

        -- Ability connections
        local abilityMap = {
                TossButton = Abilities.Toss,
                StarButton = Abilities.Star,
                RainButton = Abilities.Rain,
                BeastButton = Abilities.Beast,
                DragonButton = Abilities.Dragon,
        }

        for buttonName, abilityFunc in pairs(abilityMap) do
                local btn = actions:FindFirstChild(buttonName)
                if btn then
                        registerConnection(buttonConnections, btn.Activated:Connect(abilityFunc))
                end
        end

        -- Enhanced keybind setup with custom jump
        local abilityKeybinds = {
                [Enum.KeyCode.F] = Abilities.Toss,
                [Enum.KeyCode.G] = Abilities.Star,
                [Enum.KeyCode.Z] = Abilities.Rain,
		[Enum.KeyCode.B] = Abilities.Beast,
		[Enum.KeyCode.X] = Abilities.Dragon,
	}

	local combatKeybinds = {
		[Enum.KeyCode.E] = "Punch",
		[Enum.KeyCode.T] = "Punch",
		[Enum.KeyCode.Q] = "Kick",
		[Enum.KeyCode.R] = "Roll",
		[Enum.KeyCode.C] = "Crouch",
		[Enum.KeyCode.LeftControl] = "Slide",
		[Enum.KeyCode.Space] = "Jump", -- Custom jump override
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

		if abilityKeybinds[input.KeyCode] then
			abilityKeybinds[input.KeyCode]()
			return
		end

                if combatKeybinds[input.KeyCode] then
                        local action = combatKeybinds[input.KeyCode]
                        if action == "Jump" then
                                if customJumpEnabled then
                                        performCustomJump()
                                end
                        else
                                CombatController.perform(action)
                        end
                        return
                end

                if debugInputLogging and not ignoredInputKeys[input.KeyCode] then
                        print("Unmapped key pressed:", input.KeyCode.Name)
                end
        end))

        -- Auto-resize on screen size changes
        local camera = workspace.CurrentCamera
        if camera and (not viewportConnection or not viewportConnection.Connected) then
                viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
                        task.delay(0.1, ActionUI.init)
                end)
        end

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

-- Utility function to toggle jump mode
function ActionUI.toggleJumpMode()
        if customJumpEnabled then
                enableDefaultJump()
        else
                disableDefaultJump()
        end
        return customJumpEnabled
end

-- Utility function to add new buttons dynamically
function ActionUI.addButton(name, text, category, callback, keybind, priority)
        table.insert(BUTTON_DEFINITIONS, {
                name = name,
                text = text,
                action = text:lower(),
                category = category,
                keybind = keybind,
                priority = priority or 999
        })

        -- Reinitialize to show new button
        ActionUI.init()

        -- Connect the callback
        local player = Players.LocalPlayer
        local gui = player.PlayerGui
        local screenGui = gui:FindFirstChild("ScreenGui")
        local actions = screenGui and screenGui:FindFirstChild("Actions")
        if actions then
                local button = actions:FindFirstChild(name)
                if button and callback then
                        registerConnection(buttonConnections, button.Activated:Connect(callback))
                end
        end
end

-- Enhanced jump function that you can customize further
function ActionUI.setCustomJumpLogic(jumpFunction)
        if typeof(jumpFunction) == "function" then
                performCustomJump = function(...)
                        lastJumpTime = os.clock()
                        jumpFunction(...)
                end
        end
end

-- Developer helper to force the mobile actions UI even on desktop for testing
function ActionUI.setForceActionsVisible(enabled)
        forceActionsVisible = not not enabled
        ActionUI.init()
        return forceActionsVisible
end

function ActionUI.isForceActionsVisible()
        return forceActionsVisible
end

return ActionUI
