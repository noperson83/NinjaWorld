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

        local buy = Instance.new("TextButton")
        buy.Size = UDim2.fromScale(1,0.3)
        buy.Position = UDim2.fromScale(0,0.7)
        buy.Text = "Buy Sample Item"
        buy.Parent = frame

        buy.Activated:Connect(function()
                shop:Purchase("Sample", 10)
        end)
end

return ShopUI
