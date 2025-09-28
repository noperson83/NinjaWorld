local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ClientModules = ReplicatedStorage:WaitForChild("ClientModules")
local AbilityMetadata = require(ClientModules:WaitForChild("AbilityMetadata"))
local AbilitiesModule = require(ClientModules:WaitForChild("Abilities"))

local AbilityUI = {}
AbilityUI.__index = AbilityUI

local BUTTON_COLORS = {
    background = Color3.fromRGB(32, 36, 48),
    accent = Color3.fromRGB(95, 145, 255),
    afford = Color3.fromRGB(80, 150, 90),
    disabled = Color3.fromRGB(60, 60, 60),
    unlocked = Color3.fromRGB(60, 110, 70),
}

local TEXT_COLORS = {
    primary = Color3.fromRGB(240, 240, 255),
    secondary = Color3.fromRGB(200, 205, 220),
    warning = Color3.fromRGB(255, 170, 170),
    success = Color3.fromRGB(180, 255, 180),
}

local function formatNumber(value)
    local number = tonumber(value) or 0
    local raw = tostring(math.floor(number + 0.5))
    local sign, digits = raw:match("^([%-]?)(%d+)$")
    sign = sign or ""
    digits = digits or raw

    local reversed = digits:reverse():gsub("(%d%d%d)", "%1,")
    local formatted = reversed:reverse()
    if formatted:sub(1, 1) == "," then
        formatted = formatted:sub(2)
    end

    return sign .. formatted
end

local function createCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 10)
    corner.Parent = parent
    return corner
end

local function createStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(70, 80, 120)
    stroke.Thickness = thickness or 2
    stroke.Parent = parent
    return stroke
end

local function connectAbilityValue(self, valueObject)
    if not (valueObject and valueObject:IsA("BoolValue")) then
        return
    end

    local abilityName = valueObject.Name
    local conn = valueObject:GetPropertyChangedSignal("Value"):Connect(function()
        self:updateButton(abilityName)
    end)
    table.insert(self.connections, conn)

    self:updateButton(abilityName)
end

function AbilityUI.new(config, bootUI)
    local root = bootUI and bootUI.root
    if not root then
        return nil
    end

    local self = setmetatable({
        config = config or {},
        bootUI = bootUI,
        root = root,
        frame = nil,
        list = nil,
        entries = {},
        coins = 0,
        connections = {},
        abilitiesFolder = nil,
        learnRF = nil,
    }, AbilityUI)

    self:build()
    self:observeCurrency()
    self:observeAbilities()
    self:updateAllButtons()

    return self
end

function AbilityUI.init(config, bootUI)
    return AbilityUI.new(config, bootUI)
end

function AbilityUI:destroy()
    for _, conn in ipairs(self.connections) do
        if conn and conn.Disconnect then
            conn:Disconnect()
        end
    end
    self.connections = {}

    if self.frame then
        self.frame:Destroy()
        self.frame = nil
    end
    self.list = nil
    self.entries = {}
    self.bootUI = nil
end

function AbilityUI:isAbilityUnlocked(name)
    if AbilitiesModule and typeof(AbilitiesModule.isUnlocked) == "function" then
        local ok, result = pcall(AbilitiesModule.isUnlocked, name)
        if ok and result then
            return true
        end
    end

    local folder = self.abilitiesFolder
    if not folder then
        return false
    end

    local valueObject = folder:FindFirstChild(name)
    return valueObject and valueObject:IsA("BoolValue") and valueObject.Value
end

function AbilityUI:getAbilityInfo(name)
    local info = AbilityMetadata[name]
    if not info then
        return {cost = 0}
    end
    return info
end

function AbilityUI:updateBalance(newBalance)
    local coins = tonumber(newBalance) or 0
    if coins ~= self.coins then
        self.coins = coins
        self:updateAllButtons()
    end
end

function AbilityUI:observeCurrency()
    local currencyService = self.bootUI and self.bootUI.currencyService
    if currencyService and currencyService.BalanceChanged then
        local coins = currencyService:GetBalance()
        if typeof(coins) == "number" then
            self.coins = coins
        else
            local currentCoins = select(1, currencyService:GetBalance())
            self.coins = currentCoins or 0
        end
        local conn = currencyService.BalanceChanged.Event:Connect(function(coinsValue)
            self:updateBalance(coinsValue)
        end)
        table.insert(self.connections, conn)
        return
    end

    local player = Players.LocalPlayer
    local stats = player and player:FindFirstChild("Stats")
    local coinsValue = stats and stats:FindFirstChild("Coins")
    if coinsValue and coinsValue:IsA("IntValue") then
        self.coins = coinsValue.Value
        local conn = coinsValue:GetPropertyChangedSignal("Value"):Connect(function()
            self:updateBalance(coinsValue.Value)
        end)
        table.insert(self.connections, conn)
    end
end

function AbilityUI:observeAbilities()
    local player = Players.LocalPlayer
    if not player then
        return
    end

    local function attach(folder)
        if not (folder and folder:IsA("Folder")) then
            return
        end
        if self.abilitiesFolder == folder then
            return
        end

        self.abilitiesFolder = folder
        for _, child in ipairs(folder:GetChildren()) do
            connectAbilityValue(self, child)
        end

        local addedConn = folder.ChildAdded:Connect(function(child)
            connectAbilityValue(self, child)
        end)
        local removedConn = folder.ChildRemoved:Connect(function(child)
            local entry = self.entries[child.Name]
            if entry then
                self:updateButton(child.Name)
            end
        end)
        table.insert(self.connections, addedConn)
        table.insert(self.connections, removedConn)
    end

    local folder = player:FindFirstChild("Abilities")
    if folder then
        attach(folder)
    else
        local conn
        conn = player.ChildAdded:Connect(function(child)
            if child.Name == "Abilities" and child:IsA("Folder") then
                attach(child)
                if conn then
                    conn:Disconnect()
                end
            end
        end)
        table.insert(self.connections, conn)
    end
end

function AbilityUI:build()
    local frame = Instance.new("Frame")
    frame.Name = "AbilityShop"
    frame.Size = UDim2.fromScale(0.36, 0.48)
    frame.Position = UDim2.fromScale(0.32, 0.26)
    frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    frame.BackgroundTransparency = 0.02
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ZIndex = 60
    frame.Parent = self.root
    createCorner(frame, 14)
    createStroke(frame, Color3.fromRGB(70, 80, 120), 2)
    self.frame = frame

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundTransparency = 1
    header.ZIndex = frame.ZIndex + 1
    header.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Ability Training"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 30
    title.TextColor3 = TEXT_COLORS.primary
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = header.ZIndex + 1
    title.Parent = header

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -80, 1, 0)
    subtitle.Position = UDim2.new(0, 20, 0, 30)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Invest your coins to master new techniques"
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 16
    subtitle.TextColor3 = TEXT_COLORS.secondary
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.ZIndex = header.ZIndex + 1
    subtitle.Parent = header

    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.fromOffset(42, 42)
    closeButton.Position = UDim2.new(1, -52, 0, 10)
    closeButton.BackgroundColor3 = BUTTON_COLORS.background
    closeButton.Text = "✕"
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 20
    closeButton.TextColor3 = TEXT_COLORS.primary
    closeButton.ZIndex = header.ZIndex + 1
    closeButton.Parent = header
    createCorner(closeButton, 12)
    createStroke(closeButton, Color3.fromRGB(120, 70, 80), 2)

    closeButton.MouseEnter:Connect(function()
        closeButton.BackgroundColor3 = Color3.fromRGB(60, 45, 55)
    end)
    closeButton.MouseLeave:Connect(function()
        closeButton.BackgroundColor3 = BUTTON_COLORS.background
    end)
    closeButton.Activated:Connect(function()
        self:hide()
    end)

    local list = Instance.new("ScrollingFrame")
    list.Name = "AbilityList"
    list.Size = UDim2.new(1, -24, 1, -92)
    list.Position = UDim2.new(0, 12, 0, 72)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.ScrollBarThickness = 6
    list.ScrollBarImageColor3 = BUTTON_COLORS.accent
    list.ZIndex = frame.ZIndex + 1
    list.Parent = frame
    self.list = list

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.Parent = list

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.Parent = list

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
    end)

    local abilityNames = {}
    for abilityName in pairs(AbilityMetadata) do
        table.insert(abilityNames, abilityName)
    end
    table.sort(abilityNames)

    for _, abilityName in ipairs(abilityNames) do
        self:createAbilityEntry(abilityName, AbilityMetadata[abilityName])
    end

    self.learnRF = ReplicatedStorage:FindFirstChild("LearnAbility")
    if not self.learnRF then
        task.spawn(function()
            local ok, remote = pcall(function()
                return ReplicatedStorage:WaitForChild("LearnAbility", 5)
            end)
            if ok then
                self.learnRF = remote
            else
                warn("AbilityUI: LearnAbility remote not found")
            end
        end)
    end
end

function AbilityUI:createAbilityEntry(abilityName, info)
    info = info or {cost = 0}

    local container = Instance.new("Frame")
    container.Name = abilityName .. "Entry"
    container.Size = UDim2.new(1, -8, 0, 120)
    container.BackgroundColor3 = BUTTON_COLORS.background
    container.BackgroundTransparency = 0.08
    container.BorderSizePixel = 0
    container.ZIndex = self.list.ZIndex + 1
    container.Parent = self.list
    createCorner(container, 12)
    createStroke(container, Color3.fromRGB(45, 55, 90), 1)

    local containerPadding = Instance.new("UIPadding")
    containerPadding.PaddingTop = UDim.new(0, 12)
    containerPadding.PaddingBottom = UDim.new(0, 12)
    containerPadding.PaddingLeft = UDim.new(0, 16)
    containerPadding.PaddingRight = UDim.new(0, 16)
    containerPadding.Parent = container

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, -10, 0, 26)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 22
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextColor3 = TEXT_COLORS.primary
    nameLabel.Text = abilityName
    nameLabel.ZIndex = container.ZIndex + 1
    nameLabel.Parent = container

    local description = Instance.new("TextLabel")
    description.Name = "Description"
    description.Size = UDim2.new(1, 0, 0, 36)
    description.Position = UDim2.new(0, 0, 0, 32)
    description.BackgroundTransparency = 1
    description.Font = Enum.Font.Gotham
    description.TextSize = 16
    description.TextWrapped = true
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.TextYAlignment = Enum.TextYAlignment.Top
    description.TextColor3 = TEXT_COLORS.secondary
    description.Text = info.description or "A unique ninja technique"
    description.ZIndex = container.ZIndex + 1
    description.Parent = container

    local footer = Instance.new("Frame")
    footer.Name = "Footer"
    footer.Size = UDim2.new(1, 0, 0, 32)
    footer.Position = UDim2.new(0, 0, 1, -32)
    footer.BackgroundTransparency = 1
    footer.ZIndex = container.ZIndex + 1
    footer.Parent = container

    local costLabel = Instance.new("TextLabel")
    costLabel.Name = "CostLabel"
    costLabel.Size = UDim2.new(1, -150, 1, 0)
    costLabel.BackgroundTransparency = 1
    costLabel.Font = Enum.Font.GothamSemibold
    costLabel.TextSize = 18
    costLabel.TextXAlignment = Enum.TextXAlignment.Left
    costLabel.TextColor3 = TEXT_COLORS.secondary
    costLabel.Text = string.format("%s Coins", formatNumber(info.cost or 0))
    costLabel.ZIndex = footer.ZIndex + 1
    costLabel.Parent = footer

    local purchaseButton = Instance.new("TextButton")
    purchaseButton.Name = "PurchaseButton"
    purchaseButton.Size = UDim2.new(0, 130, 1, 0)
    purchaseButton.Position = UDim2.new(1, 0, 0, 0)
    purchaseButton.AnchorPoint = Vector2.new(1, 0)
    purchaseButton.BackgroundColor3 = BUTTON_COLORS.afford
    purchaseButton.Text = "Learn"
    purchaseButton.Font = Enum.Font.GothamBold
    purchaseButton.TextSize = 18
    purchaseButton.TextColor3 = Color3.fromRGB(245, 255, 245)
    purchaseButton.AutoButtonColor = true
    purchaseButton.ZIndex = footer.ZIndex + 1
    purchaseButton.Parent = footer
    createCorner(purchaseButton, 10)

    purchaseButton.MouseEnter:Connect(function()
        if purchaseButton.AutoButtonColor then
            purchaseButton.BackgroundColor3 = BUTTON_COLORS.afford:Lerp(Color3.fromRGB(120, 200, 130), 0.25)
        end
    end)
    purchaseButton.MouseLeave:Connect(function()
        if purchaseButton.AutoButtonColor then
            purchaseButton.BackgroundColor3 = BUTTON_COLORS.afford
        end
    end)

    purchaseButton.Activated:Connect(function()
        self:onPurchasePressed(abilityName)
    end)

    self.entries[abilityName] = {
        container = container,
        button = purchaseButton,
        costLabel = costLabel,
        info = info,
        nameLabel = nameLabel,
    }
end

function AbilityUI:flashButton(button, color)
    if not (button and button.Parent) then
        return
    end

    local original = button.BackgroundColor3
    local highlight = color or Color3.fromRGB(170, 70, 70)
    TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = highlight,
    }):Play()
    task.delay(0.18, function()
        if button and button.Parent then
            TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = original,
            }):Play()
        end
    end)
end

function AbilityUI:onPurchasePressed(abilityName)
    local entry = self.entries[abilityName]
    if not entry then
        return
    end

    if self:isAbilityUnlocked(abilityName) then
        self:updateButton(abilityName)
        return
    end

    local info = self:getAbilityInfo(abilityName)
    local cost = tonumber(info.cost) or 0
    if self.coins < cost then
        self:flashButton(entry.button, Color3.fromRGB(170, 70, 70))
        entry.costLabel.TextColor3 = TEXT_COLORS.warning
        entry.costLabel.Text = string.format("Need %s Coins", formatNumber(cost))
        task.delay(0.8, function()
            if entry.costLabel then
                entry.costLabel.TextColor3 = TEXT_COLORS.secondary
                entry.costLabel.Text = string.format("%s Coins", formatNumber(cost))
            end
        end)
        return
    end

    local remote = self.learnRF
    if not remote then
        remote = ReplicatedStorage:FindFirstChild("LearnAbility")
        self.learnRF = remote
    end
    if not remote then
        warn("AbilityUI: LearnAbility remote missing; cannot purchase")
        self:flashButton(entry.button)
        return
    end

    entry.button.AutoButtonColor = false
    entry.button.Active = false
    entry.button.Text = "Training..."

    task.spawn(function()
        local ok, result = pcall(remote.InvokeServer, remote, abilityName)
        if not ok then
            warn(string.format("AbilityUI: Failed to learn %s (%s)", abilityName, tostring(result)))
            self:flashButton(entry.button)
            entry.button.Text = "Learn"
            entry.button.AutoButtonColor = true
            entry.button.Active = true
            self:updateButton(abilityName)
            return
        end

        if typeof(result) == "table" and result.success == false then
            self:flashButton(entry.button)
        end

        task.wait(0.1)
        self:updateButton(abilityName)
    end)
end

function AbilityUI:updateButton(abilityName)
    local entry = self.entries[abilityName]
    if not entry then
        return
    end

    local info = entry.info or self:getAbilityInfo(abilityName)
    local cost = tonumber(info.cost) or 0
    local unlocked = self:isAbilityUnlocked(abilityName)
    local canAfford = self.coins >= cost

    if unlocked then
        entry.button.Text = "Unlocked"
        entry.button.AutoButtonColor = false
        entry.button.Active = false
        entry.button.BackgroundColor3 = BUTTON_COLORS.unlocked
        entry.button.TextColor3 = TEXT_COLORS.success
        entry.costLabel.Text = "Unlocked"
        entry.costLabel.TextColor3 = TEXT_COLORS.success
    else
        entry.button.Text = canAfford and "Learn" or "Need Coins"
        entry.button.AutoButtonColor = canAfford
        entry.button.Active = true
        entry.button.BackgroundColor3 = canAfford and BUTTON_COLORS.afford or BUTTON_COLORS.disabled
        entry.button.TextColor3 = TEXT_COLORS.primary
        entry.costLabel.Text = string.format("%s Coins", formatNumber(cost))
        entry.costLabel.TextColor3 = canAfford and TEXT_COLORS.secondary or TEXT_COLORS.warning
    end
end

function AbilityUI:updateAllButtons()
    for abilityName in pairs(self.entries) do
        self:updateButton(abilityName)
    end
end

function AbilityUI:show()
    if not self.frame then
        return
    end
    self:updateAllButtons()
    self.frame.Visible = true
end

function AbilityUI:hide()
    if not self.frame then
        return
    end
    self.frame.Visible = false
end

function AbilityUI:toggle()
    if not self.frame then
        return false
    end
    local visible = not self.frame.Visible
    if visible then
        self:show()
    else
        self:hide()
    end
    return visible
end

function AbilityUI:isVisible()
    return self.frame and self.frame.Visible or false
end

return AbilityUI
