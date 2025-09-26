-- Item definitions exposed to both server and client boot modules.
-- Keeping this module in ReplicatedStorage/BootModules ensures Roblox Studio
-- exports it with the exact "ShopItems" name required at runtime.
local ShopItems = {
    Elements = {
        Fire = {cost = 100},
        Beast = {cost = 150}
    },
    Weapons = {
        ["Sword A"] = {cost = 200, assetId = 16232452668},
        ["Bow A"] = {cost = 150, assetId = 16117888680}
    }
}

return ShopItems
