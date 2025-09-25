-- Client bootstrap script loading BootModules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local BootModules = ReplicatedStorage.BootModules

-- Ensure a BlurEffect exists so other scripts can safely toggle it
local blur = Lighting:FindFirstChild("Blur") or Lighting:FindFirstChildOfClass("BlurEffect")
if not blur then
    blur = Instance.new("BlurEffect")
    blur.Name = "Blur"
    blur.Enabled = false
    blur.Parent = Lighting
end

local PersonaUI = require(BootModules.PersonaUI)
PersonaUI.start({waitTime = 0, fadeTime = 0})

local DojoClient = require(BootModules.DojoClient)

local BootUI = require(BootModules.BootUI)
BootUI.start()
BootUI.setDebugLine("status", "Initializing profile fetch…")

task.spawn(function()
    local data = BootUI.fetchData()
    BootUI.applyFetchedData(data)
end)
