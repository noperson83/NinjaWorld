local AudioPlayer = {}
 
-- Roblox services
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
 
-- Function to preload audio assets
AudioPlayer.preloadAudio = function(assetArray)
	local audioAssets = {}
 
	-- Add new "Sound" assets to "audioAssets" array
	for name, audioID in pairs(assetArray) do
		local audioInstance = Instance.new("Sound")
		audioInstance.SoundId = "rbxassetid://" .. audioID
		audioInstance.Name = name
		audioInstance.Parent = SoundService
		
		table.insert(audioAssets, audioInstance)
	end
 
	local success, assets = pcall(function()
		ContentProvider:PreloadAsync(audioAssets)
	end)
end
 
-- Function to play an audio asset
AudioPlayer.playAudio = function(assetName)
	local audio = SoundService:FindFirstChild(assetName)
	if not audio then
		warn("Could not find audio asset: " .. assetName)
		return
	end
	if not audio.IsLoaded then
		audio.Loaded:Wait()
	end

	-- Setup a tween so the track starts quiet and then fades in to a normal volume
	audio.Volume = 0
	audio.Looped = true
	
	local fadeTween = TweenService:Create(audio, TweenInfo.new(10), {Volume = .5})

	audio:Play()

	-- Fade in the audio track
	fadeTween:Play()
	fadeTween.Completed:Connect(function(State)
		if State == Enum.PlaybackState.Completed then
			fadeTween:Destroy()
		end
	end)
end
 
return AudioPlayer