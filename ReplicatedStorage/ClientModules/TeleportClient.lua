-- TeleportClient Module
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

local TeleportClient = {}

local debounce = false

local function findSpawnPart(inst)
        if inst:IsA("SpawnLocation") then
                return inst, inst
        end

        if inst:IsA("BasePart") then
                local lowerName = string.lower(inst.Name)
                if lowerName:find("spawn", 1, true) then
                        return inst, inst
                end
        end

        if inst:IsA("Model") then
                local lowerName = string.lower(inst.Name)
                if lowerName:find("spawn", 1, true) then
                        local primary = inst.PrimaryPart
                        if primary and primary:IsA("BasePart") then
                                return primary, inst
                        end

                        for _, desc in ipairs(inst:GetDescendants()) do
                                if desc:IsA("BasePart") then
                                        return desc, inst
                                end
                        end
                end
        end

        return nil, nil
end

local function getPathSegments(inst)
        local segments = {}
        local current = inst
        while current and current ~= Workspace do
                table.insert(segments, 1, current.Name)
                current = current.Parent
        end
        return segments
end

local function prettifyName(raw)
        local cleaned = raw
        cleaned = cleaned:gsub("^Zone", "")
        cleaned = cleaned:gsub("SpawnLocation$", "")
        cleaned = cleaned:gsub("Spawn$", "")
        cleaned = cleaned:gsub("_%d+$", "")
        cleaned = cleaned:gsub("(%l)(%u)", "%1 %2")
        cleaned = cleaned:gsub("%s+", " ")
        cleaned = cleaned:match("^%s*(.-)%s*$") or cleaned
        if cleaned == "" then
                cleaned = raw
        end
        return cleaned
end

local function makeDisplayLabel(segments)
        local prettySegments = {}
        for _, name in ipairs(segments) do
                local pretty = prettifyName(name)
                if pretty == "" then
                        pretty = name
                end
                if prettySegments[#prettySegments] ~= pretty then
                        prettySegments[#prettySegments + 1] = pretty
                end
        end
        return table.concat(prettySegments, " / ")
end

local function makeSpawnKey(segments)
        local joined = table.concat(segments, "_")
        joined = joined:gsub("[^%w_]", "_")
        if joined == "" then
                joined = "Spawn"
        end
        return joined
end

local function resolveSpawnPart(islandOrPart, locationName)
        if typeof(islandOrPart) == "Instance" then
                if islandOrPart:IsA("BasePart") then
                        return islandOrPart
                end
                return nil
        end

        if typeof(islandOrPart) == "table" then
                local instance = islandOrPart.instance
                if typeof(instance) == "Instance" and instance:IsA("BasePart") then
                        return instance
                end
        end

        if typeof(islandOrPart) ~= "string" then
                return nil
        end

        local parentZone = Workspace:FindFirstChild(islandOrPart)
        if parentZone then
                local point = parentZone:FindFirstChild(locationName)
                if point and point:IsA("BasePart") then
                        return point
                end
        end

        return nil
end

local function teleportToSpawnPart(spawnPart)
        if debounce then
                return
        end
        if not (spawnPart and spawnPart:IsA("BasePart")) then
                warn("TeleportClient: spawn part missing or invalid")
                return
        end

        debounce = true
        task.wait(1)

        local char = player.Character or player.CharacterAdded:Wait()
        local torso = char:FindFirstChild("HumanoidRootPart")
        if not torso then
                torso = char:FindFirstChild("LowerTorso")
        end
        if not torso then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.RootPart then
                        torso = humanoid.RootPart
                end
        end

        if not torso then
                warn("TeleportClient: unable to find character root part")
                resetDebounceAfter(2)
                return
        end

        local upOffset = spawnPart.Size.Y / 2 + 3
        local destination = spawnPart.Position + Vector3.new(0, upOffset, 0)
        local lookAt = destination + spawnPart.CFrame.LookVector
        torso.CFrame = CFrame.new(destination, lookAt)

        resetDebounceAfter(2)
end

function TeleportClient.getAvailableZoneSpawns()
        local results = {}
        local seen = {}

        for _, inst in ipairs(Workspace:GetDescendants()) do
                local spawnPart, labelInstance = findSpawnPart(inst)
                if spawnPart then
                        local identifier = spawnPart:GetFullName()
                        if not seen[identifier] then
                                seen[identifier] = true

                                local segments = getPathSegments(labelInstance or spawnPart)
                                local key = makeSpawnKey(segments)
                                local label = makeDisplayLabel(segments)

                                results[#results + 1] = {
                                        key = key,
                                        label = label,
                                        instance = spawnPart,
                                }
                        end
                end
        end

        table.sort(results, function(a, b)
                return a.label < b.label
        end)

        return results
end

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
        local spawnPart = resolveSpawnPart(islandName, locationName)
        if spawnPart then
                teleportToSpawnPart(spawnPart)
        else
                local island = tostring(islandName)
                local location = tostring(locationName)
                warn("TeleportClient: spawn point missing for " .. island .. "/" .. location)
        end
end

local function teleportToPlace(placeId)
	if debounce then return end
	debounce = true
	TeleportService:Teleport(placeId, player)
	resetDebounceAfter(2)
end

function TeleportClient.bindZoneButtons(gui, callbacks)
        if not gui then
                warn("TeleportClient: gui parameter missing for zone buttons")
                return
        end

        callbacks = callbacks or {}
        local onTeleport = callbacks.onTeleport

        local teleFrame = gui:FindFirstChild("TeleFrame", true)
        if not teleFrame then
                warn("TeleportClient: TeleFrame not found")
                return
        end

        local spawnInfos = TeleportClient.getAvailableZoneSpawns()

        for _, info in ipairs(spawnInfos) do
                local button = teleFrame:FindFirstChild(info.key .. "Button")
                if button then
                        button.Activated:Connect(function()
                                local spawnPart = info.instance
                                if not (spawnPart and spawnPart.Parent) then
                                        warn("TeleportClient: spawn part missing for button " .. info.key)
                                        return
                                end

                                if onTeleport then
                                        onTeleport({
                                                source = "Zone",
                                                name = info.key,
                                                label = info.label,
                                                spawnPath = spawnPart:GetFullName(),
                                        })
                                end

                                teleportToSpawnPart(spawnPart)
                        end)
                else
                        warn("TeleportClient: zone button not found for " .. info.key)
                end
        end
end


function TeleportClient.bindWorldButtons(gui, callbacks)
        if not gui then
                warn("TeleportClient: gui parameter missing for world buttons")
                return
        end

       callbacks = callbacks or {}
       local onTeleport = callbacks.onTeleport

       local worldFrame = gui:FindFirstChild("WorldTeleFrame", true)
       if not worldFrame then
               warn("TeleportClient: WorldTeleFrame not found")
               return
       end

       local enterButton = gui:FindFirstChild("EnterRealmButton", true)
       if not enterButton then
               warn("TeleportClient: EnterRealmButton not found")
               return
       end

       local worldButtons = {}
       local buttonUpdaters = {}
       local realmFolderConnections = {}
       local statsChildAddedConnection
       local playerChildAddedConnection
       local selectedRealm = nil

       local function getRealmFlag(name)
               local realmsFolder = player:FindFirstChild("Realms")
               if realmsFolder then
                       local flag = realmsFolder:FindFirstChild(name)
                       if flag then
                               return flag
                       end
               end

               local stats = player:FindFirstChild("Stats")
               if stats then
                       local statsRealms = stats:FindFirstChild("Realms")
                       if statsRealms then
                               return statsRealms:FindFirstChild(name)
                       end
               end

               return nil
       end

       local function watchRealmFolder(folder)
               if not folder or realmFolderConnections[folder] then
                       return
               end

               realmFolderConnections[folder] = folder.ChildAdded:Connect(function(child)
                       if child:IsA("BoolValue") then
                               local updater = buttonUpdaters[child.Name]
                               if updater then
                                       updater()
                               end
                       end
               end)
       end

       local function ensureRealmFolderConnections()
               local directRealms = player:FindFirstChild("Realms")
               if directRealms then
                       watchRealmFolder(directRealms)
               end

               local stats = player:FindFirstChild("Stats")
               if stats then
                       if not statsChildAddedConnection then
                               statsChildAddedConnection = stats.ChildAdded:Connect(function(child)
                                       if child.Name == "Realms" and child:IsA("Folder") then
                                               watchRealmFolder(child)
                                               for _, updater in pairs(buttonUpdaters) do
                                                       updater()
                                               end
                                       end
                               end)
                       end

                       local statsRealms = stats:FindFirstChild("Realms")
                       if statsRealms then
                               watchRealmFolder(statsRealms)
                       end
               end

               if not playerChildAddedConnection then
                       playerChildAddedConnection = player.ChildAdded:Connect(function(child)
                               if child.Name == "Realms" and child:IsA("Folder") then
                                       watchRealmFolder(child)
                                       for _, updater in pairs(buttonUpdaters) do
                                               updater()
                                       end
                               elseif child.Name == "Stats" and child:IsA("Folder") then
                                       statsChildAddedConnection = statsChildAddedConnection or child.ChildAdded:Connect(function(grandChild)
                                               if grandChild.Name == "Realms" and grandChild:IsA("Folder") then
                                                       watchRealmFolder(grandChild)
                                                       for _, updater in pairs(buttonUpdaters) do
                                                               updater()
                                                       end
                                               end
                                       end)
                                       local childRealms = child:FindFirstChild("Realms")
                                       if childRealms then
                                               watchRealmFolder(childRealms)
                                               for _, updater in pairs(buttonUpdaters) do
                                                       updater()
                                               end
                                       end
                               end
                       end)
               end
       end

       ensureRealmFolderConnections()

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
                       local flag = getRealmFlag(name)
                       return flag and flag.Value
               end

               local flagConnection
               local lastFlag

               local function updateVisual()
                       local flag = getRealmFlag(name)

                       if flag ~= lastFlag then
                               if flagConnection then
                                       flagConnection:Disconnect()
                                       flagConnection = nil
                               end

                               lastFlag = flag

                               if flag then
                                       flagConnection = flag:GetPropertyChangedSignal("Value"):Connect(function()
                                               updateVisual()
                                       end)
                               end
                       end

                       local unlocked = flag and flag.Value

                       if TeleportClient.worldSpawnIds[name] and TeleportClient.worldSpawnIds[name] > 0 and unlocked then
                               button.BackgroundColor3 = Color3.fromRGB(50,120,255)
                               button.TextColor3 = Color3.new(1,1,1)
                       else
                               button.BackgroundColor3 = Color3.fromRGB(80,80,80)
                               button.TextColor3 = Color3.fromRGB(170,170,170)
                       end
               end

               buttonUpdaters[name] = updateVisual

               updateVisual()

               ensureRealmFolderConnections()

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
                       if onTeleport then
                               onTeleport({
                                       source = "Realm",
                                       realm = selectedRealm,
                                       placeId = placeId,
                               })
                       end
                       teleportToPlace(placeId)
               else
                       warn("TeleportClient: missing asset id for realm " .. tostring(selectedRealm))
               end
       end)
end

function TeleportClient.init(gui, callbacks)
        if not gui then
                warn("TeleportClient: gui parameter is required")
                return
        end

        if gui:FindFirstChild("TeleFrame", true) then
                TeleportClient.bindZoneButtons(gui, callbacks)
        end
        if gui:FindFirstChild("WorldTeleFrame", true) then
                TeleportClient.bindWorldButtons(gui, callbacks)
        end
end

return TeleportClient
