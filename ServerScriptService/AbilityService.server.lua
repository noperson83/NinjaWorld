local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AbilityMetadata = require(ReplicatedStorage.ClientModules.AbilityMetadata)

local function waitForCurrencyService()
    local service = shared.CurrencyService
    while not service do
        task.wait()
        service = shared.CurrencyService
    end
    return service
end

local CurrencyService = waitForCurrencyService()

local function getCurrencyService()
    local service = CurrencyService
    assert(service, "AbilityService expected CurrencyService to be initialized")
    return service
end

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
    local cs = getCurrencyService()
    local getBalance = assert(cs.GetBalance, "CurrencyService missing GetBalance")
    local adjustCoins = assert(cs.AdjustCoins, "CurrencyService missing AdjustCoins")
    local balance = getBalance(player)
    if not balance or balance.coins < info.cost then
        return false, "Not enough currency"
    end
    if not adjustCoins(player, -info.cost) then
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
