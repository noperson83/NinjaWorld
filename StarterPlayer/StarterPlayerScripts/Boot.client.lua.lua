-- Modernized boot script delegating responsibilities to BootModules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BootModules = ReplicatedStorage:WaitForChild("BootModules")

-- Load configuration once
local GameSettings = require(ReplicatedStorage:WaitForChild("GameSettings"))

-- Require modules
local BootUI = require(BootModules:WaitForChild("BootUI"))
local CurrencyService = require(BootModules:WaitForChild("CurrencyService"))
local Shop = require(BootModules:WaitForChild("Shop"))
local ShopUI = require(BootModules:WaitForChild("ShopUI"))
local Cosmetics = require(BootModules:WaitForChild("Cosmetics"))

-- Existing TeleportClient module kept in ClientModules
local successTeleport, TeleportClient = pcall(function()
        return require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("TeleportClient"))
end)
if not successTeleport then
        warn("TeleportClient failed to load: " .. tostring(TeleportClient))
        TeleportClient = nil
end

-- Initialize sequence: UI -> currency -> shop -> teleport -> cosmetics
local ui = BootUI.init(GameSettings)

-- Align the player's camera with the configured start position.
-- BootUI exposes helpers for this; we use holdStartCam here so the
-- camera immediately snaps to the startPos and stays there briefly.
-- Alternatively, developers can swap this for ui.tweenToStart() to
-- smoothly move the camera instead of snapping.
ui.holdStartCam(3)

local currency = CurrencyService.new(GameSettings)
local shop = Shop.new(GameSettings, currency)
ShopUI.init(GameSettings, shop, ui)

if TeleportClient and TeleportClient.init then
        TeleportClient.init(GameSettings)
end
Cosmetics.init(GameSettings)
