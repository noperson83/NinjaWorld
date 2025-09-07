-- TeleportClient Module
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local TeleportClient = {}

-- Place ids for the various realms in the experience.  Ids of ``0``
-- indicate a realm that does not yet have a destination place.  This
-- table is exposed so other modules (eg, BootUI) can look up the asset
-- id for a realm when teleporting.
TeleportClient.worldSpawnIds = {
        SecretVillage = 15719226587,        -- TODO: update when place is available
        Water         = 15999399322,
        Fire          = 16167296427,
        Wind          = 0,        -- TODO: update when place is available
        Growth        = 0,        -- TODO: update when place is available
        Ice           = 0,        -- TODO: update when place is available
        Light         = 0,        -- TODO: update when place is available
        Metal         = 0,        -- TODO: update when place is available
        Strength      = 89974873129107,
        Atoms         = 15915218395,
}

-- Maintain legacy name for compatibility
TeleportClient.WorldPlaceIds = TeleportClient.worldSpawnIds

local debounce = false
local function resetDebounceAfter(seconds)
	task.delay(seconds, function()
		debounce = false
	end)
end

local function teleportToIsland(islandName, locationName)
	if debounce then return end
	debounce = true
	task.wait(1)
	local char = player.Character or player.CharacterAdded:Wait()
	local torso = char:FindFirstChild("LowerTorso")
	if not torso then warn("LowerTorso not found") resetDebounceAfter(2) return end
	local parentZone = Workspace:FindFirstChild(islandName)
	if parentZone then
		local point = parentZone:FindFirstChild(locationName)
		if point then
			torso.CFrame = point.CFrame
		else
			warn("Spawn point missing: " .. islandName .. "/" .. locationName)
		end
	else
		warn("Island parent missing: " .. islandName)
	end
	resetDebounceAfter(2)
end

local function teleportToPlace(placeId)
	if debounce then return end
	debounce = true
	TeleportService:Teleport(placeId, player)
	resetDebounceAfter(2)
end

function TeleportClient.bindZoneButtons(gui)
        if not gui then
                warn("TeleportClient: gui parameter missing for zone buttons")
                return
        end

        local teleFrame = gui:FindFirstChild("TeleFrame", true)
        if not teleFrame then
                warn("TeleportClient: TeleFrame not found")
                return
        end

        local islandSpawns = {
                Atom = {"ZoneAtom", "AtomSpawnLocation"},
                Fire = {"ZoneFire", "FireSpawnLocation"},
                Grow = {"ZoneGrow", "GrowSpawnLocation"},
                Ice = {"ZoneIce", "IceSpawnLocation"},
                Light = {"ZoneLight", "LightSpawnLocation"},
                Metal = {"ZoneMetal", "MetalSpawnLocation"},
                Water = {"ZoneWater", "WaterSpawnLocation"},
                Wind = {"ZoneWind", "WindSpawnLocation"},
                Dojo = {"ZoneStarter", "StarterSpawnLocation"},
                Starter = {"ZoneStarter", "StarterZoneSpawnLocation"}
        }

        for name, zoneInfo in pairs(islandSpawns) do
                local button = teleFrame:FindFirstChild(name .. "Button")
                if button then
                        button.Activated:Connect(function()
                                teleportToIsland(unpack(zoneInfo))
                        end)
                else
                        warn("Zone button not found for: " .. name)
                end
        end
end


function TeleportClient.bindWorldButtons(gui)
        if not gui then
                warn("TeleportClient: gui parameter missing for world buttons")
                return
        end

        local worldFrame = gui:FindFirstChild("WorldTeleFrame", true)
        if not worldFrame then
                warn("TeleportClient: WorldTeleFrame not found")
                return
        end

        for name, placeId in pairs(TeleportClient.worldSpawnIds) do
                local button = worldFrame:FindFirstChild(name .. "Button")
                if button then
                        if placeId and placeId > 0 then
                                button.Activated:Connect(function()
                                        teleportToPlace(placeId)
                                end)
                        else
                                warn("TeleportClient: missing asset id for realm " .. name)
                        end
                else
                        warn("World button not found for: " .. name)
                end
        end
end

function TeleportClient.init(gui)
        if not gui then
                warn("TeleportClient: gui parameter is required")
                return
        end

        TeleportClient.bindZoneButtons(gui)
        TeleportClient.bindWorldButtons(gui)
end

return TeleportClient
