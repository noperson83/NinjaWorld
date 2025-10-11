local BootUI = {}

BootUI._initialIntroReplayDone = false
BootUI._queuedInitialIntroOptions = nil

-- =====================
-- Services & locals
-- =====================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local personaRemote

BootUI.setDebugLine = function()
end

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
        if personaRemote and personaRemote.Parent then
                return personaRemote
        end

        personaRemote = ReplicatedStorage:FindFirstChild("PersonaServiceRF")
        if not personaRemote then
                personaRemote = ReplicatedStorage:WaitForChild("PersonaServiceRF", 5)
        end
        if not personaRemote then
                warn("BootUI: PersonaServiceRF missing")
        end
        return personaRemote
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
                        result.slots = {}
                        for slotIndex, slotValue in pairs(data.slots) do
                                if typeof(slotValue) == "table" then
                                        local slotCopy = {}
                                        for k, v in pairs(slotValue) do
                                                slotCopy[k] = v
                                        end
                                        result.slots[slotIndex] = slotCopy
                                else
                                        result.slots[slotIndex] = slotValue
                                end
                        end
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

local function getLocalPlayerLevel()
        if not player then
                return 1
        end
        local stats = player:FindFirstChild("Stats")
        local levelValue = stats and stats:FindFirstChild("Level")
        if levelValue and typeof(levelValue.Value) == "number" then
                return levelValue.Value
        end
        local attribute = player:GetAttribute("Level")
        if typeof(attribute) == "number" then
                return attribute
        end
        return 1
end

local function ensurePersonaLevels(personaData)
        if typeof(personaData) ~= "table" then
                return
        end

        local slots = personaData.slots
        if typeof(slots) ~= "table" then
                return
        end

        local fallbackLevel = getLocalPlayerLevel()
        for slotIndex, slotValue in pairs(slots) do
                if typeof(slotValue) == "table" and slotValue.level == nil then
                        slotValue.level = fallbackLevel
                end
        end
end

local function profileRF(action, data)
        local remote = getPersonaRemote()
        if not remote then
                warn("PersonaServiceRF unavailable for action", action)
                return nil
        end
        local ok, result = pcall(remote.InvokeServer, remote, action, data)
        if not ok then
                warn(string.format("PersonaServiceRF:%s failed: %s", tostring(action), tostring(result)))
                return nil
        end
        return result
end

function BootUI.fetchData()
        local persona = profileRF("get", {})
        persona = sanitizePersonaData(persona)
        ensurePersonaLevels(persona)
        return {
                personaData = persona,
        }
end

-- =====================
-- Module requires
-- =====================
local Cosmetics = require(ReplicatedStorage.BootModules.Cosmetics)

local function showIntroOverlay()
        if BootUI.introGui then
                BootUI.introGui.Enabled = true
        end
        if BootUI.root then
                BootUI.root.Visible = true
        end
end

local function hideIntroOverlay()
        if BootUI.root then
                BootUI.root.Visible = false
        end
end

function BootUI.replayIntroSequence(options)
        options = options or {}
        local personaData = options.personaData or BootUI.personaData
        showIntroOverlay()
        if personaData and Cosmetics and Cosmetics.refreshSlots then
                Cosmetics.refreshSlots(personaData)
        end
        if Cosmetics and Cosmetics.showDojoPicker then
                Cosmetics.showDojoPicker()
        end
        BootUI._initialIntroReplayDone = true
end

function BootUI.applyFetchedData(data)
        BootUI.config = BootUI.config or {}

        local personaData = data and data.personaData
        if personaData then
                local sanitized = sanitizePersonaData(personaData)
                ensurePersonaLevels(sanitized)
                BootUI.config.personaData = sanitized
                BootUI.personaData = sanitized
                BootUI.replayIntroSequence({
                        personaData = sanitized,
                })
        end
end

function BootUI.showOverlay()
        showIntroOverlay()
end

function BootUI.hideOverlay()
        hideIntroOverlay()
end

function BootUI.destroy()
        if BootUI.introGui then
                BootUI.introGui:Destroy()
        end
        BootUI.introGui = nil
        BootUI.root = nil
end

function BootUI.start(config)
        config = config or {}
        BootUI.config = config

        local initialPersona = sanitizePersonaData(config.personaData)
        ensurePersonaLevels(initialPersona)
        BootUI.personaData = initialPersona

        local playerGuiParent = getPlayerGui()
        local ui = Instance.new("ScreenGui")
        ui.ResetOnSpawn = false
        ui.Name = "IntroGui"
        ui.IgnoreGuiInset = true
        ui.DisplayOrder = 100
        ui.Enabled = true
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
        BootUI.introGui = ui

        local root = Instance.new("Frame")
        root.Name = "BootUIRoot"
        root.Size = UDim2.fromScale(1, 1)
        root.BackgroundTransparency = 1
        root.BorderSizePixel = 0
        root.Visible = true
        root.Parent = ui
        BootUI.root = root

        local cosmeticsBridge = {
                showDojoPicker = function()
                        showIntroOverlay()
                end,
                showLoadout = function()
                        showIntroOverlay()
                end,
                updateBackpack = function()
                end,
                buildCharacterPreview = function()
                end,
                tweenToEnd = function()
                        return false
                end,
                getStarterBackpack = function()
                        return nil
                end,
        }

        local cosmeticsConfig = {}
        for key, value in pairs(config) do
                cosmeticsConfig[key] = value
        end
        cosmeticsConfig.personaData = BootUI.personaData

        Cosmetics.init(cosmeticsConfig, root, cosmeticsBridge)

        if BootUI.personaData then
                BootUI.replayIntroSequence({
                        personaData = BootUI.personaData,
                })
        else
                showIntroOverlay()
        end
end

return BootUI
