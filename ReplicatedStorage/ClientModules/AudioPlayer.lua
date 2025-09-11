local AudioPlayer = {}
 
-- Roblox services
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

-- Function to preload audio assets
AudioPlayer.preloadAudio = function(assetArray)
local audioAssets = {}
local invalidCount = 0

-- Scan existing sounds and discard invalid IDs
for _, descendant in ipairs(SoundService:GetDescendants()) do
if descendant:IsA("Sound") then
local existingID = tonumber(descendant.SoundId:match("%d+"))
if existingID and existingID > 0 then
table.insert(audioAssets, descendant)
else
invalidCount += 1
warn(string.format(
"Discarding invalid SoundId '%s' for sound '%s'",
descendant.SoundId,
descendant:GetFullName()
))
descendant:Destroy()
end
end
end

-- Add new "Sound" assets to "audioAssets" array
for name, audioID in pairs(assetArray) do
local numericID = tonumber(audioID)
if not numericID or numericID <= 0 or numericID % 1 ~= 0 then
invalidCount += 1
warn(
string.format(
"Invalid audio ID for '%s': %s",
name,
tostring(audioID)
)
)
else
local audioInstance = Instance.new("Sound")
audioInstance.SoundId = "rbxassetid://" .. numericID
audioInstance.Name = name
audioInstance.Parent = SoundService

table.insert(audioAssets, audioInstance)
end
end

local success, assets = pcall(function()
ContentProvider:PreloadAsync(audioAssets)
end)

if invalidCount > 0 then
warn(string.format("%d invalid audio ID(s) detected during preload", invalidCount))
end

return invalidCount
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
