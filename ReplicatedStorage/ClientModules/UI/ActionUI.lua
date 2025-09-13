local ActionUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Abilities = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("Abilities"))
local CombatController = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("CombatController"))

local function ensureActions()
    local player = Players.LocalPlayer
    local gui = player:WaitForChild("PlayerGui")

    local screenGui = gui:FindFirstChild("ScreenGui")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "ScreenGui"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = gui
    end

    local actions = screenGui:FindFirstChild("Actions")
    if not actions then
        actions = Instance.new("Frame")
        actions.Name = "Actions"
        actions.Parent = screenGui
    end

    local buttons = {
        "PunchButton", "KickButton", "RollButton", "CrouchButton", "SlideButton",
        "TossButton", "StarButton", "RainButton", "BeastButton", "DragonButton",
    }

    for _, name in ipairs(buttons) do
        if not actions:FindFirstChild(name) then
            local btn = Instance.new("TextButton")
            btn.Name = name
            btn.Text = name
            btn.Parent = actions
        end
    end

    return actions
end

function ActionUI.init()
    local actions = ensureActions()

    local actionMap = {
        PunchButton = "Punch",
        KickButton = "Kick",
        RollButton = "Roll",
        CrouchButton = "Crouch",
        SlideButton = "Slid",
    }

    for buttonName, action in pairs(actionMap) do
        local btn = actions:FindFirstChild(buttonName)
        if btn then
            btn.Activated:Connect(function()
                CombatController.perform(action)
            end)
        end
    end

    actions.TossButton.Activated:Connect(Abilities.Toss)
    actions.StarButton.Activated:Connect(Abilities.Star)
    actions.RainButton.Activated:Connect(Abilities.Rain)
    actions.BeastButton.Activated:Connect(Abilities.Beast)
    actions.DragonButton.Activated:Connect(Abilities.Dragon)

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
        [Enum.KeyCode.LeftControl] = "Slid",
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
end

return ActionUI
