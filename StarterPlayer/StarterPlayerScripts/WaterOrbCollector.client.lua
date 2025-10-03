local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BootUI = require(ReplicatedStorage:WaitForChild("BootModules"):WaitForChild("BootUI"))

local player = Players.LocalPlayer
local orb = Workspace:WaitForChild("HiddenDojo"):WaitForChild("Orbs"):WaitForChild("WaterCoin")
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

orb.Touched:Connect(function(hit)
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

        if orb.Parent then
                orb:Destroy()
        end
end)
