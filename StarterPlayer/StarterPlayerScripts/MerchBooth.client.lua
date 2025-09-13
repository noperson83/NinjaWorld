local ReplicatedStorage = game:GetService("ReplicatedStorage")
local bootModules = ReplicatedStorage.BootModules
local MerchBooth = require(bootModules.MerchBooth)

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
