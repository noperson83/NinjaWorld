-- Ninja World EXP 3000
-- Boot.client.lua — v7.4
-- Changes from v7.3:
--  • Viewport: avatar now faces the camera by default (yaw = π)
--  • Emote bar across the top of Loadout to animate preview (Wave / Point / Dance / Laugh / Cheer / Sit / Idle)
--  • Minor: consistent 0.6 transparency panels, plus small cleanups

-- =====================
-- Services & locals
-- =====================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local ContentProvider   = game:GetService("ContentProvider")
local TeleportService   = game:GetService("TeleportService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")

local player  = Players.LocalPlayer
local rf      = ReplicatedStorage:WaitForChild("PersonaServiceRF")
local cam     = Workspace.CurrentCamera
local enterRE = ReplicatedStorage:FindFirstChild("EnterDojoRE") -- created by server script

-- =====================
-- Config
-- =====================
local MAIN_PLACE_ID  = 15999399322            -- >0 shows teleport button
local CAM_TWEEN_TIME = 1.6

local ASSETS = {
	Logo     = "rbxassetid://138217463115431",
	PaperTex = "rbxassetid://131504699316598",
}

local StarterBackpack = {
	capacity = 20,
	items = {
		{name = "Elemental Orbs", qty = 3, stack = 9},
	}
}

-- =====================
-- Camera helpers (world)
-- =====================
local camerasFolder = Workspace:WaitForChild("Cameras", 5)
local startPos      = camerasFolder and camerasFolder:FindFirstChild("startPos")
local endPos        = camerasFolder and camerasFolder:FindFirstChild("endPos")

local function partAttr(p, name, default)
	local v = p and p:GetAttribute(name)
	return (typeof(v) == "number") and v or default
end

local function faceCF(part)
	if not part then return cam.CFrame end
	-- FRONT = LookVector
	local f =  part.CFrame.LookVector
	local u =  part.CFrame.UpVector
	local dist   = partAttr(part, "Dist",   0)  -- pull camera back from the part
	local height = partAttr(part, "Height", 0)  -- lift camera
	local ahead  = partAttr(part, "Ahead",  10) -- how far ahead to look into the room
	local pos    = part.Position - f*dist + u*height
	local target = part.Position + f*ahead
	return CFrame.lookAt(pos, target, u)
end

local function partFOV(part)
	return partAttr(part, "FOV", cam.FieldOfView)
end

local function applyStartCam()
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = faceCF(startPos)
	cam.FieldOfView = partFOV(startPos)
end

local function holdStartCam(seconds)
	applyStartCam()
	local untilT = os.clock() + (seconds or 1.0)
	local key = "NW_HoldStart"
	RunService:BindToRenderStep(key, Enum.RenderPriority.Camera.Value + 1, function()
		cam = Workspace.CurrentCamera
		applyStartCam()
		if os.clock() > untilT then RunService:UnbindFromRenderStep(key) end
	end)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		cam = Workspace.CurrentCamera
		applyStartCam()
	end)
end

local function tweenToEnd()
	if not endPos then return end
	local cf  = faceCF(endPos)
	local fov = partFOV(endPos)
	TweenService:Create(cam, TweenInfo.new(CAM_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = cf, FieldOfView = fov}):Play()
end

-- =====================
-- Lighting helpers (disable DOF while UI is visible)
-- =====================
local savedDOF = nil
local function disableUIBlur()
	if savedDOF then return end
	savedDOF = {}
	for _,e in ipairs(Lighting:GetChildren()) do
		if e:IsA("DepthOfFieldEffect") then savedDOF[e] = e.Enabled; e.Enabled = false end
	end
end
local function restoreUIBlur()
	if not savedDOF then return end
	for e,was in pairs(savedDOF) do if e and e.Parent then e.Enabled = was end end
	savedDOF = nil
end

-- =====================
-- UI root
-- =====================
local gui = Instance.new("ScreenGui"); local ui = gui
ui.ResetOnSpawn   = false
ui.Name           = "IntroGui"
ui.IgnoreGuiInset = true
ui.DisplayOrder   = 100
ui.Parent         = player:WaitForChild("PlayerGui")

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1,1)
root.BackgroundTransparency = 1
root.Parent = ui

-- Intro visuals
local paperBG = Instance.new("ImageLabel")
paperBG.Size = UDim2.fromScale(1,1)
paperBG.BackgroundTransparency = 1
paperBG.Image = ASSETS.PaperTex
paperBG.ScaleType = Enum.ScaleType.Tile
paperBG.TileSize = UDim2.fromOffset(256,256)
paperBG.ImageTransparency = 0.12
paperBG.ImageColor3 = Color3.fromRGB(250,235,220)
paperBG.ZIndex = 1
paperBG.Parent = root

local logoImg = Instance.new("ImageLabel")
logoImg.Size = UDim2.fromOffset(300,300)
logoImg.Position = UDim2.fromScale(0.5,0.25)
logoImg.AnchorPoint = Vector2.new(0.5,0.5)
logoImg.BackgroundTransparency = 1
logoImg.Image = ASSETS.Logo
logoImg.ZIndex = 5
logoImg.Parent = root
Instance.new("UIAspectRatioConstraint", logoImg).AspectRatio = 1

local sub = Instance.new("TextLabel")
sub.Size = UDim2.fromOffset(600,50)
sub.Position = UDim2.fromScale(0.5,0.44)
sub.AnchorPoint = Vector2.new(0.5,0.5)
sub.Text = "Loading…"
sub.Font = Enum.Font.Gotham
sub.TextScaled = true
sub.TextColor3 = Color3.fromRGB(230,230,230)
sub.BackgroundTransparency = 1
sub.ZIndex = 5
sub.Parent = root

local barBG = Instance.new("Frame")
barBG.Size = UDim2.new(0.6,0,0,8)
barBG.Position = UDim2.fromScale(0.2,0.49)
barBG.BackgroundColor3 = Color3.fromRGB(40,40,42)
barBG.BorderSizePixel = 0
barBG.ZIndex = 4
barBG.Parent = root

local bar = Instance.new("Frame")
bar.Size = UDim2.new(0,0,0,8)
bar.Position = UDim2.fromScale(0.2,0.49)
bar.BackgroundColor3 = Color3.fromRGB(255,60,60)
bar.BorderSizePixel = 0
bar.ZIndex = 6
bar.Parent = root

local fade = Instance.new("Frame")
fade.Size = UDim2.fromScale(1,1)
fade.BackgroundColor3 = Color3.new(0,0,0)
fade.BackgroundTransparency = 1
fade.ZIndex = 50
fade.Parent = root

-- =====================
-- Dojo (picker)
-- =====================
local dojo = Instance.new("Frame")
dojo.Size = UDim2.fromScale(1,1)
dojo.BackgroundTransparency = 1
dojo.Visible = false
dojo.ZIndex = 10
dojo.Parent = root

local dojoTitle = Instance.new("TextLabel")
dojoTitle.Size = UDim2.fromOffset(700,80)
dojoTitle.Position = UDim2.fromScale(0.5,0.1)
dojoTitle.AnchorPoint = Vector2.new(0.5,0.5)
dojoTitle.Text = "Starter Dojo"
dojoTitle.Font = Enum.Font.GothamBold
dojoTitle.TextScaled = true
dojoTitle.TextColor3 = Color3.fromRGB(255,200,120)
dojoTitle.BackgroundTransparency = 1
dojoTitle.ZIndex = 11
dojoTitle.Parent = dojo

local picker = Instance.new("Frame")
picker.Size = UDim2.fromScale(0.6,0.55)
picker.Position = UDim2.fromScale(0.5,0.55)
picker.AnchorPoint = Vector2.new(0.5,0.5)
picker.BackgroundColor3 = Color3.fromRGB(24,26,28)
picker.BackgroundTransparency = 0.6
picker.BorderSizePixel = 0
picker.ZIndex = 11
picker.Parent = dojo

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

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.9,0,0,40)
title.Position = UDim2.fromScale(0.5,0.1)
title.AnchorPoint = Vector2.new(0.5,0.5)
title.Text = "Choose Your Character"
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundTransparency = 1
title.ZIndex = 11
title.Parent = picker

local btnUseRoblox = makeButton("Use Roblox Avatar", 0.30)
local btnUseNinja  = makeButton("Use Starter Ninja", 0.42)

local line = Instance.new("Frame")
line.Size = UDim2.new(0.9,0,0,2)
line.Position = UDim2.fromScale(0.5,0.52)
line.AnchorPoint = Vector2.new(0.5,0.5)
line.BackgroundColor3 = Color3.fromRGB(60,60,62)
line.BorderSizePixel = 0
line.ZIndex = 11
line.Parent = picker

local slotsTitle = Instance.new("TextLabel")
slotsTitle.Size = UDim2.new(0.9,0,0,32)
slotsTitle.Position = UDim2.fromScale(0.5,0.58)
slotsTitle.AnchorPoint = Vector2.new(0.5,0.5)
slotsTitle.Text = "Persona Slots"
slotsTitle.Font = Enum.Font.GothamSemibold
slotsTitle.TextScaled = true
slotsTitle.TextColor3 = Color3.fromRGB(230,230,230)
slotsTitle.BackgroundTransparency = 1
slotsTitle.ZIndex = 11
slotsTitle.Parent = picker

local slotsFrame = Instance.new("Frame")
slotsFrame.Size = UDim2.new(0.9,0,0.28,0)
slotsFrame.Position = UDim2.fromScale(0.5,0.78)
slotsFrame.AnchorPoint = Vector2.new(0.5,0.5)
slotsFrame.BackgroundTransparency = 1
slotsFrame.ZIndex = 11
slotsFrame.Parent = picker

local slotButtons = {}
local function makeSlot(index)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1,0,0,36)
	row.Position = UDim2.new(0,0,0,(index-1)*40)
	row.BackgroundTransparency = 1
	row.ZIndex = 11
	row.Parent = slotsFrame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.45,0,1,0)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ("Slot %d — (empty)"):format(index)
	label.Font = Enum.Font.Gotham
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(220,220,220)
	label.ZIndex = 11
	label.Parent = row

	local useBtn = Instance.new("TextButton")
	useBtn.Size = UDim2.new(0.22,0,1,0)
	useBtn.Position = UDim2.new(0.48,0,0,0)
	useBtn.Text = "Use"
	useBtn.Font = Enum.Font.GothamSemibold
	useBtn.TextScaled = true
	useBtn.TextColor3 = Color3.new(1,1,1)
	useBtn.BackgroundColor3 = Color3.fromRGB(60,180,110)
	useBtn.AutoButtonColor = true
	useBtn.ZIndex = 11
	useBtn.Parent = row

	local saveBtn = Instance.new("TextButton")
	saveBtn.Size = UDim2.new(0.22,0,1,0)
	saveBtn.Position = UDim2.new(0.74,0,0,0)
	saveBtn.Text = "Overwrite"
	saveBtn.Font = Enum.Font.GothamSemibold
	saveBtn.TextScaled = true
	saveBtn.TextColor3 = Color3.new(1,1,1)
	saveBtn.BackgroundColor3 = Color3.fromRGB(100,100,220)
	saveBtn.AutoButtonColor = true
	saveBtn.ZIndex = 11
	saveBtn.Parent = row

	slotButtons[index] = {useBtn=useBtn, saveBtn=saveBtn, label=label}
end
for i=1,3 do makeSlot(i) end

-- =====================
-- Loadout (viewport + backpack + emotes)
-- =====================
local loadout = Instance.new("Frame")
loadout.Size = UDim2.fromScale(1,1)
loadout.BackgroundTransparency = 1
loadout.Visible = false
loadout.ZIndex = 20
loadout.Parent = root

local loadTitle = Instance.new("TextLabel")
loadTitle.Size = UDim2.new(1,-40,0,60)
loadTitle.Position = UDim2.fromOffset(20,20)
loadTitle.BackgroundTransparency = 0.6
loadTitle.TextXAlignment = Enum.TextXAlignment.Left
loadTitle.Text = "Loadout"
loadTitle.Font = Enum.Font.GothamBold
loadTitle.TextScaled = true
loadTitle.TextColor3 = Color3.fromRGB(255,200,120)
loadTitle.Parent = loadout

-- Emote bar (top)
local emoteBar = Instance.new("Frame")
emoteBar.Size = UDim2.new(1,-40,0,38)
emoteBar.Position = UDim2.fromOffset(20,68)
emoteBar.BackgroundColor3 = Color3.fromRGB(24,26,28)
emoteBar.BackgroundTransparency = 0.6
emoteBar.BorderSizePixel = 0
emoteBar.Parent = loadout
local emoteLayout = Instance.new("UIListLayout", emoteBar)
emoteLayout.FillDirection = Enum.FillDirection.Horizontal
emoteLayout.Padding = UDim.new(0,6)
emoteLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local function emoteButton(text)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.fromRGB(50,120,255)
	b.TextColor3 = Color3.new(1,1,1)
	b.Font = Enum.Font.GothamSemibold
	b.TextScaled = true
	b.AutoButtonColor = true
	b.Size = UDim2.new(0,120,1,0)
	b.Text = text
	b.Parent = emoteBar
	return b
end

local vpCard = Instance.new("Frame")
vpCard.BackgroundTransparency = 0.6
vpCard.Size = UDim2.new(0.48,-30,0.62,0)
vpCard.Position = UDim2.fromOffset(20,112)
vpCard.BackgroundColor3 = Color3.fromRGB(24,26,28)
vpCard.BorderSizePixel = 0
vpCard.Parent = loadout

local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.fromScale(1,1)
viewport.BackgroundColor3 = Color3.fromRGB(16,16,16)
viewport.BackgroundTransparency = 0.6
viewport.BorderSizePixel = 0
viewport.Parent = vpCard

local bpCard = Instance.new("Frame")
bpCard.Size = UDim2.new(0.48,-30,0.62,0)
bpCard.Position = UDim2.new(1,-20,0,112)
bpCard.AnchorPoint = Vector2.new(1,0)
bpCard.BackgroundColor3 = Color3.fromRGB(24,26,28)
bpCard.BackgroundTransparency = 0.6
bpCard.BorderSizePixel = 0
bpCard.Parent = loadout

local bpTitle = Instance.new("TextLabel")
bpTitle.Size = UDim2.new(1,-20,0,36)
bpTitle.Position = UDim2.fromOffset(10,8)
bpTitle.BackgroundTransparency = 1
bpTitle.TextXAlignment = Enum.TextXAlignment.Left
bpTitle.Text = "Backpack"
bpTitle.Font = Enum.Font.GothamSemibold
bpTitle.TextScaled = true
bpTitle.TextColor3 = Color3.new(1,1,1)
bpTitle.Parent = bpCard

local capBarBG = Instance.new("Frame")
capBarBG.Size = UDim2.new(1,-20,0,10)
capBarBG.Position = UDim2.fromOffset(10,50)
capBarBG.BackgroundColor3 = Color3.fromRGB(60,60,62)
capBarBG.BorderSizePixel = 0
capBarBG.Parent = bpCard

local capBar = Instance.new("Frame")
capBar.Size = UDim2.new(0,0,1,0)
capBar.BackgroundColor3 = Color3.fromRGB(80,180,120)
capBar.BorderSizePixel = 0
capBar.Parent = capBarBG

local capLabel = Instance.new("TextLabel")
capLabel.Size = UDim2.new(1,-20,0,22)
capLabel.Position = UDim2.fromOffset(10,66)
capLabel.BackgroundTransparency = 1
capLabel.TextXAlignment = Enum.TextXAlignment.Left
capLabel.Font = Enum.Font.Gotham
capLabel.TextScaled = true
capLabel.TextColor3 = Color3.fromRGB(230,230,230)
capLabel.Parent = bpCard

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1,-20,1,-110)
list.Position = UDim2.fromOffset(10,96)
list.CanvasSize = UDim2.new()
list.ScrollBarThickness = 6
list.BackgroundTransparency = 1
list.Parent = bpCard
local _layout = Instance.new("UIListLayout", list)
_layout.Padding = UDim.new(0,6)

local btnRow = Instance.new("Frame")
btnRow.Size = UDim2.new(1,-40,0,60)
btnRow.Position = UDim2.new(0,20,1,-80)
btnRow.BackgroundTransparency = 1
btnRow.Parent = loadout

local function makeAction(text, rightAlign)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0,240,1,0)
	b.Position = rightAlign and UDim2.new(1,-250,0,0) or UDim2.fromOffset(0,0)
	b.AnchorPoint = rightAlign and Vector2.new(1,0) or Vector2.new(0,0)
	b.Text = text
	b.Font = Enum.Font.GothamSemibold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1,1,1)
	b.BackgroundColor3 = Color3.fromRGB(50,120,255)
	b.AutoButtonColor = true
	b.Parent = btnRow
	return b
end

local btnBack       = makeAction("Back", false)
local btnEnterDojo  = makeAction("Enter This Dojo", true)
local btnEnterMain  = makeAction("Enter Main Realm", true)
btnEnterMain.Position = UDim2.new(1,-250-260,0,0)
btnEnterMain.Visible = (MAIN_PLACE_ID and MAIN_PLACE_ID > 0)

-- =====================
-- Helpers (UI logic)
-- =====================
local function clearChildren(p)
	for _,c in ipairs(p:GetChildren()) do c:Destroy() end
end

-- Orbitable viewport state
local vpWorld, vpModel, vpCam, vpHumanoid, currentEmoteTrack
local orbit = {yaw = math.pi, pitch = 0.1, dist = 10, min = 4, max = 40, center = Vector3.new(), dragging = false}

local function updateVPCamera()
	if not vpCam then return end
	local dir = CFrame.fromEulerAnglesYXZ(orbit.pitch, orbit.yaw, 0).LookVector
	local camPos = orbit.center - dir * orbit.dist
	vpCam.CFrame = CFrame.new(camPos, orbit.center)
end

local function hookViewportControls()
	viewport.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			orbit.dragging = true
		elseif input.UserInputType == Enum.UserInputType.Touch then
			orbit.dragging = true
		end
	end)
	viewport.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			orbit.dragging = false
		end
	end)
	viewport.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and orbit.dragging then
			local d = input.Delta
			orbit.yaw = orbit.yaw - d.X * 0.01
			orbit.pitch = math.clamp(orbit.pitch - d.Y * 0.01, -1.2, 1.2)
			updateVPCamera()
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			local scroll = input.Position.Z -- wheel delta
			orbit.dist = math.clamp(orbit.dist - scroll * 1.5, orbit.min, orbit.max)
			updateVPCamera()
		end
	end)
end

local function stopEmote()
	if currentEmoteTrack then
		currentEmoteTrack:Stop(0.1)
		currentEmoteTrack:Destroy()
		currentEmoteTrack = nil
	end
end

local EMOTES = {
	Idle  = "rbxassetid://507766388",
	Wave  = "rbxassetid://507770239",
	Point = "rbxassetid://507770453",
	Dance = "rbxassetid://507771019",
	Laugh = "rbxassetid://507770818",
	Cheer = "rbxassetid://507770677",
	Sit   = "rbxassetid://2506281703",
}

local function playEmote(name)
	if not (vpHumanoid and EMOTES[name]) then return end
	stopEmote()
	local anim = Instance.new("Animation")
	anim.AnimationId = EMOTES[name]
	currentEmoteTrack = vpHumanoid:LoadAnimation(anim)
	currentEmoteTrack.Looped = (name == "Idle" or name == "Dance")
	currentEmoteTrack:Play(0.1)
end

local function wireEmoteButtons()
	local order = {"Idle","Wave","Point","Dance","Laugh","Cheer","Sit"}
	for _,label in ipairs(order) do
		local b = emoteButton(label)
		b.MouseButton1Click:Connect(function()
			playEmote(label)
		end)
	end
end

local function buildCharacterPreview(personaType)
	clearChildren(viewport)
	vpWorld, vpModel, vpCam, vpHumanoid = nil, nil, nil, nil

	vpWorld = Instance.new("WorldModel"); vpWorld.Parent = viewport

	-- get a HumanoidDescription
	local desc
	if personaType == "Ninja" then
		local hdFolder = ReplicatedStorage:FindFirstChild("HumanoidDescriptions")
		local hd = hdFolder and hdFolder:FindFirstChild("Ninja")
		if hd then desc = hd:Clone() end
	else
		local ok, hd = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if ok then desc = hd end
	end
	if not desc then return end

	vpModel = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	vpModel:PivotTo(CFrame.new(0,0,0))
	vpModel.Parent = vpWorld
	vpHumanoid = vpModel:FindFirstChildOfClass("Humanoid")

	-- Orbit framing (face camera)
	local _, size = vpModel:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z)
	orbit.center = Vector3.new(0, size.Y*0.5, 0)
	orbit.dist   = math.clamp(radius * 1.8, 6, 20)
	orbit.min    = math.max(3, radius*0.8)
	orbit.max    = radius * 4
	orbit.pitch  = 0.15
	orbit.yaw    = math.pi -- face user

	vpCam = Instance.new("Camera")
	vpCam.Parent = viewport
	viewport.CurrentCamera = vpCam
	updateVPCamera()

	if not viewport:GetAttribute("_controlsHooked") then
		hookViewportControls()
		viewport:SetAttribute("_controlsHooked", true)
	end

	-- default to idle emote
	playEmote("Idle")
end

local function populateBackpackUI(bp)
	clearChildren(list)
	local used = 0
	for _,it in ipairs(bp.items or {}) do
		used += it.qty
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1,0,0,40)
		row.BackgroundColor3 = Color3.fromRGB(32,34,36)
		row.BorderSizePixel = 0
		row.Parent = list

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0.6,-10,1,0)
		name.Position = UDim2.fromOffset(10,0)
		name.BackgroundTransparency = 1
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Font = Enum.Font.Gotham
		name.TextScaled = true
		name.TextColor3 = Color3.new(1,1,1)
		name.Text = it.name
		name.Parent = row

		local qty = Instance.new("TextLabel")
		qty.Size = UDim2.new(0.4,-10,1,0)
		qty.Position = UDim2.new(0.6,0,0,0)
		qty.BackgroundTransparency = 1
		qty.TextXAlignment = Enum.TextXAlignment.Right
		qty.Font = Enum.Font.Gotham
		qty.TextScaled = true
		qty.TextColor3 = Color3.fromRGB(230,230,230)
		qty.Text = string.format("%d / %d", it.qty, it.stack)
		qty.Parent = row
	end
	local cap = math.max(bp.capacity or 0, used)
	capBar.Size = UDim2.new(cap>0 and (used/cap) or 0, 0, 1, 0)
	capLabel.Text = string.format("Capacity: %d / %d", used, cap)
	local layout = list:FindFirstChildOfClass("UIListLayout")
	list.CanvasSize = UDim2.new(0,0,0, layout and layout.AbsoluteContentSize.Y or 0)
end

-- =====================
-- Flow helpers
-- =====================
local personaCache = {slots={}, defaultSlotsCount=3}
local currentChoiceType = "Roblox"
local chosenSlot

local function refreshSlots()
	local data = rf:InvokeServer("get", {})
	personaCache = data or personaCache
	for i=1, personaCache.defaultSlotsCount do
		local slot = personaCache.slots[i]
		local ui = slotButtons[i]
		if ui then
			ui.label.Text = slot and ("Slot %d — %s"):format(i, slot.name or slot.type) or ("Slot %d — (empty)"):format(i)
		end
	end
end

local function showDojoPicker()
	dojo.Visible = true
	loadout.Visible = false
end

local function showLoadout(personaType)
	dojo.Visible = false
	loadout.Visible = true
	buildCharacterPreview(personaType)
	populateBackpackUI(StarterBackpack)
end

-- Buttons
btnUseRoblox.MouseButton1Click:Connect(function()
	currentChoiceType = "Roblox"
	btnUseRoblox.BackgroundColor3 = Color3.fromRGB(80,180,120)
	btnUseNinja.BackgroundColor3  = Color3.fromRGB(50,120,255)
end)
btnUseNinja.MouseButton1Click:Connect(function()
	currentChoiceType = "Ninja"
	btnUseNinja.BackgroundColor3  = Color3.fromRGB(80,180,120)
	btnUseRoblox.BackgroundColor3 = Color3.fromRGB(50,120,255)
end)

for i,row in pairs(slotButtons) do
	row.useBtn.MouseButton1Click:Connect(function()
		local result = rf:InvokeServer("use", {slot=i})
		if not (result and result.ok) then warn("Use slot failed:", result and result.err) return end
		chosenSlot = i
		-- Tween camera to endPos now that the user has chosen
		tweenToEnd()
		showLoadout(result.persona and result.persona.type or currentChoiceType)
	end)
	row.saveBtn.MouseButton1Click:Connect(function()
		local res = rf:InvokeServer("save", {slot=i, type=currentChoiceType, name=currentChoiceType=="Ninja" and "Starter Ninja" or "My Avatar"})
		if res and res.ok then personaCache = res; refreshSlots() else warn("Save failed:", res and res.err) end
	end)
end

btnBack.MouseButton1Click:Connect(function()
	-- Return to picker; snap camera back to start
	applyStartCam()
	showDojoPicker()
end)

btnEnterDojo.MouseButton1Click:Connect(function()
	TweenService:Create(fade, TweenInfo.new(0.25), {BackgroundTransparency = 0}):Play()
	task.wait(0.28)

	-- decide persona type we want to spawn as
	local personaType = currentChoiceType
	if chosenSlot and personaCache and personaCache.slots then
		local slot = personaCache.slots[chosenSlot]
		if slot and slot.type then personaType = slot.type end
	end

	-- tell server to spawn us with that persona
	if enterRE then
		enterRE:FireServer({ type = personaType, slot = chosenSlot })
	else
		warn("EnterDojoRE missing on server")
	end

	-- wait for character and hand camera back to gameplay
	task.wait(0.2)
	local char = player.Character or player.CharacterAdded:Wait()
	local hum = char:FindFirstChildOfClass("Humanoid")
	cam.CameraType = Enum.CameraType.Custom
	if hum then cam.CameraSubject = hum end

	restoreUIBlur()
	TweenService:Create(fade, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
	task.delay(0.4, function() if ui and ui.Parent then ui:Destroy() end end)
end)

btnEnterMain.MouseButton1Click:Connect(function()
	if not (MAIN_PLACE_ID and MAIN_PLACE_ID > 0) then return end
	TweenService:Create(fade, TweenInfo.new(0.25), {BackgroundTransparency = 0}):Play()
	task.wait(0.28)
	local ok, err = pcall(function() TeleportService:Teleport(MAIN_PLACE_ID, player, {slot = chosenSlot}) end)
	if not ok then warn("Teleport failed:", err) end
end)

-- Hook emote buttons once (after UI exists)
wireEmoteButtons()

-- =====================
-- FLOW
-- =====================
cam.CameraType = Enum.CameraType.Scriptable
holdStartCam(1.0)
disableUIBlur()

local items = {}
if ASSETS.Logo ~= "" then table.insert(items, logoImg) end
if ASSETS.PaperTex ~= "" then table.insert(items, paperBG) end
pcall(function() ContentProvider:PreloadAsync(items) end)

bar.Size = UDim2.new(0,0,0,8)
TweenService:Create(bar, TweenInfo.new(1.6, Enum.EasingStyle.Quad), {Size = UDim2.new(0.6,0,0,8)}):Play()
wait(1.65)

local t = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(sub, t, {TextTransparency = 1}):Play()
TweenService:Create(bar,  t, {BackgroundTransparency = 1}):Play()
TweenService:Create(barBG, t, {BackgroundTransparency = 1}):Play()
TweenService:Create(logoImg, t, {ImageTransparency = 1}):Play()
TweenService:Create(paperBG, t, {ImageTransparency = 1}):Play()
wait(0.28)
if logoImg then logoImg:Destroy() end
if paperBG then paperBG:Destroy() end

showDojoPicker()
-- We do NOT tween to end here anymore; only after "Use".
refreshSlots()
