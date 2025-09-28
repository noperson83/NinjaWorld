local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NinjaMarketplaceUI = require(ReplicatedStorage.ClientModules.UI.NinjaMarketplaceUI)
local NinjaQuestUI = require(ReplicatedStorage.ClientModules.UI.NinjaQuestUI)
local NinjaPouchUI = require(ReplicatedStorage.ClientModules.UI.NinjaPouchUI)
local TeleportUI = require(ReplicatedStorage.ClientModules.UI.TeleportUI)

local WorldHUD = {}
WorldHUD.__index = WorldHUD

local currentHud

local TEXT_CLASSES = {
        TextLabel = true,
        TextButton = true,
        TextBox = true,
}

local IMAGE_CLASSES = {
        ImageLabel = true,
        ImageButton = true,
}

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

-- Button styling configurations
local BUTTON_STYLE = {
	-- Main colors with ninja theme
	primaryColor = Color3.fromRGB(20, 25, 35),
	secondaryColor = Color3.fromRGB(35, 45, 65),
	accentColor = Color3.fromRGB(255, 140, 60), -- Orange accent
	textColor = Color3.fromRGB(255, 255, 255),
	shadowColor = Color3.fromRGB(0, 0, 0),
	
	-- Hover effects
	hoverColor = Color3.fromRGB(45, 55, 75),
	activeColor = Color3.fromRGB(255, 160, 80),
	
	-- Sizing
	buttonSize = UDim2.new(0, 160, 0, 50),
	cornerRadius = UDim.new(0, 12),
	spacing = 15,
	
	-- Animation
	hoverScale = 1.05,
	pressScale = 0.95,
	animSpeed = 0.2,
}

local function track(self, conn)
        if conn == nil then
                return nil
        end

        table.insert(self._connections, conn)
        return conn
end

local function captureTransparencyTargets(container)
        if not container then
                return {}
        end

        local targets = {}

        local function addTarget(instance)
                local entry = {instance = instance}

                if instance:IsA("GuiObject") then
                        if instance.BackgroundTransparency ~= nil then
                                entry.backgroundTransparency = instance.BackgroundTransparency
                        end

                        if TEXT_CLASSES[instance.ClassName] then
                                entry.textTransparency = instance.TextTransparency
                                entry.textStrokeTransparency = instance.TextStrokeTransparency
                        end

                        if IMAGE_CLASSES[instance.ClassName] then
                                entry.imageTransparency = instance.ImageTransparency
                        end
                elseif instance:IsA("UIStroke") then
                        entry.strokeTransparency = instance.Transparency
                else
                        return
                end

                targets[#targets + 1] = entry
        end

        addTarget(container)
        for _, descendant in ipairs(container:GetDescendants()) do
                if descendant:IsA("GuiObject") or descendant:IsA("UIStroke") then
                        addTarget(descendant)
                end
        end

        return targets
end

local function applyTransparencyEntry(entry)
        local instance = entry.instance
        if not instance then
                return
        end

        if entry.backgroundTransparency ~= nil and instance:IsA("GuiObject") then
                instance.BackgroundTransparency = entry.backgroundTransparency
        end

        if entry.textTransparency ~= nil and TEXT_CLASSES[instance.ClassName] then
                instance.TextTransparency = entry.textTransparency
        end

        if entry.textStrokeTransparency ~= nil and TEXT_CLASSES[instance.ClassName] then
                instance.TextStrokeTransparency = entry.textStrokeTransparency
        end

        if entry.imageTransparency ~= nil and IMAGE_CLASSES[instance.ClassName] then
                instance.ImageTransparency = entry.imageTransparency
        end

        if entry.strokeTransparency ~= nil and instance:IsA("UIStroke") then
                instance.Transparency = entry.strokeTransparency
        end
end

local function tweenTransparencyEntry(entry, tweenInfo)
        local instance = entry.instance
        if not (instance and instance.Parent) then
                return nil
        end

        local goal = {}

        if entry.backgroundTransparency ~= nil and instance:IsA("GuiObject") then
                goal.BackgroundTransparency = 1
        end

        if entry.textTransparency ~= nil and TEXT_CLASSES[instance.ClassName] then
                goal.TextTransparency = 1
        end

        if entry.textStrokeTransparency ~= nil and TEXT_CLASSES[instance.ClassName] then
                goal.TextStrokeTransparency = 1
        end

        if entry.imageTransparency ~= nil and IMAGE_CLASSES[instance.ClassName] then
                goal.ImageTransparency = 1
        end

        if entry.strokeTransparency ~= nil and instance:IsA("UIStroke") then
                goal.Transparency = 1
        end

        if next(goal) == nil then
                return nil
        end

        local tween = TweenService:Create(instance, tweenInfo, goal)
        tween:Play()
        return tween
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

-- Enhanced button creation with ninja styling
local function createStyledButton(parent, text, position, zIndex)
	-- Main button container
	local buttonContainer = Instance.new("Frame")
	buttonContainer.Name = text .. "Container"
	buttonContainer.Size = BUTTON_STYLE.buttonSize
	buttonContainer.Position = position
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.ZIndex = zIndex
	buttonContainer.Parent = parent
	
	-- Shadow frame (for depth effect)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 4, 1, 4)
	shadow.Position = UDim2.new(0, 2, 0, 2)
	shadow.BackgroundColor3 = BUTTON_STYLE.shadowColor
	shadow.BackgroundTransparency = 0.7
	shadow.ZIndex = zIndex
	shadow.Parent = buttonContainer
	
	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = BUTTON_STYLE.cornerRadius
	shadowCorner.Parent = shadow
	
	-- Main button
	local button = Instance.new("TextButton")
	button.Name = text .. "Button"
	button.Size = UDim2.new(1, 0, 1, 0)
	button.Position = UDim2.new(0, 0, 0, 0)
	button.BackgroundColor3 = BUTTON_STYLE.primaryColor
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = BUTTON_STYLE.textColor
	button.TextScaled = true
	button.AutoButtonColor = false
	button.ZIndex = zIndex + 1
	button.Parent = buttonContainer
	
	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = BUTTON_STYLE.cornerRadius
	corner.Parent = button
	
	-- Gradient overlay for depth
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(200, 200, 200))
	})
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.9),
		NumberSequenceKeypoint.new(1.0, 0.7)
	})
	gradient.Parent = button
	
	-- Accent border
	local border = Instance.new("UIStroke")
	border.Color = BUTTON_STYLE.accentColor
	border.Thickness = 2
	border.Transparency = 0.3
	border.Parent = button
	
	-- Text padding
	local textPadding = Instance.new("UIPadding")
	textPadding.PaddingLeft = UDim.new(0, 12)
	textPadding.PaddingRight = UDim.new(0, 12)
	textPadding.PaddingTop = UDim.new(0, 8)
	textPadding.PaddingBottom = UDim.new(0, 8)
	textPadding.Parent = button
	
	-- Animation tweens
	local hoverTweenInfo = TweenInfo.new(BUTTON_STYLE.animSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local pressTweenInfo = TweenInfo.new(BUTTON_STYLE.animSpeed * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	-- Hover effects
	button.MouseEnter:Connect(function()
		local hoverTween = TweenService:Create(button, hoverTweenInfo, {
			BackgroundColor3 = BUTTON_STYLE.hoverColor,
			Size = UDim2.new(BUTTON_STYLE.hoverScale, 0, BUTTON_STYLE.hoverScale, 0),
			Position = UDim2.new((1 - BUTTON_STYLE.hoverScale) / 2, 0, (1 - BUTTON_STYLE.hoverScale) / 2, 0)
		})
		local borderTween = TweenService:Create(border, hoverTweenInfo, {
			Transparency = 0.1
		})
		hoverTween:Play()
		borderTween:Play()
	end)
	
	button.MouseLeave:Connect(function()
		local leaveTween = TweenService:Create(button, hoverTweenInfo, {
			BackgroundColor3 = BUTTON_STYLE.primaryColor,
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0)
		})
		local borderTween = TweenService:Create(border, hoverTweenInfo, {
			Transparency = 0.3
		})
		leaveTween:Play()
		borderTween:Play()
	end)
	
	-- Press effects
	button.MouseButton1Down:Connect(function()
		local pressTween = TweenService:Create(button, pressTweenInfo, {
			Size = UDim2.new(BUTTON_STYLE.pressScale, 0, BUTTON_STYLE.pressScale, 0),
			Position = UDim2.new((1 - BUTTON_STYLE.pressScale) / 2, 0, (1 - BUTTON_STYLE.pressScale) / 2, 0),
			BackgroundColor3 = BUTTON_STYLE.activeColor
		})
		pressTween:Play()
	end)
	
	button.MouseButton1Up:Connect(function()
		local releaseTween = TweenService:Create(button, pressTweenInfo, {
			Size = UDim2.new(BUTTON_STYLE.hoverScale, 0, BUTTON_STYLE.hoverScale, 0),
			Position = UDim2.new((1 - BUTTON_STYLE.hoverScale) / 2, 0, (1 - BUTTON_STYLE.hoverScale) / 2, 0),
			BackgroundColor3 = BUTTON_STYLE.hoverColor
		})
		releaseTween:Play()
	end)
	
	return button, buttonContainer
end

local function createMenuToggleButton(parent, position, zIndex)
        local container = Instance.new("Frame")
        container.Name = "MenuToggleContainer"
        container.Size = UDim2.new(0, 64, 0, 64)
        container.AnchorPoint = Vector2.new(1, 0)
        container.Position = position
        container.BackgroundTransparency = 1
        container.ZIndex = zIndex
        container.Parent = parent

        local circle = Instance.new("Frame")
        circle.Name = "Circle"
        circle.AnchorPoint = Vector2.new(0.5, 0.5)
        circle.Position = UDim2.new(0.5, 0, 0.5, 0)
        circle.Size = UDim2.new(1, 0, 1, 0)
        circle.BackgroundColor3 = BUTTON_STYLE.primaryColor
        circle.BackgroundTransparency = 1
        circle.BorderSizePixel = 0
        circle.ZIndex = zIndex
        circle.Parent = container

        local circleCorner = Instance.new("UICorner")
        circleCorner.CornerRadius = UDim.new(1, 0)
        circleCorner.Parent = circle

        local circleAspect = Instance.new("UIAspectRatioConstraint")
        circleAspect.AspectRatio = 1
        circleAspect.Parent = circle

        local stroke = Instance.new("UIStroke")
        stroke.Color = BUTTON_STYLE.accentColor
        stroke.Thickness = 3
        stroke.Transparency = 0
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = circle

        local button = Instance.new("TextButton")
        button.Name = "MenuToggle"
        button.Size = UDim2.new(1, 0, 1, 0)
        button.Position = UDim2.new(0, 0, 0, 0)
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.Text = "☰"
        button.TextScaled = true
        button.Font = Enum.Font.GothamBold
        button.TextColor3 = BUTTON_STYLE.textColor
        button.AutoButtonColor = false
        button.ZIndex = zIndex + 1
        button.Parent = container

        return button, container, circle, stroke
end

local function setInterfaceVisible(interface, visible)
        if typeof(interface) ~= "table" then
                return
        end

        if typeof(interface.setVisible) == "function" then
                interface:setVisible(visible)
                return
        end

        local root = rawget(interface, "root")
        if typeof(root) == "Instance" and root:IsA("GuiObject") then
                root.Visible = visible and true or false
        end
end

local function isInterfaceVisible(interface)
        if typeof(interface) ~= "table" then
                return false
        end

        if typeof(interface.isVisible) == "function" then
                local ok, result = pcall(function()
                        return interface:isVisible()
                end)
                if ok then
                        return result and true or false
                end
        end

        local root = rawget(interface, "root")
        if typeof(root) == "Instance" and root:IsA("GuiObject") then
                return root.Visible
        end

        return false
end

function WorldHUD:setQuestVisible(visible)
        if visible then
                self:hideAbilityInterface()
        end
        setInterfaceVisible(self.quest, visible)
end

function WorldHUD:setBackpackVisible(visible)
        if visible then
                self:hideAbilityInterface()
        end
        setInterfaceVisible(self.backpack, visible)
end

function WorldHUD:setTeleportVisible(visible)
        setInterfaceVisible(self.teleportUI, visible)

        if visible then
                self:hideAbilityInterface()
                setInterfaceVisible(self.quest, false)
                setInterfaceVisible(self.backpack, false)
                if self.shopFrame then
                        self.shopFrame.Visible = false
                end
        end
end

function WorldHUD:closeAllInterfaces()
        self:setQuestVisible(false)
        self:setBackpackVisible(false)
        self:setTeleportVisible(false)
        self:hideAbilityInterface()
        if self.shopFrame then
                self.shopFrame.Visible = false
        end
end

function WorldHUD:cancelLoadoutDissolve()
        self._loadoutDissolveToken = (self._loadoutDissolveToken or 0) + 1

        if self._loadoutDissolveTweens then
                for _, tween in ipairs(self._loadoutDissolveTweens) do
                        tween:Cancel()
                end
        end
        self._loadoutDissolveTweens = nil

        if self._loadoutDissolveTargets then
                for _, entry in ipairs(self._loadoutDissolveTargets) do
                        local instance = entry.instance
                        if instance and instance.Parent then
                                applyTransparencyEntry(entry)
                        end
                end
        end
        self._loadoutDissolveTargets = nil

        if self.loadout then
                self.loadout.Visible = true
        end
end

function WorldHUD:playLoadoutDissolve(duration)
        if not (self.loadout and self.loadout.Parent) then
                return false
        end

        duration = duration or 0.35

        self._loadoutDissolveTargets = nil

        local targets = captureTransparencyTargets(self.loadout)
        if #targets == 0 then
                if self.loadout then
                        self.loadout.Visible = false
                end
                self:updateLoadoutHeaderVisibility()
                self:setMenuExpanded(false)
                if self.setShopButtonVisible then
                        self:setShopButtonVisible(false)
                end
                self:updatePersonaButtonVisibility()
                return false
        end

        self._loadoutDissolveToken = (self._loadoutDissolveToken or 0) + 1
        local token = self._loadoutDissolveToken

        self._loadoutDissolveTargets = targets

        if self._loadoutDissolveTweens then
                for _, tween in ipairs(self._loadoutDissolveTweens) do
                        tween:Cancel()
                end
        end
        self._loadoutDissolveTweens = {}

        self:setMenuExpanded(false)
        if self.setShopButtonVisible then
                self:setShopButtonVisible(false)
        end
        if self.backButton then
                self.backButton.Active = false
        end

        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        for _, entry in ipairs(targets) do
                local tween = tweenTransparencyEntry(entry, tweenInfo)
                if tween then
                        table.insert(self._loadoutDissolveTweens, tween)
                end
        end

        task.delay(duration, function()
                if self._destroyed or self._loadoutDissolveToken ~= token then
                        return
                end

                if self._loadoutDissolveTweens then
                        for _, tween in ipairs(self._loadoutDissolveTweens) do
                                tween:Cancel()
                        end
                end
                self._loadoutDissolveTweens = nil

                if self.loadout then
                        self.loadout.Visible = false
                end
                self:updateLoadoutHeaderVisibility()
                self:updatePersonaButtonVisibility()

                for _, entry in ipairs(targets) do
                        local instance = entry.instance
                        if instance and instance.Parent then
                                applyTransparencyEntry(entry)
                        end
                end

                if self._loadoutDissolveTargets == targets then
                        self._loadoutDissolveTargets = nil
                end
        end)

        return true
end

function WorldHUD:setMenuExpanded(expanded)
        self.menuExpanded = expanded and true or false
        if self.togglePanel then
                self.togglePanel.Visible = self.menuExpanded
        end
        if self.menuButton then
                local targetColor = self.menuExpanded and BUTTON_STYLE.accentColor or BUTTON_STYLE.textColor
                self.menuButton.TextColor3 = targetColor
        end
        if self.menuButtonStroke then
                local targetThickness = self.menuExpanded and 4 or 3
                self.menuButtonStroke.Thickness = targetThickness
                self.menuButtonStroke.Color = self.menuExpanded and BUTTON_STYLE.accentColor or BUTTON_STYLE.secondaryColor
        end
        if self.menuExpanded then
                self.menuAutoExpand = true
        end
end

function WorldHUD:toggleMenu()
        self:setMenuExpanded(not self.menuExpanded)
end

function WorldHUD:applyMenuAutoState()
        if self.menuAutoExpand == false then
                self:setMenuExpanded(false)
        else
                self:setMenuExpanded(true)
        end
end

function WorldHUD:prepareLoadoutPanels()
        self:setQuestVisible(true)
        self:setBackpackVisible(true)
        self:setTeleportVisible(true)
        if self.shopFrame then
                self.shopFrame.Visible = false
        end
        self:applyMenuAutoState()
end

function WorldHUD:ensureLoadoutHeader()
        local loadout = self.loadout
        if not loadout then
                return
        end

        if not self.loadTitle then
                local baseY = self.baseY or 0
                local loadTitle = Instance.new("TextLabel")
                loadTitle.Size = UDim2.new(1, -40, 0, 70)
                loadTitle.Position = UDim2.new(0.5, 0, 0, baseY)
                loadTitle.AnchorPoint = Vector2.new(0.5, 0)
                loadTitle.BackgroundColor3 = BUTTON_STYLE.primaryColor
                loadTitle.BackgroundTransparency = 0.1
                loadTitle.TextXAlignment = Enum.TextXAlignment.Center
                loadTitle.Text = "⚔ NINJA LOADOUT ⚔"
                loadTitle.Font = Enum.Font.GothamBold
                loadTitle.TextScaled = true
                loadTitle.TextColor3 = BUTTON_STYLE.accentColor
                loadTitle.ZIndex = 25
                loadTitle.Parent = loadout
                self.loadTitle = loadTitle

                local titleCorner = Instance.new("UICorner")
                titleCorner.CornerRadius = UDim.new(0, 15)
                titleCorner.Parent = loadTitle

                local titleStroke = Instance.new("UIStroke")
                titleStroke.Color = BUTTON_STYLE.accentColor
                titleStroke.Thickness = 2
                titleStroke.Transparency = 0.5
                titleStroke.Parent = loadTitle
        elseif not self.loadTitle.Parent then
                self.loadTitle.Parent = loadout
        end

        if not self.backButtonContainer then
                local backButton, backContainer = createStyledButton(loadout, "◀ Back", UDim2.new(0, 20, 1, -80), 40)
                backButton.Size = UDim2.new(0, 200, 0, 50)
                backContainer.Size = UDim2.new(0, 200, 0, 50)
                self.backButton = backButton
                self.backButtonContainer = backContainer
        elseif not self.backButtonContainer.Parent then
                self.backButtonContainer.Parent = loadout
        end

        if self.backButton then
                self.backButton.Visible = false
                self.backButton.Active = false
        end
        if self.backButtonContainer then
                self.backButtonContainer.Visible = false
        end
end

function WorldHUD:detachLoadoutHeader()
        if self.loadTitle then
                self.loadTitle.Visible = false
                self.loadTitle.Parent = nil
        end
        if self.backButton then
                self.backButton.Visible = false
                self.backButton.Active = false
        end
        if self.backButtonContainer then
                self.backButtonContainer.Visible = false
                self.backButtonContainer.Parent = nil
        end
end

function WorldHUD:updatePersonaButtonVisibility()
        if not self.personaButton then
                return
        end

        local shouldShow = self.worldModeActive and not (self.loadout and self.loadout.Visible)
        self.personaButton.Visible = shouldShow
        self.personaButton.Active = shouldShow
end

function WorldHUD:handlePostTeleport(teleportContext)
        self:closeAllInterfaces()

        local inWorld = false
        if teleportContext then
                if teleportContext.source == "Zone" then
                        inWorld = teleportContext.name ~= "Dojo"
                elseif teleportContext.source == "Realm" then
                        inWorld = true
                end
        end

        if inWorld then
                self:setWorldMode(true)
                self.menuAutoExpand = false

                if not self:playLoadoutDissolve() then
                        if self.loadout then
                                self.loadout.Visible = false
                        end
                        self:setMenuExpanded(false)
                        if self.setShopButtonVisible then
                                self:setShopButtonVisible(false)
                        end
                        if self.backButton then
                                self.backButton.Active = false
                        end
                        self:updateLoadoutHeaderVisibility()
                end

                if self.togglePanel then
                        self.togglePanel.Visible = false
                end

                self:updatePersonaButtonVisibility()
                return
        end

        -- Keep the main loadout menu available when returning to the dojo so the player
        -- can immediately access quests, pouch, teleports, and shop again.
        self:cancelLoadoutDissolve()
        self:setWorldMode(false)
        self.menuAutoExpand = true
        self:setMenuExpanded(true)

        -- The call to closeAllInterfaces hides the quick-access buttons that live
        -- inside the loadout menu. Explicitly re-enable them here so they remain
        -- available after a teleport (such as when entering the dojo).
        self:setQuestVisible(true)
        self:setBackpackVisible(true)
        self:setTeleportVisible(true)

        if self.loadout then
                self.loadout.Visible = true
        end

        if self.togglePanel then
                self.togglePanel.Visible = true
        end

        if self.setShopButtonVisible then
                self:setShopButtonVisible(true)
        end

        self:updatePersonaButtonVisibility()
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
        self.abilityInterface = dependencies and dependencies.abilityInterface or nil
	self._connections = {}
	self._destroyed = false
	self.backButtonEnabled = true
	self.menuAutoExpand = true
	self.worldModeActive = false

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
        self:ensureLoadoutHeader()

        local personaButton = Instance.new("TextButton")
        personaButton.Name = "PersonaButton"
        personaButton.Size = UDim2.new(0, 220, 0, 54)
        personaButton.Position = UDim2.new(0.5, 0, 0, baseY)
        personaButton.AnchorPoint = Vector2.new(0.5, 0)
        personaButton.BackgroundColor3 = BUTTON_STYLE.primaryColor
        personaButton.BackgroundTransparency = 0.1
        personaButton.Text = "Persona"
        personaButton.Font = Enum.Font.GothamBold
        personaButton.TextScaled = true
        personaButton.TextColor3 = BUTTON_STYLE.accentColor
        personaButton.AutoButtonColor = true
        personaButton.Active = false
        personaButton.Visible = false
        personaButton.ZIndex = 30
        personaButton.Parent = root
        self.personaButton = personaButton

        local personaCorner = Instance.new("UICorner")
        personaCorner.CornerRadius = UDim.new(0, 15)
        personaCorner.Parent = personaButton

        local personaStroke = Instance.new("UIStroke")
        personaStroke.Color = BUTTON_STYLE.accentColor
        personaStroke.Thickness = 2
        personaStroke.Transparency = 0.5
        personaStroke.Parent = personaButton

	-- Teleport UI
	local setTeleportsVisible

        local teleportUI = TeleportUI.init(loadout, baseY, {
                REALM_INFO = REALM_INFO,
                getRealmFolder = getRealmFolder,
                onTeleport = function(teleportContext)
                        if self and self.handlePostTeleport then
                                self:handlePostTeleport(teleportContext)
                        elseif self then
                                self:setTeleportVisible(false)
                        end
                end,
        })
	self.teleportUI = teleportUI
	local teleportCloseButton = teleportUI and teleportUI.closeButton or nil
	self.teleportCloseButton = teleportCloseButton
	self.enterRealmButton = teleportUI and teleportUI.enterRealmButton or nil

	local quest = NinjaQuestUI.init(loadout, baseY)
	self.quest = quest

	local backpack = NinjaPouchUI.init(loadout, baseY)
	self.backpack = backpack

	-- Enhanced floating button panel positioned on left center
        local togglePanel = Instance.new("Frame")
        togglePanel.Name = "PanelToggleButtons"
        togglePanel.Size = UDim2.new(0, 180, 0, self.abilityInterface and 345 or 280)
        togglePanel.AnchorPoint = Vector2.new(1, 0)
        togglePanel.Position = UDim2.new(1, -30, 0, baseY + 10)
        togglePanel.BackgroundTransparency = 1
        togglePanel.ZIndex = 40
        togglePanel.Parent = loadout
        self.togglePanel = togglePanel

        local menuButton, menuContainer, _, menuStroke = createMenuToggleButton(loadout, UDim2.new(1, -30, 0, baseY), 45)
        self.menuButton = menuButton
        self.menuContainer = menuContainer
        self.menuButtonStroke = menuStroke
        self.menuExpanded = true
        self:setMenuExpanded(true)
        track(self, menuButton.MouseButton1Click:Connect(function()
                self:toggleMenu()
        end))

        track(self, menuButton.MouseEnter:Connect(function()
                if menuStroke then
                        menuStroke.Thickness = self.menuExpanded and 5 or 4
                end
        end))

        track(self, menuButton.MouseLeave:Connect(function()
                if menuStroke then
                        menuStroke.Thickness = self.menuExpanded and 4 or 3
                end
        end))

        -- Create styled buttons with proper spacing
        local questButton, questContainer = createStyledButton(togglePanel, "Quests", UDim2.new(0, 0, 0, 0), 41)
        local pouchButton, pouchContainer = createStyledButton(togglePanel, "Pouch", UDim2.new(0, 0, 0, 65), 41)
        local teleButton, teleContainer = createStyledButton(togglePanel, "Teleports", UDim2.new(0, 0, 0, 130), 41)
        local shopButton, shopContainer = createStyledButton(togglePanel, "Shop", UDim2.new(0, 0, 0, 195), 41)
        local abilityButton, abilityContainer
        if self.abilityInterface then
                abilityButton, abilityContainer = createStyledButton(togglePanel, "Abilities", UDim2.new(0, 0, 0, 260), 41)
        end

        -- Set initial visibility
        questButton.Visible = true
        pouchButton.Visible = true  -- Changed from backpack to pouch
        teleButton.Visible = true
        shopButton.Visible = true
        if abilityButton then
                abilityButton.Visible = true
        end

	self.questOpenButton = questButton
	self.backpackOpenButton = pouchButton  -- Keep internal reference name for compatibility
	self.teleportOpenButton = teleButton
        self.shopButton = shopButton
        if abilityButton then
                self.abilityButton = abilityButton
        end

        setTeleportsVisible = function(visible)
                self:setTeleportVisible(visible)
        end

        local function hideTeleport()
                setTeleportsVisible(false)
        end

        if quest and quest.closeButton then
                track(self, quest.closeButton.MouseButton1Click:Connect(function()
                        self:setQuestVisible(false)
                        hideTeleport()
                end))
        end

        track(self, questButton.MouseButton1Click:Connect(function()
                local shouldShow = not isInterfaceVisible(quest)
                self:setQuestVisible(shouldShow)
                if shouldShow then
                        hideTeleport()
                end
        end))

        if backpack and backpack.closeButton then
                track(self, backpack.closeButton.MouseButton1Click:Connect(function()
                        self:setBackpackVisible(false)
                        hideTeleport()
                end))
        end

        track(self, pouchButton.MouseButton1Click:Connect(function()
                local shouldShow = not isInterfaceVisible(backpack)
                self:setBackpackVisible(shouldShow)
                if shouldShow then
                        hideTeleport()
                end
        end))

        track(self, shopButton.MouseButton1Click:Connect(function()
                local visible = self:toggleShop()
                if visible then
                        hideTeleport()
                end
        end))

        if abilityButton then
                track(self, abilityButton.MouseButton1Click:Connect(function()
                        local visible = self:toggleAbilityInterface()
                        if visible then
                                hideTeleport()
                        end
                end))
        end

	if teleportCloseButton then
		track(self, teleportCloseButton.MouseButton1Click:Connect(function()
			setTeleportsVisible(false)
		end))
	end

        track(self, teleButton.MouseButton1Click:Connect(function()
                local shouldShow = not isInterfaceVisible(teleportUI)
                setTeleportsVisible(shouldShow)
        end))

        setInterfaceVisible(quest, false)
        setInterfaceVisible(backpack, false)
        setTeleportsVisible(false)

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

function WorldHUD:getPersonaButton()
        return self.personaButton
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
                        if hud then
                                if hud.setWorldMode then
                                        hud:setWorldMode(false)
                                end
                                if hud.hideLoadout then
                                        hud:hideLoadout()
                                        if hud.closeAllInterfaces then
                                                hud:closeAllInterfaces()
                                        end
                                end
                        end
                end,
                showLoadout = function(personaType)
                        if hud and hud.showLoadout then
                                hud:showLoadout()
                                if hud.prepareLoadoutPanels then
                                        hud:prepareLoadoutPanels()
                                end
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

function WorldHUD:isAbilityInterfaceVisible()
        local abilityInterface = self.abilityInterface
        if not abilityInterface then
                return false
        end

        if typeof(abilityInterface.isVisible) == "function" then
                local ok, result = pcall(function()
                        return abilityInterface.isVisible()
                end)
                if ok then
                        return result and true or false
                end
        end

        local frame = abilityInterface.frame
        return (frame and frame.Visible) or false
end

function WorldHUD:hideAbilityInterface()
        local abilityInterface = self.abilityInterface
        if not abilityInterface then
                return
        end

        if typeof(abilityInterface.hide) == "function" then
                abilityInterface.hide()
                return
        end

        if typeof(abilityInterface.toggle) == "function" and self:isAbilityInterfaceVisible() then
                abilityInterface.toggle()
                return
        end

        local frame = abilityInterface.frame
        if frame then
                frame.Visible = false
        end
end

function WorldHUD:toggleAbilityInterface()
        local abilityInterface = self.abilityInterface
        if not abilityInterface then
                return false
        end

        local visible
        if typeof(abilityInterface.toggle) == "function" then
                visible = abilityInterface.toggle()
        else
                local currentlyVisible = self:isAbilityInterfaceVisible()
                if currentlyVisible then
                        if typeof(abilityInterface.hide) == "function" then
                                abilityInterface.hide()
                        elseif abilityInterface.frame then
                                abilityInterface.frame.Visible = false
                        end
                        visible = false
                else
                        if typeof(abilityInterface.show) == "function" then
                                abilityInterface.show()
                        elseif abilityInterface.frame then
                                abilityInterface.frame.Visible = true
                        end
                        visible = true
                end
        end

        if visible then
                self:setQuestVisible(false)
                self:setBackpackVisible(false)
                self:setTeleportVisible(false)
                if self.shopFrame then
                        self.shopFrame.Visible = false
                end
        end

        return visible and true or false
end

function WorldHUD:updateLoadoutHeaderVisibility()
	local loadoutVisible = self.loadout and self.loadout.Visible
	local headerVisible = loadoutVisible and not self.worldModeActive

	if self.loadTitle then
		self.loadTitle.Visible = headerVisible
	end

        local backContainer = self.backButtonContainer
        if self.backButton then
                local showBack = headerVisible and (self.backButtonEnabled ~= false)
                self.backButton.Visible = showBack
                self.backButton.Active = showBack
                if backContainer then
                        backContainer.Visible = showBack
                end
        elseif backContainer then
                backContainer.Visible = false
        end
end

function WorldHUD:setWorldMode(inWorld)
        self.worldModeActive = inWorld and true or false
        if self.worldModeActive then
                self:detachLoadoutHeader()
                self:hideAbilityInterface()
        else
                self:ensureLoadoutHeader()
        end
        self:updateLoadoutHeaderVisibility()
        self:updatePersonaButtonVisibility()
end

function WorldHUD:showLoadout()
        if self.loadout then
                self.loadout.Visible = true
        end
        self:setWorldMode(false)
        self:applyMenuAutoState()
        self:setShopButtonVisible(true)
        self:updatePersonaButtonVisibility()
end

function WorldHUD:hideLoadout()
        if self.loadout then
                self.loadout.Visible = false
        end
        self:updateLoadoutHeaderVisibility()
        self:setShopButtonVisible(false)
        self:updatePersonaButtonVisibility()
        self:hideAbilityInterface()
end

function WorldHUD:setBackButtonEnabled(enabled)
	self.backButtonEnabled = enabled and true or false
	self:updateLoadoutHeaderVisibility()
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

        if self.shopFrame and self.shopFrame.Visible then
                self:hideAbilityInterface()
                self:setTeleportVisible(false)
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
        if self.loadTitle then
                self.loadTitle:Destroy()
        end
        if self.backButtonContainer then
                self.backButtonContainer:Destroy()
        end
        if self.personaButton then
                self.personaButton:Destroy()
        end
        self.gui = nil
        self.root = nil
        self.loadout = nil
        self.loadTitle = nil
        self.shopButton = nil
        self.shopFrame = nil
        self.backButton = nil
        self.backButtonContainer = nil
        self.enterRealmButton = nil
        self.quest = nil
        self.backpack = nil
        self.togglePanel = nil
        self.menuButton = nil
        self.menuContainer = nil
        self.menuExpanded = nil
        self.questOpenButton = nil
        self.backpackOpenButton = nil
        self.teleportOpenButton = nil
        self.teleportCloseButton = nil
        self.teleportUI = nil
        self.backButtonEnabled = nil
        self.worldModeActive = nil
        self.personaButton = nil
        if currentHud == self then
                currentHud = nil
        end
end

return WorldHUD
