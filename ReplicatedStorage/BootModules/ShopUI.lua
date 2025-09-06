local ShopUI = {}

-- Basic shop interface.
function ShopUI.init(config, shop, bootUI)
        local root = bootUI and bootUI.root
        if not root then return end

        local frame = Instance.new("Frame")
        frame.Size = UDim2.fromScale(0.3,0.3)
        frame.Position = UDim2.fromScale(0.35,0.35)
        frame.BackgroundColor3 = Color3.fromRGB(40,40,42)
        frame.Parent = root

        local cost = 10

        local buy = Instance.new("TextButton")
        buy.Size = UDim2.fromScale(1,0.3)
        buy.Position = UDim2.fromScale(0,0.7)
        buy.Text = "Buy Sample Item"
        buy.Parent = frame

        local currencyService = shop and shop.currencyService
        local function updateButton(coins)
                coins = coins or (currencyService and currencyService:GetBalance() or 0)
                local canAfford = coins >= cost
                buy.Active = canAfford
                buy.AutoButtonColor = canAfford
                buy.TextTransparency = canAfford and 0 or 0.5
        end
        updateButton()
        if currencyService and currencyService.BalanceChanged then
                currencyService.BalanceChanged.Event:Connect(function(c)
                        updateButton(c)
                end)
        end

        buy.Activated:Connect(function()
                shop:Purchase("Sample", cost)
        end)
end

return ShopUI
