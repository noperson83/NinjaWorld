local ActionUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

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
local originalJumpConnection = nil
local forceActionsVisible = false

local function isMobile()
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Determines whether the touch actions UI should be visible/active
local function shouldDisplayActions()
        return forceActionsVisible or isMobile()
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

local function createStylizedButton(buttonDef)
	local button = Instance.new("TextButton")
	button.Name = buttonDef.name
	button.Text = ""
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.ZIndex = 2

	-- Special sizing for jump button
        if buttonDef.category == "jump" then
                button.Size = shouldDisplayActions() and UI_CONFIG.MOBILE_JUMP_SIZE or UI_CONFIG.JUMP_BUTTON_SIZE
        else
                button.Size = shouldDisplayActions() and UI_CONFIG.MOBILE_BUTTON_SIZE or UI_CONFIG.BUTTON_SIZE
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

	return button, buttonDef
end

local function animateButton(button, scale, duration)
	local tween = TweenService:Create(
		button,
		TweenInfo.new(duration or UI_CONFIG.TWEEN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = button.Size * scale}
	)
	tween:Play()
end

local function setupButtonAnimations(button)
	local originalSize = button.Size

        button.MouseEnter:Connect(function()
                if not shouldDisplayActions() then
                        animateButton(button, UI_CONFIG.HOVER_SCALE)
                end
        end)

        button.MouseLeave:Connect(function()
                if not shouldDisplayActions() then
                        button.Size = originalSize
                end
        end)

	button.MouseButton1Down:Connect(function()
		animateButton(button, UI_CONFIG.PRESS_SCALE, 0.08)
	end)

	button.MouseButton1Up:Connect(function()
		button.Size = originalSize
	end)
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

		-- Optional: Add custom effects, sounds, or enhanced jump mechanics here
		-- Example: Double jump, air dash, particle effects, etc.

		print("Custom jump performed!") -- Debug
	end
end

-- Function to disable default Roblox jump
local function disableDefaultJump()
	local player = Players.LocalPlayer

	-- Method 1: Hide the default jump button on mobile
	if isMobile() then
		pcall(function()
			GuiService:SetTouchGuiEnabled(Enum.TouchGuiType.Jump, false)
		end)
	end

	-- Method 2: Override space key for PC
	UserInputService.JumpRequest:Connect(function()
		-- Prevent default jump by not calling Jump
		-- The custom jump will be handled by our keybind system
	end)

	customJumpEnabled = true
	print("Default jump disabled - using custom jump system")
end

-- Function to restore default jump
local function enableDefaultJump()
	local player = Players.LocalPlayer

	if isMobile() then
		pcall(function()
			GuiService:SetTouchGuiEnabled(Enum.TouchGuiType.Jump, true)
		end)
	end

	customJumpEnabled = false
	print("Default jump restored")
end

local function ensureActions()
        local player = Players.LocalPlayer
        local gui = player.PlayerGui

        local screenGui = gui:FindFirstChild("ScreenGui")

        if not shouldDisplayActions() then
                if screenGui then
                        local existingActions = screenGui:FindFirstChild("Actions")
                        if existingActions then
                                existingActions:Destroy()
                        end
                end
                return nil
        end

        if not screenGui then
                screenGui = Instance.new("ScreenGui")
                screenGui.Name = "ScreenGui"
                screenGui.ResetOnSpawn = false
                screenGui.IgnoreGuiInset = true
                screenGui.Parent = gui
        end

        local actions = screenGui:FindFirstChild("Actions")
        if not actions then
                actions = Instance.new("Frame")
                actions.Name = "Actions"
                actions.BackgroundTransparency = 1
                actions.Parent = screenGui

                -- Responsive positioning
                -- Mobile/forced: Bottom right corner
                actions.Size = UDim2.new(0, 220, 0, 350)
                actions.Position = UDim2.new(1, -230, 1, -360)

                -- Grid layout with flexible sizing
                local gridLayout = Instance.new("UIGridLayout")
                gridLayout.Parent = actions
                gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
                gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
                gridLayout.FillDirection = Enum.FillDirection.Vertical
                gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
                gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top

                -- Padding
                local padding = Instance.new("UIPadding")
                padding.Parent = actions
                padding.PaddingTop = UI_CONFIG.PADDING
                padding.PaddingBottom = UI_CONFIG.PADDING
                padding.PaddingLeft = UI_CONFIG.PADDING
                padding.PaddingRight = UI_CONFIG.PADDING
        end

        -- Clear existing buttons and recreate with new styling
        for _, child in pairs(actions:GetChildren()) do
                if child:IsA("TextButton") then
                        child:Destroy()
                end
        end

        -- Sort buttons by priority
        local sortedButtons = {}
        for _, buttonDef in ipairs(BUTTON_DEFINITIONS) do
                table.insert(sortedButtons, buttonDef)
        end
        table.sort(sortedButtons, function(a, b)
                return (a.priority or 999) < (b.priority or 999)
        end)

        -- Create buttons with absolute positioning - properly spaced
        local yOffset = 10
        local buttonSpacing = 15

        for _, buttonDef in ipairs(sortedButtons) do
                local button = createStylizedButton(buttonDef)

                -- Absolute positioning
                button.Position = UDim2.new(0, 10, 0, yOffset)
                button.Parent = actions
                setupButtonAnimations(button)

                -- Calculate next Y position based on actual button size plus spacing
                if buttonDef.category == "jump" then
                        yOffset = yOffset + (shouldDisplayActions() and 70 or 90) + buttonSpacing
                else
                        yOffset = yOffset + (shouldDisplayActions() and 60 or 80) + buttonSpacing
                end
        end

        return actions
end

function ActionUI.init()
        local actions = ensureActions()

        if not actions then
                enableDefaultJump()
        else
                -- Disable default jump when initializing
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
                                btn.Activated:Connect(function()
                                        CombatController.perform(action)
                                end)
                        end
                end

                -- Jump button connection
                local jumpBtn = actions:FindFirstChild("JumpButton")
                if jumpBtn then
                        jumpBtn.Activated:Connect(function()
                                performCustomJump()
                        end)
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
                                btn.Activated:Connect(abilityFunc)
                        end
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

	UserInputService.InputBegan:Connect(function(input, processed)
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
				performCustomJump()
			else
				CombatController.perform(action)
			end
			return
		end

		if debugInputLogging and not ignoredInputKeys[input.KeyCode] then
			print("Unmapped key pressed:", input.KeyCode.Name)
		end
	end)

	-- Auto-resize on screen size changes
	local camera = workspace.CurrentCamera
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		wait(0.1) -- Small delay to ensure proper sizing
		ActionUI.init() -- Reinitialize with new sizing
	end)
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
                        button.Activated:Connect(callback)
                end
        end
end

-- Enhanced jump function that you can customize further
function ActionUI.setCustomJumpLogic(jumpFunction)
        if typeof(jumpFunction) == "function" then
                performCustomJump = jumpFunction
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
