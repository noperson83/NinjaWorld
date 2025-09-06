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
local TeleportClient = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("TeleportClient"))

-- Initialize sequence: UI -> currency -> shop -> teleport -> cosmetics
local ui = BootUI.init(GameSettings)
local currency = CurrencyService.new(GameSettings)
local shop = Shop.new(GameSettings, currency)
ShopUI.init(GameSettings, shop, ui)

TeleportClient.init(GameSettings)
Cosmetics.init(GameSettings)
