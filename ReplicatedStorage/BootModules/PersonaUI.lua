local PersonaUI = {}

local function getPlayerGui(player)
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

function PersonaUI.start(config)
    config = config or {}

    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local ContentProvider = game:GetService("ContentProvider")

    local player = Players.LocalPlayer

    local ASSETS = {
        Logo     = "rbxassetid://138217463115431",
        PaperTex = "rbxassetid://131504699316598",
    }

    local gui = Instance.new("ScreenGui")
    gui.ResetOnSpawn   = false
    gui.Name           = "IntroGui"
    gui.IgnoreGuiInset = true
    gui.DisplayOrder   = 100

    local parentGui = getPlayerGui(player)
    if parentGui then
        gui.Parent = parentGui
    else
        warn("PersonaUI: PlayerGui not available, deferring intro UI parent")
        task.spawn(function()
            local target = getPlayerGui(player)
            if target and gui.Parent ~= target then
                gui.Parent = target
            elseif not target then
                warn("PersonaUI: Failed to find PlayerGui; destroying intro UI")
                gui:Destroy()
            end
        end)
    end

    local root = Instance.new("Frame")
    root.Size = UDim2.fromScale(1,1)
    root.BackgroundTransparency = 1
    root.Parent = gui

    local paperBG = Instance.new("ImageLabel")
    paperBG.Size = UDim2.fromScale(1,1)
    paperBG.BackgroundTransparency = 1
    paperBG.Image = ASSETS.PaperTex
    paperBG.ScaleType = Enum.ScaleType.Tile
    paperBG.TileSize = UDim2.fromOffset(256,256)
    paperBG.ImageTransparency = 0.12
    paperBG.ImageColor3 = Color3.fromRGB(250,235,220)
    paperBG.ZIndex = 1
    paperBG.Parent = root

    local logoImg = Instance.new("ImageLabel")
    logoImg.Size = UDim2.fromScale(0.3,0.3)
    logoImg.Position = UDim2.fromScale(0.5,0.25)
    logoImg.AnchorPoint = Vector2.new(0.5,0.5)
    logoImg.BackgroundTransparency = 1
    logoImg.Image = ASSETS.Logo
    logoImg.ZIndex = 5
    logoImg.Parent = root
    Instance.new("UIAspectRatioConstraint", logoImg).AspectRatio = 1

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.fromScale(0.6,0.05)
    sub.Position = UDim2.fromScale(0.5,0.44)
    sub.AnchorPoint = Vector2.new(0.5,0.5)
    sub.Text = "Loading…"
    sub.Font = Enum.Font.Gotham
    sub.TextScaled = true
    sub.TextColor3 = Color3.fromRGB(230,230,230)
    sub.BackgroundTransparency = 1
    sub.ZIndex = 5
    sub.Parent = root

    local barBG = Instance.new("Frame")
    barBG.Size = UDim2.new(0.6,0,0.01,0)
    barBG.Position = UDim2.fromScale(0.2,0.49)
    barBG.BackgroundColor3 = Color3.fromRGB(40,40,42)
    barBG.BorderSizePixel = 0
    barBG.ZIndex = 4
    barBG.Parent = root

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0,0,0.01,0)
    bar.Position = UDim2.fromScale(0.2,0.49)
    bar.BackgroundColor3 = Color3.fromRGB(255,60,60)
    bar.BorderSizePixel = 0
    bar.ZIndex = 6
    bar.Parent = root

    local items = {}
    if ASSETS.Logo ~= "" then table.insert(items, logoImg) end
    if ASSETS.PaperTex ~= "" then table.insert(items, paperBG) end
    pcall(function()
        ContentProvider:PreloadAsync(items)
    end)

    local loadTime = config.waitTime
    if loadTime == nil then loadTime = 1.65 end
    local fadeTime = config.fadeTime
    if fadeTime == nil then fadeTime = 0.25 end

    bar.Size = UDim2.new(0,0,0.01,0)
    if loadTime > 0 then
        TweenService:Create(bar, TweenInfo.new(loadTime, Enum.EasingStyle.Quad), {Size = UDim2.new(0.6,0,0.01,0)}):Play()
        task.wait(loadTime)
    else
        bar.Size = UDim2.new(0.6,0,0.01,0)
    end

    if fadeTime > 0 then
        local t = TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(sub, t, {TextTransparency = 1}):Play()
        TweenService:Create(bar,  t, {BackgroundTransparency = 1}):Play()
        TweenService:Create(barBG, t, {BackgroundTransparency = 1}):Play()
        TweenService:Create(logoImg, t, {ImageTransparency = 1}):Play()
        TweenService:Create(paperBG, t, {ImageTransparency = 1}):Play()
        task.wait(fadeTime + 0.03)
    end

    gui:Destroy()
end

return PersonaUI

