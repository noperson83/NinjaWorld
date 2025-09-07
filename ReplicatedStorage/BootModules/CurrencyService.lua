local CurrencyService = {}
CurrencyService.__index = CurrencyService

-- Simple currency tracker with client/server sync.
function CurrencyService.new(config)
    local self = setmetatable({}, CurrencyService)
    self.coins = 0
    self.orbs = {}

    self.BalanceChanged = Instance.new("BindableEvent")
    self.BalanceChanged:Fire(self.coins, self.orbs)

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    self.updateEvent = ReplicatedStorage:FindFirstChild("CurrencyUpdated")
    if self.updateEvent then
        self.updateEvent.OnClientEvent:Connect(function(data)
            if data.coins then self.coins = data.coins end
            if data.orbs then self.orbs = data.orbs end
            self.BalanceChanged:Fire(self.coins, self.orbs)
        end)
        self.updateEvent:FireServer({request = true})
    end

    return self
end

function CurrencyService:GetBalance()
        return self.coins, self.orbs
end

function CurrencyService:AddCoins(amount)
        self.coins = self.coins + amount
        if self.updateEvent then
                self.updateEvent:FireServer({coins = self.coins})
        end
        self.BalanceChanged:Fire(self.coins, self.orbs)
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
        if self.orbs[element] then return false end
        if self:GetOrbCount() >= 10 then return false end
        self.orbs[element] = 1
        if self.updateEvent then
                self.updateEvent:FireServer({addOrb = element})
        end
        self.BalanceChanged:Fire(self.coins, self.orbs)
        return true
end

function CurrencyService:SpendCoins(amount)
        if self.coins < amount then return false end
        self.coins = self.coins - amount
        if self.updateEvent then
                self.updateEvent:FireServer({coins = self.coins})
        end
        self.BalanceChanged:Fire(self.coins, self.orbs)
        return true
end

return CurrencyService
