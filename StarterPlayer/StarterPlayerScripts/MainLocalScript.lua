-- MainLocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local Abilities = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("Abilities"))
local AudioPlayer = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("AudioPlayer"))
local CharacterManager = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("CharacterManager"))
local CombatController = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("CombatController"))
local merchModule = ReplicatedStorage:FindFirstChild("MerchBooth")
local MerchBooth = merchModule and require(merchModule)
local GameSettings = require(ReplicatedStorage:WaitForChild("GameSettings"))

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

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

-- Connect GUI buttons
local actions = PlayerGui.ScreenGui.Actions
local actionMap = {
	PunchButton = "Punch",
	KickButton = "Kick",
	RollButton = "Roll",
	CrouchButton = "Crouch",
	SlideButton = "Slid"
}

for buttonName, action in pairs(actionMap) do
	actions[buttonName].Activated:Connect(function()
		print("Button pressed for action:", action)
		CombatController.perform(action)
	end)
end

actions.TossButton.Activated:Connect(Abilities.Toss)
actions.StarButton.Activated:Connect(Abilities.Star)
actions.RainButton.Activated:Connect(Abilities.Rain)
actions.BeastButton.Activated:Connect(Abilities.Beast)
actions.DragonButton.Activated:Connect(Abilities.Dragon)

-- Connect all ability keybinds
local abilityKeybinds = {
	[Enum.KeyCode.F] = Abilities.Toss,
	[Enum.KeyCode.G] = Abilities.Star,
	[Enum.KeyCode.Z] = Abilities.Rain,
	[Enum.KeyCode.B] = Abilities.Beast,
	[Enum.KeyCode.X] = Abilities.Dragon
}

-- Connect combat keybinds
local combatKeybinds = {
	[Enum.KeyCode.E] = "Punch",
	[Enum.KeyCode.T] = "Punch",
	[Enum.KeyCode.Q] = "Kick",
	[Enum.KeyCode.R] = "Roll",
	[Enum.KeyCode.C] = "Crouch",
	[Enum.KeyCode.LeftControl] = "Slid"
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	print("?? Raw KeyCode input:", input.KeyCode.Name)

	if abilityKeybinds[input.KeyCode] then
		print("Triggering ability for:", input.KeyCode.Name)
		abilityKeybinds[input.KeyCode]()
		return
	end

	if combatKeybinds[input.KeyCode] then
		local action = combatKeybinds[input.KeyCode]
		print("Triggering combat action for:", action)
		if not CombatController or not CombatController.perform then
			warn("CombatController or perform method is nil!")
			return
		end
		print("Calling CombatController.perform with:", action)
		CombatController.perform(action)
		return
	end

	print("? Key pressed but no action mapped:", input.KeyCode.Name)
end)

-- Extended Slide behavior (1.5s duration, increased movement)
CombatController.setSlideDuration(1.5)
CombatController.setSlideqSpeedMultiplier(2.0)

-- Print Game Settings debug info
print("Game Title:", GameSettings.gameName)
print("Developer:", GameSettings.developerName)
print("Stamina Upgrade Cost (5):", GameSettings.staminaUpgradeCost(5))
print("Jump Power at Level 3:", GameSettings.jumpPower(1))
print("Health at Level 3:", GameSettings.health(3))
