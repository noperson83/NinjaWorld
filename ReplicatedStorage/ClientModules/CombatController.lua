-- CombatController Module
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CharacterManager = require(ReplicatedStorage.ClientModules.CharacterManager)
local Abilities = require(ReplicatedStorage.ClientModules.Abilities)
local AudioPlayer = require(ReplicatedStorage.ClientModules.AudioPlayer)
local SoundService = game:GetService("SoundService")

local CombatController = {}

local cooldowns = {
        Punch = 0.3,
        Kick = 0.3,
        Roll = 0.3,
        Crouch = 0.3,
        Slide = 1,
        Rain = 3
}

local slideDuration = cooldowns.Slide
local slideSpeedMultiplier = 1.25

local canStrike = true
local animationTracks = {}
local STRIKE_SOUND_NAME = "Combat_Strike_SFX"
local STRIKE_SOUND_ID = 9118820981

AudioPlayer.preloadAudio({ [STRIKE_SOUND_NAME] = STRIKE_SOUND_ID })

local snd = SoundService:WaitForChild(STRIKE_SOUND_NAME, 5)
if snd then
    snd.Volume = 1
end

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

function CombatController.setSlideDuration(seconds)
       slideDuration = seconds
end

function CombatController.setSlideSpeedMultiplier(multiplier)
       slideSpeedMultiplier = multiplier
end

function CombatController.perform(actionName)
        print("Performing action:", actionName)
        local abilityFunc = Abilities[actionName]
        if type(abilityFunc) == "function" then
                if Abilities.isUnlocked(actionName) then
                        abilityFunc()
                else
                        warn("Ability " .. actionName .. " is locked")
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
                       local humanoid = CharacterManager.humanoid
                       local originalSpeed = humanoid.WalkSpeed
                       humanoid.WalkSpeed = originalSpeed * slideSpeedMultiplier
                       task.delay(slideDuration, function()
                               if track then track:Stop() end
                               humanoid.WalkSpeed = originalSpeed
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
