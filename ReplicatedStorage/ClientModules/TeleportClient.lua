-- TeleportClient Module
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

local TeleportClient = {}

-- Place ids for the various realms in the experience.  Ids of ``0``
-- indicate a realm that does not yet have a destination place.  This
-- table is exposed so other modules (eg, BootUI) can look up the asset
-- id for a realm when teleporting.
TeleportClient.worldSpawnIds = {
        SecretVillage = 15719226587,
        Water         = 15999399322,
        Fire          = 16167296427,
        Wind          = 16912345678,
        Growth        = 17012345678,
        Ice           = 17112345678,
        Light         = 17212345678,
        Metal         = 17312345678,
        Strength      = 17412345678,
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

local function notify(text)
        pcall(function()
                StarterGui:SetCore("SendNotification", {Title = "Teleport", Text = text, Duration = 3})
        end)
end

function TeleportClient.unlockRealm(name)
        local realmsFolder = player:FindFirstChild("Realms")
        if not realmsFolder then
                realmsFolder = Instance.new("Folder")
                realmsFolder.Name = "Realms"
                realmsFolder.Parent = player
        end
        local flag = realmsFolder:FindFirstChild(name)
        if not flag then
                flag = Instance.new("BoolValue")
                flag.Name = name
                flag.Parent = realmsFolder
        end
        flag.Value = true
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

       local realmsFolder = player:FindFirstChild("Realms")

       local enterButton = worldFrame:FindFirstChild("EnterRealmButton")
       if not enterButton then
               warn("TeleportClient: EnterRealmButton not found")
               return
       end

       local worldButtons = {}
       local selectedRealm = nil

       local function selectRealm(name, button)
               selectedRealm = name
               for _, b in pairs(worldButtons) do
                       b.BackgroundColor3 = Color3.fromRGB(50,120,255)
               end
               button.BackgroundColor3 = Color3.fromRGB(80,160,255)
               enterButton.Text = "Enter " .. name
               enterButton.Active = true
               enterButton.AutoButtonColor = true
       end

       enterButton.Active = false
       enterButton.AutoButtonColor = false

       local function bindRealmButton(name, button)
               if worldButtons[name] then
                       return true
               end

               worldButtons[name] = button
               button.AutoButtonColor = false

               local function isUnlocked()
                       local flag = realmsFolder and realmsFolder:FindFirstChild(name)
                       return flag and flag.Value
               end

               local function updateVisual()
                       if TeleportClient.worldSpawnIds[name] and TeleportClient.worldSpawnIds[name] > 0 and isUnlocked() then
                               button.BackgroundColor3 = Color3.fromRGB(50,120,255)
                               button.TextColor3 = Color3.new(1,1,1)
                       else
                               button.BackgroundColor3 = Color3.fromRGB(80,80,80)
                               button.TextColor3 = Color3.fromRGB(170,170,170)
                       end
               end

               updateVisual()

               if realmsFolder then
                       local flag = realmsFolder:FindFirstChild(name)
                       if flag then
                               flag:GetPropertyChangedSignal("Value"):Connect(updateVisual)
                       end
               end

               button.Activated:Connect(function()
                       local placeId = TeleportClient.worldSpawnIds[name]
                       if not (placeId and placeId > 0) then
                               warn("TeleportClient: missing asset id for realm " .. name)
                               return
                       end
                       if not isUnlocked() then
                               notify("Realm " .. name .. " is locked")
                               return
                       end
                       selectRealm(name, button)
               end)

               return true
       end

       local function tryBindButton(name)
               local button = worldFrame:FindFirstChild(name .. "Button")
               if button then
                       return bindRealmButton(name, button)
               end
               return false
       end

       for name in pairs(TeleportClient.worldSpawnIds) do
               if not tryBindButton(name) then
                       task.delay(5, function()
                               if not worldButtons[name] then
                                       warn("World button not found for: " .. name)
                               end
                       end)
               end
       end

       worldFrame.ChildAdded:Connect(function(child)
               local suffixStart = string.find(child.Name, "Button", 1, true)
               if not suffixStart then return end

               local baseName = string.sub(child.Name, 1, suffixStart - 1)
               if TeleportClient.worldSpawnIds[baseName] then
                       bindRealmButton(baseName, child)
               end
       end)

       enterButton.Activated:Connect(function()
               if not selectedRealm then return end
               local placeId = TeleportClient.worldSpawnIds[selectedRealm]
               if placeId and placeId > 0 then
                       teleportToPlace(placeId)
               else
                       warn("TeleportClient: missing asset id for realm " .. tostring(selectedRealm))
               end
       end)
end

function TeleportClient.init(gui)
        if not gui then
                warn("TeleportClient: gui parameter is required")
                return
        end

        if gui:FindFirstChild("TeleFrame", true) then
                TeleportClient.bindZoneButtons(gui)
        end
        if gui:FindFirstChild("WorldTeleFrame", true) then
                TeleportClient.bindWorldButtons(gui)
        end
end

return TeleportClient
