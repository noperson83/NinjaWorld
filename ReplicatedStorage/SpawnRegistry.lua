local Workspace = game:GetService("Workspace")

local SpawnRegistry = {}

local cachedList
local cachedLookup
local cachedInstanceLookup
local watching = false

local ATTRIBUTE_NAMES = {"DefaultUnlocked", "AlwaysUnlocked", "UnlockedByDefault"}

local function shouldInvalidate(descendant)
        if not descendant then
                return false
        end
        local spawnFolder = Workspace:FindFirstChild("SpawnLocations")
        if not spawnFolder then
                return false
        end
        return descendant:IsDescendantOf(spawnFolder)
end

local function invalidate()
        cachedList = nil
        cachedLookup = nil
        cachedInstanceLookup = nil
end

local function registerInvalidation()
        if watching then
                return
        end
        watching = true

        Workspace.ChildAdded:Connect(function(child)
                if child.Name == "SpawnLocations" then
                        invalidate()
                        child.DescendantAdded:Connect(function()
                                invalidate()
                        end)
                        child.DescendantRemoving:Connect(function()
                                invalidate()
                        end)
                elseif shouldInvalidate(child) then
                        invalidate()
                end
        end)

        Workspace.ChildRemoved:Connect(function(child)
                if child.Name == "SpawnLocations" or shouldInvalidate(child) then
                        invalidate()
                end
        end)

        local spawnFolder = Workspace:FindFirstChild("SpawnLocations")
        if spawnFolder then
                spawnFolder.DescendantAdded:Connect(function()
                        invalidate()
                end)
                spawnFolder.DescendantRemoving:Connect(function()
                        invalidate()
                end)
        end
end

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

local function readDefaultUnlocked(instance)
        if not instance then
                return nil
        end
        for _, attrName in ipairs(ATTRIBUTE_NAMES) do
                local value = instance:GetAttribute(attrName)
                if value ~= nil then
                        return value and true or false
                end
        end
        return nil
end

local function computeDefaultUnlocked(labelInstance, spawnPart)
        local explicit = readDefaultUnlocked(labelInstance)
        if explicit ~= nil then
                return explicit
        end
        explicit = readDefaultUnlocked(spawnPart)
        if explicit ~= nil then
                return explicit
        end

        local ref = labelInstance or spawnPart
        local lowerName = string.lower(ref and ref.Name or "")
        if lowerName == "spawnlocation" or lowerName == "spawn" then
                return true
        end
        if lowerName:find("starter", 1, true) then
                return true
        end

        return false
end

local function gatherSpawnInfos()
        local results = {}
        local lookup = {}
        local instanceLookup = {}
        local seen = {}

        local function registerInstance(instance, info)
                if typeof(instance) ~= "Instance" then
                        return
                end
                instanceLookup[instance] = info
        end

        local function addSpawn(spawnPart, labelInstance, explicitLabel)
                if not (spawnPart and spawnPart:IsA("BasePart")) then
                        return
                end

                local identifier = spawnPart:GetFullName()
                if seen[identifier] then
                        return
                end
                seen[identifier] = true

                local segments
                local label

                if explicitLabel then
                        segments = {explicitLabel}
                        label = prettifyName(explicitLabel)
                        if label == "" then
                                label = explicitLabel
                        end
                else
                        segments = getPathSegments(labelInstance or spawnPart)
                        label = makeDisplayLabel(segments)
                end

                local key = makeSpawnKey(segments)
                local defaultUnlocked = computeDefaultUnlocked(labelInstance, spawnPart)

                local info = {
                        key = key,
                        label = label,
                        instance = spawnPart,
                        source = labelInstance,
                        defaultUnlocked = defaultUnlocked,
                }

                results[#results + 1] = info
                lookup[key] = info

                registerInstance(spawnPart, info)
                if labelInstance and labelInstance ~= spawnPart then
                        registerInstance(labelInstance, info)
                        if labelInstance:IsA("Model") then
                                for _, desc in ipairs(labelInstance:GetDescendants()) do
                                        if desc:IsA("BasePart") then
                                                registerInstance(desc, info)
                                        end
                                end
                        elseif labelInstance:IsA("BasePart") then
                                registerInstance(labelInstance, info)
                        end
                end
        end

        local spawnFolder = Workspace:FindFirstChild("SpawnLocations")

        local function gatherFromSpawnFolder(container)
                for _, child in ipairs(container:GetChildren()) do
                        if child:IsA("Folder") then
                                gatherFromSpawnFolder(child)
                        else
                                local spawnPart
                                if child:IsA("SpawnLocation") or child:IsA("BasePart") then
                                        spawnPart = child
                                elseif child:IsA("Model") then
                                        spawnPart = child.PrimaryPart
                                        if not (spawnPart and spawnPart:IsA("BasePart")) then
                                                for _, desc in ipairs(child:GetDescendants()) do
                                                        if desc:IsA("BasePart") then
                                                                spawnPart = desc
                                                                break
                                                        end
                                                end
                                        end
                                end

                                if spawnPart then
                                        addSpawn(spawnPart, child, child.Name)
                                else
                                        gatherFromSpawnFolder(child)
                                end
                        end
                end
        end

        if spawnFolder then
                gatherFromSpawnFolder(spawnFolder)
        else
                for _, inst in ipairs(Workspace:GetDescendants()) do
                        local spawnPart, labelInstance = findSpawnPart(inst)
                        if spawnPart then
                                addSpawn(spawnPart, labelInstance)
                        end
                end
        end

        table.sort(results, function(a, b)
                return a.label < b.label
        end)

        local hasDefault = false
        for _, info in ipairs(results) do
                if info.defaultUnlocked then
                        hasDefault = true
                        break
                end
        end
        if not hasDefault and results[1] then
                results[1].defaultUnlocked = true
        end

        return results, lookup, instanceLookup
end

local function ensureCache(forceRefresh)
        if forceRefresh or not cachedList then
                cachedList, cachedLookup, cachedInstanceLookup = gatherSpawnInfos()
        end
        return cachedList, cachedLookup, cachedInstanceLookup
end

function SpawnRegistry.invalidate()
        invalidate()
end

function SpawnRegistry.getSpawnInfos(forceRefresh)
        registerInvalidation()
        local list = ensureCache(forceRefresh)
        return list
end

function SpawnRegistry.getLookup(forceRefresh)
        registerInvalidation()
        local _, lookup = ensureCache(forceRefresh)
        return lookup
end

function SpawnRegistry.getInstanceLookup(forceRefresh)
        registerInvalidation()
        local _, _, instanceLookup = ensureCache(forceRefresh)
        return instanceLookup
end

function SpawnRegistry.isSpawnKeyValid(spawnKey)
        if typeof(spawnKey) ~= "string" then
                        return false
        end
        local lookup = SpawnRegistry.getLookup()
        return lookup[spawnKey] ~= nil
end

function SpawnRegistry.getInfoForKey(spawnKey)
        if typeof(spawnKey) ~= "string" then
                return nil
        end
        local lookup = SpawnRegistry.getLookup()
        return lookup[spawnKey]
end

function SpawnRegistry.getInfoForInstance(instance)
        if typeof(instance) ~= "Instance" then
                return nil
        end
        local instanceLookup = SpawnRegistry.getInstanceLookup()
        local current = instance
        while current do
                local info = instanceLookup[current]
                if info then
                        return info
                end
                current = current.Parent
        end

        -- force refresh and try again (in case cache was stale)
        instanceLookup = SpawnRegistry.getInstanceLookup(true)
        current = instance
        while current do
                local info = instanceLookup[current]
                if info then
                        return info
                end
                current = current.Parent
        end

        return nil
end

function SpawnRegistry.getSpawnKeyForInstance(instance)
        local info = SpawnRegistry.getInfoForInstance(instance)
        return info and info.key or nil
end

return SpawnRegistry
