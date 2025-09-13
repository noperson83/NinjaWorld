local QuestUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

function QuestUI.init(parent, baseY)
    local emoteBar = Instance.new("Frame")
    emoteBar.Size = UDim2.new(1,-40,0,38)
    emoteBar.Position = UDim2.fromOffset(20, baseY + 60)
    emoteBar.BackgroundColor3 = Color3.fromRGB(24,26,28)
    emoteBar.BackgroundTransparency = 0.6
    emoteBar.BorderSizePixel = 0
    emoteBar.Parent = parent
    local emoteLayout = Instance.new("UIListLayout", emoteBar)
    emoteLayout.FillDirection = Enum.FillDirection.Horizontal
    emoteLayout.Padding = UDim.new(0,6)
    emoteLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    local function emoteButton(text)
        local b = Instance.new("TextButton")
        b.BackgroundColor3 = Color3.fromRGB(50,120,255)
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamSemibold
        b.TextScaled = true
        b.AutoButtonColor = true
        b.Size = UDim2.new(0,120,1,0)
        b.Text = text
        b.Parent = emoteBar
        return b
    end

    local vpCard = Instance.new("Frame")
    vpCard.BackgroundTransparency = 0.6
    vpCard.Size = UDim2.new(0.48,-30,0.62,0)
    vpCard.Position = UDim2.fromOffset(20, baseY + 92)
    vpCard.BackgroundColor3 = Color3.fromRGB(24,26,28)
    vpCard.BorderSizePixel = 0
    vpCard.Parent = parent

    local viewport = Instance.new("ViewportFrame")
    viewport.Size = UDim2.fromScale(1,1)
    viewport.BackgroundColor3 = Color3.fromRGB(16,16,16)
    viewport.BackgroundTransparency = 0.6
    viewport.BorderSizePixel = 0
    viewport.Parent = vpCard

    -- Orbitable viewport state
    local vpWorld, vpModel, vpCam, vpHumanoid, currentEmoteTrack
    local orbit = {yaw = math.pi, pitch = 0.1, dist = 10, min = 4, max = 40, center = Vector3.new(), dragging = false}

    local function updateVPCamera()
        if not vpCam then return end
        local dir = CFrame.fromEulerAnglesYXZ(orbit.pitch, orbit.yaw, 0).LookVector
        local camPos = orbit.center - dir * orbit.dist
        vpCam.CFrame = CFrame.new(camPos, orbit.center)
    end

    local function hookViewportControls()
        viewport.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                orbit.dragging = true
            end
        end)
        viewport.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                orbit.dragging = false
            end
        end)
        viewport.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and orbit.dragging then
                local d = input.Delta
                orbit.yaw = orbit.yaw - d.X * 0.01
                orbit.pitch = math.clamp(orbit.pitch - d.Y * 0.01, -1.2, 1.2)
                updateVPCamera()
            elseif input.UserInputType == Enum.UserInputType.MouseWheel then
                local scroll = input.Position.Z
                orbit.dist = math.clamp(orbit.dist - scroll * 1.5, orbit.min, orbit.max)
                updateVPCamera()
            end
        end)
    end

    local function clearChildren(p)
        for _, c in ipairs(p:GetChildren()) do
            if not c:IsA("UIListLayout") then
                c:Destroy()
            end
        end
    end

    local function stopEmote()
        if currentEmoteTrack then
            currentEmoteTrack:Stop(0.1)
            currentEmoteTrack:Destroy()
            currentEmoteTrack = nil
        end
    end

    local EMOTES = {
        Idle  = "rbxassetid://507766388",
        Wave  = "rbxassetid://507770239",
        Point = "rbxassetid://507770453",
        Dance = "rbxassetid://507771019",
        Laugh = "rbxassetid://507770818",
        Cheer = "rbxassetid://507770677",
        Sit   = "rbxassetid://2506281703",
    }

    local function playEmote(name)
        if not (vpHumanoid and EMOTES[name]) then return end
        stopEmote()
        local anim = Instance.new("Animation")
        anim.AnimationId = EMOTES[name]
        currentEmoteTrack = vpHumanoid:LoadAnimation(anim)
        currentEmoteTrack.Looped = (name == "Idle" or name == "Dance")
        currentEmoteTrack:Play(0.1)
    end

    local function wireEmoteButtons()
        local order = {"Idle","Wave","Point","Dance","Laugh","Cheer","Sit"}
        for _,label in ipairs(order) do
            local b = emoteButton(label)
            b.MouseButton1Click:Connect(function()
                playEmote(label)
            end)
        end
    end

    function QuestUI.buildCharacterPreview(personaType)
        clearChildren(viewport)
        vpWorld, vpModel, vpCam, vpHumanoid = nil, nil, nil, nil
        vpWorld = Instance.new("WorldModel")
        vpWorld.Parent = viewport

        local desc
        if personaType == "Ninja" then
            local hdFolder = ReplicatedStorage:FindFirstChild("HumanoidDescriptions")
                or ReplicatedStorage:FindFirstChild("HumanoidDescription")
            local hd = hdFolder and hdFolder:FindFirstChild("Ninja")
            if hd then desc = hd:Clone() end
        else
            local ok, hd = pcall(function()
                return Players:GetHumanoidDescriptionFromUserId(Players.LocalPlayer.UserId)
            end)
            if ok then desc = hd end
        end
        if not desc then return end

        vpModel = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
        vpModel:PivotTo(CFrame.new(0,0,0))
        pcall(function()
            ContentProvider:PreloadAsync({vpModel})
        end)
        vpModel.Parent = vpWorld
        vpHumanoid = vpModel:FindFirstChildOfClass("Humanoid")

        local _, size = vpModel:GetBoundingBox()
        local radius = math.max(size.X, size.Y, size.Z)
        orbit.center = Vector3.new(0, size.Y*0.5, 0)
        orbit.dist   = math.clamp(radius * 1.8, 6, 20)
        orbit.min    = math.max(3, radius*0.8)
        orbit.max    = radius * 4
        orbit.pitch  = 0.15
        orbit.yaw    = math.pi

        vpCam = Instance.new("Camera")
        vpCam.Parent = viewport
        viewport.CurrentCamera = vpCam
        updateVPCamera()

        if not viewport:GetAttribute("_controlsHooked") then
            hookViewportControls()
            viewport:SetAttribute("_controlsHooked", true)
        end

        playEmote("Idle")
    end

    wireEmoteButtons()

    return {buildCharacterPreview = QuestUI.buildCharacterPreview}
end

return QuestUI
