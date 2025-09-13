local ActionUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Abilities = require(ReplicatedStorage.ClientModules.Abilities)
local CombatController = require(ReplicatedStorage.ClientModules.CombatController)

-- UI Configuration
local UI_CONFIG = {
    -- Colors
    COMBAT_COLOR = Color3.fromRGB(220, 50, 47),     -- Red for combat actions
    ABILITY_COLOR = Color3.fromRGB(38, 139, 210),   -- Blue for abilities  
    MOVEMENT_COLOR = Color3.fromRGB(133, 153, 0),   -- Yellow-green for movement
    
    -- Gradients
    GRADIENT_OFFSET = Vector2.new(0, 0.3),
    
    -- Animation
    PRESS_SCALE = 0.9,
    HOVER_SCALE = 1.05,
    TWEEN_TIME = 0.15,
    
    -- Layout
    BUTTON_SIZE = UDim2.new(0, 80, 0, 80),
    MOBILE_BUTTON_SIZE = UDim2.new(0, 60, 0, 60),
    PADDING = UDim.new(0, 8),
    CORNER_RADIUS = UDim.new(0, 12),
}

-- Button definitions with categories and styling
local BUTTON_DEFINITIONS = {
    -- Combat Actions (Red theme)
    {name = "PunchButton", text = "PUNCH", action = "Punch", category = "combat", keybind = "E/T"},
    {name = "KickButton", text = "KICK", action = "Kick", category = "combat", keybind = "Q"},
    
    -- Movement Actions (Yellow-green theme)
    {name = "RollButton", text = "ROLL", action = "Roll", category = "movement", keybind = "R"},
    {name = "CrouchButton", text = "CROUCH", action = "Crouch", category = "movement", keybind = "C"},
    {name = "SlideButton", text = "SLIDE", action = "Slide", category = "movement", keybind = "Ctrl"},
    
    -- Abilities (Blue theme)
    {name = "TossButton", text = "TOSS", action = "Toss", category = "ability", keybind = "F"},
    {name = "StarButton", text = "STAR", action = "Star", category = "ability", keybind = "G"},
    {name = "RainButton", text = "RAIN", action = "Rain", category = "ability", keybind = "Z"},
    {name = "BeastButton", text = "BEAST", action = "Beast", category = "ability", keybind = "B"},
    {name = "DragonButton", text = "DRAGON", action = "Dragon", category = "ability", keybind = "X"},
}

local function isMobile()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
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
    button.Size = isMobile() and UI_CONFIG.MOBILE_BUTTON_SIZE or UI_CONFIG.BUTTON_SIZE
    button.ZIndex = 2
    
    -- Colors based on category
    local color = UI_CONFIG.COMBAT_COLOR
    if buttonDef.category == "ability" then
        color = UI_CONFIG.ABILITY_COLOR
    elseif buttonDef.category == "movement" then
        color = UI_CONFIG.MOVEMENT_COLOR
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
        if not isMobile() then
            animateButton(button, UI_CONFIG.HOVER_SCALE)
        end
    end)
    
    button.MouseLeave:Connect(function()
        if not isMobile() then
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

local function ensureActions()
    local player = Players.LocalPlayer
    local gui = player.PlayerGui

    local screenGui = gui:FindFirstChild("ScreenGui")
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
        if isMobile() then
            -- Mobile: Bottom right corner
            actions.Size = UDim2.new(0, 200, 0, 300)
            actions.Position = UDim2.new(1, -210, 1, -310)
        else
            -- PC: Center right
            actions.Size = UDim2.new(0, 250, 0, 400)
            actions.Position = UDim2.new(1, -260, 0.5, -200)
        end
        
        -- Grid layout
        local gridLayout = Instance.new("UIGridLayout")
        gridLayout.Parent = actions
        gridLayout.CellSize = isMobile() and UI_CONFIG.MOBILE_BUTTON_SIZE or UI_CONFIG.BUTTON_SIZE
        gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
        gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
        
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

    -- Create buttons with enhanced styling
    for i, buttonDef in ipairs(BUTTON_DEFINITIONS) do
        local button, def = createStylizedButton(buttonDef)
        button.LayoutOrder = i
        button.Parent = actions
        setupButtonAnimations(button)
    end

    return actions
end

function ActionUI.init()
    local actions = ensureActions()

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

    -- Keybind setup (unchanged from original)
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
    }

    local ignoredInputKeys = {
        [Enum.KeyCode.W] = true,
        [Enum.KeyCode.A] = true,
        [Enum.KeyCode.S] = true,
        [Enum.KeyCode.D] = true,
        [Enum.KeyCode.Space] = true,
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
            CombatController.perform(action)
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

-- Utility function to add new buttons dynamically
function ActionUI.addButton(name, text, category, callback, keybind)
    table.insert(BUTTON_DEFINITIONS, {
        name = name,
        text = text,
        action = text:lower(),
        category = category,
        keybind = keybind
    })
    
    -- Reinitialize to show new button
    ActionUI.init()
    
    -- Connect the callback
    local player = Players.LocalPlayer
    local actions = player.PlayerGui.ScreenGui.Actions
    local button = actions:FindFirstChild(name)
    if button and callback then
        button.Activated:Connect(callback)
    end
end

return ActionUI
