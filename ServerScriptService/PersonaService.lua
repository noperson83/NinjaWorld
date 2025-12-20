--[[
	PersonaService.lua - Server-side handler for persona operations
	Place in ServerScriptService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)

local PersonaService = {}

-- Create RemoteFunction
local personaRF = Instance.new("RemoteFunction")
personaRF.Name = "PersonaServiceRF"
personaRF.Parent = ReplicatedStorage

local ReleaseIntroEvent = ReplicatedStorage:FindFirstChild("ReleaseIntro")

-- Example function called when a new persona is activated for a player
local function onPersonaStarted(player)
	if ReleaseIntroEvent then
		ReleaseIntroEvent:FireClient(player)
	else
		warn("[PersonaService] ReleaseIntro RemoteEvent not found.")
	end
end

-- ============================================================================
-- CHARACTER APPEARANCE HELPERS
-- ============================================================================

local function getPersonaDescription(personaType, userId)
	if personaType == "Ninja" then
		-- Ninja persona uses a custom character model, not HumanoidDescription
		return nil
	else
		-- Get player's Roblox avatar
		local success, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(userId)
		end)

		if success then
			return desc
		else
			warn(("PersonaService: Failed to get avatar for user %d: %s"):format(userId, desc))
			return nil
		end
	end
end

local function isNinjaCharacter(character)
	if not character then return false end
	-- Check for a tag or unique property to identify Ninja model
	local personaTypeValue = character:FindFirstChild("PersonaType")
	if personaTypeValue and personaTypeValue:IsA("StringValue") and personaTypeValue.Value == "Ninja" then
		return true
	end
	-- Fallback: check if model name is "Ninja" and has a Humanoid
	if character.Name == "Ninja" then
		return true
	end
	return false
end

local function removeOldCharacter(player)
	local character = player.Character
	if character and character.Parent == workspace then
		character:Destroy()
	end
end

local function getNinjaModel()
	local avatarsFolder = ReplicatedStorage:FindFirstChild("Avatars")
	if avatarsFolder then
		local ninjaModel = avatarsFolder:FindFirstChild("Ninja")
		if ninjaModel then return ninjaModel end
		local ninja1Model = avatarsFolder:FindFirstChild("Ninja1")
		if ninja1Model then return ninja1Model end
	end
	local wsAvatars = workspace:FindFirstChild("Avatars")
	if wsAvatars then
		local ninjaModel = wsAvatars:FindFirstChild("Ninja")
		if ninjaModel then return ninjaModel end
		local ninja1Model = wsAvatars:FindFirstChild("Ninja1")
		if ninja1Model then return ninja1Model end
	end
	return nil
end

local function playNinjaIdleAnimation(character)
	-- Play idle animation on Ninja model's Humanoid
	if not character then return end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Ensure Animator exists
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Find idle animation asset from ReplicatedStorage.Avatars.AnimateScript.idle.Animation1
	local avatarsFolder = ReplicatedStorage:FindFirstChild("Avatars")
	if not avatarsFolder then return end
	local animateScript = avatarsFolder:FindFirstChild("AnimateScript")
	if not animateScript then return end
	local idleFolder = animateScript:FindFirstChild("idle")
	if not idleFolder then return end
	local idleAnim = idleFolder:FindFirstChild("Animation1")
	if not idleAnim then return end
	if not idleAnim:IsA("Animation") then return end

	local animation = Instance.new("Animation")
	animation.AnimationId = idleAnim.AnimationId
	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if success and track then
		track.Looped = true
		track:Play()
	else
		warn("PersonaService: Failed to load or play Ninja idle animation")
	end
end

local function attachAnimateScript(character)
	-- Attach Roblox Animate script to character for proper movement animations
	if not character then return end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Remove any existing Animate scripts to avoid duplicates
	for _, child in character:GetChildren() do
		if child:IsA("LocalScript") and child.Name == "Animate" then
			child:Destroy()
		end
	end

	-- Try to get a custom AnimateScript from ReplicatedStorage.Avatars
	local avatarsFolder = ReplicatedStorage:FindFirstChild("Avatars")
	local animateScriptTemplate = nil
	if avatarsFolder then
		animateScriptTemplate = avatarsFolder:FindFirstChild("AnimateScript")
	end

	if animateScriptTemplate and animateScriptTemplate:IsA("LocalScript") then
		local animateScript = animateScriptTemplate:Clone()
		animateScript.Name = "Animate"
		animateScript.Parent = character
	else
		-- Fallback: create a default Animate script
		local animateScript = Instance.new("LocalScript")
		animateScript.Name = "Animate"
		animateScript.Parent = character
		animateScript.Source = [[
			local humanoid = script.Parent:FindFirstChild("Humanoid")
			if not humanoid then return end
			local animate = require(game:GetService("StarterCharacterScripts"):WaitForChild("Animate"))
			animate(humanoid)
		]]
	end
end

local function robustSetCharacter(player, newCharacter)
	-- Helper to robustly assign a new character model to the player
	-- 1. Parent to workspace
	-- 2. Set CFrame before assignment
	-- 3. Assign to player.Character
	local function ensureCharacterCanMove(character)
		-- Some template rigs are stored with anchored parts to display them in Studio.
		-- Clear anchors and any immobilizing states so movement/jumps work after cloning.
		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = false
			end
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
			humanoid.Sit = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end

	ensureCharacterCanMove(newCharacter)
	newCharacter.Parent = workspace
	local hrp = newCharacter:FindFirstChild("HumanoidRootPart")
	if hrp then
		-- Try to use a SpawnLocation if available, else default position
		local spawnCFrame = CFrame.new(0, 15, 0)
		local spawnLocation = workspace:FindFirstChild("SpawnLocation")
		if spawnLocation and spawnLocation:IsA("BasePart") then
			spawnCFrame = spawnLocation.CFrame
		end
		hrp.CFrame = spawnCFrame
	end
	ensureCharacterCanMove(newCharacter)
	player.Character = newCharacter
	-- Attach Animate script for movement animations
	attachAnimateScript(newCharacter)
	-- Play idle animation if Ninja
	playNinjaIdleAnimation(newCharacter)
end

-- UPGRADED FUNCTION
local function applyPersonaToCharacter(player, personaType)
	-- This function robustly applies the requested persona to the player's character.
	local character = player.Character
	if not character or not character.Parent then
		-- If no character, try to respawn
		if personaType == "Ninja" then
			local ninjaModel = getNinjaModel()
			if not ninjaModel then
				warn("PersonaService: Ninja model not found in ReplicatedStorage.Avatars or Workspace.Avatars")
				return false
			end
			local newCharacter = ninjaModel:Clone()
			newCharacter.Name = player.Name
			local personaTypeValue = Instance.new("StringValue")
			personaTypeValue.Name = "PersonaType"
			personaTypeValue.Value = "Ninja"
			personaTypeValue.Parent = newCharacter
			local newHumanoid = newCharacter:FindFirstChild("Humanoid")
			local newHRP = newCharacter:FindFirstChild("HumanoidRootPart")
			if not newHumanoid or not newHRP then
				warn("PersonaService: Ninja model missing Humanoid or HumanoidRootPart")
				return false
			end
			robustSetCharacter(player, newCharacter)
			return true
		else
			player:LoadCharacter()
			task.wait(0.1)
			local newChar = player.Character
			if not newChar then
				warn("PersonaService: Could not load character for Roblox persona")
				return false
			end
			local humanoid = newChar:FindFirstChild("Humanoid")
			if not humanoid then
				warn("PersonaService: No humanoid found for Roblox persona")
				return false
			end
			local desc = getPersonaDescription(personaType, player.UserId)
			if not desc then
				return false
			end
			local success, err = pcall(function()
				humanoid:ApplyDescription(desc)
			end)
			if not success then
				warn(("PersonaService: Failed to apply description: %s"):format(err))
				return false
			end
			return true
		end
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		warn("PersonaService: No humanoid found for " .. player.Name)
		return false
	end

	if personaType == "Ninja" then
		-- Prevent replacing if already Ninja
		if isNinjaCharacter(character) then
			print("PersonaService: Character is already Ninja for", player.Name)
			attachAnimateScript(character)
			playNinjaIdleAnimation(character)
			return true
		end
		-- Remove old character
		removeOldCharacter(player)
		-- Replace character with Ninja model
		local ninjaModel = getNinjaModel()
		if not ninjaModel then
			warn("PersonaService: Ninja model not found in ReplicatedStorage.Avatars or Workspace.Avatars")
			return false
		end
		local newCharacter = ninjaModel:Clone()
		newCharacter.Name = player.Name
		local personaTypeValue = Instance.new("StringValue")
		personaTypeValue.Name = "PersonaType"
		personaTypeValue.Value = "Ninja"
		personaTypeValue.Parent = newCharacter
		local newHumanoid = newCharacter:FindFirstChild("Humanoid")
		local newHRP = newCharacter:FindFirstChild("HumanoidRootPart")
		if not newHumanoid or not newHRP then
			warn("PersonaService: Ninja model missing Humanoid or HumanoidRootPart")
			return false
		end
		robustSetCharacter(player, newCharacter)
		return true
	end

	-- Roblox persona
	local desc = getPersonaDescription(personaType, player.UserId)
	if not desc then
		return false
	end

	local success, err = pcall(function()
		humanoid:ApplyDescription(desc)
	end)

	if not success then
		warn(("PersonaService: Failed to apply description: %s"):format(err))
		return false
	end

	return true
end

local function respawnPlayerWithPersona(player, personaType)
	-- Load the character with the persona
	if personaType == "Ninja" then
		-- Remove old character (if not already being replaced by Roblox)
		removeOldCharacter(player)
		-- For Ninja, replace character with Ninja model
		local ninjaModel = getNinjaModel()
		if not ninjaModel then
			warn("PersonaService: Ninja model not found in ReplicatedStorage.Avatars or Workspace.Avatars")
			return
		end
		local newCharacter = ninjaModel:Clone()
		newCharacter.Name = player.Name
		local personaTypeValue = Instance.new("StringValue")
		personaTypeValue.Name = "PersonaType"
		personaTypeValue.Value = "Ninja"
		personaTypeValue.Parent = newCharacter
		local newHumanoid = newCharacter:FindFirstChild("Humanoid")
		local newHRP = newCharacter:FindFirstChild("HumanoidRootPart")
		if newHumanoid and newHRP then
			robustSetCharacter(player, newCharacter)
		else
			warn("PersonaService: Ninja model missing Humanoid or HumanoidRootPart")
		end
	else
		-- For Roblox avatar, just respawn normally
		player:LoadCharacter()
	end
end

-- ============================================================================
-- ACTION HANDLERS
-- ============================================================================

local actions = {}

function actions.get(player)
	local data = DataService:GetPlayerData(player)
	return {
		activeSlot = data.activeSlot,
		slots = data.slots,
		slotCount = data.slotCount or 3
	}
end

function actions.save(player, requestData)
	if not requestData or not requestData.slot or not requestData.type then
		return {ok = false, error = "Missing slot or type"}
	end

	local slotIndex = tonumber(requestData.slot)
	if not slotIndex or slotIndex < 1 or slotIndex > 3 then
		return {ok = false, error = "Invalid slot"}
	end

	local personaType = requestData.type
	if personaType ~= "Ninja" and personaType ~= "Roblox" then
		return {ok = false, error = "Invalid type"}
	end

	-- Get current level
	local stats = player:FindFirstChild("Stats")
	local levelValue = stats and stats:FindFirstChild("Level")
	local level = levelValue and levelValue.Value or player:GetAttribute("Level") or 1

	-- Get current session data
	local sessionData = DataService:GetSessionData(player.UserId)

	-- Save slot
	local success = DataService:SaveSlot(player, slotIndex, {
		type = personaType,
		level = level,
		inventory = sessionData and sessionData.inventory or {},
		unlockedRealms = sessionData and sessionData.unlockedRealms or {},
		unlockedSpawns = sessionData and sessionData.unlockedSpawns or {},
		rebirths = sessionData and sessionData.rebirths or 0,
		createdAt = os.time()
	})

	if not success then
		return {ok = false, error = "Failed to save"}
	end

	-- Return updated data
	local data = DataService:GetPlayerData(player)
	return {
		ok = true,
		activeSlot = data.activeSlot,
		slots = data.slots,
		slotCount = data.slotCount or 3
	}
end

function actions.use(player, requestData)
	if not requestData or not requestData.slot then
		return {ok = false, error = "Missing slot"}
	end

	local slotIndex = tonumber(requestData.slot)
	if not slotIndex or slotIndex < 1 or slotIndex > 3 then
		return {ok = false, error = "Invalid slot"}
	end

	local data = DataService:GetPlayerData(player)
	local slotData = data.slots[tostring(slotIndex)]

	if not slotData then
		return {ok = false, error = "Slot is empty"}
	end

	-- Set active slot
	local success = DataService:SetActiveSlot(player, slotIndex)
	if not success then
		return {ok = false, error = "Failed to set active slot"}
	end

	-- Apply the persona appearance to character
	local personaType = slotData.type or "Ninja"

	-- Try to apply to current character first
	local applied = applyPersonaToCharacter(player, personaType)

	-- If that fails or no character, respawn
	if not applied then
		spawn(function()
			task.wait(0.1)
			respawnPlayerWithPersona(player, personaType)
		end)
	end
	onPersonaStarted(player)
	return {
		ok = true,
		persona = slotData,
		activeSlot = slotIndex
	}
end

function actions.clear(player, requestData)
	if not requestData or not requestData.slot then
		return {ok = false, error = "Missing slot"}
	end

	local slotIndex = tonumber(requestData.slot)
	if not slotIndex or slotIndex < 1 or slotIndex > 3 then
		return {ok = false, error = "Invalid slot"}
	end

	local success = DataService:ClearSlot(player, slotIndex)
	if not success then
		return {ok = false, error = "Failed to clear slot"}
	end

	-- Return updated data
	local data = DataService:GetPlayerData(player)
	return {
		ok = true,
		activeSlot = data.activeSlot,
		slots = data.slots,
		slotCount = data.slotCount or 3
	}
end

-- ============================================================================
-- REMOTEFUNCTION HANDLER
-- ============================================================================

function personaRF.OnServerInvoke(player, action, data)
	if not actions[action] then
		warn(("PersonaService: Unknown action '%s'"):format(tostring(action)))
		return {ok = false, error = "Unknown action"}
	end

	local success, result = pcall(actions[action], player, data)
	if not success then
		warn(("PersonaService: Action '%s' error: %s"):format(action, result))
		return {ok = false, error = "Internal error"}
	end

	return result
end

-- ============================================================================
-- CHARACTER SPAWN HANDLER
-- ============================================================================

-- Apply saved persona when player spawns
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- Wait a moment for character to fully load
		task.wait(0.1)

		-- Get active persona
		local data = DataService:GetPlayerData(player)
		if data.activeSlot then
			local slotData = data.slots[tostring(data.activeSlot)]
			if slotData and slotData.type then
				if slotData.type == "Ninja" then
					-- Prevent infinite loop: only replace if not already Ninja
					if isNinjaCharacter(character) then
						-- Already Ninja, just attach Animate and play idle animation
						attachAnimateScript(character)
						playNinjaIdleAnimation(character)
					else
						-- Destroy and replace with Ninja model
						if character and character.Parent == workspace then
							character:Destroy()
						end
						local ninjaModel = getNinjaModel()
						if ninjaModel then
							local newCharacter = ninjaModel:Clone()
							newCharacter.Name = player.Name
							local personaTypeValue = Instance.new("StringValue")
							personaTypeValue.Name = "PersonaType"
							personaTypeValue.Value = "Ninja"
							personaTypeValue.Parent = newCharacter
							local newHumanoid = newCharacter:FindFirstChild("Humanoid")
							local newHRP = newCharacter:FindFirstChild("HumanoidRootPart")
							if newHumanoid and newHRP then
								robustSetCharacter(player, newCharacter)
							else
								warn("PersonaService: Ninja model missing Humanoid or HumanoidRootPart")
							end
						else
							warn("PersonaService: Ninja model not found in ReplicatedStorage.Avatars or Workspace.Avatars")
						end
					end
				else
					applyPersonaToCharacter(player, slotData.type)
				end
			end
		end
	end)
end)

return PersonaService
