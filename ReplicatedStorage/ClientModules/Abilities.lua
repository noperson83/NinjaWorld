-- Abilities Module
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CharacterManager = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("CharacterManager"))

local Abilities = {}

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
	local animator = CharacterManager.animator
	if not animator or not CharacterManager.starModel then
		warn("?? Star ability failed – missing animator or starModel")
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

function Abilities.Dragon() warn("?? Dragon not implemented yet") end
function Abilities.Beast() warn("?? Beast not implemented yet") end

return Abilities
