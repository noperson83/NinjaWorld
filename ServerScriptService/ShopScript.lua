local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local shopEvent = ReplicatedStorage:FindFirstChild("ShopEvent")
if not shopEvent then
    shopEvent = Instance.new("RemoteEvent")
    shopEvent.Name = "ShopEvent"
    shopEvent.Parent = ReplicatedStorage
end

local bootModules = ReplicatedStorage:WaitForChild("BootModules")

-- Load ShopItems if available; otherwise continue with an empty list so the
-- server script doesn't abort during startup.
local ShopItems = {}
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
local function waitForCurrencyService()
    local service = shared.CurrencyService
    while not service do
        task.wait()
        service = shared.CurrencyService
    end
    return service
end

local CurrencyService = waitForCurrencyService()

local function getCurrencyService()
    local service = CurrencyService
    assert(service, "ShopScript expected CurrencyService to be initialized")
    return service
end

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

    local cs = getCurrencyService()
    local getBalance = assert(cs.GetBalance, "CurrencyService missing GetBalance")
    local adjustCoins = assert(cs.AdjustCoins, "CurrencyService missing AdjustCoins")
    local balance = getBalance(player)
    if not balance or balance.coins < cost then return end
    if not adjustCoins(player, -cost) then return end

    if category == "Weapons" then
        giveWeapon(player, itemId, def)
    elseif category == "Elements" then
        unlockElement(player, itemId)
    end
end)
