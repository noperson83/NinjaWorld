local Shop = {}
Shop.__index = Shop

-- Handles server communication for buying items.
function Shop.new(config, currencyService)
        local self = setmetatable({}, Shop)
        self.currencyService = currencyService
        self.config = config
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        self.remote = ReplicatedStorage:FindFirstChild("ShopEvent")
        return self
end

function Shop:Purchase(itemId, cost)
        if not self.currencyService:SpendCoins(cost) then
                warn("Not enough coins for purchase")
                return false
        end
        if self.remote then
                self.remote:FireServer({itemId = itemId, cost = cost})
        end
        return true
end

return Shop
