local ReplicatedStorage = game:GetService("ReplicatedStorage")

local merchModule = ReplicatedStorage:FindFirstChild("MerchBooth")
if not merchModule then
    warn("MerchBooth module not found")
    return
end

local MerchBooth = require(merchModule)

local items = {
	125630227934002,  -- MetalMagic
	125593084537583,  -- Longsleeve
	120626848945926,  -- BLKRobotMagic
	101437883259148,  -- LongSSLeeveLM
  -- Sword A	16232452668,
  -- Sword B	16232532667,
  -- Sword C	16232504981,
  -- Sword D	16232534668,
  -- Bow A	16117888680,
  -- Bow B	16117890021,	116257239830311,
  -- Bow C	16117894011,
  -- Bow D	16117895377,
  -- BowBow	16232118442,
  -- LMShirt	15899214466,
  -- LMPants	15899822232,
  -- Song 1	15933971668,
  -- IceCoin	17799298968,
}

for _, assetId in items do
	local success, errorMessage = pcall(function()
		MerchBooth.addItemAsync(assetId)
	end)
	if not success then
		warn(errorMessage)
	end
end
