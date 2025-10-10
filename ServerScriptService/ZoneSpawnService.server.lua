local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpawnRegistry = require(ReplicatedStorage:WaitForChild("SpawnRegistry"))

while not shared.sessionData do
        task.wait()
end

local sessionData = shared.sessionData

local remote = ReplicatedStorage:FindFirstChild("UnlockSpawnLocation")
if remote and not remote:IsA("RemoteEvent") then
        remote:Destroy()
        remote = nil
end
if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name = "UnlockSpawnLocation"
        remote.Parent = ReplicatedStorage
end

local ZoneSpawnService = {}

local function getZoneFolder(player)
        if not (player and player:IsA("Player")) then
                return nil
        end
        local folder = player:FindFirstChild("ZoneSpawns")
        if not folder then
                folder = Instance.new("Folder")
                folder.Name = "ZoneSpawns"
                folder.Parent = player
        end
        return folder
end

local function setSpawnUnlocked(player, spawnKey)
        if typeof(spawnKey) ~= "string" then
                return false
        end
        if not SpawnRegistry.isSpawnKeyValid(spawnKey) then
                return false
        end
        local data = sessionData[player.UserId]
        if not data then
                return false
        end
        data.unlockedSpawns = data.unlockedSpawns or {}
        if data.unlockedSpawns[spawnKey] then
                return true
        end
        data.unlockedSpawns[spawnKey] = true

        local folder = getZoneFolder(player)
        if not folder then
                return false
        end

        local flag = folder:FindFirstChild(spawnKey)
        if not flag then
                flag = Instance.new("BoolValue")
                flag.Name = spawnKey
                flag.Value = true
                flag.Parent = folder
        else
                flag.Value = true
        end

        return true
end

function ZoneSpawnService.unlockSpawnForPlayer(player, spawnKey)
        if typeof(player) ~= "Instance" or not player:IsA("Player") then
                return false
        end
        return setSpawnUnlocked(player, spawnKey)
end

function ZoneSpawnService.unlockSpawnForPart(player, instance)
        if typeof(player) ~= "Instance" or not player:IsA("Player") then
                return false
        end
        local spawnKey = SpawnRegistry.getSpawnKeyForInstance(instance)
        if not spawnKey then
                return false
        end
        return setSpawnUnlocked(player, spawnKey)
end

remote.OnServerEvent:Connect(function(player, spawnKey)
        if typeof(player) ~= "Instance" or not player:IsA("Player") then
                return
        end
        if typeof(spawnKey) ~= "string" then
                return
        end
        if not setSpawnUnlocked(player, spawnKey) then
                warn(string.format("ZoneSpawnService: failed to unlock %s for %s", tostring(spawnKey), player.Name))
        end
end)

shared.ZoneSpawnService = ZoneSpawnService
