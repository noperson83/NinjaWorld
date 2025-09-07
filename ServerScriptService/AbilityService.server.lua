local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AbilityMetadata = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("AbilityMetadata"))

local learnRF = Instance.new("RemoteFunction")
learnRF.Name = "LearnAbility"
learnRF.Parent = ReplicatedStorage

local function prerequisitesMet(player, abilityName)
    local info = AbilityMetadata[abilityName]
    if not info then return false end
    local abilitiesFolder = player:FindFirstChild("Abilities")
    for _, prereq in ipairs(info.prerequisites or {}) do
        if not (abilitiesFolder and abilitiesFolder:FindFirstChild(prereq)) then
            return false
        end
    end
    return true
end

learnRF.OnServerInvoke = function(player, abilityName)
    local info = AbilityMetadata[abilityName]
    if not info then
        return false, "Unknown ability"
    end
    local abilitiesFolder = player:FindFirstChild("Abilities")
    if abilitiesFolder and abilitiesFolder:FindFirstChild(abilityName) then
        return true
    end
    if not prerequisitesMet(player, abilityName) then
        return false, "Missing prerequisites"
    end
    local coins = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Coins")
    if not coins or coins.Value < info.cost then
        return false, "Not enough currency"
    end
    coins.Value -= info.cost
    abilitiesFolder = abilitiesFolder or Instance.new("Folder")
    abilitiesFolder.Name = "Abilities"
    abilitiesFolder.Parent = player
    local owned = Instance.new("BoolValue")
    owned.Name = abilityName
    owned.Value = true
    owned.Parent = abilitiesFolder
    return true
end
