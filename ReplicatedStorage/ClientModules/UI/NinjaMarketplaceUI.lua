local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AbilityMetadata = require(ReplicatedStorage.ClientModules.AbilityMetadata)
local bootModules = ReplicatedStorage:WaitForChild("BootModules")

-- Try to load the ShopItems module but fall back to an empty table
local ShopItems = {Elements = {}, Weapons = {}}
local function waitForShopItemsModule()
	local module = bootModules:FindFirstChild("ShopItems")
	while not module do
		if not bootModules.Parent or not bootModules:IsDescendantOf(game) then
			return nil
		end
		task.wait()
		module = bootModules:FindFirstChild("ShopItems")
	end
	return module
end

local shopItemsModule = waitForShopItemsModule()
if shopItemsModule then
	local success, items = pcall(require, shopItemsModule)
	if success and typeof(items) == "table" then
		ShopItems = items
	else
		warn("Failed to load ShopItems module:", items)
	end
else
	warn("ShopItems module missing")
end

local NinjaMarketplaceUI = {}

local tabFrames = {}
local tabButtons = {}
local frame
local BASE_Z_INDEX = 45

-- UI Helper Functions
local function createCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function createStroke(parent, thickness, color)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 1
	stroke.Color = color or Color3.fromRGB(100, 100, 100)
	stroke.Parent = parent
	return stroke
end

local function createGradient(parent, colors, transparency)
	local gradient = Instance.new("UIGradient")
	gradient.Color = colors or ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 35)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 25))
	}
	if transparency then
		gradient.Transparency = transparency
	end
	gradient.Rotation = 45
	gradient.Parent = parent
	return gradient
end

-- Build the ninja marketplace interface
function NinjaMarketplaceUI.init(config, shop, bootUI, defaultTab)
	local root = bootUI and bootUI.root
	if not root then return end

	-- Main marketplace frame
	frame = Instance.new("Frame")
	frame.Name = "NinjaMarketplace"
	frame.Size = UDim2.fromScale(0.45, 0.6)
	frame.Position = UDim2.fromScale(0.275, 0.2)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
        frame.ZIndex = BASE_Z_INDEX
	frame.Parent = root
	createCorner(frame, 15)
	createStroke(frame, 3, Color3.fromRGB(80, 50, 120))
	createGradient(frame)

	-- Marketplace header
	local header = Instance.new("Frame")
	header.Name = "MarketplaceHeader"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	header.BackgroundTransparency = 0.2
	header.BorderSizePixel = 0
        header.ZIndex = BASE_Z_INDEX + 1
	header.Parent = frame
	createCorner(header, 15)
	createGradient(header, ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 25, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 15, 30))
	})

	-- Marketplace emblem
	local emblem = Instance.new("Frame")
	emblem.Size = UDim2.new(0, 45, 0, 45)
	emblem.Position = UDim2.new(0, 15, 0, 7.5)
	emblem.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
	emblem.BackgroundTransparency = 0.2
	emblem.BorderSizePixel = 0
        emblem.ZIndex = BASE_Z_INDEX + 2
	emblem.Parent = header
	createCorner(emblem, 22.5)

	local emblemIcon = Instance.new("TextLabel")
	emblemIcon.Size = UDim2.new(1, 0, 1, 0)
	emblemIcon.BackgroundTransparency = 1
	emblemIcon.Text = "🏪"
	emblemIcon.Font = Enum.Font.GothamBold
	emblemIcon.TextScaled = true
	emblemIcon.TextColor3 = Color3.fromRGB(220, 180, 255)
        emblemIcon.ZIndex = BASE_Z_INDEX + 3
	emblemIcon.Parent = emblem

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -200, 0, 35)
	title.Position = UDim2.new(0, 70, 0, 10)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Ninja Marketplace"
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(220, 180, 100)
        title.ZIndex = BASE_Z_INDEX + 2
	title.Parent = header

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -200, 0, 20)
	subtitle.Position = UDim2.new(0, 70, 0, 35)
	subtitle.BackgroundTransparency = 1
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Text = "⚡ Ancient artifacts & forbidden techniques"
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextScaled = true
	subtitle.TextColor3 = Color3.fromRGB(160, 160, 180)
        subtitle.ZIndex = BASE_Z_INDEX + 2
	subtitle.Parent = header

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "MarketplaceClose"
	closeBtn.Size = UDim2.new(0, 45, 0, 45)
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, -10, 0, 7.5)
	closeBtn.Text = "✕"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextScaled = true
	closeBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
	closeBtn.BackgroundColor3 = Color3.fromRGB(80, 25, 25)
	closeBtn.BackgroundTransparency = 0.1
	closeBtn.BorderSizePixel = 0
        closeBtn.ZIndex = BASE_Z_INDEX + 4
	closeBtn.AutoButtonColor = true
	closeBtn.Parent = header
	createCorner(closeBtn, 22.5)
	createStroke(closeBtn, 2, Color3.fromRGB(120, 40, 40))

	-- Tab bar
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -20, 0, 45)
	tabBar.Position = UDim2.new(0, 10, 0, 70)
	tabBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	tabBar.BackgroundTransparency = 0.3
	tabBar.BorderSizePixel = 0
        tabBar.ZIndex = BASE_Z_INDEX + 1
	tabBar.Parent = frame
	createCorner(tabBar, 10)

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 5)
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tabLayout.Parent = tabBar

	-- Content area
	local content = Instance.new("Frame")
	content.Name = "MarketplaceContent"
	content.Size = UDim2.new(1, -20, 1, -135)
	content.Position = UDim2.new(0, 10, 0, 125)
	content.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
	content.BackgroundTransparency = 0.3
	content.BorderSizePixel = 0
        content.ZIndex = BASE_Z_INDEX + 1
	content.Parent = frame
	createCorner(content, 10)
	createStroke(content, 1, Color3.fromRGB(40, 40, 60))

	-- Tab configuration
	local tabData = {
		{name = "Elements", icon = "🔥", color = Color3.fromRGB(200, 100, 50)},
		{name = "Abilities", icon = "⚡", color = Color3.fromRGB(100, 150, 250)},
		{name = "Weapons", icon = "⚔️", color = Color3.fromRGB(180, 180, 200)}
	}

	local numTabs = #tabData
	for i, tab in ipairs(tabData) do
		-- Create tab button
		local btn = Instance.new("TextButton")
		btn.Name = tab.name .. "Tab"
		btn.Size = UDim2.new(0, 120, 0, 35)
		btn.Text = tab.icon .. " " .. tab.name
		btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		btn.BackgroundTransparency = 0.2
		btn.TextColor3 = Color3.fromRGB(200, 200, 220)
		btn.Font = Enum.Font.GothamSemibold
		btn.TextScaled = true
		btn.BorderSizePixel = 0
                btn.ZIndex = BASE_Z_INDEX + 2
		btn.AutoButtonColor = true
		btn.LayoutOrder = i
		btn.Parent = tabBar
		createCorner(btn, 8)
		createStroke(btn, 1, Color3.fromRGB(60, 60, 80))
		tabButtons[tab.name] = {button = btn, color = tab.color, icon = tab.icon}

		-- Tab content frame
		local tabFrame = Instance.new("ScrollingFrame")
		tabFrame.Name = tab.name .. "Content"
		tabFrame.Size = UDim2.new(1, -10, 1, -10)
		tabFrame.Position = UDim2.new(0, 5, 0, 5)
		tabFrame.BackgroundTransparency = 1
		tabFrame.Visible = false
		tabFrame.ScrollBarThickness = 8
		tabFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
		tabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
                tabFrame.ZIndex = BASE_Z_INDEX + 2
		tabFrame.Parent = content
		tabFrames[tab.name] = tabFrame

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Parent = tabFrame
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			tabFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
		end)

		-- Tab activation
		btn.Activated:Connect(function()
			NinjaMarketplaceUI.setTab(tab.name)
		end)
	end

	-- Enhanced item creation function
	local function createItemCard(itemId, itemInfo, category, purchaseCallback)
		local card = Instance.new("Frame")
		card.Name = itemId .. "Card"
		card.Size = UDim2.new(1, -10, 0, 80)
		card.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		card.BackgroundTransparency = 0.2
		card.BorderSizePixel = 0
                card.ZIndex = BASE_Z_INDEX + 3
		createCorner(card, 10)
		createStroke(card, 1, Color3.fromRGB(60, 60, 80))

		-- Item icon
		local iconFrame = Instance.new("Frame")
		iconFrame.Size = UDim2.new(0, 60, 0, 60)
		iconFrame.Position = UDim2.new(0, 10, 0, 10)
		iconFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		iconFrame.BorderSizePixel = 0
                iconFrame.ZIndex = BASE_Z_INDEX + 4
		iconFrame.Parent = card
		createCorner(iconFrame, 30)

		local itemIcon = Instance.new("TextLabel")
		itemIcon.Size = UDim2.new(1, 0, 1, 0)
		itemIcon.BackgroundTransparency = 1
		itemIcon.Text = itemInfo.icon or (category == "Elements" and "🔥" or category == "Abilities" and "⚡" or "⚔️")
		itemIcon.Font = Enum.Font.GothamBold
		itemIcon.TextScaled = true
		itemIcon.TextColor3 = tabButtons[category].color
                itemIcon.ZIndex = BASE_Z_INDEX + 5
		itemIcon.Parent = iconFrame

		-- Item details
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.5, -85, 0, 30)
		nameLabel.Position = UDim2.new(0, 80, 0, 10)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = itemInfo.displayName or itemId
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
                nameLabel.ZIndex = BASE_Z_INDEX + 4
		nameLabel.Parent = card

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.5, -85, 0, 25)
		descLabel.Position = UDim2.new(0, 80, 0, 35)
		descLabel.BackgroundTransparency = 1
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Text = itemInfo.description or "Ancient ninja artifact"
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextScaled = true
		descLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
                descLabel.ZIndex = BASE_Z_INDEX + 4
		descLabel.Parent = card

		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Size = UDim2.new(0, 80, 0, 20)
		rarityLabel.Position = UDim2.new(0, 80, 0, 55)
		rarityLabel.BackgroundColor3 = Color3.fromRGB(50, 25, 80)
		rarityLabel.BackgroundTransparency = 0.3
		rarityLabel.Text = itemInfo.rarity or "Common"
		rarityLabel.Font = Enum.Font.GothamSemibold
		rarityLabel.TextScaled = true
		rarityLabel.TextColor3 = Color3.fromRGB(180, 150, 220)
		rarityLabel.BorderSizePixel = 0
                rarityLabel.ZIndex = BASE_Z_INDEX + 4
		rarityLabel.Parent = card
		createCorner(rarityLabel, 10)

		-- Purchase button
		local purchaseBtn = Instance.new("TextButton")
		purchaseBtn.Size = UDim2.new(0, 120, 0, 50)
		purchaseBtn.Position = UDim2.new(1, -130, 0, 15)
		purchaseBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
		purchaseBtn.BackgroundTransparency = 0.2
		purchaseBtn.Text = "🪙 " .. (itemInfo.cost or 0) .. " Coins"
		purchaseBtn.Font = Enum.Font.GothamBold
		purchaseBtn.TextScaled = true
		purchaseBtn.TextColor3 = Color3.fromRGB(150, 255, 150)
		purchaseBtn.BorderSizePixel = 0
                purchaseBtn.ZIndex = BASE_Z_INDEX + 4
		purchaseBtn.AutoButtonColor = true
		purchaseBtn.Parent = card
		createCorner(purchaseBtn, 10)
		createStroke(purchaseBtn, 2, Color3.fromRGB(80, 150, 80))

		-- Purchase button effects
		purchaseBtn.MouseEnter:Connect(function()
			purchaseBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 70)
			purchaseBtn.BackgroundTransparency = 0.1
		end)

		purchaseBtn.MouseLeave:Connect(function()
			purchaseBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
			purchaseBtn.BackgroundTransparency = 0.2
		end)

		purchaseBtn.Activated:Connect(purchaseCallback)

		return card
	end

	-- Populate Abilities tab
	local abilitiesFrame = tabFrames["Abilities"]
	local learnRF = ReplicatedStorage:FindFirstChild("LearnAbility")
	for ability, info in pairs(AbilityMetadata) do
		local itemInfo = {
			cost = info.cost,
			icon = "⚡",
			displayName = ability,
			description = info.description or "Master this ancient technique",
			rarity = info.rarity or "Rare"
		}

		local card = createItemCard(ability, itemInfo, "Abilities", function()
			if shop:Purchase(ability, info.cost) and learnRF then
				local start = os.clock()
				learnRF:InvokeServer(ability)
				warn(string.format("LearnAbility took %.3fs", os.clock() - start))
			end
		end)
		card.Parent = abilitiesFrame
	end

	-- Populate Elements tab
	local elementsFrame = tabFrames["Elements"]
	for itemId, info in pairs(ShopItems.Elements) do
		local itemInfo = {
			cost = info.cost,
			icon = "🔥",
			displayName = info.displayName or itemId,
			description = info.description or "Harness elemental power",
			rarity = info.rarity or "Common"
		}

		local card = createItemCard(itemId, itemInfo, "Elements", function()
			shop:Purchase(itemId, info.cost)
		end)
		card.Parent = elementsFrame
	end

	-- Populate Weapons tab
	local weaponsFrame = tabFrames["Weapons"]
	for itemId, info in pairs(ShopItems.Weapons) do
		local itemInfo = {
			cost = info.cost,
			icon = "⚔️",
			displayName = info.displayName or itemId,
			description = info.description or "Legendary ninja weapon",
			rarity = info.rarity or "Epic"
		}

		local card = createItemCard(itemId, itemInfo, "Weapons", function()
			shop:Purchase(itemId, info.cost)
		end)
		card.Parent = weaponsFrame
	end

	-- Tab switching function
	function NinjaMarketplaceUI.setTab(tabName)
		for name, tabFrame in pairs(tabFrames) do
			tabFrame.Visible = (name == tabName)
		end

		for name, tabData in pairs(tabButtons) do
			if name == tabName then
				tabData.button.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
				tabData.button.BackgroundTransparency = 0.1
				tabData.button.TextColor3 = Color3.fromRGB(255, 220, 120)
			else
				tabData.button.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
				tabData.button.BackgroundTransparency = 0.2
				tabData.button.TextColor3 = Color3.fromRGB(200, 200, 220)
			end
		end
	end

	-- Set default tab
	NinjaMarketplaceUI.setTab(defaultTab or "Elements")

	-- Close button functionality
	closeBtn.Activated:Connect(function()
		frame.Visible = false
	end)

	return frame
end

return NinjaMarketplaceUI
