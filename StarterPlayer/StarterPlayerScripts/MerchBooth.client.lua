local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- BootModules may not be present in some testing environments. Guard against
-- missing instances so the client's scripts continue running even if the
-- merch booth functionality is unavailable.
local bootModules = ReplicatedStorage:WaitForChild("BootModules")

local MerchBooth
local ok, merchModule = pcall(function()
    return bootModules:WaitForChild("MerchBooth", 10)
end)
if ok and merchModule then
    local success, module = pcall(require, merchModule)
    if success and module then
        MerchBooth = module
    else
        warn("Failed to load MerchBooth module:", module)
        return
    end
else
    warn("MerchBooth module missing")
    return
end

local items = {
    -- Asset IDs to display in the booth
}

for _, assetId in ipairs(items) do
    local ok, err = pcall(function()
        MerchBooth.addItemAsync(assetId)
    end)
    if not ok then
        warn(string.format("Failed to add merch item %s: %s", assetId, err))
    end
end
