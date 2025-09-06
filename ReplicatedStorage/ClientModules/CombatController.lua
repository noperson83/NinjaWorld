-- CombatController Module
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CharacterManager = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("CharacterManager"))

local CombatController = {}

local cooldowns = {
	Punch = 0.3,
	Kick = 0.3,
	Roll = 0.3,
	Crouch = 0.3,
	Slide = 1,
	Rain = 3
}

local canStrike = true
local animationTracks = {}
local snd = script:FindFirstChild("Sound") or Instance.new("Sound")
snd.Name = "Sound"
snd.SoundId = "rbxassetid://12222216" -- replace with actual sound
snd.Volume = 1
snd.Parent = script

function CombatController.initAnimations()
	local animations = {
		Punch = "rbxassetid://16094588475",
		Kick = "rbxassetid://16094054595",
		Roll = "rbxassetid://16094647351",
		Crch = "rbxassetid://16094669431",
		Slid = "rbxassetid://16094829694"
	}
	task.spawn(function()
		local tries = 0
		while not CharacterManager.animator and tries < 10 do
			task.wait(0.2)
			tries += 1
		end
		local animator = CharacterManager.animator
		if not animator then
			warn("?? Animator still not available after waiting. Aborting animation init.")
			return
		end
		for name, id in pairs(animations) do
			local anim = Instance.new("Animation")
			anim.Name = name .. "Anim"
			anim.AnimationId = id
			animationTracks[name] = animator:LoadAnimation(anim)
		end
	end)
end

function CombatController.getTracks()
	return animationTracks
end

function CombatController.perform(actionName)
	print("Performing action:", actionName)
	if actionName == "Rain" then
		local offset = Vector3.new(0, 12, 0)
		local caster = CharacterManager.character
		local humanoidRoot = CharacterManager.humanoidRoot
		local rainTemplate = ReplicatedStorage:WaitForChild("Elements"):WaitForChild("WaterElem"):FindFirstChild("WaterRain")
		if not rainTemplate then warn("?? Missing WaterRain template") return end
		local target = nil
		for i = 1, math.random(3, 5) do
			task.delay(i * 0.1, function()
				local sideOffset = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
				local rainInstance = rainTemplate:Clone()
				rainInstance.Anchored = true
				rainInstance.CFrame = (target and target:FindFirstChild("Head") and CFrame.new(target.Head.Position + offset + sideOffset))
					or (humanoidRoot.CFrame + humanoidRoot.CFrame.LookVector * 6 + offset + sideOffset)
				rainInstance.Parent = workspace
				local cloud = rainInstance:Clone()
				cloud.Name = "RainCloud"
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
		return
	end
	if actionName == "Crouch" then
		local track = animationTracks["Crch"]
		if track then
			if CharacterManager.isCrouching then
				track:AdjustSpeed(1)
				track:Play()
				CharacterManager.humanoid.WalkSpeed = 24
				task.delay(0.23, function()
					track:Stop()
				end)
				CharacterManager.isCrouching = false
			else
				track.TimePosition = 0.1
				track:Play()
				track:AdjustSpeed(0)
				CharacterManager.humanoid.WalkSpeed = 8
				CharacterManager.isCrouching = true
			end
		end
		return
	end
	if canStrike and CharacterManager.humanoid and CharacterManager.humanoid.Health > 0 then
		canStrike = false
		local track = animationTracks[actionName]
		print("ActionName:", actionName, "Track:", track)
		if track then
			print("?? Playing animation for:", actionName)
			track:Play()
		else
			warn("?? Animation track missing for:", actionName)
		end
		if snd then snd:Play() end
		if actionName == "Slid" then
			CharacterManager.humanoid.WalkSpeed = 30
			task.delay(cooldowns["Slide"], function()
				if track then track:Stop() end
				CharacterManager.humanoid.WalkSpeed = 24
				canStrike = true
			end)
			return
		end
		task.delay(cooldowns[actionName], function()
			canStrike = true
		end)
	end
end

return CombatController