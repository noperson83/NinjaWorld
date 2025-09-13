local BootUI = {}

-- =====================
-- Services & locals
-- =====================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local ContentProvider   = game:GetService("ContentProvider")
local GuiService        = game:GetService("GuiService")
local TeleportService   = game:GetService("TeleportService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local HttpService       = game:GetService("HttpService")

local player  = Players.LocalPlayer
local rf      = ReplicatedStorage.PersonaServiceRF
local cam     = Workspace.CurrentCamera
local enterRE = ReplicatedStorage:FindFirstChild("EnterDojoRE") -- created by server script

local topInsetY = GuiService:GetGuiInset().Y

local function profileRF(action, data)
    local start = os.clock()
    local result = rf:InvokeServer(action, data)
    warn(string.format("PersonaServiceRF:%s took %.3fs", tostring(action), os.clock() - start))
    return result
end

function BootUI.fetchData()
    local persona = profileRF("get", {}) or {}
    local inventory
    local invStr = player:GetAttribute("Inventory")
    if typeof(invStr) == "string" then
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, invStr)
        if ok then inventory = decoded end
    end
    return {
        inventory = inventory,
        personaData = persona,
    }
end

-- =====================
-- Module requires
-- =====================
local Cosmetics       = require(ReplicatedStorage.BootModules.Cosmetics)
local CurrencyService = require(ReplicatedStorage.BootModules.CurrencyService)
local Shop            = require(ReplicatedStorage.BootModules.Shop)
local ShopUI          = require(ReplicatedStorage.ClientModules.UI.ShopUI)
local QuestUI         = require(ReplicatedStorage.ClientModules.UI.QuestUI)
local BackpackUI      = require(ReplicatedStorage.ClientModules.UI.BackpackUI)
local TeleportClient  = require(ReplicatedStorage.ClientModules.TeleportClient)
local DojoClient      = require(ReplicatedStorage.BootModules.DojoClient)

function BootUI.unlockRealm(name)
    TeleportClient.unlockRealm(name)
end

local currencyService
local backpackUI

function BootUI.start(config)
    config = config or {}
    config.showShop = config.showShop or false
    BootUI.config = config
-- Ninja World EXP 3000
-- Boot.client.lua – v7.4
-- Changes from v7.3:
--  • Viewport: avatar now faces the camera by default (yaw = π)
--  • Emote bar across the top of Loadout to animate preview (Wave / Point / Dance / Laugh / Cheer / Sit / Idle)
--  • Minor: consistent 0.6 transparency panels, plus small cleanups

-- =====================
currencyService = CurrencyService.new(config)
local shop            = Shop.new(config, currencyService)
BootUI.currencyService = currencyService
BootUI.shop = shop

    -- connect currency updates after service is created but before backpack UI is defined
    currencyService.BalanceChanged.Event:Connect(function(coins, orbs, elements)
        if backpackUI then
            backpackUI:updateCurrency(coins, orbs, elements)
        end
    end)

-- =====================
-- Config
-- =====================
local CAM_TWEEN_TIME = 1.6

local StarterBackpack = config.inventory or config.starterBackpack or {
    capacity = 20,
    weapons = {},
    food = {},
    special = {},
    coins = 0,
    orbs = {},
}
BootUI.StarterBackpack = StarterBackpack
BootUI.personaData = config.personaData


-- =====================
-- Camera helpers (world)
-- =====================
local camerasFolder = Workspace:FindFirstChild("Cameras")
local startPos      = camerasFolder and camerasFolder:FindFirstChild("startPos")
local endPos        = camerasFolder and camerasFolder:FindFirstChild("endPos")

local function partAttr(p, name, default)
    local v = p and p:GetAttribute(name)
    return (typeof(v) == "number") and v or default
end

local function faceCF(part)
    if not part then return cam.CFrame end
    -- FRONT = LookVector
    local f =  part.CFrame.LookVector
    local u =  part.CFrame.UpVector
    local dist   = partAttr(part, "Dist",   0)  -- pull camera back from the part
    local height = partAttr(part, "Height", 0)  -- lift camera
    local ahead  = partAttr(part, "Ahead",  10) -- how far ahead to look into the room
    local pos    = part.Position - f*dist + u*height
    local target = part.Position + f*ahead
    return CFrame.lookAt(pos, target, u)
end

local function partFOV(part)
    return partAttr(part, "FOV", cam.FieldOfView)
end

local function applyStartCam()
    cam.CameraType = Enum.CameraType.Scriptable
    cam.CFrame = faceCF(startPos)
    cam.FieldOfView = partFOV(startPos)
end

local function holdStartCam(seconds)
    applyStartCam()
    local untilT = os.clock() + (seconds or 1.0)
    local key = "NW_HoldStart"
    RunService:BindToRenderStep(key, Enum.RenderPriority.Camera.Value + 1, function()
        cam = Workspace.CurrentCamera
        applyStartCam()
        if os.clock() > untilT then RunService:UnbindFromRenderStep(key) end
    end)
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        cam = Workspace.CurrentCamera
        applyStartCam()
    end)
end

local function tweenToEnd()
    if not endPos then return end
    local cf  = faceCF(endPos)
    local fov = partFOV(endPos)
    TweenService:Create(cam, TweenInfo.new(CAM_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = cf, FieldOfView = fov}):Play()
end
BootUI.tweenToEnd = tweenToEnd

-- Lighting helpers (disable DOF while UI is visible)
-- =====================
local savedDOF
local savedBlurEnabled
local function getOrCreateBlur()
    local blur = Lighting:FindFirstChild("Blur") or Lighting:FindFirstChildOfClass("BlurEffect")
    if not blur then
        blur = Instance.new("BlurEffect")
        blur.Name = "Blur"
        blur.Enabled = false
        blur.Parent = Lighting
    end
    return blur
end
local function disableUIBlur()
    if savedDOF or savedBlurEnabled ~= nil then return end
    savedDOF = {}
    for _,e in ipairs(Lighting:GetChildren()) do
        if e:IsA("DepthOfFieldEffect") then
            savedDOF[e] = e.Enabled
            e.Enabled = false
        end
    end
    local blur = getOrCreateBlur()
    if blur then
        savedBlurEnabled = blur.Enabled
        blur.Enabled = false
    end
end
local function restoreUIBlur()
    if savedDOF then
        for e,was in pairs(savedDOF) do
            if e and e.Parent then e.Enabled = was end
        end
        savedDOF = nil
    end
    if savedBlurEnabled ~= nil then
        local blur = getOrCreateBlur()
        if blur then blur.Enabled = savedBlurEnabled end
        savedBlurEnabled = nil
    end
end

-- =====================
-- UI root
-- =====================
local gui = Instance.new("ScreenGui"); local ui = gui
ui.ResetOnSpawn   = false
ui.Name           = "IntroGui"
ui.IgnoreGuiInset = true
ui.DisplayOrder   = 100
ui.Parent         = player.PlayerGui

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1,1)
root.BackgroundTransparency = 1
root.Parent = ui

BootUI.root = root
Cosmetics.init(config, root, BootUI)
local function toggleShop(defaultTab)
    if not BootUI.shopFrame then
        BootUI.shopFrame = ShopUI.init(config, shop, BootUI, defaultTab)
    else
        BootUI.shopFrame.Visible = not BootUI.shopFrame.Visible
    end
    if BootUI.shopFrame and BootUI.shopFrame.Visible and defaultTab then
        if ShopUI.setTab then
            ShopUI.setTab(defaultTab)
        end
    end
end
BootUI.toggleShop = toggleShop
if config.showShop then
    toggleShop()
end
local shopBtn = Instance.new("TextButton")
shopBtn.Size = UDim2.fromScale(0.1,0.06)
shopBtn.AnchorPoint = Vector2.new(1,1)
shopBtn.Position = UDim2.fromScale(0.98,0.98)
shopBtn.Text = "Shop"
shopBtn.Font = Enum.Font.GothamSemibold
shopBtn.TextScaled = true
shopBtn.TextColor3 = Color3.new(1,1,1)
shopBtn.BackgroundColor3 = Color3.fromRGB(50,120,255)
shopBtn.AutoButtonColor = true
shopBtn.ZIndex = 10
shopBtn.Parent = root
shopBtn.Visible = false
BootUI.shopBtn = shopBtn
shopBtn.Activated:Connect(function()
    toggleShop()
end)

    -- teleport UI placeholders
    local teleFrame = Instance.new("Frame")
    teleFrame.Name = "TeleFrame"
    teleFrame.Size = UDim2.fromScale(1,1)
    teleFrame.BackgroundTransparency = 1
    teleFrame.Visible = false
    teleFrame.Parent = root

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
    worldFrame.Parent = root

    local enterRealmButton = Instance.new("TextButton")
    enterRealmButton.Name = "EnterRealmButton"
    enterRealmButton.Size = UDim2.new(0,0,0,0)
    enterRealmButton.Visible = false
    enterRealmButton.Text = "Enter"
    enterRealmButton.Parent = worldFrame

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

-- Intro visuals
local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1,1)
fade.BackgroundColor3 = Color3.new(0,0,0)
fade.BackgroundTransparency = 1
fade.ZIndex = 50
fade.Parent = root

-- =====================
-- Loadout (viewport + backpack + emotes)
-- =====================
local loadout = Instance.new("Frame")
loadout.Size = UDim2.fromScale(1,1)
loadout.BackgroundTransparency = 1
loadout.Visible = false
loadout.ZIndex = 20
loadout.Parent = root
BootUI.loadout = loadout

local baseY = topInsetY + 20

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

local quest = QuestUI.init(loadout, baseY)
BootUI.buildCharacterPreview = quest.buildCharacterPreview
backpackUI = BackpackUI.init(loadout, baseY)

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

local btnBack       = makeAction("Back", false)
local btnEnterRealm = makeAction("Enter Realm", true)

-- scrolling list of realm buttons between Back and Enter
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
realmLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    realmScroll.CanvasSize = UDim2.new(0, realmLayout.AbsoluteContentSize.X, 0, 0)
end)

local realmButtons = {}
local selectedRealm = nil
local realmInfo = {
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

local realmDisplayLookup = {}
for _,info in ipairs(realmInfo) do realmDisplayLookup[info.key] = info.name end

local realmsFolder = player:FindFirstChild("Realms")

local function updateRealmButton(key)
    local btn = realmButtons[key]
    if not btn then return end
    local unlocked = false
    if realmsFolder then
        local flag = realmsFolder:FindFirstChild(key)
        unlocked = flag and flag.Value
    end
    btn.Active = unlocked
    btn.AutoButtonColor = unlocked
    btn.BackgroundColor3 = unlocked and Color3.fromRGB(50,120,255) or Color3.fromRGB(80,80,80)
    btn.TextColor3 = unlocked and Color3.new(1,1,1) or Color3.fromRGB(170,170,170)
end

local function setSelected(key)
    selectedRealm = key
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

for _, info in ipairs(realmInfo) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,160,1,0)
    btn.Text = info.name
    btn.Font = Enum.Font.Gotham
    btn.TextScaled = true
    btn.BackgroundColor3 = Color3.fromRGB(80,80,80)
    btn.TextColor3 = Color3.fromRGB(170,170,170)
    btn.AutoButtonColor = false
    btn.Parent = realmScroll
    realmButtons[info.key] = btn
    btn.Activated:Connect(function()
        if not btn.Active then return end
        setSelected(info.key)
    end)
    if realmsFolder then
        local flag = realmsFolder:FindFirstChild(info.key)
        if flag then
            flag:GetPropertyChangedSignal("Value"):Connect(function()
                updateRealmButton(info.key)
            end)
        end
    end
    updateRealmButton(info.key)
end

btnEnterRealm.Active = false
btnEnterRealm.AutoButtonColor = false

if realmsFolder then
    realmsFolder.ChildAdded:Connect(function(child)
        local btn = realmButtons[child.Name]
        if btn then
            child:GetPropertyChangedSignal("Value"):Connect(function()
                updateRealmButton(child.Name)
            end)
            updateRealmButton(child.Name)
        end
    end)
end

-- =====================
-- Helpers (UI logic)
-- =====================
local function clearChildren(p)
    for _, c in ipairs(p:GetChildren()) do
        if not c:IsA("UIListLayout") then
            c:Destroy()
        end
    end
end

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

function BootUI.populateBackpackUI(bp)
    if backpackUI then
        backpackUI:setData(bp)
    end
end
-- =====================
btnBack.MouseButton1Click:Connect(function()
    -- Return to picker; snap camera back to start
    applyStartCam()
    Cosmetics.showDojoPicker()
end)

btnEnterRealm.MouseButton1Click:Connect(function()
    if not selectedRealm then return end
    local realmName = selectedRealm
    local displayName = realmDisplayLookup[selectedRealm]
    DojoClient.start(displayName)
    if realmName == "StarterDojo" then
        TweenService:Create(fade, TweenInfo.new(0.25), {BackgroundTransparency = 0}):Play()
        task.wait(0.28)

        local personaType, chosenSlot = Cosmetics.getSelectedPersona()
        if enterRE then
            enterRE:FireServer({ type = personaType, slot = chosenSlot })
        else
            warn("EnterDojoRE missing on server")
        end

        -- wait for character and hand camera back to gameplay
        task.wait(0.2)
        local char = player.Character or player.CharacterAdded:Wait()
        local hum = char:FindFirstChildOfClass("Humanoid")
        cam.CameraType = Enum.CameraType.Custom
        if hum then cam.CameraSubject = hum end

        DojoClient.hide()
        restoreUIBlur()
        TweenService:Create(fade, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
        task.delay(0.4, function()
            if ui and ui.Parent then ui:Destroy() end
            BootUI.destroy()
        end)
    else
        local placeId = TeleportClient.WorldPlaceIds[realmName]
        if not (placeId and placeId > 0) then
            warn("No place id for realm: " .. tostring(realmName))
            DojoClient.hide()
            return
        end
        TweenService:Create(fade, TweenInfo.new(0.25), {BackgroundTransparency = 0}):Play()
        task.wait(0.28)
        local _, chosenSlot = Cosmetics.getSelectedPersona()
        DojoClient.hide()
        local ok, err = pcall(function()
            TeleportService:Teleport(placeId, player, {slot = chosenSlot})
        end)
        if not ok then warn("Teleport failed:", err) end
        BootUI.destroy()
    end
end)

-- Hook emote buttons once (after UI exists)
-- =====================
-- FLOW
-- =====================
cam.CameraType = Enum.CameraType.Scriptable
holdStartCam(1.0)
disableUIBlur()

Cosmetics.showDojoPicker()
-- We do NOT tween to end here anymore; only after "Use".
Cosmetics.refreshSlots(config.personaData)


end

function BootUI.destroy()
    if BootUI.loadout then
        BootUI.loadout:Destroy()
        BootUI.loadout = nil
    end
    BootUI.buildCharacterPreview = nil
    BootUI.currencyService = nil
    BootUI.shop = nil
    backpackUI = nil
end

return BootUI
