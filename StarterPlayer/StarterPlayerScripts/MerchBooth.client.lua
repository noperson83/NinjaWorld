local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- BootModules may not be present in some testing environments. Guard against
-- missing instances so the client's scripts continue running even if the
-- merch booth functionality is unavailable.
local bootModules = ReplicatedStorage:FindFirstChild("BootModules")
if not bootModules then
    warn("BootModules folder missing")
    return
end

local merchModule = bootModules:FindFirstChild("MerchBooth")
if not merchModule then
    warn("MerchBooth module missing")
    return
end

local MerchBooth = require(merchModule)

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
