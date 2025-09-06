local BootUI = {}

-- Initializes the intro screen and basic camera state.
-- Returns a table with references to the GUI and helper functions.
function BootUI.init(config)
        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local Workspace = game:GetService("Workspace")
        local TweenService = game:GetService("TweenService")
        local Lighting = game:GetService("Lighting")

        local player = Players.LocalPlayer
        local cam = Workspace.CurrentCamera

        -- Camera helper from legacy Boot.client.lua
        local function partAttr(p, name, default)
                local v = p and p:GetAttribute(name)
                return (typeof(v) == "number") and v or default
        end

        local function faceCF(part)
                if not part then return cam.CFrame end
                local f = part.CFrame.LookVector
                local u = part.CFrame.UpVector
                local dist   = partAttr(part, "Dist",   0)
                local height = partAttr(part, "Height", 0)
                local ahead  = partAttr(part, "Ahead",  10)
                local pos    = part.Position - f*dist + u*height
                local target = part.Position + f*ahead
                return CFrame.lookAt(pos, target, u)
        end

        local camerasFolder = Workspace:WaitForChild("Cameras", 5)
        local startPos = camerasFolder and camerasFolder:FindFirstChild("startPos")
        if not startPos then
                warn("BootUI: expected Workspace.Cameras.startPos to exist")
        end

        local gui = Instance.new("ScreenGui")
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 100
        gui.Name = "IntroGui"
        gui.Parent = player:WaitForChild("PlayerGui")

        local root = Instance.new("Frame")
        root.Size = UDim2.fromScale(1,1)
        root.BackgroundTransparency = 1
        root.Parent = gui

        -- Simple label using GameSettings data
        local title = Instance.new("TextLabel")
        title.Size = UDim2.fromOffset(600,50)
        title.Position = UDim2.fromScale(0.5,0.44)
        title.AnchorPoint = Vector2.new(0.5,0.5)
        title.Text = config.gameName or "Loading"
        title.Font = Enum.Font.Gotham
        title.TextScaled = true
        title.TextColor3 = Color3.fromRGB(230,230,230)
        title.BackgroundTransparency = 1
        title.Parent = root

        -- Teleport GUI with zone and world frames
        local teleportGui = Instance.new("ScreenGui")
        teleportGui.ResetOnSpawn = false
        teleportGui.IgnoreGuiInset = true
        teleportGui.Name = "TeleportGui"
        teleportGui.Parent = player:WaitForChild("PlayerGui")

        local teleFrame = Instance.new("Frame")
        teleFrame.Name = "TeleFrame"
        teleFrame.BackgroundTransparency = 1
        teleFrame.Size = UDim2.fromScale(1,1)
        teleFrame.Parent = teleportGui

        local worldFrame = Instance.new("Frame")
        worldFrame.Name = "WorldTeleFrame"
        worldFrame.BackgroundTransparency = 1
        worldFrame.Size = UDim2.fromScale(1,1)
        worldFrame.Parent = teleportGui

        local zoneNames = {"Atom","Fire","Grow","Ice","Light","Metal","Water","Wind","Dojo","Starter"}
        for _, name in ipairs(zoneNames) do
                local button = Instance.new("TextButton")
                button.Name = name .. "Button"
                button.Size = UDim2.fromOffset(100,50)
                button.Text = name
                button.Parent = teleFrame
        end

        local worldNames = {"Atom","Fire","Water"}
        for _, name in ipairs(worldNames) do
                local button = Instance.new("TextButton")
                button.Name = name .. "Button"
                button.Size = UDim2.fromOffset(100,50)
                button.Text = name
                button.Parent = worldFrame
        end

        local function applyStartCam()
                if not startPos then return end
                cam.CameraType = Enum.CameraType.Scriptable
                cam.CFrame = faceCF(startPos)
                cam.FieldOfView = partAttr(startPos, "FOV", cam.FieldOfView)
        end

        local function holdStartCam(seconds)
                applyStartCam()
                local untilT = os.clock() + (seconds or 1.0)
                RunService:BindToRenderStep("BootUI_Hold", Enum.RenderPriority.Camera.Value + 1, function()
                        cam = Workspace.CurrentCamera
                        applyStartCam()
                        if os.clock() > untilT then RunService:UnbindFromRenderStep("BootUI_Hold") end
                end)
                Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
                        cam = Workspace.CurrentCamera
                        applyStartCam()
                end)
        end

        local function tweenToStart()
                if not startPos then return end
                local cf  = faceCF(startPos)
                local fov = partAttr(startPos, "FOV", cam.FieldOfView)
                TweenService:Create(cam, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = cf, FieldOfView = fov}):Play()
        end

        return {
                gui = gui,
                root = root,
                teleportGui = teleportGui,
                holdStartCam = holdStartCam,
                tweenToStart = tweenToStart
        }
end

return BootUI
