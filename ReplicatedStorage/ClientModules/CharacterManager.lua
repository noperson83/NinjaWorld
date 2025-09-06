-- CharacterManager Module
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterManager = {}

CharacterManager.character = nil
CharacterManager.humanoid = nil
CharacterManager.humanoidRoot = nil
CharacterManager.animator = nil
CharacterManager.rightArm = nil
CharacterManager.starModel = nil

function CharacterManager.setup(player)
	local function updateCharacterReferences()
		CharacterManager.character = player.Character or player.CharacterAdded:Wait()
		CharacterManager.humanoidRoot = CharacterManager.character:WaitForChild("HumanoidRootPart")
		CharacterManager.humanoid = CharacterManager.character:WaitForChild("Humanoid")
		CharacterManager.animator = CharacterManager.humanoid:WaitForChild("Animator")
		CharacterManager.rightArm = CharacterManager.character:FindFirstChild("RightUpperArm") or CharacterManager.character:WaitForChild("RightUpperArm")

		local elements = ReplicatedStorage:WaitForChild("Elements")
		local waterElem = elements:WaitForChild("WaterElem")
		CharacterManager.starModel = waterElem:FindFirstChild("WaterStar")

		if not CharacterManager.starModel then
			warn("?? WaterStar not found in WaterElem")
		end

		-- ? Init animations only after character + animator are ready
		local success, CombatController = pcall(function()
			return require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("CombatController"))
		end)
		if success then
			CombatController.initAnimations()
		else
			warn("?? Could not require CombatController for animation init")
		end
	end

	updateCharacterReferences()
	player.CharacterAdded:Connect(updateCharacterReferences)
end

return CharacterManager