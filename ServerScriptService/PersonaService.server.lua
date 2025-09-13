
-- Ninja World EXP 3000
-- PersonaService.server.lua — v2
-- Purpose: Data + persona selection via RemoteFunction (no spawning here).
-- Works side-by-side with Init.server.lua (which controls WHEN/HOW we spawn).

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local DataStoreService   = game:GetService("DataStoreService")
local ServerStorage      = game:GetService("ServerStorage")
local GameSettings       = require(ReplicatedStorage.GameSettings)

-- === Remotes ===
local rf = ReplicatedStorage:FindFirstChild("PersonaServiceRF")
if rf and not rf:IsA("RemoteFunction") then rf:Destroy(); rf = nil end
if not rf then
	rf = Instance.new("RemoteFunction")
	rf.Name = "PersonaServiceRF"
	rf.Parent = ReplicatedStorage
end

-- === DataStore ===
local STORE = DataStoreService:GetDataStore("NW_Personas_v1")

-- Simple persona schema for v1:
-- personas = { [1] = {type="Roblox", name="My Avatar"}, [2] = {type="Ninja", name="Starter Ninja"}, [3] = nil }
local MAX_SLOTS = GameSettings.maxSlots or 3

local function safeGet(key)
	local ok, data = pcall(function() return STORE:GetAsync(key) end)
	if not ok then warn("DataStore Get failed:", data) end
	return ok and data or nil
end

local function safeSet(key, value)
	local ok, err = pcall(function() STORE:SetAsync(key, value) end)
	if not ok then warn("DataStore Set failed:", err) end
	return ok
end

local function playerKey(userId) return "u_"..tostring(userId) end

-- Resolve the Ninja HumanoidDescription from either ReplicatedStorage (HD) or ServerStorage (Model)
local function resolveNinjaHD()
       -- Preferred: client-visible HumanoidDescription folder is "HumanoidDescriptions".
       -- Some older content used the singular name; fall back for compatibility.
       local rFolder = ReplicatedStorage:FindFirstChild("HumanoidDescriptions")
               or ReplicatedStorage:FindFirstChild("HumanoidDescription")
       local hd = rFolder and rFolder:FindFirstChild("Ninja")
       if hd and hd:IsA("HumanoidDescription") then return hd end

       -- Fallback: server-only model of the ninja
       local sFolder = ServerStorage:FindFirstChild("HumanoidDescription") or ServerStorage:FindFirstChild("HumanoidDescriptions")
       local ninModel = sFolder and sFolder:FindFirstChild("Ninja")
       if ninModel then
               local hum = ninModel:FindFirstChildOfClass("Humanoid")
               if hum then
                       local ok, desc = pcall(function() return hum:GetAppliedDescription() end)
                       if ok and desc then
                               -- Replicate to ReplicatedStorage so clients can render the ninja immediately.
                               local target = ReplicatedStorage:FindFirstChild("HumanoidDescriptions")
                               if not target then
                                       target = Instance.new("Folder")
                                       target.Name = "HumanoidDescriptions" -- expected plural folder
                                       target.Parent = ReplicatedStorage
                               end
                               if not target:FindFirstChild("Ninja") then
                                       local clone = desc:Clone()
                                       clone.Name = "Ninja"
                                       clone.Parent = target
                               end
                               return desc
                       end
               end
       end
       return nil
end

-- Preload the description so it's replicated before any players join.
resolveNinjaHD()

-- Apply selected persona whenever the character loads (safely idempotent)
local function onCharacterAppearance(player, character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local personaType = player:GetAttribute("PersonaType") or "Roblox"
	if personaType == "Ninja" then
		local hd = resolveNinjaHD()
		if hd then
			-- Re-apply is harmless; ensures joins/respawns keep the chosen look
			humanoid:ApplyDescription(hd)
		else
			warn("[PersonaService] Ninja description not found. Add ReplicatedStorage/HumanoidDescriptions/Ninja (HumanoidDescription)\n"
				.."or a model at ServerStorage/HumanoidDescription(s)/Ninja with a Humanoid.")
		end
	end
	-- Roblox avatar: nothing to do.
end

Players.PlayerAdded:Connect(function(player)
	-- default attribute; UI will set this via RF "use"
	player:SetAttribute("PersonaType", "Roblox")
	player.CharacterAppearanceLoaded:Connect(function(character)
		onCharacterAppearance(player, character)
	end)
end)

--  "get" -> returns {slots=[1..n], slotCount}
--  "save", data = {slot=int, type="Roblox"|"Ninja", name=string}
--  "use",  data = {slot=int}  (sets player attribute and returns the chosen persona or nil)
rf.OnServerInvoke = function(player, action, data)
        local key = playerKey(player.UserId)

        -- DataStore arrays lose entries beyond the first nil index. Store as a dictionary
        -- with string keys and rebuild a numeric array locally to preserve holes.
        local raw = safeGet(key) or {}
        local personas = {}
        for k, v in pairs(raw) do
                local idx = tonumber(k)
                if idx and idx >= 1 and idx <= MAX_SLOTS then
                        personas[idx] = v
                end
        end

        local function persist()
                local toSave = {}
                for i = 1, MAX_SLOTS do
                        if personas[i] ~= nil then
                                toSave[tostring(i)] = personas[i]
                        end
                end
                safeSet(key, toSave)
        end

        if action == "get" then
                return { slots = personas, slotCount = MAX_SLOTS }

       elseif action == "save" then
               local s = data and tonumber(data.slot)
               local t = data and tostring(data.type or "")
               local n = data and tostring(data.name or "")
               if not (s and s >= 1 and s <= MAX_SLOTS) then return {ok=false, err="bad slot"} end
               if t ~= "Roblox" and t ~= "Ninja" then return {ok=false, err="bad type"} end

               personas[s] = personas[s] or {inventory = {}, unlockedRealms = {}}
               personas[s].type = t
               personas[s].name = (#n > 0 and n) or (t == "Ninja" and "Starter Ninja" or "My Avatar")
               if data.inventory then personas[s].inventory = data.inventory end
               if data.unlockedRealms or data.realms then
                       personas[s].unlockedRealms = data.unlockedRealms or data.realms
               end
               persist()
               return {ok=true, slots = personas}

       elseif action == "use" then
               local s = data and tonumber(data.slot)
               if not (s and s >= 1 and s <= MAX_SLOTS) then return {ok=false, err="bad slot"} end
               local p = personas[s]
               if not p then return {ok=false, err="empty slot"} end

               player:SetAttribute("PersonaType", p.type)
               player:SetAttribute("PersonaSlot", s)
               p.inventory = p.inventory or {}
               p.unlockedRealms = p.unlockedRealms or {}
               return {ok=true, persona=p}

        elseif action == "clear" then
                local s = data and tonumber(data.slot)
                if not (s and s >= 1 and s <= MAX_SLOTS) then return {ok=false, err="bad slot"} end
                personas[s] = nil
                persist()
                return {ok=true, slots=personas}
        end

	return {ok=false, err="unknown action"}
end
