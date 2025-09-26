local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NinjaMarketplaceUI = require(ReplicatedStorage.ClientModules.UI.NinjaMarketplaceUI)
local NinjaQuestUI = require(ReplicatedStorage.ClientModules.UI.NinjaQuestUI)
local NinjaPouchUI = require(ReplicatedStorage.ClientModules.UI.NinjaPouchUI)
local TeleportUI = require(ReplicatedStorage.ClientModules.UI.TeleportUI)

local WorldHUD = {}
WorldHUD.__index = WorldHUD

local currentHud

local player = Players.LocalPlayer

local REALM_INFO = {
	{key = "StarterDojo",   name = "Starter Dojo"},
	{key = "SecretVillage", name = "Secret Village of Elementara"},
	{key = "Water",         name = "Water"},
	{key = "Fire",          name = "Fire"},
	{key = "Wind",          name = "Wind"},
	{key = "Growth",        name = "Growth"},
	{key = "Ice",           name = "Ice"},
	{key = "Light",         name = "Light"},
	{key = "Metal",         name = "Metal"},
	{key = "Strength",      name = "Strength"},
	{key = "Atoms",         name = "Atoms"},
}

local function track(self, conn)
	if conn == nil then
		return nil
	end

	table.insert(self._connections, conn)
	return conn
end

local function ensureParent()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		playerGui = player:WaitForChild("PlayerGui")
	end
	return playerGui
end

local function getRealmFolder()
	local realmsFolder = player:FindFirstChild("Realms")
	if not realmsFolder then
		local stats = player:FindFirstChild("Stats")
		if stats then
			realmsFolder = stats:FindFirstChild("Realms")
		end
	end
	return realmsFolder
end

function WorldHUD.get()
	if currentHud and currentHud._destroyed then
		currentHud = nil
	end
	return currentHud
end

function WorldHUD.new(config, dependencies)
	if currentHud and currentHud.gui and currentHud.gui.Parent then
		if config then currentHud.config = config end
		if dependencies then
			if dependencies.shop then currentHud.shop = dependencies.shop end
			if dependencies.currencyService then currentHud.currencyService = dependencies.currencyService end
		end
		return currentHud
	elseif currentHud and (not currentHud.gui or not currentHud.gui.Parent) then
		currentHud = nil
	end

	local self = setmetatable({}, WorldHUD)
	self.config = config or {}
	self.shop = dependencies and dependencies.shop or nil
	self.currencyService = dependencies and dependencies.currencyService or nil
	self._connections = {}
	self._destroyed = false
	self.backButtonEnabled = true

	local playerGui = ensureParent()

	local gui = Instance.new("ScreenGui")
	gui.Name = "WorldHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.DisplayOrder = 75
	gui.Parent = playerGui
	self.gui = gui

	local root = Instance.new("Frame")
	root.Name = "WorldHUDRoot"
	root.Size = UDim2.fromScale(1,1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	self.root = root

	-- Loadout UI
	local loadout = Instance.new("Frame")
	loadout.Name = "Loadout"
	loadout.Size = UDim2.fromScale(1,1)
	loadout.BackgroundTransparency = 1
	loadout.Visible = false
	loadout.ZIndex = 20
	loadout.Parent = root
	self.loadout = loadout

	local baseY = GuiService:GetGuiInset().Y + 20
	self.baseY = baseY

	local loadTitle = Instance.new("TextLabel")
	loadTitle.Size = UDim2.new(1,-40,0,60)
	loadTitle.Position = UDim2.new(0.5,0,0,baseY)
	loadTitle.AnchorPoint = Vector2.new(0.5,0)
	loadTitle.BackgroundTransparency = 0.6
	loadTitle.TextXAlignment = Enum.TextXAlignment.Center
	loadTitle.Text = "Loadout"
	loadTitle.Font = Enum.Font.GothamBold
	loadTitle.TextScaled = true
	loadTitle.TextColor3 = Color3.fromRGB(255,200,120)
	loadTitle.Parent = loadout

	-- Teleport UI
	local teleportUI = TeleportUI.init(loadout, baseY, {
		REALM_INFO = REALM_INFO,
		getRealmFolder = getRealmFolder,
	})
	self.teleportUI = teleportUI
	local teleportCloseButton = teleportUI and teleportUI.closeButton or nil
	self.teleportCloseButton = teleportCloseButton
	self.enterRealmButton = teleportUI and teleportUI.enterRealmButton or nil

	local quest = NinjaQuestUI.init(loadout, baseY)
	self.quest = quest

	local backpack = NinjaPouchUI.init(loadout, baseY)
	self.backpack = backpack

	local togglePanel = Instance.new("Frame")
	togglePanel.Name = "PanelToggleButtons"
	togglePanel.Size = UDim2.new(0,180,0,160)
	togglePanel.AnchorPoint = Vector2.new(0,1)
	togglePanel.Position = UDim2.new(0,20,1,-220)
	togglePanel.BackgroundTransparency = 1
	togglePanel.ZIndex = 40
	togglePanel.Parent = loadout
	self.togglePanel = togglePanel

	local toggleLayout = Instance.new("UIListLayout")
	toggleLayout.FillDirection = Enum.FillDirection.Vertical
	toggleLayout.Padding = UDim.new(0,6)
	toggleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	toggleLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	toggleLayout.Parent = togglePanel

	local function createOpenButton(label)
		local btn = Instance.new("TextButton")
		btn.Name = label .. "OpenButton"
		btn.Size = UDim2.new(1,0,0,36)
		btn.BackgroundColor3 = Color3.fromRGB(50,120,255)
		btn.TextColor3 = Color3.new(1,1,1)
		btn.Font = Enum.Font.GothamSemibold
		btn.TextScaled = true
		btn.AutoButtonColor = true
		btn.Text = label
		btn.Visible = false
		btn.ZIndex = 41
		btn.Parent = togglePanel
		return btn
	end

	local questOpenButton = createOpenButton("Quests")
	local backpackOpenButton = createOpenButton("Backpack")
	local teleOpenButton = createOpenButton("Teleports")
	local shopButton = createOpenButton("Shop")
	shopButton.Visible = true
	self.questOpenButton = questOpenButton
	self.backpackOpenButton = backpackOpenButton
	self.teleportOpenButton = teleOpenButton
	self.shopButton = shopButton

	local function setTeleportsVisible(visible)
		if teleportUI then
			teleportUI:setVisible(visible)
		end
		teleOpenButton.Visible = not visible
	end

	if quest and quest.closeButton then
		track(self, quest.closeButton.MouseButton1Click:Connect(function()
			if quest.setVisible then
				quest:setVisible(false)
			end
			questOpenButton.Visible = true
		end))
	end

	track(self, questOpenButton.MouseButton1Click:Connect(function()
		if quest and quest.setVisible then
			quest:setVisible(true)
		end
		questOpenButton.Visible = false
	end))

	if quest and quest.isVisible and not quest:isVisible() then
		questOpenButton.Visible = true
	end

	if backpack and backpack.closeButton then
		track(self, backpack.closeButton.MouseButton1Click:Connect(function()
			if backpack.setVisible then
				backpack:setVisible(false)
			end
			backpackOpenButton.Visible = true
		end))
	end

	track(self, backpackOpenButton.MouseButton1Click:Connect(function()
		if backpack and backpack.setVisible then
			backpack:setVisible(true)
		end
		backpackOpenButton.Visible = false
	end))

	if backpack and backpack.isVisible and not backpack:isVisible() then
		backpackOpenButton.Visible = true
	end

	track(self, shopButton.MouseButton1Click:Connect(function()
		self:toggleShop()
	end))

	if teleportCloseButton then
		track(self, teleportCloseButton.MouseButton1Click:Connect(function()
			setTeleportsVisible(false)
		end))
	end

	track(self, teleOpenButton.MouseButton1Click:Connect(function()
		setTeleportsVisible(true)
	end))

	setTeleportsVisible(false)

	local backButton = Instance.new("TextButton")
	backButton.Name = "BackButton"
	backButton.Size = UDim2.new(0, 220, 0, 48)
	backButton.AnchorPoint = Vector2.new(0, 1)
	backButton.Position = UDim2.new(0, 20, 1, -20)
	backButton.BackgroundColor3 = Color3.fromRGB(50, 120, 255)
	backButton.TextColor3 = Color3.new(1, 1, 1)
	backButton.Font = Enum.Font.GothamSemibold
	backButton.TextScaled = true
	backButton.AutoButtonColor = true
	backButton.Text = "Back"
	backButton.ZIndex = 40
	backButton.Parent = loadout
	self.backButton = backButton

	local realmDisplayLookup = {}
	self.realmDisplayLookup = realmDisplayLookup
	for _, info in ipairs(REALM_INFO) do
		realmDisplayLookup[info.key] = info.name
	end

	if self.config and self.config.showShop then
		self:toggleShop()
	end

	currentHud = self
	return self
end

function WorldHUD:getLoadoutFrame()
	return self.loadout
end

function WorldHUD:getShopButton()
	return self.shopButton
end

function WorldHUD:getQuestInterface()
	return self.quest
end

function WorldHUD:getBackpackInterface()
	return self.backpack
end

function WorldHUD:createCosmeticsInterface()
	local hud = self
	return {
		showDojoPicker = function()
			if hud and hud.hideLoadout then
				hud:hideLoadout()
			end
		end,
		showLoadout = function(personaType)
			if hud and hud.showLoadout then
				hud:showLoadout()
			end
		end,
		updateBackpack = function(data)
			if hud and hud.setBackpackData then
				hud:setBackpackData(data)
			end
		end,
		buildCharacterPreview = function(personaType)
			if hud and hud.quest and hud.quest.buildCharacterPreview then
				hud.quest.buildCharacterPreview(personaType)
			end
		end,
	}
end

function WorldHUD:setShopButtonVisible(visible)
	if self.shopButton then
		self.shopButton.Visible = visible and true or false
	end
end

function WorldHUD:showLoadout()
	if self.loadout then
		self.loadout.Visible = true
	end
	if self.backButton then
		local showBack = self.backButtonEnabled ~= false
		self.backButton.Visible = showBack
		self.backButton.Active = showBack
	end
	self:setShopButtonVisible(true)
end

function WorldHUD:hideLoadout()
	if self.loadout then
		self.loadout.Visible = false
	end
	if self.backButton then
		self.backButton.Visible = false
		self.backButton.Active = false
	end
	self:setShopButtonVisible(false)
end

function WorldHUD:setBackButtonEnabled(enabled)
	self.backButtonEnabled = enabled and true or false
	if self.backButton then
		local showBack = self.backButtonEnabled and self.loadout and self.loadout.Visible
		self.backButton.Visible = showBack
		self.backButton.Active = showBack
	end
end

function WorldHUD:toggleShop(defaultTab)
	if not self.shop then
		warn("WorldHUD: shop instance missing")
		return
	end
	if not self.shopFrame or not self.shopFrame.Parent then
		local fakeBoot = {root = self.root}
		self.shopFrame = NinjaMarketplaceUI.init(self.config, self.shop, fakeBoot, defaultTab)
	else
		self.shopFrame.Visible = not self.shopFrame.Visible
	end
	if self.shopFrame and self.shopFrame.Visible and defaultTab and NinjaMarketplaceUI.setTab then
		NinjaMarketplaceUI.setTab(defaultTab)
	end
	return self.shopFrame and self.shopFrame.Visible
end

function WorldHUD:setBackpackData(data)
	if self.backpack and self.backpack.setData then
		self.backpack:setData(data)
	end
end

function WorldHUD:updateCurrency(coins, orbs, elements)
	if self.backpack and self.backpack.updateCurrency then
		self.backpack:updateCurrency(coins, orbs, elements)
	end
end

function WorldHUD:getSelectedRealm()
	if self.teleportUI and self.teleportUI.getSelectedRealm then
		return self.teleportUI:getSelectedRealm()
	end
	return nil
end

function WorldHUD:getRealmDisplayName(key)
	return self.realmDisplayLookup and self.realmDisplayLookup[key]
end

function WorldHUD:setSelectedRealm(key)
	if self.teleportUI and self.teleportUI.setSelectedRealm then
		self.teleportUI:setSelectedRealm(key)
	end
end

function WorldHUD:destroy()
	if self._destroyed then return end
	self._destroyed = true
	for _, conn in ipairs(self._connections) do
		if conn.Disconnect then conn:Disconnect() end
	end
	self._connections = {}
	if self.teleportUI and self.teleportUI.destroy then
		self.teleportUI:destroy()
	end
	if self.gui then
		self.gui:Destroy()
	end
	self.gui = nil
	self.root = nil
	self.loadout = nil
	self.shopButton = nil
	self.shopFrame = nil
	self.backButton = nil
	self.enterRealmButton = nil
	self.quest = nil
	self.backpack = nil
	self.togglePanel = nil
	self.questOpenButton = nil
	self.backpackOpenButton = nil
	self.teleportOpenButton = nil
	self.teleportCloseButton = nil
	self.teleportUI = nil
	self.backButtonEnabled = nil
	if currentHud == self then
		currentHud = nil
	end
end

return WorldHUD
