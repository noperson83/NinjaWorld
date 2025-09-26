local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopUI = require(ReplicatedStorage.ClientModules.UI.ShopUI)
local QuestUI = require(ReplicatedStorage.ClientModules.UI.QuestUI)
local NinjaPouchUI = require(ReplicatedStorage.ClientModules.UI.NinjaPouchUI)
local TeleportClient = require(ReplicatedStorage.ClientModules.TeleportClient)

local WorldHUD = {}
WorldHUD.__index = WorldHUD

local currentHud

local player = Players.LocalPlayer

local REALM_INFO = {
    {key = "StarterDojo",   name = "Starter Dojo"},
    {key = "SecretVillage", name = "Secret Village of Elementara"},
    {key = "Water",         name = "Water"},
    {key = "Fire",          name = "Fire"},
    {key = "Wind",          name = "Wind"},
    {key = "Growth",        name = "Growth"},
    {key = "Ice",           name = "Ice"},
    {key = "Light",         name = "Light"},
    {key = "Metal",         name = "Metal"},
    {key = "Strength",      name = "Strength"},
    {key = "Atoms",         name = "Atoms"},
}

local function track(self, conn)
    if conn == nil then
        return nil
    end

    table.insert(self._connections, conn)
    return conn
end

local function getEnumValue(enumType, itemName, fallback)
    local ok, value = pcall(function()
        return enumType[itemName]
    end)

    if ok and value ~= nil then
        return value
    end

    return fallback
end

local function createRealmButton(parent, info, order)
    local btn = Instance.new("TextButton")
    btn.Name = info.key .. "Button"
    btn.Size = UDim2.new(1, 0, 0, 44)
    btn.LayoutOrder = order or 0
    btn.Text = info.name
    btn.Font = Enum.Font.GothamSemibold
    btn.TextScaled = true
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    btn.TextColor3 = Color3.fromRGB(170, 170, 170)
    btn.AutoButtonColor = true
    btn.BorderSizePixel = 0
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    return btn
end

local function ensureParent()
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        playerGui = player:WaitForChild("PlayerGui")
    end
    return playerGui
end

local function getRealmFolder()
    local realmsFolder = player:FindFirstChild("Realms")
    if not realmsFolder then
        local stats = player:FindFirstChild("Stats")
        if stats then
            realmsFolder = stats:FindFirstChild("Realms")
        end
    end
    return realmsFolder
end

function WorldHUD.get()
    if currentHud and currentHud._destroyed then
        currentHud = nil
    end
    return currentHud
end

function WorldHUD.new(config, dependencies)
    if currentHud and currentHud.gui and currentHud.gui.Parent then
        if config then currentHud.config = config end
        if dependencies then
            if dependencies.shop then currentHud.shop = dependencies.shop end
            if dependencies.currencyService then currentHud.currencyService = dependencies.currencyService end
        end
        return currentHud
    elseif currentHud and (not currentHud.gui or not currentHud.gui.Parent) then
        currentHud = nil
    end

    local self = setmetatable({}, WorldHUD)
    self.config = config or {}
    self.shop = dependencies and dependencies.shop or nil
    self.currencyService = dependencies and dependencies.currencyService or nil
    self._connections = {}
    self._flagConnections = {}
    self._destroyed = false
    self.backButtonEnabled = true

    local playerGui = ensureParent()

    local gui = Instance.new("ScreenGui")
    gui.Name = "WorldHUD"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 75
    gui.Parent = playerGui
    self.gui = gui

    local root = Instance.new("Frame")
    root.Name = "WorldHUDRoot"
    root.Size = UDim2.fromScale(1,1)
    root.BackgroundTransparency = 1
    root.Parent = gui
    self.root = root

    -- Loadout UI
    local loadout = Instance.new("Frame")
    loadout.Name = "Loadout"
    loadout.Size = UDim2.fromScale(1,1)
    loadout.BackgroundTransparency = 1
    loadout.Visible = false
    loadout.ZIndex = 20
    loadout.Parent = root
    self.loadout = loadout

    local baseY = GuiService:GetGuiInset().Y + 20
    self.baseY = baseY

    local loadTitle = Instance.new("TextLabel")
    loadTitle.Size = UDim2.new(1,-40,0,60)
    loadTitle.Position = UDim2.new(0.5,0,0,baseY)
    loadTitle.AnchorPoint = Vector2.new(0.5,0)
    loadTitle.BackgroundTransparency = 0.6
    loadTitle.TextXAlignment = Enum.TextXAlignment.Center
    loadTitle.Text = "Loadout"
    loadTitle.Font = Enum.Font.GothamBold
    loadTitle.TextScaled = true
    loadTitle.TextColor3 = Color3.fromRGB(255,200,120)
    loadTitle.Parent = loadout

    -- Teleport UI
    local teleportContainer = Instance.new("Frame")
    teleportContainer.Name = "TeleportContainer"
    teleportContainer.Size = UDim2.new(0.65, -20, 0.65, 0)
    teleportContainer.Position = UDim2.new(0, 20, 0, baseY + 80)
    teleportContainer.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
    teleportContainer.BackgroundTransparency = 0.05
    teleportContainer.BorderSizePixel = 0
    teleportContainer.Visible = false
    teleportContainer.ZIndex = 25
    teleportContainer.Parent = loadout

    local teleportCorner = Instance.new("UICorner")
    teleportCorner.CornerRadius = UDim.new(0, 12)
    teleportCorner.Parent = teleportContainer

    local teleportStroke = Instance.new("UIStroke")
    teleportStroke.Color = Color3.fromRGB(70, 90, 140)
    teleportStroke.Thickness = 2
    teleportStroke.Transparency = 0.3
    teleportStroke.Parent = teleportContainer

    local teleportTitle = Instance.new("TextLabel")
    teleportTitle.Size = UDim2.new(1, -48, 0, 34)
    teleportTitle.Position = UDim2.new(0, 20, 0, 16)
    teleportTitle.BackgroundTransparency = 1
    teleportTitle.Text = "Teleport Hub"
    teleportTitle.TextXAlignment = Enum.TextXAlignment.Left
    teleportTitle.Font = Enum.Font.GothamBold
    teleportTitle.TextScaled = true
    teleportTitle.TextColor3 = Color3.fromRGB(225, 225, 240)
    teleportTitle.Parent = teleportContainer

    local teleportCloseButton = Instance.new("TextButton")
    teleportCloseButton.Name = "TeleportCloseButton"
    teleportCloseButton.Size = UDim2.new(0, 32, 0, 32)
    teleportCloseButton.AnchorPoint = Vector2.new(1, 0)
    teleportCloseButton.Position = UDim2.new(1, -20, 0, 16)
    teleportCloseButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
    teleportCloseButton.TextColor3 = Color3.new(1, 1, 1)
    teleportCloseButton.Text = "X"
    teleportCloseButton.Font = Enum.Font.GothamBold
    teleportCloseButton.TextScaled = true
    teleportCloseButton.AutoButtonColor = true
    teleportCloseButton.Visible = false
    teleportCloseButton.ZIndex = 30
    teleportCloseButton.Parent = teleportContainer

    local teleportCloseCorner = Instance.new("UICorner")
    teleportCloseCorner.CornerRadius = UDim.new(0, 10)
    teleportCloseCorner.Parent = teleportCloseButton

    local teleportContent = Instance.new("Frame")
    teleportContent.Name = "TeleportContent"
    teleportContent.Size = UDim2.new(1, -32, 1, -84)
    teleportContent.Position = UDim2.new(0, 16, 0, 60)
    teleportContent.BackgroundTransparency = 1
    teleportContent.Parent = teleportContainer

    local localColumn = Instance.new("Frame")
    localColumn.Name = "LocalTeleports"
    localColumn.Size = UDim2.new(0.48, 0, 1, 0)
    localColumn.BackgroundTransparency = 1
    localColumn.Parent = teleportContent

    local worldColumn = Instance.new("Frame")
    worldColumn.Name = "WorldTeleports"
    worldColumn.Size = UDim2.new(0.48, 0, 1, 0)
    worldColumn.Position = UDim2.new(0.52, 0, 0, 0)
    worldColumn.BackgroundTransparency = 1
    worldColumn.Parent = teleportContent

    local localTitle = Instance.new("TextLabel")
    localTitle.Size = UDim2.new(1, 0, 0, 28)
    localTitle.BackgroundTransparency = 1
    localTitle.Text = "Locations"
    localTitle.TextXAlignment = Enum.TextXAlignment.Left
    localTitle.Font = Enum.Font.GothamSemibold
    localTitle.TextScaled = true
    localTitle.TextColor3 = Color3.fromRGB(200, 200, 220)
    localTitle.Parent = localColumn

    local teleFrame = Instance.new("Frame")
    teleFrame.Name = "TeleFrame"
    teleFrame.Size = UDim2.new(1, 0, 1, -36)
    teleFrame.Position = UDim2.new(0, 0, 0, 36)
    teleFrame.BackgroundColor3 = Color3.fromRGB(24, 26, 28)
    teleFrame.BackgroundTransparency = 0.4
    teleFrame.BorderSizePixel = 0
    teleFrame.Parent = localColumn

    local teleFrameCorner = Instance.new("UICorner")
    teleFrameCorner.CornerRadius = UDim.new(0, 10)
    teleFrameCorner.Parent = teleFrame

    local telePadding = Instance.new("UIPadding")
    telePadding.PaddingTop = UDim.new(0, 8)
    telePadding.PaddingBottom = UDim.new(0, 8)
    telePadding.PaddingLeft = UDim.new(0, 8)
    telePadding.PaddingRight = UDim.new(0, 8)
    telePadding.Parent = teleFrame

    local teleGrid = Instance.new("UIGridLayout")
    teleGrid.CellSize = UDim2.new(0.5, -10, 0, 52)
    teleGrid.CellPadding = UDim2.new(0, 8, 0, 8)
    teleGrid.SortOrder = Enum.SortOrder.LayoutOrder
    teleGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    teleGrid.VerticalAlignment = Enum.VerticalAlignment.Top
    teleGrid.Parent = teleFrame

    local zoneButtonsInfo = {
        {name = "Starter", label = "Starter Zone"},
        {name = "Dojo", label = "Dojo Entrance"},
        {name = "Water", label = "Water Island"},
        {name = "Fire", label = "Fire Island"},
        {name = "Wind", label = "Wind Island"},
        {name = "Grow", label = "Growth Island"},
        {name = "Ice", label = "Ice Island"},
        {name = "Light", label = "Light Island"},
        {name = "Metal", label = "Metal Island"},
        {name = "Atom", label = "Atoms Island"},
    }

    for index, info in ipairs(zoneButtonsInfo) do
        local button = Instance.new("TextButton")
        button.Name = info.name .. "Button"
        button.Size = UDim2.new(0, 0, 0, 0)
        button.LayoutOrder = index
        button.BackgroundColor3 = Color3.fromRGB(50, 120, 255)
        button.BackgroundTransparency = 0.2
        button.TextColor3 = Color3.new(1, 1, 1)
        button.Font = Enum.Font.GothamSemibold
        button.TextScaled = true
        button.AutoButtonColor = true
        button.Text = info.label
        button.Parent = teleFrame

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = button
    end

    local worldTitle = Instance.new("TextLabel")
    worldTitle.Size = UDim2.new(1, 0, 0, 28)
    worldTitle.BackgroundTransparency = 1
    worldTitle.Text = "Realms"
    worldTitle.TextXAlignment = Enum.TextXAlignment.Left
    worldTitle.Font = Enum.Font.GothamSemibold
    worldTitle.TextScaled = true
    worldTitle.TextColor3 = Color3.fromRGB(200, 200, 220)
    worldTitle.Parent = worldColumn

    local worldFrame = Instance.new("ScrollingFrame")
    worldFrame.Name = "WorldTeleFrame"
    worldFrame.Size = UDim2.new(1, 0, 1, -88)
    worldFrame.Position = UDim2.new(0, 0, 0, 36)
    worldFrame.BackgroundColor3 = Color3.fromRGB(24, 26, 28)
    worldFrame.BackgroundTransparency = 0.4
    worldFrame.BorderSizePixel = 0
    worldFrame.ScrollBarThickness = 6
    worldFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    worldFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    worldFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    worldFrame.Parent = worldColumn

    local worldCorner = Instance.new("UICorner")
    worldCorner.CornerRadius = UDim.new(0, 10)
    worldCorner.Parent = worldFrame

    local worldPadding = Instance.new("UIPadding")
    worldPadding.PaddingTop = UDim.new(0, 8)
    worldPadding.PaddingBottom = UDim.new(0, 8)
    worldPadding.PaddingLeft = UDim.new(0, 8)
    worldPadding.PaddingRight = UDim.new(0, 8)
    worldPadding.Parent = worldFrame

    local worldLayout = Instance.new("UIListLayout")
    worldLayout.FillDirection = Enum.FillDirection.Vertical
    worldLayout.Padding = UDim.new(0, 8)
    worldLayout.HorizontalAlignment = getEnumValue(Enum.HorizontalAlignment, "Stretch", Enum.HorizontalAlignment.Left)
    worldLayout.SortOrder = Enum.SortOrder.LayoutOrder
    worldLayout.Parent = worldFrame

    local enterRealmButton = Instance.new("TextButton")
    enterRealmButton.Name = "EnterRealmButton"
    enterRealmButton.Size = UDim2.new(1, 0, 0, 48)
    enterRealmButton.LayoutOrder = 1000
    enterRealmButton.Text = "Select a realm"
    enterRealmButton.Font = Enum.Font.GothamBold
    enterRealmButton.TextScaled = true
    enterRealmButton.TextColor3 = Color3.fromRGB(220, 220, 230)
    enterRealmButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    enterRealmButton.AutoButtonColor = false
    enterRealmButton.Active = false
    enterRealmButton.Parent = worldFrame

    local enterCorner = Instance.new("UICorner")
    enterCorner.CornerRadius = UDim.new(0, 8)
    enterCorner.Parent = enterRealmButton

    TeleportClient.bindZoneButtons(root)
    TeleportClient.bindWorldButtons(root)

    self.teleportContainer = teleportContainer
    self.teleportCloseButton = teleportCloseButton
    self.enterRealmButton = enterRealmButton

    local quest = QuestUI.init(loadout, baseY)
    self.quest = quest

    local backpack = NinjaPouchUI.init(loadout, baseY)
    self.backpack = backpack

    local togglePanel = Instance.new("Frame")
    togglePanel.Name = "PanelToggleButtons"
    togglePanel.Size = UDim2.new(0,180,0,160)
    togglePanel.AnchorPoint = Vector2.new(0,1)
    togglePanel.Position = UDim2.new(0,20,1,-220)
    togglePanel.BackgroundTransparency = 1
    togglePanel.ZIndex = 40
    togglePanel.Parent = loadout
    self.togglePanel = togglePanel

    local toggleLayout = Instance.new("UIListLayout")
    toggleLayout.FillDirection = Enum.FillDirection.Vertical
    toggleLayout.Padding = UDim.new(0,6)
    toggleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    toggleLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    toggleLayout.Parent = togglePanel

    local function createOpenButton(label)
        local btn = Instance.new("TextButton")
        btn.Name = label .. "OpenButton"
        btn.Size = UDim2.new(1,0,0,36)
        btn.BackgroundColor3 = Color3.fromRGB(50,120,255)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.GothamSemibold
        btn.TextScaled = true
        btn.AutoButtonColor = true
        btn.Text = label
        btn.Visible = false
        btn.ZIndex = 41
        btn.Parent = togglePanel
        return btn
    end

    local questOpenButton = createOpenButton("Quests")
    local backpackOpenButton = createOpenButton("Backpack")
    local teleOpenButton = createOpenButton("Teleports")
    local shopButton = createOpenButton("Shop")
    shopButton.Visible = true
    self.questOpenButton = questOpenButton
    self.backpackOpenButton = backpackOpenButton
    self.teleportOpenButton = teleOpenButton
    self.shopButton = shopButton

    local function setTeleportsVisible(visible)
        teleportContainer.Visible = visible and true or false
        teleportCloseButton.Visible = visible and true or false
        teleOpenButton.Visible = not visible
    end

    if quest and quest.closeButton then
        track(self, quest.closeButton.MouseButton1Click:Connect(function()
            if quest.setVisible then
                quest:setVisible(false)
            end
            questOpenButton.Visible = true
        end))
    end

    track(self, questOpenButton.MouseButton1Click:Connect(function()
        if quest and quest.setVisible then
            quest:setVisible(true)
        end
        questOpenButton.Visible = false
    end))

    if quest and quest.isVisible and not quest:isVisible() then
        questOpenButton.Visible = true
    end

    if backpack and backpack.closeButton then
        track(self, backpack.closeButton.MouseButton1Click:Connect(function()
            if backpack.setVisible then
                backpack:setVisible(false)
            end
            backpackOpenButton.Visible = true
        end))
    end

    track(self, backpackOpenButton.MouseButton1Click:Connect(function()
        if backpack and backpack.setVisible then
            backpack:setVisible(true)
        end
        backpackOpenButton.Visible = false
    end))

    if backpack and backpack.isVisible and not backpack:isVisible() then
        backpackOpenButton.Visible = true
    end

    track(self, shopButton.MouseButton1Click:Connect(function()
        self:toggleShop()
    end))

    track(self, teleportCloseButton.MouseButton1Click:Connect(function()
        setTeleportsVisible(false)
    end))

    track(self, teleOpenButton.MouseButton1Click:Connect(function()
        setTeleportsVisible(true)
    end))

    setTeleportsVisible(false)

    local backButton = Instance.new("TextButton")
    backButton.Name = "BackButton"
    backButton.Size = UDim2.new(0, 220, 0, 48)
    backButton.AnchorPoint = Vector2.new(0, 1)
    backButton.Position = UDim2.new(0, 20, 1, -20)
    backButton.BackgroundColor3 = Color3.fromRGB(50, 120, 255)
    backButton.TextColor3 = Color3.new(1, 1, 1)
    backButton.Font = Enum.Font.GothamSemibold
    backButton.TextScaled = true
    backButton.AutoButtonColor = true
    backButton.Text = "Back"
    backButton.ZIndex = 40
    backButton.Parent = loadout
    self.backButton = backButton

    local realmButtons = {}
    self.realmButtons = realmButtons
    local realmDisplayLookup = {}
    self.realmDisplayLookup = realmDisplayLookup
    for _, info in ipairs(REALM_INFO) do
        realmDisplayLookup[info.key] = info.name
    end

    local function isRealmUnlocked(key)
        local realmsFolder = getRealmFolder()
        if not realmsFolder then return false end
        local flag = realmsFolder:FindFirstChild(key)
        return flag and flag.Value or false
    end

    local function updateRealmButton(key)
        local btn = realmButtons[key]
        if not btn then return end
        local unlocked = isRealmUnlocked(key)
        btn.Active = unlocked
        btn.AutoButtonColor = unlocked
        btn.BackgroundColor3 = unlocked and Color3.fromRGB(50,120,255) or Color3.fromRGB(40,40,48)
        btn.TextColor3 = unlocked and Color3.new(1,1,1) or Color3.fromRGB(170,170,170)
    end

    local function setSelected(key)
        self.selectedRealm = key
        for k, b in pairs(realmButtons) do
            if k == key then
                b.BackgroundColor3 = Color3.fromRGB(80,160,255)
            else
                updateRealmButton(k)
            end
        end
        local hasPlace = (key == "StarterDojo") or (TeleportClient.WorldPlaceIds[key] and TeleportClient.WorldPlaceIds[key] > 0)
        enterRealmButton.Active = hasPlace
        enterRealmButton.AutoButtonColor = hasPlace
        enterRealmButton.BackgroundColor3 = hasPlace and Color3.fromRGB(50,120,255) or Color3.fromRGB(80,80,80)
        enterRealmButton.TextColor3 = hasPlace and Color3.new(1,1,1) or Color3.fromRGB(220,220,230)
        enterRealmButton.Text = "Enter " .. (realmDisplayLookup[key] or "Realm")
    end
    self._setSelectedRealm = setSelected

    track(self, enterRealmButton:GetPropertyChangedSignal("Text"):Connect(function()
        local key = self.selectedRealm
        if not key then return end
        local desired = "Enter " .. (realmDisplayLookup[key] or key)
        if enterRealmButton.Text ~= desired then
            enterRealmButton.Text = desired
        end
    end))

    for index, info in ipairs(REALM_INFO) do
        local btn = createRealmButton(worldFrame, info, index)
        realmButtons[info.key] = btn
        track(self, btn.Activated:Connect(function()
            if not btn.Active then return end
            setSelected(info.key)
        end))
        local realmsFolder = getRealmFolder()
        if realmsFolder then
            local flag = realmsFolder:FindFirstChild(info.key)
            if flag then
                local conn = flag:GetPropertyChangedSignal("Value"):Connect(function()
                    updateRealmButton(info.key)
                end)
                self._flagConnections[#self._flagConnections + 1] = conn
            end
        end
        updateRealmButton(info.key)
    end

    enterRealmButton.Active = false
    enterRealmButton.AutoButtonColor = false

    -- If no realm has been selected yet, default to the first unlocked realm
    if not self.selectedRealm then
        local defaultRealm
        local realmsFolder = getRealmFolder()
        if realmsFolder then
            for _, info in ipairs(REALM_INFO) do
                local flag = realmsFolder:FindFirstChild(info.key)
                if flag and flag.Value then
                    defaultRealm = info.key
                    break
                end
            end
        end

        if not defaultRealm and REALM_INFO[1] then
            defaultRealm = REALM_INFO[1].key
        end

        if defaultRealm then
            setSelected(defaultRealm)
        end
    end

    local realmsFolder = getRealmFolder()
    if realmsFolder then
        track(self, realmsFolder.ChildAdded:Connect(function(child)
            local btn = realmButtons[child.Name]
            if btn then
                local conn = child:GetPropertyChangedSignal("Value"):Connect(function()
                    updateRealmButton(child.Name)
                end)
                self._flagConnections[#self._flagConnections + 1] = conn
                updateRealmButton(child.Name)
            end
        end))
    end

    if self.config and self.config.showShop then
        self:toggleShop()
    end

    currentHud = self
    return self
end

function WorldHUD:getLoadoutFrame()
    return self.loadout
end

function WorldHUD:getShopButton()
    return self.shopButton
end

function WorldHUD:getQuestInterface()
    return self.quest
end

function WorldHUD:getBackpackInterface()
    return self.backpack
end

function WorldHUD:createCosmeticsInterface()
    local hud = self
    return {
        showDojoPicker = function()
            if hud and hud.hideLoadout then
                hud:hideLoadout()
            end
        end,
        showLoadout = function(personaType)
            if hud and hud.showLoadout then
                hud:showLoadout()
            end
        end,
        updateBackpack = function(data)
            if hud and hud.setBackpackData then
                hud:setBackpackData(data)
            end
        end,
        buildCharacterPreview = function(personaType)
            if hud and hud.quest and hud.quest.buildCharacterPreview then
                hud.quest.buildCharacterPreview(personaType)
            end
        end,
    }
end

function WorldHUD:setShopButtonVisible(visible)
    if self.shopButton then
        self.shopButton.Visible = visible and true or false
    end
end

function WorldHUD:showLoadout()
    if self.loadout then
        self.loadout.Visible = true
    end
    if self.backButton then
        local showBack = self.backButtonEnabled ~= false
        self.backButton.Visible = showBack
        self.backButton.Active = showBack
    end
    self:setShopButtonVisible(true)
end

function WorldHUD:hideLoadout()
    if self.loadout then
        self.loadout.Visible = false
    end
    if self.backButton then
        self.backButton.Visible = false
        self.backButton.Active = false
    end
    self:setShopButtonVisible(false)
end

function WorldHUD:setBackButtonEnabled(enabled)
    self.backButtonEnabled = enabled and true or false
    if self.backButton then
        local showBack = self.backButtonEnabled and self.loadout and self.loadout.Visible
        self.backButton.Visible = showBack
        self.backButton.Active = showBack
    end
end

function WorldHUD:toggleShop(defaultTab)
    if not self.shop then
        warn("WorldHUD: shop instance missing")
        return
    end
    if not self.shopFrame or not self.shopFrame.Parent then
        local fakeBoot = {root = self.root}
        self.shopFrame = ShopUI.init(self.config, self.shop, fakeBoot, defaultTab)
    else
        self.shopFrame.Visible = not self.shopFrame.Visible
    end
    if self.shopFrame and self.shopFrame.Visible and defaultTab and ShopUI.setTab then
        ShopUI.setTab(defaultTab)
    end
    return self.shopFrame and self.shopFrame.Visible
end

function WorldHUD:setBackpackData(data)
    if self.backpack and self.backpack.setData then
        self.backpack:setData(data)
    end
end

function WorldHUD:updateCurrency(coins, orbs, elements)
    if self.backpack and self.backpack.updateCurrency then
        self.backpack:updateCurrency(coins, orbs, elements)
    end
end

function WorldHUD:getSelectedRealm()
    return self.selectedRealm
end

function WorldHUD:getRealmDisplayName(key)
    return self.realmDisplayLookup and self.realmDisplayLookup[key]
end

function WorldHUD:setSelectedRealm(key)
    if self._setSelectedRealm then
        self._setSelectedRealm(key)
    end
end

function WorldHUD:destroy()
    if self._destroyed then return end
    self._destroyed = true
    for _, conn in ipairs(self._connections) do
        if conn.Disconnect then conn:Disconnect() end
    end
    for _, conn in ipairs(self._flagConnections) do
        if conn.Disconnect then conn:Disconnect() end
    end
    self._connections = {}
    self._flagConnections = {}
    if self.gui then
        self.gui:Destroy()
    end
    self.gui = nil
    self.root = nil
    self.loadout = nil
    self.shopButton = nil
    self.shopFrame = nil
    self.backButton = nil
    self.enterRealmButton = nil
    self.quest = nil
    self.backpack = nil
    self.togglePanel = nil
    self.questOpenButton = nil
    self.backpackOpenButton = nil
    self.teleportOpenButton = nil
    self.teleportContainer = nil
    self.teleportCloseButton = nil
    self.backButtonEnabled = nil
    self._setSelectedRealm = nil
    if currentHud == self then
        currentHud = nil
    end
end

return WorldHUD

