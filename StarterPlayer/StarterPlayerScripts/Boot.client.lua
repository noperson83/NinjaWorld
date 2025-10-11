-- Client bootstrap script loading BootModules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local BootModules = ReplicatedStorage.BootModules

-- Ensure a BlurEffect exists so other scripts can safely toggle it
local blur = Lighting:FindFirstChild("Blur") or Lighting:FindFirstChildOfClass("BlurEffect")
if not blur then
	blur = Instance.new("BlurEffect")
	blur.Name = "Blur"
	blur.Enabled = false
	blur.Parent = Lighting
end

local LoadingUI = require(BootModules.LoadingUI)
LoadingUI.start({waitTime = 0, fadeTime = 0})

local DojoClient = require(BootModules.DojoClient)

local BootUI = require(BootModules.BootUI)
BootUI.start()
BootUI.setDebugLine("status", "Initializing profile fetch…")

local function setCameraToStartPos()
        local cameraFolder = Workspace:FindFirstChild("Camera")
        if not cameraFolder then
                return
        end

        local startPos = cameraFolder:FindFirstChild("startPos")
        if not (startPos and startPos:IsA("BasePart")) then
                return
        end

        local function applyToCurrentCamera()
                local currentCamera = Workspace.CurrentCamera
                if currentCamera then
                        currentCamera.CFrame = startPos.CFrame
                end
        end

        applyToCurrentCamera()

        local connection
        connection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
                applyToCurrentCamera()
                if connection then
                        connection:Disconnect()
                end
        end)
end

task.spawn(setCameraToStartPos)

task.spawn(function()
        local data = BootUI.fetchData()
        BootUI.applyFetchedData(data)
end)
