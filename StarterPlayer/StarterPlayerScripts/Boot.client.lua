-- Client bootstrap script loading BootModules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BootModules = ReplicatedStorage:WaitForChild("BootModules")

local BootUI = require(BootModules:WaitForChild("BootUI"))
BootUI.start()
