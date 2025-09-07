local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

-- single datastore for all player data
local DataStore = DataStoreService:GetDataStore("PlayerData")

-- default schema for player saves
local REALM_LIST = {
    "StarterDojo","SecretVillage","Water","Fire","Wind","Growth",
    "Ice","Light","Metal","Strength","Atoms"
}

local DEFAULT_DATA = {
    level = 1,
    experience = 0,
    kills = 0,
    currency = {
        Coins = 0,
        Orbs = 0,
    },
    elements = {
        Water = 0,
        Fire = 0,
        Grow = 0,
        Ice = 0,
        Light = 0,
        Metal = 0,
        Magic = 0,
        Strength = 0,
        Wind = 0,
        Atom = 0,
    },
    unlockedAbilities = {},
    -- realms the player has unlocked; start with all locked
    unlockedRealms = {
        StarterDojo = true,
        SecretVillage = true,
        Water = false,
        Fire = false,
        Wind = false,
        Growth = false,
        Ice = false,
        Light = false,
        Metal = false,
        Strength = false,
        Atoms = true,
    },
    inventory = {
        coins = 0,
        orbs = {},
        weapons = {},
        food = {},
        special = {},
    },
}

local sessionData = {}

local function decodeInventory(value)
    if typeof(value) ~= "string" then return nil end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, value)
    return ok and data or nil
end

local function deepCopy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = type(v) == "table" and deepCopy(v) or v
    end
    return copy
end

-- Ensure orbs table is a dictionary with a total not exceeding 10
local function sanitizeOrbs(orbs)
    orbs = typeof(orbs) == "table" and orbs or {}
    local total = 0
    local cleaned = {}
    for element, count in pairs(orbs) do
        count = tonumber(count) or 0
        if count > 0 and total < 10 then
            local allowed = math.min(count, 10 - total)
            cleaned[element] = allowed
            total += allowed
        end
    end
    return cleaned
end

local function fillMissing(data, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            data[k] = type(data[k]) == "table" and data[k] or {}
            fillMissing(data[k], v)
        elseif data[k] == nil then
            data[k] = v
        end
    end
end

-- helper: load player data from datastore
local function loadPlayerData(player)
    local key = tostring(player.UserId)
    local success, data = pcall(function()
        return DataStore:GetAsync(key)
    end)
    if success then
        data = data or deepCopy(DEFAULT_DATA)
        fillMissing(data, DEFAULT_DATA)
        -- ensure all realm flags exist
        data.unlockedRealms = type(data.unlockedRealms) == "table" and data.unlockedRealms or {}
        for _, realm in ipairs(REALM_LIST) do
            if data.unlockedRealms[realm] == nil then
                data.unlockedRealms[realm] = DEFAULT_DATA.unlockedRealms[realm] or false
            end
        end
        data.inventory.orbs = sanitizeOrbs(data.inventory.orbs)
        sessionData[player.UserId] = data
        return data
    else
        warn("Couldn't load data: " .. player.Name)
    end
end

-- helper: save player data to datastore
local function savePlayerData(player)
    local key = tostring(player.UserId)
    local data = sessionData[player.UserId]
    if not data then
        return
    end
    local inv = decodeInventory(player:GetAttribute("Inventory"))
    if inv then
        inv.orbs = sanitizeOrbs(inv.orbs)
        data.inventory = inv
    else
        data.inventory.orbs = sanitizeOrbs(data.inventory.orbs)
    end
    local success, err = pcall(function()
        DataStore:SetAsync(key, data)
    end)
    if not success then
        warn("Failed to save data for " .. player.Name .. ": " .. err)
    end
end

local function addExperience(player, amount)
    local exp = player:FindFirstChild("Stats") and player.Stats:FindFirstChild("Experience")
    if not exp then
        return
    end
    exp.Value += amount
end

local function playerAdded(player)
    local data = loadPlayerData(player)
    if not data then
        player:Kick("Couldn't load your data, rejoin")
        return
    end

    data.inventory.orbs = sanitizeOrbs(data.inventory.orbs)
    player:SetAttribute("Inventory", HttpService:JSONEncode(data.inventory))
    player:GetAttributeChangedSignal("Inventory"):Connect(function()
        local inv = decodeInventory(player:GetAttribute("Inventory"))
        if inv then
            inv.orbs = sanitizeOrbs(inv.orbs)
            sessionData[player.UserId].inventory = inv
        end
    end)

    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local coinsValue = Instance.new("IntValue")
    coinsValue.Name = "Coins"
    coinsValue.Value = data.currency.Coins
    coinsValue.Parent = leaderstats
    coinsValue:GetPropertyChangedSignal("Value"):Connect(function()
        sessionData[player.UserId].currency.Coins = coinsValue.Value
    end)

    local checkpoint = Instance.new("IntValue")
    checkpoint.Name = "Checkpoint"
    checkpoint.Value = 0
    checkpoint.Parent = leaderstats

    local statsFolder = Instance.new("Folder")
    statsFolder.Name = "Stats"
    statsFolder.Parent = player

    local levelValue = Instance.new("IntValue")
    levelValue.Name = "Level"
    levelValue.Value = data.level
    levelValue.Parent = statsFolder

    local experienceValue = Instance.new("IntValue")
    experienceValue.Name = "Experience"
    experienceValue.Value = data.experience
    experienceValue.Parent = statsFolder
    experienceValue:GetPropertyChangedSignal("Value"):Connect(function()
        sessionData[player.UserId].experience = experienceValue.Value
    end)

    local kills = Instance.new("IntValue")
    kills.Name = "Kills"
    kills.Value = data.kills
    kills.Parent = statsFolder
    kills:GetPropertyChangedSignal("Value"):Connect(function()
        sessionData[player.UserId].kills = kills.Value
    end)

    local leaderLevel = Instance.new("IntValue")
    leaderLevel.Name = "Level"
    leaderLevel.Value = levelValue.Value
    leaderLevel.Parent = leaderstats

    leaderLevel:GetPropertyChangedSignal("Value"):Connect(function()
        if leaderLevel.Value ~= levelValue.Value then
            levelValue.Value = leaderLevel.Value
        end
        sessionData[player.UserId].level = leaderLevel.Value
    end)

    levelValue:GetPropertyChangedSignal("Value"):Connect(function()
        sessionData[player.UserId].level = levelValue.Value
        if leaderLevel.Value ~= levelValue.Value then
            leaderLevel.Value = levelValue.Value
        end
    end)

    local abilitiesFolder = Instance.new("Folder")
    abilitiesFolder.Name = "Abilities"
    abilitiesFolder.Parent = player
    for _, ability in ipairs(data.unlockedAbilities) do
        local owned = Instance.new("BoolValue")
        owned.Name = ability
        owned.Value = true
        owned.Parent = abilitiesFolder
    end
    abilitiesFolder.ChildAdded:Connect(function(child)
        if child:IsA("BoolValue") and child.Value then
            local abilities = sessionData[player.UserId].unlockedAbilities
            if not table.find(abilities, child.Name) then
                table.insert(abilities, child.Name)
            end
        end
    end)

    -- folder replicating which realms the player has unlocked
    local realmsFolder = Instance.new("Folder")
    realmsFolder.Name = "Realms"
    realmsFolder.Parent = player
    for _, realm in ipairs(REALM_LIST) do
        local flag = Instance.new("BoolValue")
        flag.Name = realm
        flag.Value = data.unlockedRealms[realm] or false
        flag.Parent = realmsFolder
        flag:GetPropertyChangedSignal("Value"):Connect(function()
            sessionData[player.UserId].unlockedRealms[realm] = flag.Value
        end)
    end
    realmsFolder.ChildAdded:Connect(function(child)
        if child:IsA("BoolValue") then
            sessionData[player.UserId].unlockedRealms[child.Name] = child.Value
            child:GetPropertyChangedSignal("Value"):Connect(function()
                sessionData[player.UserId].unlockedRealms[child.Name] = child.Value
            end)
        end
    end)

    experienceValue:GetPropertyChangedSignal("Value"):Connect(function()
        local requiredExperience = math.floor(levelValue.Value ^ 1.5 + 0.5) * 500
        local maxHealth = math.floor(player.Character:WaitForChild("Humanoid").MaxHealth ^ 0 + 1) * 1
        if experienceValue.Value >= requiredExperience then
            levelValue.Value += 1
            player.Character:WaitForChild("Humanoid").MaxHealth += maxHealth
        end
    end)

    player.CharacterAdded:Connect(function(character)
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then
            return
        end

        humanoid.Died:Connect(function()
            local creator = humanoid:FindFirstChild("creator")
            local killer = creator and creator.Value
            if killer then
                local killStat = killer:FindFirstChild("Stats") and killer.Stats:FindFirstChild("Kills")
                if killStat then
                    killStat.Value += 1
                    addExperience(killer, 100)
                end
            end
        end)
    end)
end

Players.PlayerAdded:Connect(playerAdded)

Players.PlayerRemoving:Connect(function(player)
    savePlayerData(player)
    sessionData[player.UserId] = nil
end)

game:BindToClose(function()
    if RunService:IsStudio() then
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        savePlayerData(player)
    end
end)

