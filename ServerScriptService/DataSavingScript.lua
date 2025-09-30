local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameSettings = require(ReplicatedStorage.GameSettings)

-- single datastore for all player data
local DataStore = DataStoreService:GetDataStore("PlayerData")
local PersonaStore = DataStoreService:GetDataStore("NW_Personas_v1")

-- default schema for player saves
local REALM_LIST = {
    "StarterDojo","SecretVillage","Water","Fire","Wind","Growth",
    "Ice","Light","Metal","Strength","Atoms"
}

local DEFAULT_DATA = {
    level = 1,
    experience = 0,
    kills = 0,
    rebirths = 0,
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
    slots = {},
}

local sessionData = {}
shared.sessionData = sessionData

local rebirthFunction = Instance.new("BindableFunction")
rebirthFunction.Name = "RebirthFunction"
rebirthFunction.Parent = script

local movementModeEvent = ReplicatedStorage:FindFirstChild("MovementModeEvent")
if movementModeEvent and not movementModeEvent:IsA("RemoteEvent") then
    movementModeEvent:Destroy()
    movementModeEvent = nil
end
if not movementModeEvent then
    movementModeEvent = Instance.new("RemoteEvent")
    movementModeEvent.Name = "MovementModeEvent"
    movementModeEvent.Parent = ReplicatedStorage
end

local MOVEMENT_MODES = GameSettings.movementModes or {RunDance = "RunDance", Battle = "Battle"}
local RUN_MODE = MOVEMENT_MODES.RunDance or "RunDance"
local BATTLE_MODE = MOVEMENT_MODES.Battle or "Battle"

local function computeModeSpeed(level, mode)
    if GameSettings.movementSpeedForMode then
        return GameSettings.movementSpeedForMode(level, mode)
    end

    local baseSpeed = GameSettings.movementSpeed(level)
    local runSpeed = baseSpeed + (GameSettings.runSpeedBonus or 0)

    if mode == RUN_MODE then
        return runSpeed
    elseif mode == BATTLE_MODE then
        return math.max(0, runSpeed - (GameSettings.battleSpeedPenalty or 0))
    end

    return runSpeed
end

local function applyMovementSpeed(player, stats, humanoid)
    stats = stats or (player and player:FindFirstChild("Stats"))
    if not stats then
        return
    end

    local levelValue = stats:FindFirstChild("Level")
    local walkSpeedValue = stats:FindFirstChild("WalkSpeed")
    local modeValue = stats:FindFirstChild("MovementMode")

    if not (levelValue and walkSpeedValue and modeValue) then
        return
    end

    local speed = computeModeSpeed(levelValue.Value, modeValue.Value)
    walkSpeedValue.Value = speed

    if humanoid then
        humanoid.WalkSpeed = speed
    end
end

movementModeEvent.OnServerEvent:Connect(function(player, requestedMode)
    if typeof(requestedMode) ~= "string" then
        return
    end

    if requestedMode ~= RUN_MODE and requestedMode ~= BATTLE_MODE then
        return
    end

    local stats = player:FindFirstChild("Stats")
    if not stats then
        return
    end

    local movementModeValue = stats:FindFirstChild("MovementMode")
    if not movementModeValue then
        return
    end

    movementModeValue.Value = requestedMode
    local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    applyMovementSpeed(player, stats, humanoid)
end)

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

-- Ensure orbs table is a dictionary; limit total to 10 to match inventory size
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

-- Ensure elements table only contains numbers for known elements
local function sanitizeElements(elements)
    elements = typeof(elements) == "table" and elements or {}
    local cleaned = {}
    for element, _ in pairs(DEFAULT_DATA.elements) do
        cleaned[element] = tonumber(elements[element]) or 0
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
        if data ~= nil and typeof(data) ~= "table" then
            warn(string.format(
                "Invalid data for %s from datastore (type %s): %s",
                player.Name,
                typeof(data),
                tostring(data)
            ))
            data = deepCopy(DEFAULT_DATA)
        else
            data = typeof(data) == "table" and data or deepCopy(DEFAULT_DATA)
        end

        fillMissing(data, DEFAULT_DATA)
        data.elements = sanitizeElements(data.elements)
        data.slots = typeof(data.slots) == "table" and data.slots or {}
        local slotData = data.slots["1"]
        if not slotData then
            slotData = {
                inventory = deepCopy(data.inventory),
                unlockedRealms = deepCopy(data.unlockedRealms),
                rebirths = data.rebirths or 0,
            }
            data.slots["1"] = slotData
        end
        data.inventory = slotData.inventory or data.inventory
        data.unlockedRealms = slotData.unlockedRealms or data.unlockedRealms
        data.rebirths = slotData.rebirths or data.rebirths or 0
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
    local slot = tonumber(player:GetAttribute("PersonaSlot")) or 1
    data.slots[tostring(slot)] = data.slots[tostring(slot)] or {}
    data.slots[tostring(slot)].inventory = data.inventory
    data.slots[tostring(slot)].unlockedRealms = data.unlockedRealms
    data.slots[tostring(slot)].rebirths = data.rebirths

    data.elements = sanitizeElements(data.elements)
    local success, err = pcall(function()
        DataStore:SetAsync(key, data)
    end)
    if not success then
        warn("Failed to save data for " .. player.Name .. ": " .. err)
    end

    local personaKey = "u_" .. tostring(player.UserId)
    local ok, raw = pcall(function() return PersonaStore:GetAsync(personaKey) end)
    raw = ok and raw or {}
    local pSlot = raw[tostring(slot)] or {}
    pSlot.inventory = data.inventory
    pSlot.unlockedRealms = data.unlockedRealms
    pSlot.rebirths = data.rebirths
    raw[tostring(slot)] = pSlot
    local ok2, err2 = pcall(function() PersonaStore:SetAsync(personaKey, raw) end)
    if not ok2 then
        warn("Failed to save persona data for " .. player.Name .. ": " .. err2)
    end
end

local function addExperience(player, amount)
    local exp = player:FindFirstChild("Stats") and player.Stats:FindFirstChild("Experience")
    if not exp then
        return
    end
    exp.Value += amount
end

local function performRebirth(player)
    local data = sessionData[player.UserId]
    if not data then
        return false
    end

    data.rebirths = (data.rebirths or 0) + 1

    for element in pairs(data.elements) do
        data.elements[element] = 0
    end

    data.unlockedAbilities = {}
    local abilitiesFolder = player:FindFirstChild("Abilities")
    if abilitiesFolder then
        abilitiesFolder:ClearAllChildren()
    end

    local inv = data.inventory
    inv.orbs = {}
    inv.weapons = {}
    inv.food = {}
    inv.special = {}
    player:SetAttribute("Inventory", HttpService:JSONEncode(inv))

    local stats = player:FindFirstChild("Stats")
    if stats then
        local rebirthsValue = stats:FindFirstChild("Rebirths")
        if rebirthsValue then
            rebirthsValue.Value = data.rebirths
        end
    end

    return true
end

rebirthFunction.OnInvoke = performRebirth

local function playerAdded(player)
    local data = loadPlayerData(player)
    if not data then
        player:Kick("Couldn't load your data, rejoin")
        return
    end

    sessionData[player.UserId].slot = 1
    player:SetAttribute("PersonaSlot", 1)
    player:GetAttributeChangedSignal("PersonaSlot"):Connect(function()
        local sd = sessionData[player.UserId]
        local old = sd.slot or 1
        sd.slots[tostring(old)] = sd.slots[tostring(old)] or {}
        sd.slots[tostring(old)].inventory = sd.inventory
        sd.slots[tostring(old)].unlockedRealms = sd.unlockedRealms
        sd.slots[tostring(old)].rebirths = sd.rebirths
        sd.slot = tonumber(player:GetAttribute("PersonaSlot")) or 1
        local new = sd.slots[tostring(sd.slot)] or {}
        sd.inventory = new.inventory or sd.inventory
        sd.unlockedRealms = new.unlockedRealms or sd.unlockedRealms
        sd.rebirths = new.rebirths or sd.rebirths or 0
    end)

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

    local rebirthsValue = Instance.new("IntValue")
    rebirthsValue.Name = "Rebirths"
    rebirthsValue.Value = data.rebirths or 0
    rebirthsValue.Parent = statsFolder
    rebirthsValue:GetPropertyChangedSignal("Value"):Connect(function()
        sessionData[player.UserId].rebirths = rebirthsValue.Value
    end)

    local movementModeValue = Instance.new("StringValue")
    movementModeValue.Name = "MovementMode"
    movementModeValue.Value = BATTLE_MODE
    movementModeValue.Parent = statsFolder

    movementModeValue:GetPropertyChangedSignal("Value"):Connect(function()
        local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
        applyMovementSpeed(player, statsFolder, humanoid)
    end)

    local walkSpeedValue = Instance.new("NumberValue")
    walkSpeedValue.Name = "WalkSpeed"
    walkSpeedValue.Parent = statsFolder

    local jumpPowerValue = Instance.new("NumberValue")
    jumpPowerValue.Name = "JumpPower"
    jumpPowerValue.Value = GameSettings.jumpPower(levelValue.Value)
    jumpPowerValue.Parent = statsFolder

    applyMovementSpeed(player, statsFolder, player.Character and player.Character:FindFirstChild("Humanoid"))

    local leaderSpeed = Instance.new("IntValue")
    leaderSpeed.Name = "WalkSpeed"
    leaderSpeed.Value = walkSpeedValue.Value
    leaderSpeed.Parent = leaderstats

    local leaderJump = Instance.new("IntValue")
    leaderJump.Name = "JumpPower"
    leaderJump.Value = jumpPowerValue.Value
    leaderJump.Parent = leaderstats

    walkSpeedValue:GetPropertyChangedSignal("Value"):Connect(function()
        leaderSpeed.Value = walkSpeedValue.Value
    end)

    jumpPowerValue:GetPropertyChangedSignal("Value"):Connect(function()
        leaderJump.Value = jumpPowerValue.Value
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

        local jump = GameSettings.jumpPower(levelValue.Value)
        jumpPowerValue.Value = jump
        local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.JumpPower = jump
        end
        applyMovementSpeed(player, statsFolder, humanoid)
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
        local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
        local requiredExperience = math.floor(levelValue.Value ^ 1.5 + 0.5) * 500
        if experienceValue.Value >= requiredExperience then
            levelValue.Value += 1
            if humanoid then
                local maxHealth = math.floor(humanoid.MaxHealth ^ 0 + 1) * 1
                humanoid.MaxHealth += maxHealth
            end
        end

        local jump = GameSettings.jumpPower(levelValue.Value)
        jumpPowerValue.Value = jump
        if humanoid then
            humanoid.JumpPower = jump
        end
        applyMovementSpeed(player, statsFolder, humanoid)
    end)

    player.CharacterAdded:Connect(function(character)
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then
            return
        end

        humanoid.JumpPower = jumpPowerValue.Value
        applyMovementSpeed(player, statsFolder, humanoid)

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

    if player.Character then
        local humanoid = player.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.JumpPower = jumpPowerValue.Value
            applyMovementSpeed(player, statsFolder, humanoid)
        end
    end
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

