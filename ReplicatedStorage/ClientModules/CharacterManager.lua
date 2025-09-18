-- CharacterManager Module
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CharacterManager = {}

CharacterManager.character = nil
CharacterManager.humanoid = nil
CharacterManager.humanoidRoot = nil
CharacterManager.animator = nil
CharacterManager.rightArm = nil
CharacterManager.starModel = nil
CharacterManager.isCrouching = false

CharacterManager._player = nil
CharacterManager._characterAddedConnection = nil

local function safeWaitForChild(parent, childName, timeout)
        if not parent then
                return nil
        end

        local child = parent:FindFirstChild(childName)
        if child then
                return child
        end

        local ok, result = pcall(function()
                return parent:WaitForChild(childName, timeout or 5)
        end)

        if ok then
                return result
        end

        return nil
end

local function updateStarModel()
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
end

function CharacterManager.setup(player)
        if not player then
                warn("?? CharacterManager.setup called without player")
                return
        end

        if CharacterManager._player == player and CharacterManager._characterAddedConnection then
                return
        end

        CharacterManager._player = player

        if CharacterManager._characterAddedConnection then
                CharacterManager._characterAddedConnection:Disconnect()
                CharacterManager._characterAddedConnection = nil
        end

        local function updateCharacterReferences(character)
                if character then
                        CharacterManager.character = character
                else
                        local resolved = player.Character
                        if not resolved then
                                local ok, newCharacter = pcall(function()
                                        return player.CharacterAdded:Wait()
                                end)
                                if ok then
                                        resolved = newCharacter
                                end
                        end

                        if not resolved then
                                warn("?? CharacterManager failed to resolve character for player " .. player.Name)
                                return
                        end

                        CharacterManager.character = resolved
                        character = resolved
                end

                CharacterManager.humanoidRoot = safeWaitForChild(character, "HumanoidRootPart")

                CharacterManager.humanoid = safeWaitForChild(character, "Humanoid")
                if not CharacterManager.humanoid then
                        warn("?? CharacterManager could not locate Humanoid for player " .. player.Name)
                        CharacterManager.animator = nil
                else
                        CharacterManager.animator = safeWaitForChild(CharacterManager.humanoid, "Animator")
                        if not CharacterManager.animator then
                                warn("?? CharacterManager could not locate Animator on humanoid for player " .. player.Name)
                        end
                end

                CharacterManager.rightArm = safeWaitForChild(character, "RightUpperArm")
                        or safeWaitForChild(character, "Right Arm")
                        or safeWaitForChild(character, "RightHand")
                if not CharacterManager.rightArm then
                        warn("?? CharacterManager could not locate a right arm reference for player " .. player.Name)
                end

                CharacterManager.isCrouching = false

                updateStarModel()

                local success, CombatController = pcall(function()
                        return require(ReplicatedStorage.ClientModules.CombatController)
                end)
                if success and CombatController then
                        CombatController.initAnimations()
                else
                        warn("?? Could not require CombatController for animation init")
                end
        end

        CharacterManager._characterAddedConnection = player.CharacterAdded:Connect(updateCharacterReferences)

        local currentCharacter = player.Character
        if currentCharacter then
                updateCharacterReferences(currentCharacter)
        else
                task.spawn(updateCharacterReferences)
        end
end

if RunService:IsClient() then
        task.defer(function()
                local player = Players.LocalPlayer
                while not player do
                        task.wait()
                        player = Players.LocalPlayer
                end
                CharacterManager.setup(player)
        end)
end

return CharacterManager
