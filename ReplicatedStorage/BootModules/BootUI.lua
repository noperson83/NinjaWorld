local BootUI = {}

-- =====================
-- Services & locals
-- =====================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local TeleportService   = game:GetService("TeleportService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local HttpService       = game:GetService("HttpService")

local player  = Players.LocalPlayer
local rf      = ReplicatedStorage.PersonaServiceRF
local cam     = Workspace.CurrentCamera
local enterRE = ReplicatedStorage:FindFirstChild("EnterDojoRE") -- created by server script

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
local WorldHUD        = require(ReplicatedStorage.ClientModules.UI.WorldHUD)
local TeleportClient  = require(ReplicatedStorage.ClientModules.TeleportClient)
local DojoClient      = require(ReplicatedStorage.BootModules.DojoClient)

function BootUI.unlockRealm(name)
    TeleportClient.unlockRealm(name)
end

function BootUI.getHUD()
    return BootUI.hud
end

function BootUI.showLoadout()
    local hud = BootUI.hud
    if hud and hud.showLoadout then
        hud:showLoadout()
    elseif BootUI.loadout then
        BootUI.loadout.Visible = true
    end
end

function BootUI.hideLoadout()
    local hud = BootUI.hud
    if hud and hud.hideLoadout then
        hud:hideLoadout()
    elseif BootUI.loadout then
        BootUI.loadout.Visible = false
    end
end

function BootUI.setShopButtonVisible(visible)
    local hud = BootUI.hud
    if hud and hud.setShopButtonVisible then
        hud:setShopButtonVisible(visible)
    elseif BootUI.shopBtn then
        BootUI.shopBtn.Visible = visible and true or false
    end
end

function BootUI.toggleShop(defaultTab)
    local hud = BootUI.hud
    if hud and hud.toggleShop then
        local visible = hud:toggleShop(defaultTab)
        BootUI.shopFrame = hud.shopFrame
        return visible
    end
end

function BootUI.populateBackpackUI(data)
    local hud = BootUI.hud
    if hud and hud.setBackpackData then
        hud:setBackpackData(data)
    end
end

function BootUI.getSelectedRealm()
    local hud = BootUI.hud
    if hud and hud.getSelectedRealm then
        return hud:getSelectedRealm()
    end
end

function BootUI.getRealmDisplayName(realmKey)
    local hud = BootUI.hud
    if hud and hud.getRealmDisplayName then
        return hud:getRealmDisplayName(realmKey)
    end
end

function BootUI.destroyHUD()
    local hud = BootUI.hud
    if hud and hud.destroy then
        hud:destroy()
    end
    BootUI.hud = nil
end

function BootUI.hideOverlay()
    if BootUI.introGui then
        BootUI.introGui.Enabled = false
    end
end

function BootUI.destroy()
    BootUI.hideOverlay()
end

local currencyService

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

local hud = WorldHUD.new(config, {currencyService = currencyService, shop = shop})
BootUI.hud = hud
BootUI.loadout = hud and hud:getLoadoutFrame() or nil
BootUI.shopBtn = hud and hud:getShopButton() or nil
BootUI.shopFrame = hud and hud.shopFrame or nil

local questInterface = hud and hud:getQuestInterface() or nil
BootUI.questInterface = questInterface
BootUI.buildCharacterPreview = questInterface and questInterface.buildCharacterPreview or nil

    -- connect currency updates after service is created so backpack UI stays in sync
    currencyService.BalanceChanged.Event:Connect(function(coins, orbs, elements)
        local currentHud = BootUI.hud
        if currentHud then
            currentHud:updateCurrency(coins, orbs, elements)
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
BootUI.introGui   = ui

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1,1)
root.BackgroundTransparency = 1
root.Parent = ui

BootUI.root = root
Cosmetics.init(config, root, BootUI)

-- Intro visuals
local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1,1)
fade.BackgroundColor3 = Color3.new(0,0,0)
fade.BackgroundTransparency = 1
fade.ZIndex = 50
fade.Parent = root

local backButton = hud and hud.backButton
if backButton then
    backButton.MouseButton1Click:Connect(function()
        applyStartCam()
        Cosmetics.showDojoPicker()
    end)
end

local enterRealmButton = hud and hud.enterRealmButton
if enterRealmButton then
    enterRealmButton.MouseButton1Click:Connect(function()
        local realmName = BootUI.getSelectedRealm()
        if not realmName then return end
        local displayName = BootUI.getRealmDisplayName(realmName) or realmName
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

            task.wait(0.2)
            local char = player.Character or player.CharacterAdded:Wait()
            local hum = char:FindFirstChildOfClass("Humanoid")
            cam.CameraType = Enum.CameraType.Custom
            if hum then cam.CameraSubject = hum end

            DojoClient.hide()
            restoreUIBlur()
            TweenService:Create(fade, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
            task.delay(0.4, function()
                BootUI.hideOverlay()
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
            BootUI.hideOverlay()
        end
end)
end
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

return BootUI
