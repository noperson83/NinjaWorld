-- Abilities Module
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CharacterManager = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("CharacterManager"))
local AbilityMetadata = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("AbilityMetadata"))

local Elements = ReplicatedStorage:WaitForChild("Elements")
local DragonFX = nil
local BeastFX = nil

do
        local fireElem = Elements:FindFirstChild("FireElem")
        local beastElem = Elements:FindFirstChild("BeastElem")
        if fireElem then
                local module = fireElem:FindFirstChild("DragonFX")
                if module then
                        DragonFX = require(module)
                end
        end
        if beastElem then
                local module = beastElem:FindFirstChild("BeastFX")
                if module then
                        BeastFX = require(module)
                end
        end
end

local Abilities = {}
local unlocked = {}
Abilities.unlocked = unlocked

local player = Players.LocalPlayer
local abilitiesFolder = player:WaitForChild("Abilities", 5)
if abilitiesFolder then
        for _, child in ipairs(abilitiesFolder:GetChildren()) do
                if child:IsA("BoolValue") and child.Value then
                        unlocked[child.Name] = true
                end
        end
        abilitiesFolder.ChildAdded:Connect(function(child)
                if child:IsA("BoolValue") and child.Value then
                        unlocked[child.Name] = true
                end
        end)
end

function Abilities.isUnlocked(name)
        return unlocked[name]
end

local function ensureUnlocked(name)
        if not unlocked[name] then
                warn("Ability " .. name .. " is locked")
                return false
        end
        return true
end

-- FX templates
local function createOrb()
	local orb = Instance.new("Part")
	orb.Name = "Orb"
	orb.Size = Vector3.new(1.455, 1.455, 1.455)
	orb.Material = Enum.Material.SmoothPlastic
	orb.BrickColor = BrickColor.new(Color3.fromRGB(4, 175, 236))
	orb.Shape = Enum.PartType.Ball

	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(4, 175, 236)
	fire.SecondaryColor = Color3.fromRGB(85, 255, 255)
	fire.Size = 3
	fire.Heat = -5
	fire.TimeScale = 0.2
	fire.Parent = orb

	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(0, 0, 127)
	smoke.Opacity = 0.05
	smoke.Size = 0.5
	smoke.RiseVelocity = -1
	smoke.TimeScale = 0.5
	smoke.Parent = orb

	return orb
end

function Abilities.Toss()
        if not ensureUnlocked("Toss") then return end
        local animator = CharacterManager.animator
	if not animator then return end

	local tossAnimation = Instance.new("Animation")
	tossAnimation.AnimationId = "rbxassetid://16094513608"
	local tossTrack = animator:LoadAnimation(tossAnimation)
	tossTrack:Play()

	local orb = createOrb()
	orb.CFrame = CharacterManager.rightArm.CFrame * CFrame.new(0, -1.5, 0)
	orb.Velocity = (CharacterManager.rightArm.CFrame.LookVector * 100) + Vector3.new(0, 50, 0)
	orb.Parent = Workspace

	task.wait(7)
	orb:Destroy()
end

function Abilities.Star()
        if not ensureUnlocked("Star") then return end
        local animator = CharacterManager.animator
	if not animator or not CharacterManager.starModel then
		warn("?? Star ability failed  missing animator or starModel")
		return
	end

	local star = CharacterManager.starModel:Clone()
	star.CFrame = CharacterManager.rightArm.CFrame * CFrame.new(0, -1.5, 0)
	star.Velocity = (CharacterManager.rightArm.CFrame.LookVector * 100) + Vector3.new(0, 50, 0)
	star.Anchored = false
	star.Parent = Workspace

	local tossAnimation = Instance.new("Animation")
	tossAnimation.AnimationId = "rbxassetid://16094513608"
	local tossTrack = animator:LoadAnimation(tossAnimation)
	tossTrack:Play()

	task.wait(3)
	local explosion = Instance.new("Explosion")
	explosion.Position = star.Position
	explosion.BlastRadius = 5
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = Workspace

	task.wait(1)
	star:Destroy()
end

function Abilities.Rain()
        if not ensureUnlocked("Rain") then return end
        local offset = Vector3.new(0, 12, 0)
	local caster = CharacterManager.character
	local humanoidRoot = CharacterManager.humanoidRoot
	local rainTemplate = ReplicatedStorage:WaitForChild("Elements"):WaitForChild("WaterElem"):FindFirstChild("WaterRain")
	if not rainTemplate then warn("?? Missing WaterRain template") return end

	local target = nil -- insert your enemy targeting logic here
	for i = 1, math.random(3, 5) do
		task.delay(i * 0.1, function()
			local sideOffset = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
			local rainInstance = rainTemplate:Clone()
			rainInstance.Anchored = true
			rainInstance.CFrame = (target and target:FindFirstChild("Head") and CFrame.new(target.Head.Position + offset + sideOffset))
				or (humanoidRoot.CFrame + humanoidRoot.CFrame.LookVector * 6 + offset + sideOffset)
			rainInstance.Parent = workspace

			local cloud = Instance.new("Part")
			cloud.Name = "RainCloud"
			cloud.Shape = Enum.PartType.Ball
			cloud.Size = Vector3.new(math.random(4, 8), math.random(4, 8), math.random(4, 8))
			cloud.Position = rainInstance.Position + Vector3.new(0, 4, 0)
			cloud.Anchored = true
			cloud.CanCollide = false
			cloud.Transparency = 0.4
			cloud.Material = Enum.Material.ForceField
			cloud.Color = Color3.fromRGB(200, 200, 200)
			cloud.Parent = workspace

			local runConn
			runConn = game:GetService("RunService").RenderStepped:Connect(function()
				if target and target:FindFirstChild("Head") then
					rainInstance.Position = target.Head.Position + offset
				end
			end)
			task.delay(5, function()
				rainInstance:Destroy()
				cloud:Destroy()
				if runConn then runConn:Disconnect() end
			end)
		end)
	end
end

function Abilities.Dragon()
        if not ensureUnlocked("Dragon") then return end

        local animator = CharacterManager.animator
        if not animator then return end

        local projectile = DragonFX and DragonFX.create() or Instance.new("Part")
        if not DragonFX then
                projectile.Name = "DragonProjectile"
                projectile.Size = Vector3.new(2, 2, 4)
                projectile.Material = Enum.Material.Neon
                projectile.BrickColor = BrickColor.new("Bright orange")
                projectile.CanCollide = false
                local fire = Instance.new("Fire")
                fire.Heat = 0
                fire.Size = 5
                fire.Color = Color3.fromRGB(255, 170, 0)
                fire.SecondaryColor = Color3.fromRGB(255, 255, 255)
                fire.Parent = projectile
        end

        projectile.CFrame = CharacterManager.rightArm.CFrame * CFrame.new(0, -1.5, 0)
        projectile.Velocity = CharacterManager.rightArm.CFrame.LookVector * 120
        projectile.Parent = Workspace

        projectile.Touched:Connect(function(hit)
                local humanoid = hit.Parent and hit.Parent:FindFirstChild("Humanoid")
                if humanoid and humanoid ~= CharacterManager.humanoid then
                        humanoid:TakeDamage(40)
                        local explosion = Instance.new("Explosion")
                        explosion.Position = projectile.Position
                        explosion.BlastRadius = 6
                        explosion.BlastPressure = 0
                        explosion.DestroyJointRadiusPercent = 0
                        explosion.Parent = Workspace
                        projectile:Destroy()
                end
        end)

        task.delay(5, function()
                if projectile then
                        projectile:Destroy()
                end
        end)
end
function Abilities.Beast()
        if not ensureUnlocked("Beast") then return end

        local humanoidRoot = CharacterManager.humanoidRoot
        if not humanoidRoot then return end

        local aura = BeastFX and BeastFX.create() or Instance.new("Part")
        if not BeastFX then
                aura.Name = "BeastAura"
                aura.Shape = Enum.PartType.Ball
                aura.Size = Vector3.new(8, 8, 8)
                aura.Transparency = 0.7
                aura.Material = Enum.Material.Neon
                aura.BrickColor = BrickColor.new("Earth green")
                aura.CanCollide = false
                aura.Anchored = true
                local smoke = Instance.new("Smoke")
                smoke.Color = Color3.fromRGB(80, 255, 80)
                smoke.Opacity = 0.3
                smoke.Size = 5
                smoke.RiseVelocity = 0
                smoke.Parent = aura
        end

        aura.CFrame = humanoidRoot.CFrame
        aura.Parent = Workspace

        local radius = aura.Size.X / 2
        local parts = Workspace:GetPartBoundsInRadius(humanoidRoot.Position, radius)
        for _, part in ipairs(parts) do
                local humanoid = part.Parent and part.Parent:FindFirstChild("Humanoid")
                if humanoid and humanoid ~= CharacterManager.humanoid then
                        humanoid:TakeDamage(25)
                        local bodyVelocity = Instance.new("BodyVelocity")
                        bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                        bodyVelocity.Velocity = (part.Position - humanoidRoot.Position).Unit * 60 + Vector3.new(0, 30, 0)
                        bodyVelocity.Parent = part
                        task.delay(0.5, function()
                                bodyVelocity:Destroy()
                        end)
                end
        end

        task.delay(0.5, function()
                aura:Destroy()
        end)
end

return Abilities
