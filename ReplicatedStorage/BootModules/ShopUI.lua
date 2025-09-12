local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AbilityMetadata = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("AbilityMetadata"))
local bootModules = ReplicatedStorage:WaitForChild("BootModules")
local shopItemsModule = bootModules:WaitForChild("ShopItems", 5)
if not shopItemsModule then
    warn("ShopItems module missing")
    return
end
local ShopItems = require(shopItemsModule)

local ShopUI = {}

local tabFrames = {}
local frame

-- Build the shop interface with category tabs.
function ShopUI.init(config, shop, bootUI, defaultTab)
    local root = bootUI and bootUI.root
    if not root then return end

    frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(0.4,0.5)
    frame.Position = UDim2.fromScale(0.3,0.25)
    frame.BackgroundColor3 = Color3.fromRGB(40,40,42)
    frame.Parent = root

    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1,0,0,30)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = frame

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabBar

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1,0,1,-30)
    content.Position = UDim2.new(0,0,0,30)
    content.BackgroundTransparency = 1
    content.Parent = frame

    local names = {"Elements","Abilities","Weapons"}
    local numTabs = #names
    for _,name in ipairs(names) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1/numTabs,0,1,0)
        btn.Text = name
        btn.BackgroundColor3 = Color3.fromRGB(60,60,62)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.AutoButtonColor = true
        btn.Parent = tabBar
        btn.Activated:Connect(function()
            ShopUI.setTab(name)
        end)

        local tabFrame = Instance.new("ScrollingFrame")
        tabFrame.Size = UDim2.fromScale(1,1)
        tabFrame.BackgroundTransparency = 1
        tabFrame.Visible = false
        tabFrame.ScrollBarThickness = 6
        tabFrame.CanvasSize = UDim2.new(0,0,0,0)
        tabFrame.Parent = content
        tabFrames[name] = tabFrame

        local layout = Instance.new("UIListLayout")
        layout.Parent = tabFrame
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            tabFrame.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y)
        end)
    end

    -- Abilities tab
    local abilitiesFrame = tabFrames["Abilities"]
    local learnRF = ReplicatedStorage:WaitForChild("LearnAbility")
    for ability, info in pairs(AbilityMetadata) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,0,0,40)
        btn.BackgroundColor3 = Color3.fromRGB(80,80,82)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Text = ability .. " (" .. info.cost .. " Coins)"
        btn.Parent = abilitiesFrame
        btn.Activated:Connect(function()
            if shop:Purchase(ability, info.cost) then
                learnRF:InvokeServer(ability)
            end
        end)
    end

    -- Elements tab
    local elementsFrame = tabFrames["Elements"]
    for itemId, info in pairs(ShopItems.Elements) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,0,0,40)
        btn.BackgroundColor3 = Color3.fromRGB(80,80,82)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Text = itemId .. " (" .. info.cost .. " Coins)"
        btn.Parent = elementsFrame
        btn.Activated:Connect(function()
            shop:Purchase(itemId, info.cost)
        end)
    end

    -- Weapons tab
    local weaponsFrame = tabFrames["Weapons"]
    for itemId, info in pairs(ShopItems.Weapons) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,0,0,40)
        btn.BackgroundColor3 = Color3.fromRGB(80,80,82)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Text = itemId .. " (" .. info.cost .. " Coins)"
        btn.Parent = weaponsFrame
        btn.Activated:Connect(function()
            shop:Purchase(itemId, info.cost)
        end)
    end

    function ShopUI.setTab(tabName)
        for name, f in pairs(tabFrames) do
            f.Visible = (name == tabName)
        end
    end

    ShopUI.setTab(defaultTab or names[1])

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromScale(0.06,0.12)
    closeBtn.AnchorPoint = Vector2.new(1,0)
    closeBtn.Position = UDim2.fromScale(0.98,0.02)
    closeBtn.Text = "X"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextScaled = true
    closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200,60,60)
    closeBtn.ZIndex = 2
    closeBtn.Parent = frame
    closeBtn.Activated:Connect(function()
        frame.Visible = false
    end)

    return frame
end

return ShopUI

