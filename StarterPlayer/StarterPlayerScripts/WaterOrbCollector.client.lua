local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BootUI = require(ReplicatedStorage:WaitForChild("BootModules"):WaitForChild("BootUI"))

local player = Players.LocalPlayer

local function waitForPath(root, path, timeout)
        local current = root
        local deadline = os.clock() + (timeout or 5)

        for _, name in ipairs(path) do
                if not current then
                        return nil
                end

                local child = current:FindFirstChild(name)
                if not child then
                        local remaining = deadline - os.clock()
                        if remaining <= 0 then
                                return nil
                        end
                        child = current:WaitForChild(name, remaining)
                end

                if not child then
                        return nil
                end

                current = child
        end

        return current
end

local function resolveWaterOrb()
        local candidates = {
                {"HiddenDojo", "Orbs", "WaterCoin"},
                {"HiddenDojo", "OrbSpawns", "Orbs", "WaterOrb"},
                {"HiddenDojo", "OrbSpawns", "Orbs", "WaterCoin"},
        }

        for _, path in ipairs(candidates) do
                local orbInstance = waitForPath(Workspace, path, 8)
                if orbInstance then
                        return orbInstance
                end
        end

        return nil
end

local orbInstance = resolveWaterOrb()
if not orbInstance then
        warn("WaterOrbCollector: Water orb could not be located in Workspace")
        return
end

local orbPart
if orbInstance:IsA("BasePart") then
        orbPart = orbInstance
elseif orbInstance:IsA("Model") then
        orbPart = orbInstance.PrimaryPart or orbInstance:FindFirstChildWhichIsA("BasePart", true)
else
        orbPart = orbInstance:FindFirstChildWhichIsA("BasePart", true)
end

if not orbPart then
        warn("WaterOrbCollector: No touchable part found within water orb container")
        return
end
local claimed = false

local function isPlayerCharacterPart(part)
        if not player then
                return false
        end

        local character = player.Character
        if not character then
                return false
        end

        if not part or not part:IsDescendantOf(character) then
                return false
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        return humanoid ~= nil
end

orbPart.Touched:Connect(function(hit)
        if claimed then
                return
        end

        if not isPlayerCharacterPart(hit) then
                return
        end

        local currencyService = BootUI.currencyService
        if not currencyService or not currencyService.AddOrb then
                warn("WaterOrbCollector: Currency service unavailable")
                return
        end

        claimed = true
        currencyService:AddOrb("Water")

        if orbInstance and orbInstance.Parent then
                orbInstance:Destroy()
        end
end)
