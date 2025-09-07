local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local updateEvent = ReplicatedStorage:FindFirstChild("CurrencyUpdated")
if not updateEvent then
    updateEvent = Instance.new("RemoteEvent")
    updateEvent.Name = "CurrencyUpdated"
    updateEvent.Parent = ReplicatedStorage
end

local balances = {}

local function sendBalance(player)
    local data = balances[player.UserId]
    if data then
        updateEvent:FireClient(player, data)
    end
end

Players.PlayerAdded:Connect(function(player)
    balances[player.UserId] = {coins = 0, orbs = 0}
end)

Players.PlayerRemoving:Connect(function(player)
    balances[player.UserId] = nil
end)

updateEvent.OnServerEvent:Connect(function(player, data)
    local balance = balances[player.UserId]
    if not balance then
        balance = {coins = 0, orbs = 0}
        balances[player.UserId] = balance
    end
    if typeof(data) == "table" then
        if data.coins then balance.coins = data.coins end
        if data.orbs then balance.orbs = data.orbs end
    end
    sendBalance(player)
end)

