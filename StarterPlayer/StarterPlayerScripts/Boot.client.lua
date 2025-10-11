-- Enhanced Client Bootstrap Script
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
	BLUR_FADE_TIME = 0.5
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

function CameraController.setToStartPos()
	local cameraFolder = Workspace:FindFirstChild("IntroCameras")
	if not cameraFolder then
		warn("⚠️ IntroCameras folder not found in Workspace")
		return false
	end
	
	local startPos = cameraFolder:FindFirstChild("startPos")
	if not (startPos and startPos:IsA("BasePart")) then
		warn("⚠️ startPos part not found or invalid in IntroCameras")
		return false
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
		CFrame = startPos.CFrame
	})
	
	tween:Play()
	
	-- Add cinematic blur
	local blurTween = TweenService:Create(blur, TweenInfo.new(CONFIG.BLUR_FADE_TIME), {
		Size = CONFIG.BLUR_SIZE
	})
	blurTween:Play()
	
	BootUI.setDebugLine("status", "📹 Camera locked to intro position")
	
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
