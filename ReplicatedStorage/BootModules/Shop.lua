local Shop = {}
Shop.__index = Shop

-- Handles server communication for buying items.
function Shop.new(config, currencyService)
        local self = setmetatable({}, Shop)
        self.currencyService = currencyService
        self.config = config
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local function waitForRemote()
                local remote = ReplicatedStorage:FindFirstChild("ShopEvent")
                while not remote do
                        if not ReplicatedStorage.Parent or not ReplicatedStorage:IsDescendantOf(game) then
                                return nil
                        end
                        task.wait()
                        remote = ReplicatedStorage:FindFirstChild("ShopEvent")
                end
                return remote
        end

        self.remote = waitForRemote()
        return self
end

function Shop:Purchase(itemId, cost)
        local coins = self.currencyService:GetBalance()
        if coins < cost then
                warn("Not enough coins for purchase")
                return false
        end
        if self.remote then
                self.remote:FireServer({itemId = itemId, cost = cost})
        end
        return true
end

return Shop
