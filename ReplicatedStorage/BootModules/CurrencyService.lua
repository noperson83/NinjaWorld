local CurrencyService = {}
CurrencyService.__index = CurrencyService

-- Simple currency tracker with client/server sync.
function CurrencyService.new(config)
        local self = setmetatable({}, CurrencyService)
        self.coins = config.startCoins or 0
        self.orbs = config.startOrbs or 0

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
