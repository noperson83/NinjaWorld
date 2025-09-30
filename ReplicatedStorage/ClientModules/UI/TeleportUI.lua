local Players = game:GetService("Players")
local TeleportClient = require(game:GetService("ReplicatedStorage").ClientModules.TeleportClient)

local TeleportUI = {}
TeleportUI.__index = TeleportUI

local player = Players.LocalPlayer

local BASE_Z_INDEX = 25

TeleportUI.ZONE_INFO = {
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

local DEFAULT_REALM_INFO = {
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
        btn.Font = Enum.Font.GothamMedium
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

local function defaultGetRealmFolder()
        local realmsFolder = player:FindFirstChild("Realms")
        if not realmsFolder then
                local stats = player:FindFirstChild("Stats")
                if stats then
                        realmsFolder = stats:FindFirstChild("Realms")
                end
        end
        return realmsFolder
end

local function track(self, conn)
        if not conn then return nil end
        table.insert(self._connections, conn)
        return conn
end

local function styleNinjaCloseButton(button)
        if not button then
                return
        end

        button.Text = "X"
        button.Font = Enum.Font.GothamBold
        button.TextScaled = true
        button.TextColor3 = Color3.fromRGB(255, 245, 245)
        button.TextStrokeTransparency = 0.6
        button.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
        button.BackgroundTransparency = 0.05
        button.AutoButtonColor = true
        button.BorderSizePixel = 0

        for _, child in ipairs(button:GetChildren()) do
                if child:IsA("UICorner") or child:IsA("UIStroke") then
                        child:Destroy()
                end
        end

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = button

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(220, 70, 70)
        stroke.Thickness = 2
        stroke.Transparency = 0.1
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = button
end

function TeleportUI:setVisible(visible)
        if self._destroyed then return end
        if self.root then
                self.root.Visible = visible and true or false
        end
        if self.closeButton then
                self.closeButton.Visible = visible and true or false
        end
end

function TeleportUI:isVisible()
        if self.root then
                return self.root.Visible
        end
        return false
end

function TeleportUI:getSelectedRealm()
        return self.selectedRealm
end

function TeleportUI:setSelectedRealm(key)
        if self._setSelectedRealm then
                self._setSelectedRealm(key)
        end
end

function TeleportUI:destroy()
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
        if self.root then
                self.root:Destroy()
        end
        self.root = nil
        self.closeButton = nil
        self.enterRealmButton = nil
        self.realmButtons = nil
        self.realmDisplayLookup = nil
        self._setSelectedRealm = nil
end

function TeleportUI.init(parent, baseY, dependencies)
        dependencies = dependencies or {}

        local self = setmetatable({}, TeleportUI)
        self._connections = {}
        self._flagConnections = {}
        self._destroyed = false
        self.selectedRealm = nil
        self.realmInfo = dependencies.REALM_INFO or DEFAULT_REALM_INFO
        self.getRealmFolder = dependencies.getRealmFolder or defaultGetRealmFolder
        self.onTeleport = dependencies.onTeleport

        local teleportContainer = Instance.new("Frame")
        teleportContainer.Name = "TeleportContainer"
        teleportContainer.Size = UDim2.new(0.65, -20, 0.65, 0)
        teleportContainer.AnchorPoint = Vector2.new(0.5, 0)
        teleportContainer.Position = UDim2.new(0.5, 0, 0, baseY + 80)
        teleportContainer.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
        teleportContainer.BackgroundTransparency = 0.05
        teleportContainer.BorderSizePixel = 0
        teleportContainer.Visible = false
        teleportContainer.ZIndex = BASE_Z_INDEX
        teleportContainer.Parent = parent

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
        teleportTitle.ZIndex = BASE_Z_INDEX + 1
        teleportTitle.Parent = teleportContainer

        local teleportCloseButton = Instance.new("TextButton")
        teleportCloseButton.Name = "TeleportCloseButton"
        teleportCloseButton.Size = UDim2.new(0, 32, 0, 32)
        teleportCloseButton.AnchorPoint = Vector2.new(1, 0)
        teleportCloseButton.Position = UDim2.new(1, -20, 0, 16)
        teleportCloseButton.Visible = false
        teleportCloseButton.ZIndex = BASE_Z_INDEX + 5
        teleportCloseButton.Parent = teleportContainer
        styleNinjaCloseButton(teleportCloseButton)

        local teleportContent = Instance.new("Frame")
        teleportContent.Name = "TeleportContent"
        teleportContent.Size = UDim2.new(1, -32, 1, -84)
        teleportContent.Position = UDim2.new(0, 16, 0, 60)
        teleportContent.BackgroundTransparency = 1
        teleportContent.ZIndex = BASE_Z_INDEX + 1
        teleportContent.Parent = teleportContainer

        local localColumn = Instance.new("Frame")
        localColumn.Name = "LocalTeleports"
        localColumn.Size = UDim2.new(0.48, 0, 1, 0)
        localColumn.BackgroundTransparency = 1
        localColumn.ZIndex = BASE_Z_INDEX + 2
        localColumn.Parent = teleportContent

        local worldColumn = Instance.new("Frame")
        worldColumn.Name = "WorldTeleports"
        worldColumn.Size = UDim2.new(0.48, 0, 1, 0)
        worldColumn.Position = UDim2.new(0.52, 0, 0, 0)
        worldColumn.BackgroundTransparency = 1
        worldColumn.ZIndex = BASE_Z_INDEX + 2
        worldColumn.Parent = teleportContent

        local localTitle = Instance.new("TextLabel")
        localTitle.Size = UDim2.new(1, 0, 0, 28)
        localTitle.BackgroundTransparency = 1
        localTitle.Text = "Locations"
        localTitle.TextXAlignment = Enum.TextXAlignment.Left
        localTitle.Font = Enum.Font.GothamMedium
        localTitle.TextScaled = true
        localTitle.TextColor3 = Color3.fromRGB(200, 200, 220)
        localTitle.ZIndex = BASE_Z_INDEX + 3
        localTitle.Parent = localColumn

        local teleFrame = Instance.new("Frame")
        teleFrame.Name = "TeleFrame"
        teleFrame.Size = UDim2.new(1, 0, 1, -36)
        teleFrame.Position = UDim2.new(0, 0, 0, 36)
        teleFrame.BackgroundColor3 = Color3.fromRGB(24, 26, 28)
        teleFrame.BackgroundTransparency = 0.4
        teleFrame.BorderSizePixel = 0
        teleFrame.ZIndex = BASE_Z_INDEX + 3
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

        for index, info in ipairs(TeleportUI.ZONE_INFO) do
                local button = Instance.new("TextButton")
                button.Name = info.name .. "Button"
                button.Size = UDim2.new(0, 0, 0, 0)
                button.LayoutOrder = index
                button.BackgroundColor3 = Color3.fromRGB(50, 120, 255)
                button.BackgroundTransparency = 0.2
                button.TextColor3 = Color3.new(1, 1, 1)
                button.Font = Enum.Font.GothamMedium
                button.TextScaled = true
                button.AutoButtonColor = true
                button.Text = info.label
                button.ZIndex = BASE_Z_INDEX + 4
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
        worldTitle.Font = Enum.Font.GothamMedium
        worldTitle.TextScaled = true
        worldTitle.TextColor3 = Color3.fromRGB(200, 200, 220)
        worldTitle.ZIndex = BASE_Z_INDEX + 3
        worldTitle.Parent = worldColumn

        local worldFrame = Instance.new("ScrollingFrame")
        worldFrame.Name = "WorldTeleFrame"
        worldFrame.Size = UDim2.new(1, 0, 1, -92)
        worldFrame.Position = UDim2.new(0, 0, 0, 36)
        worldFrame.BackgroundColor3 = Color3.fromRGB(24, 26, 28)
        worldFrame.BackgroundTransparency = 0.4
        worldFrame.BorderSizePixel = 0
        worldFrame.ScrollBarThickness = 6
        worldFrame.ScrollingDirection = Enum.ScrollingDirection.Y
        worldFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        worldFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        worldFrame.ZIndex = BASE_Z_INDEX + 3
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

        local enterButtonHolder = Instance.new("Frame")
        enterButtonHolder.Name = "EnterRealmButtonHolder"
        enterButtonHolder.Size = UDim2.new(1, 0, 0, 56)
        enterButtonHolder.AnchorPoint = Vector2.new(0, 1)
        enterButtonHolder.Position = UDim2.new(0, 0, 1, 0)
        enterButtonHolder.BackgroundTransparency = 1
        enterButtonHolder.ZIndex = BASE_Z_INDEX + 3
        enterButtonHolder.Parent = worldColumn

        local enterButtonPadding = Instance.new("UIPadding")
        enterButtonPadding.PaddingTop = UDim.new(0, 8)
        enterButtonPadding.PaddingBottom = UDim.new(0, 8)
        enterButtonPadding.PaddingLeft = UDim.new(0, 8)
        enterButtonPadding.PaddingRight = UDim.new(0, 8)
        enterButtonPadding.Parent = enterButtonHolder

        local enterRealmButton = Instance.new("TextButton")
        enterRealmButton.Name = "EnterRealmButton"
        enterRealmButton.Size = UDim2.new(1, 0, 1, 0)
        enterRealmButton.LayoutOrder = 1000
        enterRealmButton.Text = "Select a realm"
        enterRealmButton.Font = Enum.Font.GothamBold
        enterRealmButton.TextScaled = true
        enterRealmButton.TextColor3 = Color3.fromRGB(220, 220, 230)
        enterRealmButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        enterRealmButton.AutoButtonColor = false
        enterRealmButton.Active = false
        enterRealmButton.ZIndex = BASE_Z_INDEX + 4
        enterRealmButton.Parent = enterButtonHolder

        local enterCorner = Instance.new("UICorner")
        enterCorner.CornerRadius = UDim.new(0, 8)
        enterCorner.Parent = enterRealmButton

        self.root = teleportContainer
        self.closeButton = teleportCloseButton
        self.enterRealmButton = enterRealmButton

        self.realmButtons = {}
        self.realmDisplayLookup = {}
        for _, info in ipairs(self.realmInfo) do
                self.realmDisplayLookup[info.key] = info.name
        end

        local function isRealmUnlocked(key)
                local realmsFolder = self.getRealmFolder()
                if not realmsFolder then return false end
                local flag = realmsFolder:FindFirstChild(key)
                return flag and flag.Value or false
        end

        local function updateRealmButton(key)
                local btn = self.realmButtons[key]
                if not btn then return end
                local unlocked = isRealmUnlocked(key)
                btn.Active = unlocked
                btn.AutoButtonColor = unlocked
                btn.BackgroundColor3 = unlocked and Color3.fromRGB(50,120,255) or Color3.fromRGB(40,40,48)
                btn.TextColor3 = unlocked and Color3.new(1,1,1) or Color3.fromRGB(170,170,170)
        end

        local function setSelected(key)
                self.selectedRealm = key
                for k, b in pairs(self.realmButtons) do
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
                enterRealmButton.Text = "Enter " .. (self.realmDisplayLookup[key] or "Realm")
        end
        self._setSelectedRealm = setSelected

        track(self, enterRealmButton:GetPropertyChangedSignal("Text"):Connect(function()
                local key = self.selectedRealm
                if not key then return end
                local desired = "Enter " .. (self.realmDisplayLookup[key] or key)
                if enterRealmButton.Text ~= desired then
                        enterRealmButton.Text = desired
                end
        end))

        for index, info in ipairs(self.realmInfo) do
                local btn = createRealmButton(worldFrame, info, index)
                btn.ZIndex = BASE_Z_INDEX + 4
                self.realmButtons[info.key] = btn
                track(self, btn.Activated:Connect(function()
                        if not btn.Active then return end
                        setSelected(info.key)
                end))
                local realmsFolder = self.getRealmFolder()
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

        if not self.selectedRealm then
                local defaultRealm
                local realmsFolder = self.getRealmFolder()
                if realmsFolder then
                        for _, info in ipairs(self.realmInfo) do
                                local flag = realmsFolder:FindFirstChild(info.key)
                                if flag and flag.Value then
                                        defaultRealm = info.key
                                        break
                                end
                        end
                end
                if not defaultRealm and self.realmInfo[1] then
                        defaultRealm = self.realmInfo[1].key
                end
                if defaultRealm then
                        setSelected(defaultRealm)
                end
        end

        local realmsFolder = self.getRealmFolder()
        if realmsFolder then
                        track(self, realmsFolder.ChildAdded:Connect(function(child)
                                local btn = self.realmButtons[child.Name]
                                if btn then
                                        local conn = child:GetPropertyChangedSignal("Value"):Connect(function()
                                                updateRealmButton(child.Name)
                                        end)
                                        self._flagConnections[#self._flagConnections + 1] = conn
                                        updateRealmButton(child.Name)
                                end
                        end))
        end

        track(self, teleportCloseButton.MouseButton1Click:Connect(function()
                self:setVisible(false)
        end))

        local teleportCallbacks
        if self.onTeleport then
                teleportCallbacks = {onTeleport = self.onTeleport}
        end

        TeleportClient.bindZoneButtons(teleportContainer, teleportCallbacks)
        TeleportClient.bindWorldButtons(teleportContainer, teleportCallbacks)

        return self
end

return TeleportUI
