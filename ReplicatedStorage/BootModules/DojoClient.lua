local DojoClient = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui
local label

function DojoClient.start(realmName)
    local text = "Entering " .. (realmName or "Dojo") .. "..."
    if gui then
        if label then label.Text = text end
        return
    end
    gui = Instance.new("ScreenGui")
    gui.Name = "DojoLoadingGui"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 200
    gui.Parent = player:WaitForChild("PlayerGui")

    local root = Instance.new("Frame")
    root.Size = UDim2.fromScale(1,1)
    root.BackgroundColor3 = Color3.fromRGB(0,0,0)
    root.BackgroundTransparency = 0.2
    root.Parent = gui

    label = Instance.new("TextLabel")
    label.Text = text
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.TextColor3 = Color3.new(1,1,1)
    label.Size = UDim2.fromScale(0.6,0.1)
    label.AnchorPoint = Vector2.new(0.5,0.5)
    label.Position = UDim2.fromScale(0.5,0.5)
    label.BackgroundTransparency = 1
    label.Parent = root

    local tween = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, true)
    TweenService:Create(label, tween, {TextTransparency = 0.4}):Play()
end

function DojoClient.hide()
    if gui then
        gui:Destroy()
        gui = nil
        label = nil
    end
end

return DojoClient

