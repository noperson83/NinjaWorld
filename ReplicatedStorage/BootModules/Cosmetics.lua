local Cosmetics = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local rf = ReplicatedStorage:WaitForChild("PersonaServiceRF")
local player = Players.LocalPlayer

local dojo
local slotButtons = {}
local boot
local rootUI

local personaCache = {slots = {}, slotCount = 0}
local currentChoiceType = "Roblox"
local chosenSlot

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

local function updateSlotLabels()
    for i = 1, personaCache.slotCount do
        local slot = personaCache.slots[i]
        local ui = slotButtons[i]
        if ui then
            local index = i
            ui.label.Text = slot and ("Slot %d – %s"):format(index, slot.name or slot.type) or ("Slot %d – (empty)"):format(index)
            if slot then
                ui.useBtn.Visible = true
                ui.clearBtn.Visible = true
                ui.robloxBtn.Visible = false
                ui.starterBtn.Visible = false
                if not ui.clearConn then
                    ui.clearConn = ui.clearBtn.MouseButton1Click:Connect(function()
                        showConfirm(("Clear slot %d?"):format(index), function()
                            local res = rf:InvokeServer("clear", {slot = index})
                            if res and res.ok then
                                personaCache = res
                                if chosenSlot == index then chosenSlot = nil end
                                refreshSlots()
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
            end
        end
    end
end

refreshSlots = function()
    local data = rf:InvokeServer("get", {})
    personaCache = data or personaCache
    updateSlotLabels()
end

local function showDojoPicker()
    if dojo then dojo.Visible = true end
    if boot then
        if boot.loadout then boot.loadout.Visible = false end
        if boot.shopBtn then boot.shopBtn.Visible = false end
        if boot.abilityBtn then boot.abilityBtn.Visible = false end
    end
end

local function showLoadout(personaType)
    if dojo then dojo.Visible = false end
    if boot then
        if boot.shopBtn then boot.shopBtn.Visible = true end
        if boot.abilityBtn then boot.abilityBtn.Visible = true end
        if boot.loadout then
            boot.loadout.Visible = true
            if boot.buildCharacterPreview then boot.buildCharacterPreview(personaType) end
            if boot.populateBackpackUI then
                local saved = player:GetAttribute("Inventory")
                if saved then
                    boot.populateBackpackUI(saved)
                elseif boot.StarterBackpack then
                    boot.populateBackpackUI(boot.StarterBackpack)
                    local conn
                    conn = player:GetAttributeChangedSignal("Inventory"):Connect(function()
                        local inv = player:GetAttribute("Inventory")
                        if inv then
                            boot.populateBackpackUI(inv)
                            conn:Disconnect()
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

function Cosmetics.refreshSlots()
    refreshSlots()
end

function Cosmetics.showDojoPicker()
    showDojoPicker()
end

function Cosmetics.init(config, root, bootUI)
    boot = bootUI
    rootUI = root

    dojo = Instance.new("Frame")
    dojo.Size = UDim2.fromScale(1,1)
    dojo.BackgroundTransparency = 1
    dojo.Visible = false
    dojo.ZIndex = 10
    dojo.Parent = root

    local dojoTitle = Instance.new("ImageLabel")
    dojoTitle.Size = UDim2.fromOffset(700,80)
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

    -- Display starter dojo image above personas inside the picker
    local starterDojoImg = Instance.new("ImageLabel")
    starterDojoImg.Size = UDim2.fromOffset(700,80)
    starterDojoImg.Position = UDim2.fromScale(0.5,0.08)
    starterDojoImg.AnchorPoint = Vector2.new(0.5,0.5)
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

    local line = Instance.new("Frame")
    line.Size = UDim2.new(0.9,0,0,2)
    line.Position = UDim2.fromScale(0.5,0.38)
    line.AnchorPoint = Vector2.new(0.5,0.5)
    line.BackgroundColor3 = Color3.fromRGB(60,60,62)
    line.BorderSizePixel = 0
    line.ZIndex = 11
    line.Parent = picker

    local slotsTitle = Instance.new("TextLabel")
    slotsTitle.Size = UDim2.new(0.9,0,0,32)
    -- Lift persona slot title to reduce empty space below the dojo title
    slotsTitle.Position = UDim2.fromScale(0.5,0.3)
    slotsTitle.AnchorPoint = Vector2.new(0.5,0.5)
    slotsTitle.Text = "Persona Slots"
    slotsTitle.Font = Enum.Font.GothamSemibold
    slotsTitle.TextScaled = true
    slotsTitle.TextColor3 = Color3.fromRGB(230,230,230)
    slotsTitle.BackgroundTransparency = 1
    slotsTitle.ZIndex = 11
    slotsTitle.Parent = picker

    local slotsFrame = Instance.new("ScrollingFrame")
    slotsFrame.Size = UDim2.new(0.9,0,0.55,0)
    -- Move persona slots upward to better utilize vertical space
    slotsFrame.Position = UDim2.fromScale(0.5,0.6)
    slotsFrame.AnchorPoint = Vector2.new(0.5,0.5)
    slotsFrame.BackgroundTransparency = 1
    slotsFrame.BorderSizePixel = 0
    slotsFrame.ScrollBarThickness = 6
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

        local robloxBtn = Instance.new("TextButton")
        robloxBtn.Size = UDim2.new(0.24,0,1,0)
        robloxBtn.Position = UDim2.new(0.47,0,0,0)
        robloxBtn.Text = "Roblox"
        robloxBtn.Font = Enum.Font.GothamSemibold
        robloxBtn.TextScaled = true
        robloxBtn.TextColor3 = Color3.new(1,1,1)
        robloxBtn.BackgroundColor3 = Color3.fromRGB(80,120,200)
        robloxBtn.AutoButtonColor = true
        robloxBtn.ZIndex = 11
        robloxBtn.Parent = row

        local starterBtn = Instance.new("TextButton")
        starterBtn.Size = UDim2.new(0.24,0,1,0)
        starterBtn.Position = UDim2.new(0.74,0,0,0)
        starterBtn.Text = "Starter"
        starterBtn.Font = Enum.Font.GothamSemibold
        starterBtn.TextScaled = true
        starterBtn.TextColor3 = Color3.new(1,1,1)
        starterBtn.BackgroundColor3 = Color3.fromRGB(100,100,220)
        starterBtn.AutoButtonColor = true
        starterBtn.ZIndex = 11
        starterBtn.Parent = row

        local useBtn = Instance.new("TextButton")
        useBtn.Size = UDim2.new(0.24,0,1,0)
        useBtn.Position = UDim2.new(0.47,0,0,0)
        useBtn.Text = "Use"
        useBtn.Font = Enum.Font.GothamSemibold
        useBtn.TextScaled = true
        useBtn.TextColor3 = Color3.new(1,1,1)
        useBtn.BackgroundColor3 = Color3.fromRGB(60,180,110)
        useBtn.AutoButtonColor = true
        useBtn.ZIndex = 11
        useBtn.Parent = row

        local clearBtn = Instance.new("TextButton")
        clearBtn.Size = UDim2.new(0.24,0,1,0)
        clearBtn.Position = UDim2.new(0.74,0,0,0)
        clearBtn.Text = "Clear"
        clearBtn.Font = Enum.Font.GothamSemibold
        clearBtn.TextScaled = true
        clearBtn.TextColor3 = Color3.new(1,1,1)
        clearBtn.BackgroundColor3 = Color3.fromRGB(200,80,80)
        clearBtn.AutoButtonColor = true
        clearBtn.ZIndex = 11
        clearBtn.Parent = row

        slotButtons[index] = {
            useBtn = useBtn,
            clearBtn = clearBtn,
            robloxBtn = robloxBtn,
            starterBtn = starterBtn,
            label = label
        }
    end
    for i = 1, personaCache.slotCount do makeSlot(i) end
    slotsFrame.CanvasSize = UDim2.new(0,0,0, personaCache.slotCount * 40)

    updateSlotLabels()

    for i,row in pairs(slotButtons) do
        local index = i
        row.useBtn.MouseButton1Click:Connect(function()
            local result = rf:InvokeServer("use", {slot = index})
            if not (result and result.ok) then warn("Use slot failed:", result and result.err) return end
            chosenSlot = index
            currentChoiceType = result.persona and result.persona.type or currentChoiceType
            if boot and boot.tweenToEnd then boot.tweenToEnd() end
            showLoadout(result.persona and result.persona.type or currentChoiceType)
        end)
        row.robloxBtn.MouseButton1Click:Connect(function()
            local res = rf:InvokeServer("save", {slot = index, type = "Roblox"})
            if res and res.ok then
                personaCache = res
                refreshSlots()
                local useRes = rf:InvokeServer("use", {slot = index})
                if useRes and useRes.ok then
                    chosenSlot = index
                    currentChoiceType = "Roblox"
                    if boot and boot.tweenToEnd then boot.tweenToEnd() end
                    showLoadout("Roblox")
                else
                    warn("Use slot failed:", useRes and useRes.err)
                end
            else
                warn("Save failed:", res and res.err)
            end
        end)
        row.starterBtn.MouseButton1Click:Connect(function()
            local res = rf:InvokeServer("save", {slot = index, type = "Ninja"})
            if res and res.ok then
                personaCache = res
                refreshSlots()
                local useRes = rf:InvokeServer("use", {slot = index})
                if useRes and useRes.ok then
                    chosenSlot = index
                    currentChoiceType = "Ninja"
                    if boot and boot.tweenToEnd then boot.tweenToEnd() end
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

