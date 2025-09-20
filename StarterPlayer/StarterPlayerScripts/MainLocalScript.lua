local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionUI = require(ReplicatedStorage.ClientModules.UI.ActionUI)

local player = Players.LocalPlayer

local function initializeActionUI()
    task.defer(function()
        local success, err = pcall(ActionUI.init)
        if not success then
            warn("ActionUI.init failed:", err)
        end
    end)
end

local function onCharacterAdded(character)
    if not character then
        return
    end

    local ok = pcall(function()
        character:WaitForChild("HumanoidRootPart", 10)
    end)
    if not ok then
        -- Even if the humanoid root part never appears, refresh so the UI can
        -- clean up any existing state.
        initializeActionUI()
        return
    end

    initializeActionUI()
end

local function onCharacterRemoving()
    initializeActionUI()
end

if player then
    player.CharacterAdded:Connect(onCharacterAdded)
    player.CharacterRemoving:Connect(onCharacterRemoving)

    if player.Character then
        onCharacterAdded(player.Character)
    else
        initializeActionUI()
    end
else
    initializeActionUI()
end
