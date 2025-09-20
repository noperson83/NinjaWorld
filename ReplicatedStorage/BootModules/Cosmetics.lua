local Cosmetics = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")

local rf = ReplicatedStorage.PersonaServiceRF
local function profileRF(action, data)
    local start = os.clock()
    local result = rf:InvokeServer(action, data)
    warn(string.format("PersonaServiceRF:%s took %.3fs", tostring(action), os.clock() - start))
    return result
end
local player = Players.LocalPlayer

local dojo
local slotButtons = {}
local uiBridge
local rootUI
local slotsContainer

local personaCache = {slots = {}, slotCount = 0}
local currentChoiceType = "Roblox"
local chosenSlot

local levelValue
local fallbackStarterBackpack

local function getCallback(name)
        if typeof(uiBridge) ~= "table" then
                return nil
        end
        local cb = uiBridge[name]
        if typeof(cb) == "function" then
                return cb
        end
        return nil
end

local function callCallback(name, ...)
        local cb = getCallback(name)
        if cb then
                return cb(...)
        end
end

local function getStarterBackpack()
        if typeof(uiBridge) == "table" then
                local fetch = uiBridge.getStarterBackpack
                if typeof(fetch) == "function" then
                        return fetch()
                end
                if uiBridge.starterBackpack ~= nil then
                        return uiBridge.starterBackpack
                end
        end
        return fallbackStarterBackpack
end

local function triggerTweenToEnd()
        local tween = getCallback("tweenToEnd")
        if tween then
                tween()
        end
end

local function applyPersonaData(p)
        if not p then return end
        if p.inventory then
                player:SetAttribute("Inventory", HttpService:JSONEncode(p.inventory))
        end
        local realms = p.unlockedRealms or p.realms
        if realms then
                local folder = player:FindFirstChild("Realms")
                if folder then
                        for name, value in pairs(realms) do
                                local flag = folder:FindFirstChild(name)
                                if not flag then
                                        flag = Instance.new("BoolValue")
                                        flag.Name = name
                                        flag.Parent = folder
                                end
                                flag.Value = value and true or false
                        end
                end
        end
end

local function getLevel()
	if levelValue and levelValue.Value then
		return levelValue.Value
	end
	local attr = player:GetAttribute("Level")
	return typeof(attr) == "number" and attr or 0
end

local function updateLevelLabels()
	for i, ui in pairs(slotButtons) do
		if ui and ui.levelLabel then
			local slot = personaCache.slots[i]
			local lvl = slot and slot.level or getLevel()
			ui.levelLabel.Text = ("Level %d"):format(lvl)
		end
	end
end

local function showConfirm(text, onYes)
	local cover = Instance.new("Frame")
	cover.Size = UDim2.fromScale(1,1)
	cover.BackgroundColor3 = Color3.new(0,0,0)
	cover.BackgroundTransparency = 0.4
	cover.ZIndex = 200
	cover.Parent = rootUI

	local box = Instance.new("Frame")
	box.Size = UDim2.fromScale(0.3,0.2)
	box.Position = UDim2.fromScale(0.5,0.5)
	box.AnchorPoint = Vector2.new(0.5,0.5)
	box.BackgroundColor3 = Color3.fromRGB(24,26,28)
	box.ZIndex = 201
	box.Parent = cover

	local msg = Instance.new("TextLabel")
	msg.Size = UDim2.new(1,0,0.5,0)
	msg.BackgroundTransparency = 1
	msg.Text = text
	msg.Font = Enum.Font.Gotham
	msg.TextScaled = true
	msg.TextColor3 = Color3.new(1,1,1)
	msg.ZIndex = 202
	msg.Parent = box

	local yes = Instance.new("TextButton")
	yes.Size = UDim2.new(0.4,0,0.3,0)
	yes.Position = UDim2.new(0.1,0,0.6,0)
	yes.Text = "Yes"
	yes.Font = Enum.Font.GothamSemibold
	yes.TextScaled = true
	yes.TextColor3 = Color3.new(1,1,1)
	yes.BackgroundColor3 = Color3.fromRGB(60,180,110)
	yes.ZIndex = 202
	yes.Parent = box

	local no = Instance.new("TextButton")
	no.Size = UDim2.new(0.4,0,0.3,0)
	no.Position = UDim2.new(0.5,0,0.6,0)
	no.Text = "No"
	no.Font = Enum.Font.GothamSemibold
	no.TextScaled = true
	no.TextColor3 = Color3.new(1,1,1)
	no.BackgroundColor3 = Color3.fromRGB(220,100,100)
	no.ZIndex = 202
	no.Parent = box

	local function close()
		cover:Destroy()
	end
	yes.MouseButton1Click:Connect(function()
		close()
		if onYes then onYes() end
	end)
	no.MouseButton1Click:Connect(close)
end

local refreshSlots

local function highestUsed()
	local hi = 0
	for i = 1, personaCache.slotCount do
		if personaCache.slots[i] ~= nil then
			hi = i
		end
	end
	return hi
end

local function getDescription(personaType)
	local desc
	if personaType == "Ninja" then
		-- Expected folder "HumanoidDescriptions" contains shared HumanoidDescription assets.
		-- Use singular name as a fallback for legacy content.
		local hdFolder = ReplicatedStorage:FindFirstChild("HumanoidDescriptions")
			or ReplicatedStorage:FindFirstChild("HumanoidDescription")
		local hd = hdFolder and hdFolder:FindFirstChild("Ninja")
		if hd then desc = hd:Clone() end
	else
		local ok, hd = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if ok then desc = hd end
	end
	return desc
end

local function updateSlots()
	local hi = math.min(highestUsed(), #slotButtons)
	local visible = math.min(hi + 1, #slotButtons)
	for i = 1, #slotButtons do
		local slot = personaCache.slots[i]
		local ui = slotButtons[i]
		if ui then
			if ui.viewport then
				ui.viewport:ClearAllChildren()
				ui.viewport.CurrentCamera = nil
			end
			if ui.placeholder then
				ui.placeholder.Visible = false
			end
			ui.frame.Visible = i <= visible
			if i <= visible then
				local index = i
				if slot then
					ui.useBtn.Visible = true
					ui.clearBtn.Visible = true
					ui.robloxBtn.Visible = false
					ui.starterBtn.Visible = false
					if ui.placeholder then ui.placeholder.Visible = false end
					if ui.viewport then
						local desc = getDescription(slot.type)
						if desc then
							local world = Instance.new("WorldModel")
							world.Parent = ui.viewport
							local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
							model:PivotTo(CFrame.new(0,0,0) * CFrame.Angles(0, math.pi, 0))
							-- Preload assets so the preview doesn't show the default black figure.
							pcall(function()
								ContentProvider:PreloadAsync({model})
							end)
							model.Parent = world
							local cam = Instance.new("Camera")
							cam.CFrame = CFrame.new(Vector3.new(0,2,4), Vector3.new(0,2,0))
							cam.Parent = ui.viewport
							ui.viewport.CurrentCamera = cam
						end
					end
					if not ui.clearConn then
						ui.clearConn = ui.clearBtn.MouseButton1Click:Connect(function()
							showConfirm(("Clear slot %d?"):format(index), function()
                                                                local res = profileRF("clear", {slot = index})
                                                                if res and res.ok then
                                                                        if chosenSlot == index then chosenSlot = nil end
                                                                        refreshSlots(res)
                                                                else
                                                                        warn("Clear failed:", res and res.err)
                                                                end
                                                        end)
                                                end)
                                        end
                                else
                                        ui.useBtn.Visible = false
					ui.clearBtn.Visible = false
					ui.robloxBtn.Visible = true
					ui.starterBtn.Visible = true
					if ui.clearConn then
						ui.clearConn:Disconnect()
						ui.clearConn = nil
					end
					if ui.placeholder then ui.placeholder.Visible = true end
				end
			end
		end
	end
	updateLevelLabels()
end

refreshSlots = function(data)
        personaCache = data or personaCache
        updateSlots()
end

local function showDojoPicker()
        if dojo then dojo.Visible = true end
        callCallback("showDojoPicker")
end

local function showLoadout(personaType)
        if dojo then dojo.Visible = false end
        local showLoadoutCallback = getCallback("showLoadout")
        if showLoadoutCallback then
                showLoadoutCallback(personaType)
        end

        local buildPreview = getCallback("buildCharacterPreview")
        if buildPreview then
                buildPreview(personaType)
        end

        local updateBackpack = getCallback("updateBackpack")
        if updateBackpack then
                local saved = player:GetAttribute("Inventory")
                if typeof(saved) == "string" then
                        local ok, data = pcall(HttpService.JSONDecode, HttpService, saved)
                        if ok then
                                updateBackpack(data)
                        end
                else
                        local starter = getStarterBackpack()
                        if starter then
                                updateBackpack(starter)
                                local conn
                                conn = player:GetAttributeChangedSignal("Inventory"):Connect(function()
                                        local inv = player:GetAttribute("Inventory")
                                        if typeof(inv) == "string" then
                                                local ok, data = pcall(HttpService.JSONDecode, HttpService, inv)
                                                if ok then
                                                        updateBackpack(data)
                                                        if conn then
                                                                conn:Disconnect()
                                                                conn = nil
                                                        end
                                                end
                                        end
                                end)
                        end
                end
        end
end
end

function Cosmetics.getSelectedPersona()
	local personaType = currentChoiceType
	if chosenSlot and personaCache and personaCache.slots then
		local slot = personaCache.slots[chosenSlot]
		if slot and slot.type then personaType = slot.type end
	end
	return personaType, chosenSlot
end

function Cosmetics.refreshSlots(data)
        refreshSlots(data)
end

function Cosmetics.showDojoPicker()
	showDojoPicker()
end

function Cosmetics.init(config, root, interface)
        uiBridge = interface
        rootUI = root
        if typeof(config) == "table" then
                fallbackStarterBackpack = config.inventory or config.starterBackpack
        else
                fallbackStarterBackpack = nil
        end

        local stats = player:FindFirstChild("Stats")
        if stats then
                levelValue = stats:FindFirstChild("Level")
		if levelValue then
			levelValue:GetPropertyChangedSignal("Value"):Connect(updateLevelLabels)
			updateLevelLabels()
		end
	else
		player.ChildAdded:Connect(function(child)
			if child.Name == "Stats" then
				levelValue = child:FindFirstChild("Level")
				if levelValue then
					levelValue:GetPropertyChangedSignal("Value"):Connect(updateLevelLabels)
					updateLevelLabels()
				end
			end
		end)
	end
	player:GetAttributeChangedSignal("Level"):Connect(updateLevelLabels)

	dojo = Instance.new("Frame")
	dojo.Size = UDim2.fromScale(1,1)
	dojo.BackgroundTransparency = 1
	dojo.Visible = false
	dojo.ZIndex = 10
	dojo.Parent = root

	local dojoTitle = Instance.new("ImageLabel")
	dojoTitle.Size = UDim2.fromScale(0.7,0.24)
	dojoTitle.Position = UDim2.fromScale(0.5,0.1)
	dojoTitle.AnchorPoint = Vector2.new(0.5,0.5)
	-- Use BootUI logo where starter dojo image was
	dojoTitle.Image = "rbxassetid://138217463115431"
	dojoTitle.BackgroundTransparency = 1
	dojoTitle.ScaleType = Enum.ScaleType.Fit
	dojoTitle.ZIndex = 11
	dojoTitle.Parent = dojo

	local picker = Instance.new("Frame")
	picker.Size = UDim2.fromScale(0.8,0.7)
	picker.Position = UDim2.fromScale(0.5,0.55)
	picker.AnchorPoint = Vector2.new(0.5,0.5)
	picker.BackgroundColor3 = Color3.fromRGB(24,26,28)
	picker.BackgroundTransparency = 0.6
	picker.BorderSizePixel = 0
	picker.ZIndex = 11
	picker.Parent = dojo

	-- Display starter dojo image at the bottom of the picker
	local starterDojoImg = Instance.new("ImageLabel")
	starterDojoImg.Size = UDim2.fromScale(0.7,0.08)
	starterDojoImg.Position = UDim2.fromScale(0.5,0.92)
	starterDojoImg.AnchorPoint = Vector2.new(0.5,1)
	starterDojoImg.Image = "rbxassetid://137361385013636"
	starterDojoImg.BackgroundTransparency = 1
	starterDojoImg.ScaleType = Enum.ScaleType.Fit
	starterDojoImg.ZIndex = 12
	starterDojoImg.Parent = picker

	local function makeButton(text, y)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.9, 0, 0, 56)
		b.Position = UDim2.fromScale(0.5, y)
		b.AnchorPoint = Vector2.new(0.5,0.5)
		b.Text = text
		b.Font = Enum.Font.GothamSemibold
		b.TextScaled = true
		b.TextColor3 = Color3.new(1,1,1)
		b.BackgroundColor3 = Color3.fromRGB(50,120,255)
		b.AutoButtonColor = true
		b.ZIndex = 11
		b.Parent = picker
		return b
	end

	-- Display persona slots above the dojo image
	slotsContainer = Instance.new("Frame")
	slotsContainer.Size = UDim2.new(0.9,0,0.9,0)
	slotsContainer.Position = UDim2.fromScale(0.5,0.44)
	slotsContainer.AnchorPoint = Vector2.new(0.5,0.5)
	slotsContainer.BackgroundTransparency = 1
	slotsContainer.BorderSizePixel = 0
	slotsContainer.ZIndex = 11
	slotsContainer.Parent = picker

        -- fetch initial slot data
        personaCache = config.personaData or personaCache

	slotButtons = {}

	-- create slot 1 (center, larger)
	do
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(0.4, 0.6)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BackgroundTransparency = 1
		frame.ZIndex = 11
		frame.Parent = slotsContainer

		local viewport = Instance.new("ViewportFrame")
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.BackgroundTransparency = 1
		viewport.BorderSizePixel = 2
		viewport.BorderColor3 = Color3.fromRGB(40, 40, 40)
		viewport.ZIndex = 9
		viewport.Parent = frame

		local placeholder = Instance.new("ImageLabel")
		placeholder.Size = UDim2.fromScale(1,1)
		placeholder.BackgroundTransparency = 1
		placeholder.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
		placeholder.ScaleType = Enum.ScaleType.Fit
		placeholder.ZIndex = 10
		placeholder.Parent = frame

		local levelLabel = Instance.new("TextLabel")
		levelLabel.Name = "LevelLabel"
		levelLabel.Size = UDim2.new(1,0,0.15,0)
		levelLabel.Position = UDim2.new(0.5,0,0,0)
		levelLabel.AnchorPoint = Vector2.new(0.5,1)
		levelLabel.BackgroundTransparency = 1
		levelLabel.TextXAlignment = Enum.TextXAlignment.Center
		levelLabel.Text = ""
		levelLabel.Font = Enum.Font.Garamond
		levelLabel.TextScaled = false
		levelLabel.TextSize = 14
		levelLabel.TextColor3 = Color3.fromRGB(220,220,220)
		levelLabel.ZIndex = 11
		levelLabel.Parent = frame

		local robloxBtn = Instance.new("TextButton")
		robloxBtn.Size = UDim2.new(0.45,0,0.25,0)
		robloxBtn.Position = UDim2.new(0.05,0,0.3,0)
		robloxBtn.Text = "Roblox"
		robloxBtn.Font = Enum.Font.GothamSemibold
		robloxBtn.TextScaled = true
		robloxBtn.TextColor3 = Color3.new(1,1,1)
		robloxBtn.BackgroundColor3 = Color3.fromRGB(80,120,200)
		robloxBtn.AutoButtonColor = true
		robloxBtn.ZIndex = 11
		robloxBtn.Parent = frame

		local starterBtn = Instance.new("TextButton")
		starterBtn.Size = UDim2.new(0.45,0,0.25,0)
		starterBtn.Position = UDim2.new(0.5,0,0.3,0)
		starterBtn.Text = "Starter"
		starterBtn.Font = Enum.Font.GothamSemibold
		starterBtn.TextScaled = true
		starterBtn.TextColor3 = Color3.new(1,1,1)
		starterBtn.BackgroundColor3 = Color3.fromRGB(100,100,220)
		starterBtn.AutoButtonColor = true
		starterBtn.ZIndex = 11
		starterBtn.Parent = frame

		local useBtn = Instance.new("TextButton")
		useBtn.Size = UDim2.new(0.7,0,0.15,0)
		useBtn.Position = UDim2.new(0.15,0,0.7,0)
		useBtn.Text = "Use"
		useBtn.Font = Enum.Font.GothamSemibold
		useBtn.TextScaled = true
		useBtn.TextColor3 = Color3.new(1,1,1)
		useBtn.BackgroundColor3 = Color3.fromRGB(60,180,110)
		useBtn.AutoButtonColor = true
		useBtn.ZIndex = 11
		useBtn.Parent = frame

		local clearBtn = Instance.new("TextButton")
		clearBtn.Size = UDim2.new(0.5,0,0.08,0)
		clearBtn.AnchorPoint = Vector2.new(0.5,0)
		clearBtn.Position = UDim2.new(0.5,0,0.88,0)
		clearBtn.Text = "Clear"
		clearBtn.Font = Enum.Font.Gotham
		clearBtn.TextScaled = true
		clearBtn.TextColor3 = Color3.new(1,1,1)
		clearBtn.BackgroundColor3 = Color3.fromRGB(200,80,80)
		clearBtn.AutoButtonColor = true
		clearBtn.ZIndex = 11
		clearBtn.Parent = frame

		slotButtons[1] = {
			frame = frame,
			viewport = viewport,
			placeholder = placeholder,
			useBtn = useBtn,
			clearBtn = clearBtn,
			robloxBtn = robloxBtn,
			starterBtn = starterBtn,
			levelLabel = levelLabel
		}
	end

	-- create slot 2 (left)
	do
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(0.25, 0.4)
		frame.Position = UDim2.fromScale(0.15, 0.5)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BackgroundTransparency = 1
		frame.ZIndex = 11
		frame.Parent = slotsContainer

		local viewport = Instance.new("ViewportFrame")
		viewport.Size = UDim2.fromScale(1,1)
		viewport.BackgroundTransparency = 1
		viewport.ZIndex = 9
		viewport.Parent = frame

		local placeholder = Instance.new("ImageLabel")
		placeholder.Size = UDim2.fromScale(1,1)
		placeholder.BackgroundTransparency = 1
		placeholder.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
		placeholder.ScaleType = Enum.ScaleType.Fit
		placeholder.ZIndex = 10
		placeholder.Parent = frame

		local levelLabel = Instance.new("TextLabel")
		levelLabel.Name = "LevelLabel"
		levelLabel.Size = UDim2.new(1,0,0.15,0)
		levelLabel.Position = UDim2.new(0.5,0,0,0)
		levelLabel.AnchorPoint = Vector2.new(0.5,1)
		levelLabel.BackgroundTransparency = 1
		levelLabel.TextXAlignment = Enum.TextXAlignment.Center
		levelLabel.Text = ""
		levelLabel.Font = Enum.Font.Garamond
		levelLabel.TextScaled = false
		levelLabel.TextSize = 14
		levelLabel.TextColor3 = Color3.fromRGB(220,220,220)
		levelLabel.ZIndex = 11
		levelLabel.Parent = frame

		local robloxBtn = Instance.new("TextButton")
		robloxBtn.Size = UDim2.new(0.45,0,0.25,0)
		robloxBtn.Position = UDim2.new(0.05,0,0.3,0)
		robloxBtn.Text = "Roblox"
		robloxBtn.Font = Enum.Font.GothamSemibold
		robloxBtn.TextScaled = true
		robloxBtn.TextColor3 = Color3.new(1,1,1)
		robloxBtn.BackgroundColor3 = Color3.fromRGB(80,120,200)
		robloxBtn.AutoButtonColor = true
		robloxBtn.ZIndex = 11
		robloxBtn.Parent = frame

		local starterBtn = Instance.new("TextButton")
		starterBtn.Size = UDim2.new(0.45,0,0.25,0)
		starterBtn.Position = UDim2.new(0.5,0,0.3,0)
		starterBtn.Text = "Starter"
		starterBtn.Font = Enum.Font.GothamSemibold
		starterBtn.TextScaled = true
		starterBtn.TextColor3 = Color3.new(1,1,1)
		starterBtn.BackgroundColor3 = Color3.fromRGB(100,100,220)
		starterBtn.AutoButtonColor = true
		starterBtn.ZIndex = 11
		starterBtn.Parent = frame

		local useBtn = Instance.new("TextButton")
		useBtn.Size = UDim2.new(0.7,0,0.15,0)
		useBtn.Position = UDim2.new(0.15,0,0.7,0)
		useBtn.Text = "Use"
		useBtn.Font = Enum.Font.GothamSemibold
		useBtn.TextScaled = true
		useBtn.TextColor3 = Color3.new(1,1,1)
		useBtn.BackgroundColor3 = Color3.fromRGB(60,180,110)
		useBtn.AutoButtonColor = true
		useBtn.ZIndex = 11
		useBtn.Parent = frame

		local clearBtn = Instance.new("TextButton")
		clearBtn.Size = UDim2.new(0.5,0,0.08,0)
		clearBtn.AnchorPoint = Vector2.new(0.5,0)
		clearBtn.Position = UDim2.new(0.5,0,0.88,0)
		clearBtn.Text = "Clear"
		clearBtn.Font = Enum.Font.Gotham
		clearBtn.TextScaled = true
		clearBtn.TextColor3 = Color3.new(1,1,1)
		clearBtn.BackgroundColor3 = Color3.fromRGB(200,80,80)
		clearBtn.AutoButtonColor = true
		clearBtn.ZIndex = 11
		clearBtn.Parent = frame

		slotButtons[2] = {
			frame = frame,
			viewport = viewport,
			placeholder = placeholder,
			useBtn = useBtn,
			clearBtn = clearBtn,
			robloxBtn = robloxBtn,
			starterBtn = starterBtn,
			levelLabel = levelLabel
		}
	end

	-- create slot 3 (right)
	do
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(0.25, 0.4)
		frame.Position = UDim2.fromScale(0.85, 0.5)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BackgroundTransparency = 1
		frame.ZIndex = 11
		frame.Parent = slotsContainer

		local viewport = Instance.new("ViewportFrame")
		viewport.Size = UDim2.fromScale(1,1)
		viewport.BackgroundTransparency = 1
		viewport.ZIndex = 9
		viewport.Parent = frame

		local placeholder = Instance.new("ImageLabel")
		placeholder.Size = UDim2.fromScale(1,1)
		placeholder.BackgroundTransparency = 1
		placeholder.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
		placeholder.ScaleType = Enum.ScaleType.Fit
		placeholder.ZIndex = 10
		placeholder.Parent = frame

		local levelLabel = Instance.new("TextLabel")
		levelLabel.Name = "LevelLabel"
		levelLabel.Size = UDim2.new(1,0,0.15,0)
		levelLabel.Position = UDim2.new(0.5,0,0,0)
		levelLabel.AnchorPoint = Vector2.new(0.5,1)
		levelLabel.BackgroundTransparency = 1
		levelLabel.TextXAlignment = Enum.TextXAlignment.Center
		levelLabel.Text = ""
		levelLabel.Font = Enum.Font.Garamond
		levelLabel.TextScaled = false
		levelLabel.TextSize = 14
		levelLabel.TextColor3 = Color3.fromRGB(220,220,220)
		levelLabel.ZIndex = 11
		levelLabel.Parent = frame

		local robloxBtn = Instance.new("TextButton")
		robloxBtn.Size = UDim2.new(0.45,0,0.25,0)
		robloxBtn.Position = UDim2.new(0.05,0,0.3,0)
		robloxBtn.Text = "Roblox"
		robloxBtn.Font = Enum.Font.GothamSemibold
		robloxBtn.TextScaled = true
		robloxBtn.TextColor3 = Color3.new(1,1,1)
		robloxBtn.BackgroundColor3 = Color3.fromRGB(80,120,200)
		robloxBtn.AutoButtonColor = true
		robloxBtn.ZIndex = 11
		robloxBtn.Parent = frame

		local starterBtn = Instance.new("TextButton")
		starterBtn.Size = UDim2.new(0.45,0,0.25,0)
		starterBtn.Position = UDim2.new(0.5,0,0.3,0)
		starterBtn.Text = "Starter"
		starterBtn.Font = Enum.Font.GothamSemibold
		starterBtn.TextScaled = true
		starterBtn.TextColor3 = Color3.new(1,1,1)
		starterBtn.BackgroundColor3 = Color3.fromRGB(100,100,220)
		starterBtn.AutoButtonColor = true
		starterBtn.ZIndex = 11
		starterBtn.Parent = frame

		local useBtn = Instance.new("TextButton")
		useBtn.Size = UDim2.new(0.7,0,0.15,0)
		useBtn.Position = UDim2.new(0.15,0,0.7,0)
		useBtn.Text = "Use"
		useBtn.Font = Enum.Font.GothamSemibold
		useBtn.TextScaled = true
		useBtn.TextColor3 = Color3.new(1,1,1)
		useBtn.BackgroundColor3 = Color3.fromRGB(60,180,110)
		useBtn.AutoButtonColor = true
		useBtn.ZIndex = 11
		useBtn.Parent = frame

		local clearBtn = Instance.new("TextButton")
		clearBtn.Size = UDim2.new(0.5,0,0.08,0)
		clearBtn.AnchorPoint = Vector2.new(0.5,0)
		clearBtn.Position = UDim2.new(0.5,0,0.88,0)
		clearBtn.Text = "Clear"
		clearBtn.Font = Enum.Font.Gotham
		clearBtn.TextScaled = true
		clearBtn.TextColor3 = Color3.new(1,1,1)
		clearBtn.BackgroundColor3 = Color3.fromRGB(200,80,80)
		clearBtn.AutoButtonColor = true
		clearBtn.ZIndex = 11
		clearBtn.Parent = frame

		slotButtons[3] = {
			frame = frame,
			viewport = viewport,
			placeholder = placeholder,
			useBtn = useBtn,
			clearBtn = clearBtn,
			robloxBtn = robloxBtn,
			starterBtn = starterBtn,
			levelLabel = levelLabel
		}
	end

	updateSlots()

	for i,entry in pairs(slotButtons) do
		local index = i
               entry.useBtn.MouseButton1Click:Connect(function()
                        local result = profileRF("use", {slot = index})
                        if not (result and result.ok) then warn("Use slot failed:", result and result.err) return end
                        chosenSlot = index
                        currentChoiceType = result.persona and result.persona.type or currentChoiceType
                        applyPersonaData(result.persona)
                        triggerTweenToEnd()
                        showLoadout(result.persona and result.persona.type or currentChoiceType)
                end)
               entry.robloxBtn.MouseButton1Click:Connect(function()
                        local res = profileRF("save", {slot = index, type = "Roblox"})
                        if res and res.ok then
                                refreshSlots(res)
                                local useRes = profileRF("use", {slot = index})
                                if useRes and useRes.ok then
                                        chosenSlot = index
                                        currentChoiceType = "Roblox"
                                        applyPersonaData(useRes.persona)
                                        triggerTweenToEnd()
                                        showLoadout("Roblox")
                                else
                                        warn("Use slot failed:", useRes and useRes.err)
                                end
                        else
                                warn("Save failed:", res and res.err)
                        end
                end)
               entry.starterBtn.MouseButton1Click:Connect(function()
                        local res = profileRF("save", {slot = index, type = "Ninja"})
                        if res and res.ok then
                                refreshSlots(res)
                                local useRes = profileRF("use", {slot = index})
                                if useRes and useRes.ok then
                                        chosenSlot = index
                                        currentChoiceType = "Ninja"
                                        applyPersonaData(useRes.persona)
                                        triggerTweenToEnd()
                                        showLoadout("Ninja")
                                else
                                        warn("Use slot failed:", useRes and useRes.err)
                                end
                        else
                                warn("Save failed:", res and res.err)
                        end
                end)
	end
end

return Cosmetics
