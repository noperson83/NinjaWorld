local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local shopEvent = ReplicatedStorage:FindFirstChild("ShopEvent")
if not shopEvent then
    shopEvent = Instance.new("RemoteEvent")
    shopEvent.Name = "ShopEvent"
    shopEvent.Parent = ReplicatedStorage
end

local bootModules = ReplicatedStorage:WaitForChild("BootModules")
local shopItemsModule = bootModules:WaitForChild("ShopItems")
assert(shopItemsModule, "ShopItems module missing")
local ShopItems = require(shopItemsModule)
local CurrencyService = shared.CurrencyService

local function findItem(itemId)
    for category, items in pairs(ShopItems) do
        local item = items[itemId]
        if item then
            return category, item
        end
    end
end

local function giveWeapon(player, itemId, def)
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end

    if def.assetId then
        local ok, model = pcall(function()
            return InsertService:LoadAsset(def.assetId)
        end)
        if ok and model then
            local tool = model:FindFirstChildWhichIsA("Tool")
            if tool then
                tool.Parent = backpack
            end
            model:Destroy()
            return
        end
    end

    local tool = Instance.new("Tool")
    tool.Name = tostring(def.name or itemId or "Weapon")
    tool.Parent = backpack
end

local function unlockElement(player, itemId)
    local folder = player:FindFirstChild("Elements")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "Elements"
        folder.Parent = player
    end
    if not folder:FindFirstChild(itemId) then
        local flag = Instance.new("BoolValue")
        flag.Name = itemId
        flag.Value = true
        flag.Parent = folder
    end
end

shopEvent.OnServerEvent:Connect(function(player, data)
    if typeof(data) ~= "table" then return end
    local itemId = data.itemId
    local cost = data.cost
    if typeof(itemId) ~= "string" or typeof(cost) ~= "number" then return end

    local category, def = findItem(itemId)
    if not def or def.cost ~= cost then return end

    local balance = CurrencyService and CurrencyService.GetBalance(player)
    if not balance or balance.coins < cost then return end
    if not CurrencyService.AdjustCoins(player, -cost) then return end

    if category == "Weapons" then
        giveWeapon(player, itemId, def)
    elseif category == "Elements" then
        unlockElement(player, itemId)
    end
end)
