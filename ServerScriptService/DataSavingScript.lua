local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DatastoreService = game:GetService("DataStoreService")
local Data = DatastoreService:GetDataStore("2")
local sessionData = {}

-- Function to increment a player's experience by a specified amount
local function addExperience(player, amount)
	local currentExperience = player.Stats.Experience.Value
	local newExperience = currentExperience + amount
	player.Stats.Experience.Value = newExperience
end

-- Function to save a player's level and experience to the DataStore
local function savePlayerData(player)
	local success, result = pcall(function()
		local playerKey = player.UserId .. "_Level"
		local level = player.Stats.Level.Value
		local experience = player.Stats.Experience.Value
		local kill = player.Stats.Kills.Value
		return Data:SetAsync(playerKey, {level, experience, kill})
	end)
	if not success then
		warn("Failed to save player data for player", player.Name, result)
	end
end

-- Function to load a player's level and experience from the DataStore
local function loadPlayerData(player)
	local playerKey = player.UserId .. "_Level"
	local success, result = pcall(function()
		return Data:GetAsync(playerKey)
	end)
	if success and result then
		player.Stats.Level.Value = result[1]
		player.Stats.Experience.Value = result[2]
		player.Stats.Kills.Value = result[3]
	end
end
				
function PlayerAdded(player)

	--local coins = Instance.new("NumberValue")
	--coins.Name = "Coins" -- Change Coins to whatever your currency is called.
	--coins.Parent = player

	local water = Instance.new("NumberValue")
	local fire = Instance.new("NumberValue")
	local grow = Instance.new("NumberValue")
	local ice = Instance.new("NumberValue")
	local light = Instance.new("NumberValue")
	local metal = Instance.new("NumberValue")
	local magic = Instance.new("NumberValue")
	local strength = Instance.new("NumberValue")
	local wind = Instance.new("NumberValue")
	local atom = Instance.new("NumberValue")

	water.Name = "Water"
	fire.Name = "Fire" 
	grow.Name = "Grow" 
	ice.Name = "Ice" 
	light.Name = "Light" 
	metal.Name = "Metal" 
	magic.Name = "Magic" 
	strength.Name = "Strength" 
	wind.Name = "Wind" 
	atom.Name = "Atom"
	
	water.Parent = player
	fire.Parent = player 
	grow.Parent = player 
	ice.Parent = player 
	light.Parent = player 
	metal.Parent = player 
	magic.Parent = player 
	strength.Parent = player 
	wind.Parent = player 
	atom.Parent = player

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local checkpoint = Instance.new("IntValue")
	checkpoint.Name = "Checkpoint"
	checkpoint.Value = 0  -- Start at checkpoint 0
	checkpoint.Parent = leaderstats

	local success, playerData = pcall(function()
		return Data:GetAsync(player.UserId)
	end)

	if success then
		if not playerData then
			print("New player, giving default data")

			playerData = {
				["Water"] = 0, ["Atom"] = 0, ["Fire"] = 0, ["Grow"] = 0, ["Ice"] = 0, ["Light"] = 0, ["Magic"] = 0, ["Metal"] = 0, ["Strength"] = 0, ["Wind"] = 0,
				--Change Coins to whatever your currency is called.
			}
		end

		sessionData[player.UserId] = playerData
	else
		warn("Couldn't load data: " .. player.Name)
		player:Kick("Couldn't load your data, rejoin")
	end

	water.Parent = leaderstats
	fire.Parent = leaderstats 
	grow.Parent = leaderstats 
	ice.Parent = leaderstats 
	light.Parent = leaderstats 
	metal.Parent = leaderstats 
	magic.Parent = leaderstats 
	strength.Parent = leaderstats 
	wind.Parent = leaderstats 
	atom.Parent = leaderstats
	--coins.Parent = leaderstats
	
	if sessionData[player.UserId].Water == nil then sessionData[player.UserId].Water = 0 end
	if sessionData[player.UserId].Fire == nil then sessionData[player.UserId].Fire = 0 end
	if sessionData[player.UserId].Grow == nil then sessionData[player.UserId].Grow = 0 end
	if sessionData[player.UserId].Ice == nil then sessionData[player.UserId].Ice = 0 end
	if sessionData[player.UserId].Light == nil then sessionData[player.UserId].Light = 0 end
	if sessionData[player.UserId].Metal == nil then sessionData[player.UserId].Metal = 0 end
	if sessionData[player.UserId].Magic == nil then sessionData[player.UserId].Magic = 0 end
	if sessionData[player.UserId].Strength == nil then sessionData[player.UserId].Strength = 0 end
	if sessionData[player.UserId].Wind == nil then sessionData[player.UserId].Wind = 0 end
	if sessionData[player.UserId].Atom  == nil then sessionData[player.UserId].Atom = 0 end
		
	water.Value = sessionData[player.UserId].Water
	fire.Value = sessionData[player.UserId].Fire
	grow.Value = sessionData[player.UserId].Grow
	ice.Value = sessionData[player.UserId].Ice
	light.Value = sessionData[player.UserId].Light
	metal.Value = sessionData[player.UserId].Metal
	magic.Value = sessionData[player.UserId].Magic
	strength.Value = sessionData[player.UserId].Strength
	wind.Value = sessionData[player.UserId].Wind
	atom.Value  = sessionData[player.UserId].Atom 
	
	--coins.Value = sessionData[player.UserId].Coins -- Change Coins to whatever your currency is

	atom:GetPropertyChangedSignal("Value"):Connect(function()
		sessionData[player.UserId].Atom = atom.Value -- Change Coins to whatever your currency is
	end)
	fire:GetPropertyChangedSignal("Value"):Connect(function()
		sessionData[player.UserId].Fire = fire.Value -- Change Coins to whatever your currency is
	end)
	grow:GetPropertyChangedSignal("Value"):Connect(function()
		sessionData[player.UserId].Grow = grow.Value -- Change Coins to whatever your currency is
	end)
	ice:GetPropertyChangedSignal("Value"):Connect(function()
		sessionData[player.UserId].Ice = ice.Value -- Change Coins to whatever your currency is
	end)
	light:GetPropertyChangedSignal("Value"):Connect(function()
		sessionData[player.UserId].Light = light.Value -- Change Coins to whatever your currency is
	end)
	magic:GetPropertyChangedSignal("Value"):Connect(function()
		sessionData[player.UserId].Magic = magic.Value -- Change Coins to whatever your currency is
	end)
	metal:GetPropertyChangedSignal("Value"):Connect(function()
		sessionData[player.UserId].Metal = metal.Value -- Change Coins to whatever your currency is
	end)
	strength:GetPropertyChangedSignal("Value"):Connect(function()
		sessionData[player.UserId].Strength = strength.Value -- Change Coins to whatever your currency is
	end)
	water:GetPropertyChangedSignal("Value"):Connect(function()
		sessionData[player.UserId].Water = water.Value -- Change Coins to whatever your currency is
	end)
	wind:GetPropertyChangedSignal("Value"):Connect(function()
		sessionData[player.UserId].Wind = wind.Value -- Change Coins to whatever your currency is
	end)
	--coins:GetPropertyChangedSignal("Value"):Connect(function()
	--	sessionData[player.UserId].Coins = coins.Value -- Change Coins to whatever your currency is
		--end)

	-- Create a folder to store the player's stats
	local statsFolder = Instance.new("Folder")
	statsFolder.Name = "Stats"
	statsFolder.Parent = player

	-- Create an IntValue for the player's level and set it to 1
	local levelValue = Instance.new("IntValue")
	levelValue.Name = "Level"
	levelValue.Value = 1
	levelValue.Parent = statsFolder

	-- Create an IntValue for the player's experience and set it to 0
	local experienceValue = Instance.new("IntValue")
	experienceValue.Name = "Experience"
	experienceValue.Value = 0
	experienceValue.Parent = statsFolder

	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Value = 0
	kills.Parent = statsFolder

	-- Load the player's level and experience from the DataStore
	loadPlayerData(player)

	-- Listen for changes to the player's experience and level up if necessary
	experienceValue:GetPropertyChangedSignal("Value"):Connect(function()
		local requiredExperience = math.floor(levelValue.Value ^ 1.5 + 0.5) * 500
		local maxHealth = math.floor(player.Character:WaitForChild("Humanoid").MaxHealth ^ 0 + 1) * 1
		if experienceValue.Value >= requiredExperience then
			levelValue.Value += 1
			player.Character:WaitForChild("Humanoid").MaxHealth += maxHealth
		end
	end)

	-- Increment the player's experience every kill
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:FindFirstChild("Humanoid")

		humanoid.Died:Connect(function(died)
			local creator = humanoid:FindFirstChild("creator")
			local killer = creator.Value
			if creator and killer then
				killer.Stats:FindFirstChild("Kills").Value += 1
				addExperience(killer, 100)
			end
		end)
	end)
end

Players.PlayerAdded:Connect(PlayerAdded)

function PlayerLeaving(player)

	if sessionData[player.UserId] then

		local success, errorMsg = pcall(function()
			Data:SetAsync(player.UserId, sessionData[player.UserId])
		end)

		if success then
			print("Data saved: " .. player.Name)
		else
			warn("Can't save: " .. player.Name)
		end
	end
end

Players.PlayerRemoving:Connect(PlayerLeaving)

function ServerShutdown()
	if RunService:IsStudio() then
		return
	end


	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			PlayerLeaving(player)
		end)
	end
end

game:BindToClose(ServerShutdown)
