local BootUI = {}

-- =====================
-- Services & locals
-- =====================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local TeleportService   = game:GetService("TeleportService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local HttpService       = game:GetService("HttpService")

local player  = Players.LocalPlayer
local rf      = nil
local cam     = Workspace.CurrentCamera
local enterRE -- RemoteEvent created by Init.server.lua
local lastFreezeRestore

BootUI.setDebugLine = function()
end

local function getEnterRemote()
	if enterRE and enterRE.Parent then
		return enterRE
	end

	local remote = ReplicatedStorage:FindFirstChild("EnterDojoRE")
	if not remote then
		local ok, result = pcall(function()
			return ReplicatedStorage:WaitForChild("EnterDojoRE", 5)
		end)
		if ok then
			remote = result
		end
	end

	if remote and remote:IsA("RemoteEvent") then
		enterRE = remote
		return enterRE
	end

	if remote and not remote:IsA("RemoteEvent") then
		warn("BootUI: EnterDojoRE exists but is a " .. remote.ClassName)
	end

	return nil
end

local function getPlayerGui()
        if not player then
                player = Players.LocalPlayer
        end
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

local GameSettings = require(ReplicatedStorage.GameSettings)
local DEFAULT_SLOT_COUNT = tonumber(GameSettings.maxSlots) or 3

local function freezeCharacter()
        if lastFreezeRestore then
                lastFreezeRestore()
                lastFreezeRestore = nil
        end

        if not player then
                player = Players.LocalPlayer
        end

        local currentPlayer = player
        if not currentPlayer then
                return function() end
        end

        local character = currentPlayer.Character
        if not character then
                local ok, newChar = pcall(function()
                        return currentPlayer.CharacterAdded:Wait()
                end)
                if ok then
                        character = newChar
                end
        end

        if not character then
                return function() end
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoid then
                return function() end
        end

        local original = {
                walkSpeed = humanoid.WalkSpeed,
                autoRotate = humanoid.AutoRotate,
                jumpPower = humanoid.JumpPower,
                jumpHeight = humanoid.JumpHeight,
                hrpAnchored = rootPart and rootPart.Anchored or false,
        }

        humanoid.WalkSpeed = 0
        if humanoid.UseJumpPower ~= false then
                humanoid.JumpPower = 0
        else
                humanoid.JumpHeight = 0
        end
        humanoid.AutoRotate = false

        if rootPart then
                rootPart.Anchored = true
                rootPart.AssemblyLinearVelocity = Vector3.zero
                rootPart.AssemblyAngularVelocity = Vector3.zero
        end

        local restored = false
        local restoreConn

        local function restore()
                if restored then
                        return
                end
                restored = true

                if humanoid.Parent then
                        humanoid.WalkSpeed = original.walkSpeed or humanoid.WalkSpeed
                        if humanoid.UseJumpPower ~= false then
                                humanoid.JumpPower = original.jumpPower or humanoid.JumpPower
                        else
                                humanoid.JumpHeight = original.jumpHeight or humanoid.JumpHeight
                        end
                        humanoid.AutoRotate = original.autoRotate ~= nil and original.autoRotate or humanoid.AutoRotate
                end

                if rootPart and rootPart.Parent then
                        rootPart.Anchored = original.hrpAnchored
                end

                if restoreConn then
                        restoreConn:Disconnect()
                        restoreConn = nil
                end

                if lastFreezeRestore == restore then
                        lastFreezeRestore = nil
                end
        end

        restoreConn = currentPlayer.CharacterAdded:Connect(function()
                restore()
        end)

        lastFreezeRestore = restore

        task.delay(12, restore)

        return restore
end

BootUI.freezeCharacter = freezeCharacter

local function getPersonaRemote()
	if rf and rf.Parent then
		return rf
	end
	rf = ReplicatedStorage:FindFirstChild("PersonaServiceRF")
	if not rf then
		rf = ReplicatedStorage:WaitForChild("PersonaServiceRF", 5)
	end
	if not rf then
		warn("BootUI: PersonaServiceRF missing")
	end
	return rf
end

local function sanitizePersonaData(data)
	local result = {}

	if typeof(data) == "table" then
		for key, value in pairs(data) do
			if key ~= "slots" then
				result[key] = value
			end
		end
		if typeof(data.slots) == "table" then
			result.slots = data.slots
		end
	end

	if typeof(result.slots) ~= "table" then
		result.slots = {}
	end

	local slotCount = tonumber(result.slotCount)
	if not slotCount then
		local highest = 0
		for key in pairs(result.slots) do
			local idx = tonumber(key)
			if idx and idx > highest then
				highest = idx
			end
		end
		slotCount = highest
	end

	if not slotCount or slotCount < 0 then
		slotCount = 0
	end
	if slotCount == 0 and DEFAULT_SLOT_COUNT > 0 then
		slotCount = DEFAULT_SLOT_COUNT
	end

	result.slotCount = slotCount

	return result
end

local function profileRF(action, data)
	local remote = getPersonaRemote()
	if not remote then
		warn("PersonaServiceRF unavailable for action", action)
		return nil
	end
	local start = os.clock()
	local ok, result = pcall(remote.InvokeServer, remote, action, data)
	if not ok then
		warn(string.format("PersonaServiceRF:%s failed: %s", tostring(action), tostring(result)))
		return nil
	end
	warn(string.format("PersonaServiceRF:%s took %.3fs", tostring(action), os.clock() - start))
	return result
end

function BootUI.fetchData()
	local persona = profileRF("get", {})
	persona = sanitizePersonaData(persona)
	local inventory
	local invStr = player:GetAttribute("Inventory")
	if typeof(invStr) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, invStr)
		if ok then
			inventory = decoded
		end
	end
	return {
		inventory = inventory,
		personaData = persona,
	}
end

-- =====================
-- Module requires
-- =====================
local Cosmetics       = require(ReplicatedStorage.BootModules.Cosmetics)
local CurrencyService = require(ReplicatedStorage.BootModules.CurrencyService)
local Shop            = require(ReplicatedStorage.BootModules.Shop)
local AbilityUI       = require(ReplicatedStorage.BootModules.AbilityUI)
local IntroCamera     = require(ReplicatedStorage.BootModules.IntroCamera)
local WorldHUD        = require(ReplicatedStorage.ClientModules.UI.WorldHUD)
local TeleportClient  = require(ReplicatedStorage.ClientModules.TeleportClient)
local DojoClient      = require(ReplicatedStorage.BootModules.DojoClient)

function BootUI.unlockRealm(name)
	TeleportClient.unlockRealm(name)
end

function BootUI.getHUD()
	return BootUI.hud
end

function BootUI.showLoadout()
	local hud = BootUI.hud
	if hud and hud.showLoadout then
		hud:showLoadout()
	elseif BootUI.loadout then
		BootUI.loadout.Visible = true
	end
end

function BootUI.hideLoadout()
	local hud = BootUI.hud
	if hud and hud.hideLoadout then
		hud:hideLoadout()
	elseif BootUI.loadout then
		BootUI.loadout.Visible = false
	end
end

function BootUI.setShopButtonVisible(visible)
	local hud = BootUI.hud
	if hud and hud.setShopButtonVisible then
		hud:setShopButtonVisible(visible)
	elseif BootUI.shopBtn then
		BootUI.shopBtn.Visible = visible and true or false
	end
end

function BootUI.toggleShop(defaultTab)
        local hud = BootUI.hud
        if hud and hud.toggleShop then
                local visible = hud:toggleShop(defaultTab)
                BootUI.shopFrame = hud.shopFrame
                return visible
        end
end

function BootUI.isAbilityUIVisible()
        local abilityUI = BootUI.abilityUI
        if not abilityUI then
                return false
        end

        if typeof(abilityUI.isVisible) == "function" then
                local ok, result = pcall(function()
                        return abilityUI:isVisible()
                end)
                if ok then
                        return result and true or false
                end
        end

        local frame = abilityUI.frame
        return (frame and frame.Visible) or false
end

function BootUI.hideAbilityUI()
        local abilityUI = BootUI.abilityUI
        if not abilityUI then
                return
        end

        if typeof(abilityUI.hide) == "function" then
                abilityUI:hide()
        elseif abilityUI.frame then
                abilityUI.frame.Visible = false
        end
end

function BootUI.showAbilityUI()
        local abilityUI = BootUI.abilityUI
        if not abilityUI then
                return
        end

        if typeof(abilityUI.show) == "function" then
                abilityUI:show()
        elseif abilityUI.frame then
                abilityUI.frame.Visible = true
        end
end

function BootUI.toggleAbilityUI()
        local abilityUI = BootUI.abilityUI
        if not abilityUI then
                return false
        end

        if typeof(abilityUI.toggle) == "function" then
                local ok, result = pcall(function()
                        return abilityUI:toggle()
                end)
                if ok then
                        return result and true or false
                end
        elseif abilityUI.frame then
                abilityUI.frame.Visible = not abilityUI.frame.Visible
                return abilityUI.frame.Visible
        end

        return false
end

local function ensureAbilityInterface()
        if BootUI.abilityInterface then
                return BootUI.abilityInterface
        end

        local interface = {
                show = function()
                        BootUI.showAbilityUI()
                end,
                hide = function()
                        BootUI.hideAbilityUI()
                end,
                toggle = function()
                        return BootUI.toggleAbilityUI()
                end,
                isVisible = function()
                        return BootUI.isAbilityUIVisible()
                end,
        }

        BootUI.abilityInterface = interface
        return interface
end

function BootUI.populateBackpackUI(data)
        local hud = BootUI.hud
        if hud and hud.setBackpackData then
                hud:setBackpackData(data)
        end
end

function BootUI.applyFetchedData(data)
	data = data or {}

	BootUI.config = BootUI.config or {}

	local inventory = data.inventory
	if typeof(inventory) == "table" then
		BootUI.config.inventory = inventory
		BootUI.StarterBackpack = inventory
		BootUI.populateBackpackUI(inventory)
	end

	local personaData = data.personaData
	if personaData ~= nil then
		local sanitized = sanitizePersonaData(personaData)
		BootUI.config.personaData = sanitized
		BootUI.personaData = sanitized
                if typeof(Cosmetics.refreshSlots) == "function" then
                        Cosmetics.refreshSlots(sanitized)
                end
                if typeof(Cosmetics.showDojoPicker) == "function" then
                        Cosmetics.showDojoPicker()
                end
	end
end

function BootUI.getSelectedRealm()
	local hud = BootUI.hud
	if hud and hud.getSelectedRealm then
		return hud:getSelectedRealm()
	end
end

function BootUI.getRealmDisplayName(realmKey)
	local hud = BootUI.hud
	if hud and hud.getRealmDisplayName then
		return hud:getRealmDisplayName(realmKey)
	end
end

function BootUI.destroyHUD()
	local hud = BootUI.hud
	if hud and hud.destroy then
		hud:destroy()
	end
	BootUI.hud = nil
end

function BootUI.hideOverlay()
        if BootUI.introGui then
                BootUI.introGui.Enabled = false
        end
        BootUI.hideAbilityUI()
end

function BootUI.destroy()
        BootUI.hideOverlay()
        local abilityUI = BootUI.abilityUI
        if abilityUI and typeof(abilityUI.destroy) == "function" then
                abilityUI:destroy()
        end
        BootUI.abilityUI = nil
        if BootUI.abilityInterface then
                BootUI.abilityInterface.frame = nil
        end
end

local currencyService

function BootUI.start(config)
	config = config or {}
	config.showShop = config.showShop or false
	BootUI.config = config
	-- Ninja World EXP 3000
	-- Boot.client.lua – v7.4
	-- Changes from v7.3:
	--  • Viewport: avatar now faces the camera by default (yaw = π)
	--  • Emote bar across the top of Loadout to animate preview (Wave / Point / Dance / Laugh / Cheer / Sit / Idle)
	--  • Minor: consistent 0.6 transparency panels, plus small cleanups

	-- =====================
        currencyService = CurrencyService.new(config)
        local shop            = Shop.new(config, currencyService)
        local abilityInterface = ensureAbilityInterface()
        BootUI.currencyService = currencyService
        BootUI.shop = shop

        local hud = WorldHUD.new(config, {
                currencyService = currencyService,
                shop = shop,
                abilityInterface = abilityInterface,
        })
        BootUI.hud = hud
        BootUI.loadout = hud and hud:getLoadoutFrame() or nil
        BootUI.shopBtn = hud and hud:getShopButton() or nil
        BootUI.shopFrame = hud and hud.shopFrame or nil

	local questInterface = hud and hud:getQuestInterface() or nil
	BootUI.questInterface = questInterface
	BootUI.buildCharacterPreview = questInterface and questInterface.buildCharacterPreview or nil

	-- connect currency updates after service is created so backpack UI stays in sync
	currencyService.BalanceChanged.Event:Connect(function(coins, orbs, elements)
		local currentHud = BootUI.hud
		if currentHud then
			currentHud:updateCurrency(coins, orbs, elements)
		end
	end)

	-- =====================
	-- Config
	-- =====================
	local CAM_TWEEN_TIME = 1.6

	local StarterBackpack = config.inventory or config.starterBackpack or {
		capacity = 20,
		weapons = {},
		food = {},
		special = {},
		coins = 0,
		orbs = {},
	}
	BootUI.StarterBackpack = StarterBackpack
	BootUI.personaData = config.personaData

	local cosmeticsInterface = {}
	if hud and hud.createCosmeticsInterface then
		cosmeticsInterface = hud:createCosmeticsInterface() or {}
	end

	if not cosmeticsInterface.showDojoPicker then
		cosmeticsInterface.showDojoPicker = function()
			BootUI.hideLoadout()
			BootUI.setShopButtonVisible(false)
		end
	end

	if not cosmeticsInterface.showLoadout then
		cosmeticsInterface.showLoadout = function(personaType)
			BootUI.showLoadout()
			BootUI.setShopButtonVisible(true)
		end
	end

	if not cosmeticsInterface.updateBackpack then
		cosmeticsInterface.updateBackpack = function(data)
			BootUI.populateBackpackUI(data)
		end
	end

	if not cosmeticsInterface.buildCharacterPreview then
		cosmeticsInterface.buildCharacterPreview = function(personaType)
			local builder = BootUI.buildCharacterPreview
			if builder then
				builder(personaType)
			end
		end
	end

	if not cosmeticsInterface.getStarterBackpack then
		cosmeticsInterface.getStarterBackpack = function()
			return BootUI.StarterBackpack
		end
	end

	BootUI.cosmeticsInterface = cosmeticsInterface

	BootUI.populateBackpackUI(config.inventory)


        -- =====================
        -- Camera helpers (world)
        -- =====================
        local introCamera = IntroCamera.new({
                workspace = Workspace,
                replicatedStorage = ReplicatedStorage,
                tweenService = TweenService,
                runService = RunService,
        })
        BootUI.introCamera = introCamera

        local pendingIntroOptions
        local pendingReadyDisconnect

        local replayIntroSequence

        local function cloneOptions(options)
                local copy = {}
                if typeof(options) == "table" then
                        for key, value in pairs(options) do
                                copy[key] = value
                        end
                end
                return copy
        end

        local function cancelPendingReplay()
                if pendingReadyDisconnect then
                        pendingReadyDisconnect()
                        pendingReadyDisconnect = nil
                end
        end

        local function getCamera()
                cam = introCamera:getCurrentCamera() or cam or Workspace.CurrentCamera
                return cam
        end

        local function waitForCurrentCamera(timeout)
                cam = introCamera:waitForCamera(timeout) or cam
                return cam
        end

        local function waitForCameraParts(timeout, requireEnd)
                local startPart, endPart = introCamera:waitForParts(timeout, requireEnd)
                return startPart, endPart
        end

        local function applyStartCam()
                if introCamera:applyStartCamera() then
                        cam = getCamera()
                        return true
                end
                return false
        end

        local function holdStartCam(seconds)
                if introCamera:holdStartCamera(seconds) then
                        cam = getCamera()
                        return true
                end
                return false
        end

        local function tweenToEnd()
                local success = select(1, introCamera:tweenToEnd(CAM_TWEEN_TIME))
                if success then
                        cam = getCamera()
                end
                return success
        end
        BootUI.tweenToEnd = tweenToEnd

        if not cosmeticsInterface.tweenToEnd then
                cosmeticsInterface.tweenToEnd = tweenToEnd
        end

        local function scheduleIntroReplay(options)
                cancelPendingReplay()
                pendingIntroOptions = cloneOptions(options)
                pendingReadyDisconnect = introCamera:onReady(function()
                        pendingReadyDisconnect = nil
                        if pendingIntroOptions then
                                local optionsCopy = pendingIntroOptions
                                pendingIntroOptions = nil
                                replayIntroSequence(optionsCopy)
                        end
                end)
        end

        -- Lighting helpers (disable DOF while UI is visible)
        -- =====================
        local savedDOF
        local savedBlurEnabled
        local function getOrCreateBlur()
                local blur = Lighting:FindFirstChild("Blur") or Lighting:FindFirstChildOfClass("BlurEffect")
                if not blur then
                        blur = Instance.new("BlurEffect")
                        blur.Name = "Blur"
                        blur.Enabled = false
                        blur.Parent = Lighting
                end
                return blur
        end
        local function disableUIBlur()
                if savedDOF or savedBlurEnabled ~= nil then return end
                savedDOF = {}
                for _,e in ipairs(Lighting:GetChildren()) do
                        if e:IsA("DepthOfFieldEffect") then
                                savedDOF[e] = e.Enabled
                                e.Enabled = false
                        end
                end
                local blur = getOrCreateBlur()
                if blur then
                        savedBlurEnabled = blur.Enabled
                        blur.Enabled = false
                end
        end
        local function restoreUIBlur()
                if savedDOF then
                        for e,was in pairs(savedDOF) do
                                if e and e.Parent then e.Enabled = was end
                        end
                        savedDOF = nil
                end
                if savedBlurEnabled ~= nil then
                        local blur = getOrCreateBlur()
                        if blur then blur.Enabled = savedBlurEnabled end
                        savedBlurEnabled = nil
                end
        end

        replayIntroSequence = function(options)
                options = options or {}
                local currentCamera = waitForCurrentCamera(options.cameraWait)
                local startPart = waitForCameraParts(options.cameraWait)

                if not startPart then
                        scheduleIntroReplay(options)
                        return
                end

                pendingIntroOptions = nil
                cancelPendingReplay()
                cam = currentCamera or getCamera()
                applyStartCam()
                holdStartCam(options.holdTime or 0.3)
                if options.disableBlur ~= false then
                        disableUIBlur()
                end

                if Cosmetics and typeof(Cosmetics.showDojoPicker) == "function" then
                        Cosmetics.showDojoPicker()
                end

                if Cosmetics and typeof(Cosmetics.refreshSlots) == "function" then
                        local personaData = options.personaData
                        if personaData == nil then
                                personaData = BootUI.personaData
                        end
                        Cosmetics.refreshSlots(personaData)
                end
        end

        BootUI.replayIntroSequence = replayIntroSequence

        local introController = {
                freezeCharacter = freezeCharacter,
                replayIntroSequence = replayIntroSequence,
                disableUIBlur = disableUIBlur,
                restoreUIBlur = restoreUIBlur,
        }

        BootUI.introController = introController

        if hud and hud.setIntroController then
                hud:setIntroController(introController)
        end

        -- =====================
        -- UI root
        -- =====================
        local gui = Instance.new("ScreenGui"); local ui = gui
	ui.ResetOnSpawn   = false
	ui.Name           = "IntroGui"
	ui.IgnoreGuiInset = true
	ui.DisplayOrder   = 100
	local playerGuiParent = getPlayerGui()
	if playerGuiParent then
		ui.Parent = playerGuiParent
	else
		task.spawn(function()
			local target = getPlayerGui()
			if target then
				ui.Parent = target
			end
		end)
	end
	BootUI.introGui   = ui

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1,1)
	root.BackgroundTransparency = 1
	root.Parent = ui

        BootUI.root = root
        Cosmetics.init(config, root, cosmeticsInterface)

        local abilityUI = AbilityUI.init(config, BootUI)
        BootUI.abilityUI = abilityUI
        if BootUI.abilityInterface then
                BootUI.abilityInterface.frame = abilityUI and abilityUI.frame or nil
        end

	getEnterRemote()

	-- Intro visuals
	local fade = Instance.new("Frame")
	fade.Size = UDim2.fromScale(1,1)
	fade.BackgroundColor3 = Color3.new(0,0,0)
	fade.BackgroundTransparency = 1
	fade.ZIndex = 50
	fade.Parent = root

        local personaButton = hud and hud.getPersonaButton and hud:getPersonaButton()
        if personaButton then
                personaButton.MouseButton1Click:Connect(function()
                        local function openDojoPicker()
                                applyStartCam()
                                if typeof(Cosmetics.showDojoPicker) == "function" then
                                        Cosmetics.showDojoPicker()
                                end
                        end

                        local currentHud = BootUI.hud
                        if currentHud and currentHud.promptPersonaChange then
                                currentHud:promptPersonaChange(openDojoPicker)
                        else
                                openDojoPicker()
                        end
                end)
        end

	local enterRealmButton = hud and hud.enterRealmButton
	if enterRealmButton then
		enterRealmButton.MouseButton1Click:Connect(function()
			local realmName = BootUI.getSelectedRealm()
			if not realmName then return end
			local displayName = BootUI.getRealmDisplayName(realmName) or realmName
			DojoClient.start(displayName)
			if realmName == "StarterDojo" then
				TweenService:Create(fade, TweenInfo.new(0.25), {BackgroundTransparency = 0}):Play()
				task.wait(0.28)

				local personaType, chosenSlot = Cosmetics.getSelectedPersona()
				local currentHud = BootUI.hud
				local dissolvePlayed = false
				if currentHud and currentHud.playLoadoutDissolve then
					dissolvePlayed = currentHud:playLoadoutDissolve(0.35)
				end
				if not dissolvePlayed then
					BootUI.hideLoadout()
				end
				local enterRemote = getEnterRemote()
				if enterRemote then
					enterRemote:FireServer({ type = personaType, slot = chosenSlot })
				else
					warn("EnterDojoRE missing on server")
				end

				task.wait(0.2)
				local char = player.Character or player.CharacterAdded:Wait()
				local hum = char:FindFirstChildOfClass("Humanoid")
				cam = getCamera()
				if cam then
					cam.CameraType = Enum.CameraType.Custom
					if hum then cam.CameraSubject = hum end
				end

				DojoClient.hide()
				restoreUIBlur()
				local hudAfterTeleport = BootUI.hud
				if hudAfterTeleport and hudAfterTeleport.handlePostTeleport then
					-- Re-open the loadout menu shortly after spawning so the quick-access
					-- buttons (quests, pouch, teleports, shop) remain available in the dojo.
					task.defer(function()
						if hudAfterTeleport and hudAfterTeleport.handlePostTeleport then
							hudAfterTeleport:handlePostTeleport()
						end
					end)
				end
				local fadeTween = TweenService:Create(fade, TweenInfo.new(0.35), {BackgroundTransparency = 1})
				fadeTween.Completed:Connect(function(playbackState)
					if playbackState == Enum.PlaybackState.Completed then
						local hudAfter = BootUI.hud
					end
				end)
				fadeTween:Play()
				task.delay(0.4, function()
					BootUI.hideOverlay()
				end)
			else
				local placeId = TeleportClient.WorldPlaceIds[realmName]
				if not (placeId and placeId > 0) then
					warn("No place id for realm: " .. tostring(realmName))
					DojoClient.hide()
					return
				end
				TweenService:Create(fade, TweenInfo.new(0.25), {BackgroundTransparency = 0}):Play()
				task.wait(0.28)
				local _, chosenSlot = Cosmetics.getSelectedPersona()
				local hudBeforeTeleport = BootUI.hud
				if hudBeforeTeleport and hudBeforeTeleport.handlePostTeleport then
					hudBeforeTeleport:handlePostTeleport({
						source = "Realm",
						realm = realmName,
					})
				end
				DojoClient.hide()
				local ok, err = pcall(function()
					TeleportService:Teleport(placeId, player, {slot = chosenSlot})
				end)
				if not ok then warn("Teleport failed:", err) end
				BootUI.hideOverlay()
			end
		end)
	end
	-- Hook emote buttons once (after UI exists)
	-- =====================
	-- FLOW
	-- =====================
        BootUI.replayIntroSequence({
                holdTime = 0.3,
                personaData = config.personaData,
        })


end

return BootUI
