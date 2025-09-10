-- Client bootstrap script loading BootModules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BootModules = ReplicatedStorage:WaitForChild("BootModules")

local PersonaUI = require(BootModules:WaitForChild("PersonaUI"))
PersonaUI.start()

local BootUI = require(BootModules:WaitForChild("BootUI"))
local config = BootUI.fetchData()
BootUI.start(config)
