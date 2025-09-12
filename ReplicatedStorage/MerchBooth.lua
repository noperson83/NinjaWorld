local MerchBooth = {}

MerchBooth.items = {}

function MerchBooth.addItemAsync(assetId)
    table.insert(MerchBooth.items, assetId)
    -- Optionally fetch product info via MarketplaceService here
end

-- Toggles the catalog button visibility.
function MerchBooth.toggleCatalogButton(_enabled)
    -- no-op stub
end

-- Accepts configuration options for the booth.
function MerchBooth.configure(_options)
    -- no-op stub
end

-- Opens the merch booth interface.
function MerchBooth.openMerchBooth()
    -- no-op stub
end

-- Closes the merch booth interface.
function MerchBooth.closeMerchBooth()
    -- no-op stub
end

function MerchBooth.getItems()
    return MerchBooth.items
end

return MerchBooth

