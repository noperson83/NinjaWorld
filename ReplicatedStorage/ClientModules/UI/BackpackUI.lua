local BackpackUI = {}

local function clearChildren(p)
    for _, c in ipairs(p:GetChildren()) do
        if not c:IsA("UIListLayout") then
            c:Destroy()
        end
    end
end

function BackpackUI.init(parent, baseY)
    local self = {}
    self.data = {coins = 0, orbs = {}, elements = {}}
    self.currentTab = "Main"

    local card = Instance.new("Frame")
    card.Size = UDim2.new(0.48,-30,0.62,0)
    card.Position = UDim2.new(1,-20,0, baseY + 92)
    card.AnchorPoint = Vector2.new(1,0)
    card.BackgroundColor3 = Color3.fromRGB(24,26,28)
    card.BackgroundTransparency = 0.6
    card.BorderSizePixel = 0
    card.Parent = parent

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,-20,0,36)
    title.Position = UDim2.new(0.02,0,0.02,0)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Backpack"
    title.Font = Enum.Font.GothamSemibold
    title.TextScaled = true
    title.TextColor3 = Color3.new(1,1,1)
    title.Parent = card

    local closeButton = Instance.new("TextButton")
    closeButton.Name = "BackpackCloseButton"
    closeButton.Size = UDim2.new(0,32,0,32)
    closeButton.AnchorPoint = Vector2.new(1,0)
    closeButton.Position = UDim2.new(1,-6,0,6)
    closeButton.Text = "X"
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextScaled = true
    closeButton.TextColor3 = Color3.new(1,1,1)
    closeButton.BackgroundColor3 = Color3.fromRGB(120,40,40)
    closeButton.AutoButtonColor = true
    closeButton.Parent = card

    local capBarBG = Instance.new("Frame")
    capBarBG.Size = UDim2.new(1,-20,0,10)
    capBarBG.Position = UDim2.new(0.02,0,0.12,0)
    capBarBG.BackgroundColor3 = Color3.fromRGB(60,60,62)
    capBarBG.BorderSizePixel = 0
    capBarBG.Parent = card

    local capBar = Instance.new("Frame")
    capBar.Size = UDim2.new(0,0,1,0)
    capBar.BackgroundColor3 = Color3.fromRGB(80,180,120)
    capBar.BorderSizePixel = 0
    capBar.Parent = capBarBG

    local capLabel = Instance.new("TextLabel")
    capLabel.Size = UDim2.new(1,-20,0,22)
    capLabel.Position = UDim2.new(0.02,0,0.16,0)
    capLabel.BackgroundTransparency = 1
    capLabel.TextXAlignment = Enum.TextXAlignment.Left
    capLabel.Font = Enum.Font.Gotham
    capLabel.TextScaled = true
    capLabel.TextColor3 = Color3.fromRGB(230,230,230)
    capLabel.Parent = card

    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1,-20,0,30)
    tabBar.Position = UDim2.new(0.02,0,0.26,0)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = card

    local tabButtons = {}
    local tabNames = {"Main","Weapons","Food","Special"}
    for i,name in ipairs(tabNames) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0,80,1,0)
        btn.Position = UDim2.new((i-1)*0.082,0,0,0)
        btn.BackgroundColor3 = Color3.fromRGB(50,50,52)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.Gotham
        btn.TextScaled = true
        btn.Text = name
        btn.AutoButtonColor = true
        btn.Parent = tabBar
        tabButtons[name] = btn
    end

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1,-20,1,-140)
    list.Position = UDim2.new(0.02,0,0.32,0)
    list.CanvasSize = UDim2.new()
    list.ScrollBarThickness = 6
    list.BackgroundTransparency = 1
    list.Parent = card
    local layout = Instance.new("UIListLayout", list)
    layout.Padding = UDim.new(0,6)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y)
    end)

    local function addHeader(text)
        local h = Instance.new("TextLabel")
        h.Size = UDim2.new(1,0,0,30)
        h.BackgroundTransparency = 1
        h.TextXAlignment = Enum.TextXAlignment.Left
        h.Font = Enum.Font.GothamSemibold
        h.TextScaled = true
        h.TextColor3 = Color3.fromRGB(200,200,200)
        h.Text = text
        h.Parent = list
    end

    local function addSimpleRow(label, value)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,0,0,30)
        row.BackgroundTransparency = 1
        row.Parent = list

        local name = Instance.new("TextLabel")
        name.Size = UDim2.new(0.6,-10,1,0)
        name.Position = UDim2.fromOffset(10,0)
        name.BackgroundTransparency = 1
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.Font = Enum.Font.Gotham
        name.TextScaled = true
        name.TextColor3 = Color3.new(1,1,1)
        name.Text = label
        name.Parent = row

        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0.4,-10,1,0)
        val.Position = UDim2.new(0.6,0,0,0)
        val.BackgroundTransparency = 1
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Font = Enum.Font.Gotham
        val.TextScaled = true
        val.TextColor3 = Color3.fromRGB(230,230,230)
        val.Text = tostring(value or 0)
        val.Parent = row
    end

    local function addItemRow(it)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,0,0,40)
        row.BackgroundColor3 = Color3.fromRGB(32,34,36)
        row.BorderSizePixel = 0
        row.Parent = list

        local name = Instance.new("TextLabel")
        name.Size = UDim2.new(0.6,-10,1,0)
        name.Position = UDim2.fromOffset(10,0)
        name.BackgroundTransparency = 1
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.Font = Enum.Font.Gotham
        name.TextScaled = true
        name.TextColor3 = Color3.new(1,1,1)
        name.Text = it.name
        name.Parent = row

        local qty = Instance.new("TextLabel")
        qty.Size = UDim2.new(0.4,-10,1,0)
        qty.Position = UDim2.new(0.6,0,0,0)
        qty.BackgroundTransparency = 1
        qty.TextXAlignment = Enum.TextXAlignment.Right
        qty.Font = Enum.Font.Gotham
        qty.TextScaled = true
        qty.TextColor3 = Color3.fromRGB(230,230,230)
        qty.Text = string.format("%d / %d", it.qty, it.stack)
        qty.Parent = row
    end

    function self:render(tab)
        self.currentTab = tab or self.currentTab
        clearChildren(list)
        local data = self.data
        if not data then return end
        if self.currentTab == "Main" then
            addHeader("Stats")
            addSimpleRow("Coins", data.coins or 0)
        elseif self.currentTab == "Weapons" then
            for _,it in ipairs(data.weapons or {}) do
                addItemRow(it)
            end
        elseif self.currentTab == "Food" then
            for _,it in ipairs(data.food or {}) do
                addItemRow(it)
            end
        elseif self.currentTab == "Special" then
            for _,it in ipairs(data.special or {}) do
                addItemRow(it)
            end
        end
    end

    function self:setData(bp)
        self.data = bp or {}
        self:render(self.currentTab)
    end

    function self:updateCurrency(coins, orbs, elements)
        self.data = self.data or {}
        self.data.coins = coins
        self.data.orbs = orbs
        self.data.elements = elements
        self:render(self.currentTab)
    end

    function self:setVisible(visible)
        card.Visible = visible and true or false
    end

    function self:isVisible()
        return card.Visible
    end

    self.closeButton = closeButton
    self.root = card

    closeButton.MouseButton1Click:Connect(function()
        self:setVisible(false)
    end)

    for name,btn in pairs(tabButtons) do
        btn.MouseButton1Click:Connect(function()
            self:render(name)
        end)
    end

    self:render(self.currentTab)
    return self
end

return BackpackUI
