-- MainLocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")

local clientModules = ReplicatedStorage:WaitForChild("ClientModules", 5)
local Abilities = require(clientModules:WaitForChild("Abilities"))
local AudioPlayer = require(clientModules:WaitForChild("AudioPlayer"))
local CharacterManager = require(clientModules:WaitForChild("CharacterManager"))
local CombatController = require(clientModules:WaitForChild("CombatController"))
local bootModules = ReplicatedStorage:WaitForChild("BootModules", 5)
if not bootModules then
    warn("BootModules folder missing")
    return
end
local merchModule = bootModules and (bootModules:FindFirstChild("MerchBooth")
    or bootModules:WaitForChild("MerchBooth", 5))
local MerchBooth = merchModule and require(merchModule)
local GameSettings = require(ReplicatedStorage:WaitForChild("GameSettings", 5))

local player = Players.LocalPlayer
local PlayerGui = player.PlayerGui

-- Attempt to load the ActionUI module but don't hard fail if it is missing.
-- This mirrors the defensive loading used for other optional boot modules and
-- prevents runtime errors when the file hasn't been replicated.
local uiFolder = clientModules and (clientModules:FindFirstChild("UI")
    or clientModules:WaitForChild("UI", 5))
local actionUIModule = uiFolder and (uiFolder:FindFirstChild("ActionUI")
    or uiFolder:WaitForChild("ActionUI", 5))
local ActionUI = actionUIModule and require(actionUIModule) or { init = function() end }
if not actionUIModule then
    warn("ActionUI module missing")
end

-- Preload and validate audio assets
-- Purge placeholder sounds before preloading
local DEFAULT_SOUND_ID = "rbxassetid://81165228663280"

local function fixSound(sound)
    local id = sound.SoundId
    if id == "" or id == "rbxassetid://0" then
        if sound.Playing or sound.Looped or sound.PlayOnRemove then
            sound.SoundId = DEFAULT_SOUND_ID
        else
            sound:Destroy()
        end
    end
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

for _, descendant in ipairs(game:GetDescendants()) do
    if descendant:IsA("Sound") then
        fixSound(descendant)
    end
end

game.DescendantAdded:Connect(function(obj)
    if obj:IsA("Sound") then
        fixSound(obj)
    end
end)

local invalidAudioCount = AudioPlayer.preloadAudio({ Main_Background_Theme = 15933971668 })
assert(invalidAudioCount == 0, "Invalid audio asset IDs detected during startup")
AudioPlayer.playAudio("Main_Background_Theme")

-- Setup character and wait until fully initialized
CharacterManager.setup(player)
CombatController.initAnimations()

if MerchBooth then
        MerchBooth.toggleCatalogButton(true)
        MerchBooth.configure({
                disableCharacterMovement = true
        })
else
        warn("MerchBooth module missing")
end

--local ts = game:GetService("TweenService")
--local currentCamera = game.Workspace.CurrentCamera

--local cameras = game.Workspace.Cameras

--char.Hum
--currentCamera.CameraType = Enum.CageType.Scriptable
--currentCamera.CFrame = game.Workspace.Cameras.startPos.CFrame



-- Attach WaterStar to character
local function onCharacterAdded(character)
        local elements = ReplicatedStorage.Elements
        local waterElem = elements and elements.WaterElem
	local waterStarTemplate = waterElem:FindFirstChild("WaterStar")

	if not waterStarTemplate then
		warn("WaterStar template not found in WaterElem!")
		return
	end

	local waterStarClone = waterStarTemplate:Clone()
	waterStarClone.Name = "WaterStarClone"
	waterStarClone.Parent = character
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Merch touch region
local function setupRegion(region: BasePart)
        if not MerchBooth then return end
        region.Touched:Connect(function(otherPart)
                local character = Players.LocalPlayer.Character
                if character and otherPart == character.PrimaryPart then
                        MerchBooth.openMerchBooth()
                end
        end)
        region.TouchEnded:Connect(function(otherPart)
                local character = Players.LocalPlayer.Character
                if character and otherPart == character.PrimaryPart then
                        MerchBooth.closeMerchBooth()
                end
        end)
end

for _, region in CollectionService:GetTagged("ShopRegion") do
        setupRegion(region)
end
CollectionService:GetInstanceAddedSignal("ShopRegion"):Connect(setupRegion)

ActionUI.init()

-- Extended Slide behavior (1.5s duration, increased movement)
CombatController.setSlideDuration(1.5)
CombatController.setSlideSpeedMultiplier(2.0)

-- Print Game Settings debug info
print("Game Title:", GameSettings.gameName)
print("Developer:", GameSettings.developerName)
print("Stamina Upgrade Cost (5):", GameSettings.staminaUpgradeCost(5))
print("Jump Power at Level 3:", GameSettings.jumpPower(1))
print("Health at Level 3:", GameSettings.health(3))
