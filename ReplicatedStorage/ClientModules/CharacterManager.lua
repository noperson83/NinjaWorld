-- CharacterManager Module
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterManager = {}

CharacterManager.character = nil
CharacterManager.humanoid = nil
CharacterManager.humanoidRoot = nil
CharacterManager.animator = nil
CharacterManager.rightArm = nil
CharacterManager.starModel = nil

function CharacterManager.setup(player)
    local function updateCharacterReferences()
        CharacterManager.character = player.Character or player.CharacterAdded:Wait()
        CharacterManager.humanoidRoot = CharacterManager.character.HumanoidRootPart
        CharacterManager.humanoid = CharacterManager.character.Humanoid
        CharacterManager.animator = CharacterManager.humanoid:FindFirstChild("Animator")
        CharacterManager.rightArm = CharacterManager.character.RightUpperArm

        local elements = ReplicatedStorage.Elements
        local waterElem = elements and elements.WaterElem
        CharacterManager.starModel = waterElem:FindFirstChild("WaterStar")

        if not CharacterManager.starModel then
            warn("?? WaterStar not found in WaterElem")
        end

        -- ? Init animations only after character + animator are ready
        local success, CombatController = pcall(function()
            return require(ReplicatedStorage.ClientModules.CombatController)
        end)
        if success then
            CombatController.initAnimations()
        else
            warn("?? Could not require CombatController for animation init")
        end
    end

    updateCharacterReferences()
    player.CharacterAdded:Connect(updateCharacterReferences)
end

return CharacterManager

