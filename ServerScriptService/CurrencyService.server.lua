local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local updateEvent = ReplicatedStorage:FindFirstChild("CurrencyUpdated")
if not updateEvent then
    updateEvent = Instance.new("RemoteEvent")
    updateEvent.Name = "CurrencyUpdated"
    updateEvent.Parent = ReplicatedStorage
end

local ORB_THRESHOLD = 10
local balances = {}

local sessionData = shared.sessionData or {}

local CurrencyService = {balances = balances}
shared.CurrencyService = CurrencyService

local function sendBalance(player, leveled)
    local data = balances[player.UserId]
    if data then
        local payload = {coins = data.coins, orbs = data.orbs, elements = data.elements}
        if leveled then payload.elementLeveled = leveled end
        updateEvent:FireClient(player, payload)
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
    balance.elements = balance.elements or {}
    local count = (balance.orbs[element] or 0) + 1
    balance.orbs[element] = count

    local invStr = player:GetAttribute("Inventory")
    local inv = {}
    if typeof(invStr) == "string" then
        local ok, data = pcall(HttpService.JSONDecode, HttpService, invStr)
        if ok then inv = data end
    end
    inv.orbs = inv.orbs or {}
    inv.orbs[element] = count

    local leveled
    local sd = sessionData[player.UserId]
    if sd then
        sd.elements = sd.elements or {}
        local levels = math.floor(count / ORB_THRESHOLD)
        if levels > 0 then
            sd.elements[element] = (sd.elements[element] or 0) + levels
            balance.elements[element] = sd.elements[element]
            count = count % ORB_THRESHOLD
            balance.orbs[element] = count
            inv.orbs[element] = count
            leveled = element
        else
            balance.elements[element] = sd.elements[element] or 0
        end
    end

    player:SetAttribute("Inventory", HttpService:JSONEncode(inv))

    sendBalance(player, leveled)
end

Players.PlayerAdded:Connect(function(player)
    local sd = sessionData[player.UserId]
    if not sd then
        repeat task.wait() sd = sessionData[player.UserId] until sd
    end
    balances[player.UserId] = {coins = 0, orbs = {}, elements = sd and sd.elements or {}}
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
        balance = {coins = 0, orbs = {}, elements = {}}
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

