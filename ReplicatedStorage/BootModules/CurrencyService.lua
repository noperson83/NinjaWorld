local CurrencyService = {}
CurrencyService.__index = CurrencyService

-- Simple currency tracker with client/server sync.
function CurrencyService.new(config)
    local self = setmetatable({}, CurrencyService)
    self.coins = 0
    self.orbs = {}
    self.elements = {}

    self.BalanceChanged = Instance.new("BindableEvent")
    self.ElementLeveled = Instance.new("BindableEvent")
    self.BalanceChanged:Fire(self.coins, self.orbs, self.elements)

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    self.updateEvent = ReplicatedStorage:FindFirstChild("CurrencyUpdated")
    if self.updateEvent then
        self.updateEvent.OnClientEvent:Connect(function(data)
            if data.coins then self.coins = data.coins end
            if data.orbs then self.orbs = data.orbs end
            if data.elements then self.elements = data.elements end
            if data.elementLeveled then
                self.ElementLeveled:Fire(data.elementLeveled, self.elements[data.elementLeveled])
            end
            self.BalanceChanged:Fire(self.coins, self.orbs, self.elements)
        end)
        self.updateEvent:FireServer({request = true})
    end

    return self
end

function CurrencyService:GetBalance()
        return self.coins, self.orbs, self.elements
end

function CurrencyService:AddCoins(amount)
        if self.updateEvent then
                self.updateEvent:FireServer({addCoins = amount})
        end
end

function CurrencyService:GetOrbCount()
        local total = 0
        for _, v in pairs(self.orbs) do
                total += v
        end
        return total
end

function CurrencyService:AddOrb(element)
        if typeof(element) ~= "string" then return false end
        self.orbs[element] = (self.orbs[element] or 0) + 1
        if self.updateEvent then
                self.updateEvent:FireServer({addOrb = element})
        end
        self.BalanceChanged:Fire(self.coins, self.orbs, self.elements)
        return true
end

function CurrencyService:SpendCoins(amount)
        if self.updateEvent then
                self.updateEvent:FireServer({spendCoins = amount})
        end
        return true
end

return CurrencyService
