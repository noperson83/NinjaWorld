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

        local elements = ReplicatedStorage:FindFirstChild("Elements")
        local waterElem = elements and elements:FindFirstChild("WaterElem")
        CharacterManager.starModel = waterElem and waterElem:FindFirstChild("WaterStar") or nil

        if not CharacterManager.starModel then
            if not elements then
                warn("?? Elements folder missing: cannot locate WaterStar")
            elseif not waterElem then
                warn("?? WaterElem folder missing: cannot locate WaterStar")
            else
                warn("?? WaterStar not found in WaterElem")
            end
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

