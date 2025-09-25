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
local rf      = nil
local cam     = Workspace.CurrentCamera
local enterRE = ReplicatedStorage:FindFirstChild("EnterDojoRE") -- created by server script

local debugLines = {}
local debugOrder = {}
local debugLabel

local function rebuildDebugText()
    if not debugLabel then
        return
    end

    local lines = {}
    for _, key in ipairs(debugOrder) do
        local value = debugLines[key]
        if value and value ~= "" then
            table.insert(lines, value)
        end
    end

    if #lines == 0 then
        debugLabel.Text = "Debug Checks\n(no entries)"
    else
        debugLabel.Text = "Debug Checks\n" .. table.concat(lines, "\n")
    end
end

local function setDebugLine(key, text)
    if text and text ~= "" then
        if not debugLines[key] then
            table.insert(debugOrder, key)
        end
        debugLines[key] = text
    else
        if debugLines[key] then
            debugLines[key] = nil
            for index, existing in ipairs(debugOrder) do
                if existing == key then
                    table.remove(debugOrder, index)
                    break
                end
            end
        end
    end

    rebuildDebugText()
end

BootUI.setDebugLine = setDebugLine

local function getPlayerGui()
    if not player then
        player = Players.LocalPlayer
    end
    if not player then
        return nil
    end

    local gui = player:FindFirstChildOfClass("PlayerGui")
    if gui then
        return gui
    end

    local ok, result = pcall(function()
        return player:WaitForChild("PlayerGui", 5)
    end)
    if ok and result then
        return result
    end

    return nil
end

local GameSettings = require(ReplicatedStorage.GameSettings)
local DEFAULT_SLOT_COUNT = tonumber(GameSettings.maxSlots) or 3

local function getPersonaRemote()
    if rf and rf.Parent then
        return rf
    end
    rf = ReplicatedStorage:FindFirstChild("PersonaServiceRF")
    if not rf then
        rf = ReplicatedStorage:WaitForChild("PersonaServiceRF", 5)
    end
    if not rf then
        warn("BootUI: PersonaServiceRF missing")
    end
    return rf
end

local function sanitizePersonaData(data)
    local result = {}

    if typeof(data) == "table" then
        for key, value in pairs(data) do
            if key ~= "slots" then
                result[key] = value
            end
        end
        if typeof(data.slots) == "table" then
            result.slots = data.slots
        end
    end

    if typeof(result.slots) ~= "table" then
        result.slots = {}
    end

    local slotCount = tonumber(result.slotCount)
    if not slotCount then
        local highest = 0
        for key in pairs(result.slots) do
            local idx = tonumber(key)
            if idx and idx > highest then
                highest = idx
            end
        end
        slotCount = highest
    end

    if not slotCount or slotCount < 0 then
        slotCount = 0
    end
    if slotCount == 0 and DEFAULT_SLOT_COUNT > 0 then
        slotCount = DEFAULT_SLOT_COUNT
    end

    result.slotCount = slotCount

    return result
end

local function profileRF(action, data)
    local remote = getPersonaRemote()
    if remote then
        setDebugLine("personaRemote", "Persona remote ready")
    else
        setDebugLine("personaRemote", "Persona remote missing")
    end
    if not remote then
        warn("PersonaServiceRF unavailable for action", action)
        setDebugLine("status", "Persona remote missing")
        return nil
    end
    local start = os.clock()
    local ok, result = pcall(remote.InvokeServer, remote, action, data)
    if not ok then
        warn(string.format("PersonaServiceRF:%s failed: %s", tostring(action), tostring(result)))
        return nil
    end
    warn(string.format("PersonaServiceRF:%s took %.3fs", tostring(action), os.clock() - start))
    return result
end

function BootUI.fetchData()
    setDebugLine("status", "Fetching persona data…")
    local persona = profileRF("get", {})
    persona = sanitizePersonaData(persona)
    if persona and typeof(persona.slotCount) == "number" then
        setDebugLine("personaSlots", string.format("Persona slots loaded: %d", persona.slotCount))
    else
        setDebugLine("personaSlots", "Persona slots unavailable")
    end
    local inventory
    local invStr = player:GetAttribute("Inventory")
    if typeof(invStr) == "string" then
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, invStr)
        if ok then
            inventory = decoded
            setDebugLine("inventory", "Inventory cache decoded")
        else
            setDebugLine("inventory", "Inventory decode failed")
        end
    else
        setDebugLine("inventory", "Inventory not cached")
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

function BootUI.applyFetchedData(data)
    data = data or {}

    BootUI.config = BootUI.config or {}

    local inventory = data.inventory
    if typeof(inventory) == "table" then
        BootUI.config.inventory = inventory
        BootUI.StarterBackpack = inventory
        BootUI.populateBackpackUI(inventory)
    end

    local personaData = data.personaData
    if personaData ~= nil then
        local sanitized = sanitizePersonaData(personaData)
        BootUI.config.personaData = sanitized
        BootUI.personaData = sanitized
        Cosmetics.refreshSlots(sanitized)
        local function describeMainPersona()
            if typeof(sanitized) ~= "table" then
                return "Main persona: unavailable"
            end

            local slots = sanitized.slots
            if typeof(slots) ~= "table" then
                return "Main persona: no slots"
            end

            local preferred = sanitized.activeSlot or sanitized.selectedSlot or sanitized.currentSlot or sanitized.lastUsedSlot
            preferred = tonumber(preferred)
            local chosen = preferred and slots[preferred] or nil
            local chosenIndex = preferred

            if not chosen then
                local limit = tonumber(sanitized.slotCount) or #slots
                for index = 1, limit do
                    local slot = slots[index]
                    if slot ~= nil then
                        chosen = slot
                        chosenIndex = index
                        break
                    end
                end
            end

            if not chosen then
                return "Main persona: empty"
            end

            local details = {}
            table.insert(details, string.format("Main persona (slot %d): %s", chosenIndex or 0, tostring(chosen.type or "Unknown")))

            if typeof(chosen.level) == "number" then
                table.insert(details, string.format("Level %d", chosen.level))
            end
            if typeof(chosen.exp) == "number" then
                table.insert(details, string.format("XP %d", chosen.exp))
            end
            if typeof(chosen.power) == "number" then
                table.insert(details, string.format("Power %d", chosen.power))
            end
            if typeof(chosen.wins) == "number" then
                table.insert(details, string.format("Wins %d", chosen.wins))
            end
            if typeof(chosen.coins) == "number" then
                table.insert(details, string.format("Coins %d", chosen.coins))
            end

            return table.concat(details, " | ")
        end

        setDebugLine("mainPersona", describeMainPersona())
        setDebugLine("status", "Persona selection ready")
        Cosmetics.showDojoPicker()
    else
        setDebugLine("mainPersona", "Main persona: missing data")
        setDebugLine("status", "Persona data unavailable")
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

local cosmeticsInterface = {}
if hud and hud.createCosmeticsInterface then
    cosmeticsInterface = hud:createCosmeticsInterface() or {}
end

if not cosmeticsInterface.showDojoPicker then
    cosmeticsInterface.showDojoPicker = function()
        BootUI.hideLoadout()
        BootUI.setShopButtonVisible(false)
    end
end

if not cosmeticsInterface.showLoadout then
    cosmeticsInterface.showLoadout = function(personaType)
        BootUI.showLoadout()
        BootUI.setShopButtonVisible(true)
    end
end

if not cosmeticsInterface.updateBackpack then
    cosmeticsInterface.updateBackpack = function(data)
        BootUI.populateBackpackUI(data)
    end
end

if not cosmeticsInterface.buildCharacterPreview then
    cosmeticsInterface.buildCharacterPreview = function(personaType)
        local builder = BootUI.buildCharacterPreview
        if builder then
            builder(personaType)
        end
    end
end

if not cosmeticsInterface.getStarterBackpack then
    cosmeticsInterface.getStarterBackpack = function()
        return BootUI.StarterBackpack
    end
end

BootUI.cosmeticsInterface = cosmeticsInterface

BootUI.populateBackpackUI(config.inventory)


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

if not cosmeticsInterface.tweenToEnd then
    cosmeticsInterface.tweenToEnd = tweenToEnd
end

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
local playerGuiParent = getPlayerGui()
if playerGuiParent then
    ui.Parent = playerGuiParent
else
    task.spawn(function()
        local target = getPlayerGui()
        if target then
            ui.Parent = target
        end
    end)
end
BootUI.introGui   = ui

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1,1)
root.BackgroundTransparency = 1
root.Parent = ui

BootUI.root = root
Cosmetics.init(config, root, cosmeticsInterface)

local debugPanel = Instance.new("Frame")
debugPanel.Name = "DebugPanel"
debugPanel.Size = UDim2.new(0, 320, 0, 0)
debugPanel.Position = UDim2.fromOffset(16, 16)
debugPanel.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
debugPanel.BackgroundTransparency = 0.35
debugPanel.BorderSizePixel = 0
debugPanel.AutomaticSize = Enum.AutomaticSize.Y
debugPanel.ZIndex = 500
debugPanel.Parent = root

local debugCorner = Instance.new("UICorner")
debugCorner.CornerRadius = UDim.new(0, 8)
debugCorner.Parent = debugPanel

local debugPadding = Instance.new("UIPadding")
debugPadding.PaddingTop = UDim.new(0, 8)
debugPadding.PaddingBottom = UDim.new(0, 8)
debugPadding.PaddingLeft = UDim.new(0, 10)
debugPadding.PaddingRight = UDim.new(0, 10)
debugPadding.Parent = debugPanel

local debugTextLabel = Instance.new("TextLabel")
debugTextLabel.Name = "DebugText"
debugTextLabel.Size = UDim2.new(1, 0, 0, 0)
debugTextLabel.AutomaticSize = Enum.AutomaticSize.Y
debugTextLabel.BackgroundTransparency = 1
debugTextLabel.Font = Enum.Font.Gotham
debugTextLabel.TextSize = 16
debugTextLabel.TextWrapped = true
debugTextLabel.TextXAlignment = Enum.TextXAlignment.Left
debugTextLabel.TextYAlignment = Enum.TextYAlignment.Top
debugTextLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
debugTextLabel.ZIndex = 501
debugTextLabel.Text = ""
debugTextLabel.Parent = debugPanel

debugLabel = debugTextLabel
BootUI.debugPanel = debugPanel
rebuildDebugText()

local playerName = "Unknown player"
if player then
    local displayName = player.DisplayName
    if typeof(displayName) == "string" and displayName ~= "" then
        playerName = string.format("Player: %s (@%s)", displayName, player.Name)
    else
        playerName = string.format("Player: %s", player.Name)
    end
end

setDebugLine("player", playerName)
setDebugLine("personaSlots", "Waiting for persona data…")
setDebugLine("mainPersona", "Main persona: awaiting data")
setDebugLine("status", "Boot interface ready")

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
            BootUI.hideLoadout()
            local currentHud = BootUI.hud
            if currentHud and currentHud.setBackButtonEnabled then
                currentHud:setBackButtonEnabled(false)
            end
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
holdStartCam(0.3)
disableUIBlur()

Cosmetics.showDojoPicker()
-- We do NOT tween to end here anymore; only after "Use".
Cosmetics.refreshSlots(config.personaData)


end

return BootUI
