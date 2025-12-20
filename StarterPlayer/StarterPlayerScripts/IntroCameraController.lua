local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local ReleaseIntroEvent = ReplicatedStorage:FindFirstChild("ReleaseIntro")

-- Camera blocks
local IntroCamerasFolder = ReplicatedStorage:FindFirstChild("IntroCameras")
local startPosBlock = nil
local endPosBlock = nil
if IntroCamerasFolder then
    startPosBlock = IntroCamerasFolder:FindFirstChild("startPos")
    endPosBlock = IntroCamerasFolder:FindFirstChild("endPos")
end

-- Track whether intro is active (should freeze character)
local introActive = true
local characterAddedConn

-- Tween camera from startPos to endPos
local function tweenIntroCamera(callback)
    local camera = Workspace.CurrentCamera
    if not camera or not startPosBlock or not endPosBlock then
        warn("[IntroCameraController] Camera blocks not found for intro tween.")
        if callback then callback() end
        return
    end

    -- Set camera to Scriptable and position at front face of startPos
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = startPosBlock.CFrame

    -- Tween to endPos
    local tweenInfo = TweenInfo.new(
        3, -- duration (seconds)
        Enum.EasingStyle.Sine,
        Enum.EasingDirection.Out
    )
    local goal = {CFrame = endPosBlock.CFrame}
    local tween = TweenService:Create(camera, tweenInfo, goal)
    tween:Play()

    tween.Completed:Connect(function()
        if callback then callback() end
    end)
end

-- Freeze logic
local function freezeCharacter(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid then
        print("[IntroCameraController] No humanoid found to freeze.")
        return
    end

    humanoid.WalkSpeed = 0
    if humanoid.UseJumpPower ~= false then
        humanoid.JumpPower = 0
    else
        humanoid.JumpHeight = 0
    end
    humanoid.AutoRotate = false

    if rootPart then
        rootPart.Anchored = true
    end

    -- Optionally disable controls
    ContextActionService:BindAction(
        "FreezeMovement",
        function() return Enum.ContextActionResult.Sink end,
        false,
        Enum.PlayerActions.CharacterForward,
        Enum.PlayerActions.CharacterBackward,
        Enum.PlayerActions.CharacterLeft,
        Enum.PlayerActions.CharacterRight,
        Enum.PlayerActions.CharacterJump
    )

    -- Ensure intro camera is always the same for all personas
    local camera = Workspace.CurrentCamera
    if camera and rootPart then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = rootPart
    end
end

local function unfreezeCharacter(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        print("[IntroCameraController] No humanoid found to unfreeze.")
        return
    end

    humanoid.WalkSpeed = 16
    if humanoid.UseJumpPower ~= false then
        humanoid.JumpPower = 50
    else
        humanoid.JumpHeight = 7
    end
    humanoid.AutoRotate = true

    -- Unanchor all BaseParts in the character
    local unanchoredCount = 0
    for _, part in character:GetDescendants() do
        if part:IsA("BasePart") then
            if part.Anchored then
                part.Anchored = false
                unanchoredCount = unanchoredCount + 1
            end
        end
    end

    -- Restore controls
    ContextActionService:UnbindAction("FreezeMovement")
end

local function switchCameraToGameplay()
    local camera = Workspace.CurrentCamera
    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if camera and rootPart then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = rootPart
    end
end

local function onCharacterAdded(character)
    if introActive then
        -- Tween camera first, then freeze character
        tweenIntroCamera(function()
			freezeCharacter(character)
        end)
    else
        -- After intro, ensure character is unfrozen
        unfreezeCharacter(character)
    end
end

local player = Players.LocalPlayer
if player.Character then
    if introActive then
        tweenIntroCamera(function()
			freezeCharacter(player.Character)
        end)
    else
        unfreezeCharacter(player.Character)
    end
end

-- Always keep CharacterAdded connected, but only freeze if introActive
if characterAddedConn then
    characterAddedConn:Disconnect()
    characterAddedConn = nil
end
characterAddedConn = player.CharacterAdded:Connect(onCharacterAdded)

-- Listen for ReleaseIntro RemoteEvent to unfreeze and switch camera
if ReleaseIntroEvent then
    ReleaseIntroEvent.OnClientEvent:Connect(function()
		introActive = false
        -- No longer disconnect CharacterAdded connection, so new characters will always be unfrozen after intro
		local character = player.Character or player.CharacterAdded:Wait()
		unfreezeCharacter(character)
		switchCameraToGameplay()
    end)
else
    warn("[IntroCameraController] ReleaseIntro RemoteEvent not found!")
end

