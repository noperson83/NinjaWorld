local Cosmetics = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local rf = ReplicatedStorage:WaitForChild("PersonaServiceRF")
local player = Players.LocalPlayer

local dojo
local btnUseRoblox
local btnUseNinja
local slotButtons = {}
local boot

local personaCache = {slots = {}, slotCount = 0}
local currentChoiceType = "Roblox"
local chosenSlot

local function updateSlotLabels()
    for i = 1, personaCache.slotCount do
        local slot = personaCache.slots[i]
        local ui = slotButtons[i]
        if ui then
            ui.label.Text = slot and ("Slot %d – %s"):format(i, slot.name or slot.type) or ("Slot %d – (empty)"):format(i)
        end
    end
end

local function refreshSlots()
    local data = rf:InvokeServer("get", {})
    personaCache = data or personaCache
    updateSlotLabels()
end

local function showDojoPicker()
    if dojo then dojo.Visible = true end
    if boot and boot.loadout then boot.loadout.Visible = false end
end

local function showLoadout(personaType)
    if dojo then dojo.Visible = false end
    if boot and boot.loadout then
        boot.loadout.Visible = true
        if boot.buildCharacterPreview then boot.buildCharacterPreview(personaType) end
        if boot.populateBackpackUI and boot.StarterBackpack then
            boot.populateBackpackUI(boot.StarterBackpack)
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

function Cosmetics.refreshSlots()
    refreshSlots()
end

function Cosmetics.showDojoPicker()
    showDojoPicker()
end

function Cosmetics.init(config, root, bootUI)
    boot = bootUI

    dojo = Instance.new("Frame")
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

    btnUseRoblox = makeButton("Use Roblox Avatar", 0.30)
    btnUseNinja  = makeButton("Use Starter Ninja", 0.42)

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

    -- fetch initial slot data to know how many rows to build
    personaCache = rf:InvokeServer("get", {}) or personaCache

    slotButtons = {}
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
        label.Text = ("Slot %d – (empty)"):format(index)
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

        slotButtons[index] = {useBtn = useBtn, saveBtn = saveBtn, label = label}
    end
    for i = 1, personaCache.slotCount do makeSlot(i) end

    updateSlotLabels()

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
            local result = rf:InvokeServer("use", {slot = i})
            if not (result and result.ok) then warn("Use slot failed:", result and result.err) return end
            chosenSlot = i
            if boot and boot.tweenToEnd then boot.tweenToEnd() end
            showLoadout(result.persona and result.persona.type or currentChoiceType)
        end)
        row.saveBtn.MouseButton1Click:Connect(function()
            local res = rf:InvokeServer("save", {slot = i, type = currentChoiceType, name = currentChoiceType == "Ninja" and "Starter Ninja" or "My Avatar"})
            if res and res.ok then personaCache = res; refreshSlots() else warn("Save failed:", res and res.err) end
        end)
    end
end

return Cosmetics

