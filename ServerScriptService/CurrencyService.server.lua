local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local updateEvent = ReplicatedStorage:FindFirstChild("CurrencyUpdated")
if not updateEvent then
    updateEvent = Instance.new("RemoteEvent")
    updateEvent.Name = "CurrencyUpdated"
    updateEvent.Parent = ReplicatedStorage
end

local MAX_ORBS = 10
local balances = {}

local CurrencyService = {balances = balances}
shared.CurrencyService = CurrencyService

local function getOrbCount(orbs)
    local total = 0
    for _, v in pairs(orbs) do
        total += v
    end
    return total
end

local function sendBalance(player)
    local data = balances[player.UserId]
    if data then
        updateEvent:FireClient(player, data)
    end
end

function CurrencyService.GetBalance(player)
    return balances[player.UserId]
end

function CurrencyService.AdjustCoins(player, amount)
    local balance = balances[player.UserId]
    if not balance or balance.coins + amount < 0 then
        return false
    end
    balance.coins += amount
    sendBalance(player)
    return true
end

local function addOrb(player, element)
    local balance = balances[player.UserId]
    if not balance or typeof(element) ~= "string" then return end
    balance.orbs = balance.orbs or {}
    if balance.orbs[element] then return end
    if getOrbCount(balance.orbs) >= MAX_ORBS then return end
    balance.orbs[element] = 1

    local invStr = player:GetAttribute("Inventory")
    local inv = {}
    if typeof(invStr) == "string" then
        local ok, data = pcall(HttpService.JSONDecode, HttpService, invStr)
        if ok then inv = data end
    end
    inv.orbs = inv.orbs or {}
    inv.orbs[element] = 1
    player:SetAttribute("Inventory", HttpService:JSONEncode(inv))

    sendBalance(player)
end

Players.PlayerAdded:Connect(function(player)
    balances[player.UserId] = {coins = 0, orbs = {}}
    sendBalance(player)
    player:GetAttributeChangedSignal("Inventory"):Connect(function()
        local invStr = player:GetAttribute("Inventory")
        if typeof(invStr) == "string" then
            local ok, inv = pcall(HttpService.JSONDecode, HttpService, invStr)
            if ok and type(inv.orbs) == "table" then
                balances[player.UserId].orbs = inv.orbs
                sendBalance(player)
            end
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    balances[player.UserId] = nil
end)

updateEvent.OnServerEvent:Connect(function(player, data)
    local balance = balances[player.UserId]
    if not balance then
        balance = {coins = 0, orbs = {}}
        balances[player.UserId] = balance
    end
    if typeof(data) == "table" then
        if data.addOrb then addOrb(player, data.addOrb) return end
        if data.addCoins then CurrencyService.AdjustCoins(player, data.addCoins) return end
        if data.spendCoins then CurrencyService.AdjustCoins(player, -data.spendCoins) return end
        if data.request then sendBalance(player) return end
    end
    sendBalance(player)
end)

