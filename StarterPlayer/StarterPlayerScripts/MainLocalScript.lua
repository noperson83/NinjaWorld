-- MainLocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")

local Abilities = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("Abilities"))
local AudioPlayer = require(ReplicatedStorage.ClientModules.AudioPlayer)
local CharacterManager = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("CharacterManager"))
local CombatController = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("CombatController"))
local merchModule = ReplicatedStorage:FindFirstChild("MerchBooth")
local MerchBooth = merchModule and require(merchModule)
local GameSettings = require(ReplicatedStorage:WaitForChild("GameSettings"))

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local ActionUI = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("UI"):WaitForChild("ActionUI"))

-- Preload and validate audio assets
-- Purge placeholder sounds before preloading
for _, descendant in ipairs(SoundService:GetDescendants()) do
    if descendant:IsA("Sound") and descendant.SoundId:match("rbxassetid://0") then
        -- Replace placeholder/invalid sound IDs with a valid asset
        descendant.SoundId = "rbxassetid://81165228663280"
    end
end

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

--local cameras = game.Workspace:WaitForChild("cameras")

--char.Hum
--currentCamera.CameraType = Enum.CageType.Scriptable
--currentCamera.CFrame = game.Workspace.Cameras.startPos.CFrame



-- Attach WaterStar to character
local function onCharacterAdded(character)
	local elements = ReplicatedStorage:WaitForChild("Elements")
	local waterElem = elements:WaitForChild("WaterElem")
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
