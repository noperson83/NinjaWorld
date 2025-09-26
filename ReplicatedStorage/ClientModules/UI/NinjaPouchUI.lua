local NinjaPouchUI = {}

local function clearChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

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

function NinjaPouchUI.init(parent, baseY)
	local self = {}
	self.data = {gold = 0, shurikens = 0, kunai = 0, scrolls = 0}
	self.currentTab = "Tools"

	-- Main pouch container
	local pouch = Instance.new("Frame")
	pouch.Name = "NinjaPouch"
	pouch.Size = UDim2.new(0.49, -20, 0.74, 0)
	pouch.Position = UDim2.new(1, -20, 0, baseY + 80)
	pouch.AnchorPoint = Vector2.new(1, 0)
	pouch.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	pouch.BackgroundTransparency = 0.1
	pouch.BorderSizePixel = 0
	pouch.Parent = parent
	createCorner(pouch, 12)
	createStroke(pouch, 2, Color3.fromRGB(60, 60, 80))

	-- Ninja emblem background
	local emblem = Instance.new("Frame")
	emblem.Size = UDim2.new(0, 40, 0, 40)
	emblem.Position = UDim2.new(0, 15, 0, 10)
	emblem.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
	emblem.BackgroundTransparency = 0.3
	emblem.BorderSizePixel = 0
	emblem.Parent = pouch
	createCorner(emblem, 20)

	local emblemIcon = Instance.new("TextLabel")
	emblemIcon.Size = UDim2.new(1, 0, 1, 0)
	emblemIcon.BackgroundTransparency = 1
	emblemIcon.Text = "忍" -- Japanese character for "ninja"
	emblemIcon.Font = Enum.Font.GothamBold
	emblemIcon.TextScaled = true
	emblemIcon.TextColor3 = Color3.fromRGB(200, 50, 50)
	emblemIcon.Parent = emblem

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -120, 0, 35)
	title.Position = UDim2.new(0, 65, 0, 15)
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Ninja's Pouch"
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(220, 220, 240)
	title.Parent = pouch

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "PouchCloseButton"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -8, 0, 8)
	closeButton.Text = "✕"
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextScaled = true
	closeButton.TextColor3 = Color3.fromRGB(255, 100, 100)
	closeButton.BackgroundColor3 = Color3.fromRGB(40, 15, 15)
	closeButton.BackgroundTransparency = 0.2
	closeButton.BorderSizePixel = 0
	closeButton.Parent = pouch
	createCorner(closeButton, 15)

	-- Stealth meter
	local stealthFrame = Instance.new("Frame")
	stealthFrame.Size = UDim2.new(1, -30, 0, 12)
	stealthFrame.Position = UDim2.new(0, 15, 0, 60)
	stealthFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	stealthFrame.BorderSizePixel = 0
	stealthFrame.Parent = pouch
	createCorner(stealthFrame, 6)

	local stealthBar = Instance.new("Frame")
	stealthBar.Size = UDim2.new(0.8, 0, 1, 0)
	stealthBar.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
	stealthBar.BorderSizePixel = 0
	stealthBar.Parent = stealthFrame
	createCorner(stealthBar, 6)

	local stealthLabel = Instance.new("TextLabel")
	stealthLabel.Size = UDim2.new(1, -30, 0, 20)
	stealthLabel.Position = UDim2.new(0, 15, 0, 78)
	stealthLabel.BackgroundTransparency = 1
	stealthLabel.TextXAlignment = Enum.TextXAlignment.Left
	stealthLabel.Text = "Stealth: 80% • Ready for mission"
	stealthLabel.Font = Enum.Font.Gotham
	stealthLabel.TextScaled = true
	stealthLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	stealthLabel.Parent = pouch

	-- Tab bar
	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2.new(1, -30, 0, 35)
	tabBar.Position = UDim2.new(0, 15, 0, 110)
	tabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	tabBar.BorderSizePixel = 0
	tabBar.Parent = pouch
	createCorner(tabBar, 8)

	local tabButtons = {}
	local tabData = {
		{name = "Tools", icon = "⚔"},
		{name = "Weapons", icon = "🗡"},
		{name = "Consumables", icon = "📜"},
		{name = "Secrets", icon = "🔮"}
	}

	for i, tab in ipairs(tabData) do
		local btn = Instance.new("TextButton")
		btn.Name = tab.name .. "Tab"
		btn.Size = UDim2.new(0.25, -2, 1, -4)
		btn.Position = UDim2.new((i-1) * 0.25, 2, 0, 2)
		btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
		btn.BackgroundTransparency = 0.3
		btn.TextColor3 = Color3.fromRGB(200, 200, 220)
		btn.Font = Enum.Font.GothamSemibold
		btn.TextScaled = true
		btn.Text = tab.icon .. "\n" .. tab.name
		btn.BorderSizePixel = 0
		btn.Parent = tabBar
		createCorner(btn, 6)
		tabButtons[tab.name] = btn
	end

	-- Content area
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ContentScroll"
	scrollFrame.Size = UDim2.new(1, -30, 1, -160)
	scrollFrame.Position = UDim2.new(0, 15, 0, 155)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.ScrollBarThickness = 8
	scrollFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	scrollFrame.BackgroundTransparency = 0.5
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
	scrollFrame.Parent = pouch
	createCorner(scrollFrame, 8)

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Padding = UDim.new(0, 8)
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Parent = scrollFrame

	contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 10)
	end)

	-- Helper functions for content creation
	local function addSectionHeader(text, icon)
		local header = Instance.new("Frame")
		header.Size = UDim2.new(1, -10, 0, 35)
		header.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		header.BorderSizePixel = 0
		header.Parent = scrollFrame
		createCorner(header, 6)

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -15, 1, 0)
		label.Position = UDim2.new(0, 15, 0, 0)
		label.BackgroundTransparency = 1
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(220, 180, 100)
		label.Text = (icon or "▶") .. " " .. text
		label.Parent = header
	end

	local function addStatRow(name, value, icon)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 32)
		row.BackgroundTransparency = 1
		row.Parent = scrollFrame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.65, -15, 1, 0)
		nameLabel.Position = UDim2.new(0, 15, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
		nameLabel.Text = (icon or "•") .. " " .. name
		nameLabel.Parent = row

		local valueLabel = Instance.new("TextLabel")
		valueLabel.Size = UDim2.new(0.35, -10, 1, 0)
		valueLabel.Position = UDim2.new(0.65, 0, 0, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Font = Enum.Font.GothamBold
		valueLabel.TextScaled = true
		valueLabel.TextColor3 = Color3.fromRGB(100, 200, 150)
		valueLabel.Text = tostring(value or 0)
		valueLabel.Parent = row
	end

	local function addItemRow(item)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 45)
		row.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
		row.BackgroundTransparency = 0.3
		row.BorderSizePixel = 0
		row.Parent = scrollFrame
		createCorner(row, 6)
		createStroke(row, 1, Color3.fromRGB(60, 60, 70))

		local itemIcon = Instance.new("TextLabel")
		itemIcon.Size = UDim2.new(0, 35, 0, 35)
		itemIcon.Position = UDim2.new(0, 8, 0, 5)
		itemIcon.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		itemIcon.BorderSizePixel = 0
		itemIcon.Text = item.icon or "⚫"
		itemIcon.Font = Enum.Font.GothamBold
		itemIcon.TextScaled = true
		itemIcon.TextColor3 = Color3.fromRGB(180, 180, 200)
		itemIcon.Parent = row
		createCorner(itemIcon, 17)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.55, -50, 0, 22)
		nameLabel.Position = UDim2.new(0, 50, 0, 5)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Font = Enum.Font.GothamSemibold
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
		nameLabel.Text = item.name
		nameLabel.Parent = row

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.55, -50, 0, 18)
		descLabel.Position = UDim2.new(0, 50, 0, 22)
		descLabel.BackgroundTransparency = 1
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextScaled = true
		descLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
		descLabel.Text = item.description or "Ancient ninja tool"
		descLabel.Parent = row

		local qtyLabel = Instance.new("TextLabel")
		qtyLabel.Size = UDim2.new(0.3, -15, 1, 0)
		qtyLabel.Position = UDim2.new(0.7, 0, 0, 0)
		qtyLabel.BackgroundTransparency = 1
		qtyLabel.TextXAlignment = Enum.TextXAlignment.Right
		qtyLabel.Font = Enum.Font.GothamBold
		qtyLabel.TextScaled = true
		qtyLabel.TextColor3 = Color3.fromRGB(120, 200, 160)
		qtyLabel.Text = string.format("%d/%d", item.quantity or 0, item.maxStack or 99)
		qtyLabel.Parent = row
	end

	-- Rendering functions
	function self:render(tab)
		self.currentTab = tab or self.currentTab
		clearChildren(scrollFrame)

		-- Update tab button states
		for name, btn in pairs(tabButtons) do
			if name == self.currentTab then
				btn.BackgroundColor3 = Color3.fromRGB(80, 50, 120)
				btn.BackgroundTransparency = 0.1
			else
				btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
				btn.BackgroundTransparency = 0.3
			end
		end

		local data = self.data
		if not data then return end

		if self.currentTab == "Tools" then
			addSectionHeader("Resources", "💰")
			addStatRow("Gold Coins", data.gold or 0, "🪙")
			addStatRow("Honor Points", data.honor or 100, "⭐")

			addSectionHeader("Mission Stats", "📊")
			addStatRow("Completed Missions", data.missions or 0, "✅")
			addStatRow("Stealth Rating", "S-Rank", "🥷")

		elseif self.currentTab == "Weapons" then
			addSectionHeader("Arsenal", "⚔")
			for _, weapon in ipairs(data.weapons or {}) do
				addItemRow(weapon)
			end

		elseif self.currentTab == "Consumables" then
			addSectionHeader("Potions & Scrolls", "🧪")
			for _, item in ipairs(data.consumables or {}) do
				addItemRow(item)
			end

		elseif self.currentTab == "Secrets" then
			addSectionHeader("Hidden Arts", "🔮")
			for _, secret in ipairs(data.secrets or {}) do
				addItemRow(secret)
			end
		end
	end

	function self:setData(pouchData)
		self.data = pouchData or {}
		self:render(self.currentTab)
	end

	function self:updateResources(gold, honor, missions)
		self.data = self.data or {}
		self.data.gold = gold or self.data.gold or 0
		self.data.honor = honor or self.data.honor or 100
		self.data.missions = missions or self.data.missions or 0
		self:render(self.currentTab)
	end

	function self:setVisible(visible)
		pouch.Visible = visible and true or false
	end

	function self:isVisible()
		return pouch.Visible
	end

	-- Event connections
	closeButton.MouseButton1Click:Connect(function()
		self:setVisible(false)
	end)

	for name, btn in pairs(tabButtons) do
		btn.MouseButton1Click:Connect(function()
			self:render(name)
		end)
	end

	-- Store references
	self.closeButton = closeButton
	self.root = pouch
	self.tabButtons = tabButtons

	-- Initial render
	self:render(self.currentTab)
	return self
end

return NinjaPouchUI
