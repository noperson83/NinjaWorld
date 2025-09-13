local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AbilityMetadata = require(ReplicatedStorage.ClientModules.AbilityMetadata)
local CurrencyService = shared.CurrencyService

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
    local cs = CurrencyService
    if not cs then
        return false, "Currency service unavailable"
    end
    local balance = cs.GetBalance(player)
    if not balance or balance.coins < info.cost then
        return false, "Not enough currency"
    end
    if not cs.AdjustCoins(player, -info.cost) then
        return false, "Not enough currency"
    end
    abilitiesFolder = abilitiesFolder or Instance.new("Folder")
    abilitiesFolder.Name = "Abilities"
    abilitiesFolder.Parent = player
    local owned = Instance.new("BoolValue")
    owned.Name = abilityName
    owned.Value = true
    owned.Parent = abilitiesFolder
    return true
end
