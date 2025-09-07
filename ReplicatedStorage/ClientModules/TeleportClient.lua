-- TeleportClient Module
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local TeleportClient = {}

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
        local screenGui = (gui and (gui.ScreenGui or gui.gui)) or gui
        if not screenGui then
                warn("TeleportClient: ScreenGui missing for zone buttons")
                return
        end

        local teleFrame = screenGui:FindFirstChild("TeleFrame")
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
        local screenGui = (gui and (gui.ScreenGui or gui.gui)) or gui
        if not screenGui then
                warn("TeleportClient: ScreenGui missing for world buttons")
                return
        end

        local worldFrame = screenGui:FindFirstChild("WorldTeleFrame")
        if not worldFrame then
                warn("TeleportClient: WorldTeleFrame not found")
                return
        end

        local worldSpawnIds = {
                Atom = 15915218395,
                Fire = 16167296427,
                Water = 15999399322
        }

        for name, placeId in pairs(worldSpawnIds) do
                local button = worldFrame:FindFirstChild(name .. "Button")
                if button then
                        button.Activated:Connect(function()
                                teleportToPlace(placeId)
                        end)
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
