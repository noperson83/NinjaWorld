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
    if not conn then return end
    table.insert(self._connections, conn)
end

local function createRealmButton(parent, info)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,160,1,0)
    btn.Text = info.name
    btn.Font = Enum.Font.Gotham
    btn.TextScaled = true
    btn.BackgroundColor3 = Color3.fromRGB(80,80,80)
    btn.TextColor3 = Color3.fromRGB(170,170,170)
    btn.AutoButtonColor = false
    btn.Parent = parent
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

    -- Shop button and toggle logic
    local shopButton = Instance.new("TextButton")
    shopButton.Name = "ShopButton"
    shopButton.Size = UDim2.fromScale(0.1,0.06)
    shopButton.AnchorPoint = Vector2.new(1,1)
    shopButton.Position = UDim2.fromScale(0.98,0.98)
    shopButton.Text = "Shop"
    shopButton.Font = Enum.Font.GothamSemibold
    shopButton.TextScaled = true
    shopButton.TextColor3 = Color3.new(1,1,1)
    shopButton.BackgroundColor3 = Color3.fromRGB(50,120,255)
    shopButton.AutoButtonColor = true
    shopButton.ZIndex = 10
    shopButton.Visible = false
    shopButton.Parent = root
    self.shopButton = shopButton

    track(self, shopButton.Activated:Connect(function()
        self:toggleShop()
    end))

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

    -- Teleport UI placeholders
    local teleportContainer = Instance.new("Frame")
    teleportContainer.Name = "TeleportContainer"
    teleportContainer.Size = UDim2.fromScale(1,1)
    teleportContainer.BackgroundTransparency = 1
    teleportContainer.Visible = false
    teleportContainer.ZIndex = 25
    teleportContainer.Parent = loadout

    local teleFrame = Instance.new("Frame")
    teleFrame.Name = "TeleFrame"
    teleFrame.Size = UDim2.fromScale(1,1)
    teleFrame.BackgroundTransparency = 1
    teleFrame.Visible = false
    teleFrame.Parent = teleportContainer

    local zoneButtons = {"Atom","Fire","Grow","Ice","Light","Metal","Water","Wind","Dojo","Starter"}
    for _, zone in ipairs(zoneButtons) do
        local button = Instance.new("TextButton")
        button.Name = zone .. "Button"
        button.Size = UDim2.new(0,0,0,0)
        button.Visible = false
        button.Text = zone
        button.Parent = teleFrame
    end

    local worldFrame = Instance.new("Frame")
    worldFrame.Name = "WorldTeleFrame"
    worldFrame.Size = UDim2.fromScale(1,1)
    worldFrame.BackgroundTransparency = 1
    worldFrame.Visible = false
    worldFrame.Parent = teleportContainer

    local enterRealmButton = Instance.new("TextButton")
    enterRealmButton.Name = "EnterRealmButton"
    enterRealmButton.Size = UDim2.new(0,0,0,0)
    enterRealmButton.Visible = false
    enterRealmButton.Text = "Enter"
    enterRealmButton.Parent = worldFrame
    self.enterRealmButton = enterRealmButton

    for realmName, _ in pairs(TeleportClient.worldSpawnIds) do
        local button = Instance.new("TextButton")
        button.Name = realmName .. "Button"
        button.Size = UDim2.new(0,0,0,0)
        button.Visible = false
        button.Text = realmName
        button.Parent = worldFrame
    end

    TeleportClient.bindZoneButtons(root)
    TeleportClient.bindWorldButtons(root)

    local teleportCloseButton = Instance.new("TextButton")
    teleportCloseButton.Name = "TeleportCloseButton"
    teleportCloseButton.Size = UDim2.new(0,32,0,32)
    teleportCloseButton.AnchorPoint = Vector2.new(1,0)
    teleportCloseButton.Position = UDim2.new(1,-20,0, baseY + 20)
    teleportCloseButton.BackgroundColor3 = Color3.fromRGB(120,40,40)
    teleportCloseButton.TextColor3 = Color3.new(1,1,1)
    teleportCloseButton.Text = "X"
    teleportCloseButton.Font = Enum.Font.GothamBold
    teleportCloseButton.TextScaled = true
    teleportCloseButton.AutoButtonColor = true
    teleportCloseButton.Visible = false
    teleportCloseButton.ZIndex = 30
    teleportCloseButton.Parent = teleportContainer
    self.teleportContainer = teleportContainer
    self.teleportCloseButton = teleportCloseButton

    local quest = QuestUI.init(loadout, baseY)
    self.quest = quest

    local backpack = NinjaPouchUI.init(loadout, baseY)
    self.backpack = backpack

    local togglePanel = Instance.new("Frame")
    togglePanel.Name = "PanelToggleButtons"
    togglePanel.Size = UDim2.new(0,180,0,120)
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
    self.questOpenButton = questOpenButton
    self.backpackOpenButton = backpackOpenButton
    self.teleportOpenButton = teleOpenButton

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

    track(self, teleportCloseButton.MouseButton1Click:Connect(function()
        setTeleportsVisible(false)
    end))

    track(self, teleOpenButton.MouseButton1Click:Connect(function()
        setTeleportsVisible(true)
    end))

    setTeleportsVisible(false)

    local btnRow = Instance.new("Frame")
    btnRow.Size = UDim2.new(1,-40,0,60)
    btnRow.Position = UDim2.new(0,20,1,-80)
    btnRow.BackgroundTransparency = 1
    btnRow.Parent = loadout

    local function makeAction(text, rightAlign)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0,240,1,0)
        b.Position = rightAlign and UDim2.new(1,-250,0,0) or UDim2.fromOffset(0,0)
        b.AnchorPoint = rightAlign and Vector2.new(1,0) or Vector2.new(0,0)
        b.Text = text
        b.Font = Enum.Font.GothamSemibold
        b.TextScaled = true
        b.TextColor3 = Color3.new(1,1,1)
        b.BackgroundColor3 = Color3.fromRGB(50,120,255)
        b.AutoButtonColor = true
        b.Parent = btnRow
        return b
    end

    local btnBack = makeAction("Back", false)
    local btnEnterRealm = makeAction("Enter Realm", true)
    self.backButton = btnBack
    self.enterRealmButton = btnEnterRealm

    local realmScroll = Instance.new("ScrollingFrame")
    realmScroll.Size = UDim2.new(1,-500,1,0)
    realmScroll.Position = UDim2.fromOffset(250,-100)
    realmScroll.BackgroundTransparency = 1
    realmScroll.ScrollBarThickness = 6
    realmScroll.CanvasSize = UDim2.new()
    realmScroll.Parent = btnRow
    local realmLayout = Instance.new("UIListLayout", realmScroll)
    realmLayout.FillDirection = Enum.FillDirection.Horizontal
    realmLayout.Padding = UDim.new(0,6)
    track(self, realmLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        realmScroll.CanvasSize = UDim2.new(0, realmLayout.AbsoluteContentSize.X, 0, 0)
    end))

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
        btn.BackgroundColor3 = unlocked and Color3.fromRGB(50,120,255) or Color3.fromRGB(80,80,80)
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
        btnEnterRealm.Active = hasPlace
        btnEnterRealm.AutoButtonColor = hasPlace
        btnEnterRealm.BackgroundColor3 = hasPlace and Color3.fromRGB(50,120,255) or Color3.fromRGB(80,80,80)
        btnEnterRealm.Text = "Enter " .. (realmDisplayLookup[key] or "Realm")
    end
    self._setSelectedRealm = setSelected

    for _, info in ipairs(REALM_INFO) do
        local btn = createRealmButton(realmScroll, info)
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

    btnEnterRealm.Active = false
    btnEnterRealm.AutoButtonColor = false

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

