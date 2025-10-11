-- Enhanced Client Bootstrap Script
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local BootModules = ReplicatedStorage.BootModules
local LocalPlayer = Players.LocalPlayer

-- Configuration
local CONFIG = {
        CAMERA_LOCK_DURATION = 3, -- How long to lock camera (seconds)
        CAMERA_TRANSITION_TIME = 1.5, -- Smooth transition time
        BLUR_SIZE = 24,
        BLUR_FADE_TIME = 0.5,
        CAMERA_ASSET_WAIT_TIME = 5 -- How long to wait for intro camera assets to replicate
}

-- ═══════════════════════════════════════════════════════════════
-- BLUR SETUP
-- ═══════════════════════════════════════════════════════════════
local blur = Lighting:FindFirstChild("Blur") or Lighting:FindFirstChildOfClass("BlurEffect")
if not blur then
	blur = Instance.new("BlurEffect")
	blur.Name = "Blur"
	blur.Size = 0
	blur.Enabled = true
	blur.Parent = Lighting
end

-- ═══════════════════════════════════════════════════════════════
-- LOADING UI INITIALIZATION
-- ═══════════════════════════════════════════════════════════════
local LoadingUI = require(BootModules.LoadingUI)
LoadingUI.start({waitTime = 0, fadeTime = 0})

local DojoClient = require(BootModules.DojoClient)
local BootUI = require(BootModules.BootUI)
BootUI.start()
BootUI.setDebugLine("status", "🎮 Initializing game client...")

-- ═══════════════════════════════════════════════════════════════
-- ENHANCED CAMERA SYSTEM
-- ═══════════════════════════════════════════════════════════════
local CameraController = {}
CameraController.isLocked = false
CameraController.originalCameraType = nil

local function findFirstSpawnPart(container)
        if not container then
                return nil
        end

        for _, child in ipairs(container:GetChildren()) do
                if child:IsA("BasePart") then
                        return child
                end
        end

        for _, child in ipairs(container:GetChildren()) do
                local found = findFirstSpawnPart(child)
                if found then
                        return found
                end
        end

        return nil
end

local INTRO_CAMERA_SEARCH_CONTAINERS = {
        Workspace,
        ReplicatedFirst,
        ReplicatedStorage,
        Lighting,
}

local function locateIntroCameraFolder()
        -- Check direct child first for backwards compatibility
        local folder = Workspace:FindFirstChild("IntroCameras")
        if folder then
                return folder
        end

        -- Some experiences keep the cameras in ReplicatedStorage (or other
        -- containers) until the player loads into the dojo. To support that
        -- workflow we walk a small set of replicated containers looking for
        -- a descendant named "IntroCameras".
        for _, container in ipairs(INTRO_CAMERA_SEARCH_CONTAINERS) do
                local ok, result = pcall(function()
                        return container:FindFirstChild("IntroCameras", true)
                end)
                if ok and result then
                        return result
                end
        end

        return nil
end

local function findFallbackCameraCFrame()
        local spawnFolder = Workspace:FindFirstChild("SpawnLocations")
        local spawnPart = findFirstSpawnPart(spawnFolder)

        if not spawnPart then
                local dojoSpawn = Workspace:FindFirstChild("DojoSpawn", true)
                if dojoSpawn and dojoSpawn:IsA("BasePart") then
                        spawnPart = dojoSpawn
                end
        end

        if not spawnPart then
                for _, descendant in ipairs(Workspace:GetDescendants()) do
                        if descendant:IsA("SpawnLocation") then
                                spawnPart = descendant
                                break
                        end
                end
        end

        if spawnPart and spawnPart:IsA("BasePart") then
                local baseCFrame = spawnPart.CFrame
                local lookTarget = baseCFrame.Position + baseCFrame.LookVector * 5
                local eyePosition = baseCFrame.Position + Vector3.new(0, 5, 0) - baseCFrame.LookVector * 12
                return CFrame.lookAt(eyePosition, lookTarget)
        end

        local character = LocalPlayer.Character
        if not character then
                local ok, result = pcall(function()
                        return LocalPlayer.CharacterAdded:Wait()
                end)
                if ok then
                        character = result
                end
        end

        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if hrp then
                local baseCFrame = hrp.CFrame
                local lookTarget = baseCFrame.Position + baseCFrame.LookVector * 5
                local eyePosition = baseCFrame.Position + Vector3.new(0, 5, 0) - baseCFrame.LookVector * 12
                return CFrame.lookAt(eyePosition, lookTarget)
        end

        return CFrame.new(Vector3.new(0, 10, 0), Vector3.new(0, 0, 0))
end

function CameraController.setToStartPos()
        local targetCFrame
        local usingFallback = false
        local cameraFolder
        local startTime = os.clock()

        repeat
                cameraFolder = locateIntroCameraFolder()
                if cameraFolder then
                        break
                end
                task.wait(0.1)
        until os.clock() - startTime >= CONFIG.CAMERA_ASSET_WAIT_TIME

        if cameraFolder then
                local startPos

                local ok = pcall(function()
                        startPos = cameraFolder:FindFirstChild("startPos", true)
                end)

                if not ok then
                        startPos = nil
                end

                if startPos and startPos:IsA("BasePart") then
                        targetCFrame = startPos.CFrame
                else
                        if not startPos then
                                warn("⚠️ startPos part not found in IntroCameras, using fallback")
                        else
                                warn("⚠️ startPos exists but is not a BasePart, using fallback")
                        end
                        usingFallback = true
                end
        else
                warn("⚠️ IntroCameras folder not found in replicated containers, using fallback")
                usingFallback = true
        end

        if not targetCFrame then
                targetCFrame = findFallbackCameraCFrame()
                if not targetCFrame then
                        warn("⚠️ Unable to determine fallback camera position")
                        return false
                end
        end
	
	local camera = Workspace.CurrentCamera
	if not camera then
		warn("⚠️ CurrentCamera not available")
		return false
	end
	
	-- Store original camera type
	CameraController.originalCameraType = camera.CameraType
	
	-- Lock camera to scriptable
	camera.CameraType = Enum.CameraType.Scriptable
	CameraController.isLocked = true
	
	-- Smooth transition to start position
	local tweenInfo = TweenInfo.new(
		CONFIG.CAMERA_TRANSITION_TIME,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	
        local tween = TweenService:Create(camera, tweenInfo, {
                CFrame = targetCFrame
        })
	
	tween:Play()
	
	-- Add cinematic blur
	local blurTween = TweenService:Create(blur, TweenInfo.new(CONFIG.BLUR_FADE_TIME), {
		Size = CONFIG.BLUR_SIZE
	})
	blurTween:Play()
	
        if usingFallback then
                BootUI.setDebugLine("status", "📹 Camera locked to fallback position")
        else
                BootUI.setDebugLine("status", "📹 Camera locked to intro position")
        end

        return true
end

function CameraController.unlock()
	if not CameraController.isLocked then return end
	
	local camera = Workspace.CurrentCamera
	if camera and CameraController.originalCameraType then
		-- Restore original camera type
		camera.CameraType = CameraController.originalCameraType
		CameraController.isLocked = false
		
		-- Fade out blur
		local blurTween = TweenService:Create(blur, TweenInfo.new(CONFIG.BLUR_FADE_TIME), {
			Size = 0
		})
		blurTween:Play()
		blurTween.Completed:Connect(function()
			blur.Enabled = false
		end)
		
		BootUI.setDebugLine("status", "✅ Camera control restored")
	end
end

function CameraController.autoUnlockAfterDelay()
	task.wait(CONFIG.CAMERA_LOCK_DURATION)
	CameraController.unlock()
end

-- ═══════════════════════════════════════════════════════════════
-- CAMERA RESET HANDLER (Prevents camera drift)
-- ═══════════════════════════════════════════════════════════════
local function setupCameraResetProtection()
	local connection
	connection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if CameraController.isLocked then
			CameraController.setToStartPos()
		end
		if connection then
			connection:Disconnect()
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- CHARACTER SPAWN HANDLER
-- ═══════════════════════════════════════════════════════════════
local function onCharacterAdded(character)
	-- Wait for character to fully load
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		BootUI.setDebugLine("status", "👤 Character loaded")
	end
end

if LocalPlayer.Character then
	task.spawn(onCharacterAdded, LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- ═══════════════════════════════════════════════════════════════
-- MAIN INITIALIZATION SEQUENCE
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
	-- Set camera to intro position
	local success = CameraController.setToStartPos()
	
	if success then
		-- Setup protection against camera reset
		setupCameraResetProtection()
		
		-- Auto-unlock after configured duration
		task.spawn(CameraController.autoUnlockAfterDelay)
	else
		-- If camera setup fails, just continue normally
		blur.Enabled = false
	end
end)

-- Fetch and apply player data
task.spawn(function()
	BootUI.setDebugLine("status", "🔄 Fetching player profile...")
	local data = BootUI.fetchData()
	BootUI.applyFetchedData(data)
	BootUI.setDebugLine("status", "✅ Profile loaded successfully")
end)

-- ═══════════════════════════════════════════════════════════════
-- EXPORT FOR OTHER SCRIPTS
-- ═══════════════════════════════════════════════════════════════
_G.CameraController = CameraController

print("🚀 Client bootstrap complete!")
