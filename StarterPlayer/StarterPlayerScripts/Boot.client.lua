-- Modernized boot script delegating responsibilities to BootModules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BootModules = ReplicatedStorage:WaitForChild("BootModules")

-- Load configuration once
local GameSettings = require(ReplicatedStorage:WaitForChild("GameSettings"))

-- Require modules
local BootUI = require(BootModules:WaitForChild("BootUI"))
local CurrencyService = require(BootModules:WaitForChild("CurrencyService"))
local Shop = require(BootModules:WaitForChild("Shop"))
local Cosmetics = require(ReplicatedStorage.BootModules.Cosmetics)

-- TeleportClient centralizes teleport button wiring
local TeleportClient = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("TeleportClient"))

-- Initialize UI and run the intro flow
local ui = BootUI.init(GameSettings)
ui.holdStartCam(3)

local persona = ui.selectPersona()
ui.tweenToStart()
ui.showProfile(persona)

-- Services that can initialize after the intro sequence
local currency = CurrencyService.new(GameSettings)
local shop = Shop.new(GameSettings, currency)

ui.teleportGui.Enabled = true
TeleportClient.init(ui.teleportGui)
Cosmetics.init(GameSettings)
