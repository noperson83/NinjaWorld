-- Ninja World EXP 3000 
-- Init.server.lua — persona-controlled spawning (v4)
-- Put this in **ServerScriptService** and REMOVE any older DojoSpawn.server.lua to avoid conflicts.
-- What it does:
--   • Disables automatic spawning (CharacterAutoLoads=false) so NOTHING spawns before persona is chosen
--   • Ensures ReplicatedStorage.EnterDojoRE is a RemoteEvent
--   • On EnterDojoRE: spawns with the chosen persona
--         - Ninja: **prefer a full MODEL** at ServerStorage/HumanoidDescription(s)/Ninja (clone as character)
--                  fallback to HumanoidDescription if present
--         - Roblox: default LoadCharacter()
--   • After spawn: drops player on a spawn pad and faces them toward Cameras.endPos
--   • Ensures the cloned Ninja has a working **Animate (LocalScript)** and an **Animator** so it isn't stiff

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Workspace         = game:GetService("Workspace")
local StarterPlayer     = game:GetService("StarterPlayer")

local CAMERA_FOLDER_NAME = "Cameras"
local CAMERA_START_NAME = "startPos"
local CAMERA_END_NAME = "endPos"

local cachedCameraFolder

-- 1) Do NOT auto-spawn. We will only spawn after the client says "Enter This Dojo".
Players.CharacterAutoLoads = false

-- 2) Ensure RemoteEvent exists and is the right class
local EnterDojoRE = ReplicatedStorage:FindFirstChild("EnterDojoRE")
if EnterDojoRE and not EnterDojoRE:IsA("RemoteEvent") then
	warn("[Init] EnterDojoRE existed as " .. EnterDojoRE.ClassName .. ", replacing with RemoteEvent")
	EnterDojoRE:Destroy()
	EnterDojoRE = nil
end
if not EnterDojoRE then
	EnterDojoRE = Instance.new("RemoteEvent")
	EnterDojoRE.Name = "EnterDojoRE"
	EnterDojoRE.Parent = ReplicatedStorage
	print("[Init] Created ReplicatedStorage.EnterDojoRE")
end

-- 3) Helpers to find spawn and a facing direction
local function firstSpawnFrom(container)
        for _, child in ipairs(container:GetChildren()) do
                if child:IsA("SpawnLocation") or child:IsA("BasePart") then
                        return child
                end

                if child:IsA("Model") then
                        local primary = child.PrimaryPart
                        if primary and primary:IsA("BasePart") then
                                return primary
                        end

                        for _, desc in ipairs(child:GetDescendants()) do
                                if desc:IsA("BasePart") then
                                        return desc
                                end
                        end
                end

                local nested = firstSpawnFrom(child)
                if nested then
                        return nested
                end
        end
        return nil
end

local function findSpawn()
        -- Preferred: a spawn defined under Workspace.SpawnLocations
        local spawnFolder = Workspace:FindFirstChild("SpawnLocations")
        if spawnFolder then
                local fromFolder = firstSpawnFrom(spawnFolder)
                if fromFolder then
                        return fromFolder
                end
        end

        -- Legacy fallbacks
        local named = Workspace:FindFirstChild("DojoSpawn", true)
        if named and named:IsA("BasePart") then return named end

        for _,d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("SpawnLocation") then return d end
        end

        for _,d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("BasePart") and d.Name == "SpawnLocation" then return d end
        end

        return nil
end

local function findCameraPart(container, name)
        if not container then
                return nil
        end

        local direct = container:FindFirstChild(name)
        if direct and (direct:IsA("BasePart") or direct:IsA("Camera")) then
                return direct
        end

        local descendant = container:FindFirstChild(name, true)
        if descendant and (descendant:IsA("BasePart") or descendant:IsA("Camera")) then
                return descendant
        end

        return nil
end

local function cameraFolderHasParts(container)
        if not container then
                return false
        end

        if findCameraPart(container, CAMERA_START_NAME) then
                return true
        end

        if findCameraPart(container, CAMERA_END_NAME) then
                return true
        end

        return false
end

local function resolveCameraFolder()
        if cachedCameraFolder then
                if cachedCameraFolder.Parent and cameraFolderHasParts(cachedCameraFolder) then
                        return cachedCameraFolder
                end
                cachedCameraFolder = nil
        end

        local function pickFolder()
                local direct = Workspace:FindFirstChild(CAMERA_FOLDER_NAME)
                if direct and cameraFolderHasParts(direct) then
                        cachedCameraFolder = direct
                        return direct
                end

                local fallback = direct
                for _, descendant in ipairs(Workspace:GetDescendants()) do
                        if descendant.Name == CAMERA_FOLDER_NAME then
                                if cameraFolderHasParts(descendant) then
                                        cachedCameraFolder = descendant
                                        return descendant
                                end
                                if not fallback then
                                        fallback = descendant
                                end
                        end
                end

                return fallback
        end

        local folder = pickFolder()
        if folder then
                cachedCameraFolder = folder
                return folder
        end

        local deadline = os.clock() + 5
        local found
        local conn
        conn = Workspace.DescendantAdded:Connect(function(inst)
                if not inst then
                        return
                end

                if inst.Name == CAMERA_FOLDER_NAME or inst.Name == CAMERA_START_NAME or inst.Name == CAMERA_END_NAME then
                        local candidate = pickFolder()
                        if candidate then
                                cachedCameraFolder = candidate
                                found = candidate
                        end
                end
        end)

        repeat
                if found then
                        break
                end
                task.wait(0.1)
                local candidate = pickFolder()
                if candidate then
                        cachedCameraFolder = candidate
                        found = candidate
                        break
                end
        until os.clock() >= deadline

        if conn then
                conn:Disconnect()
        end

        return found
end

local function getEndFacing()
        local folder = resolveCameraFolder()
        local endPart = findCameraPart(folder, CAMERA_END_NAME) or findCameraPart(Workspace, CAMERA_END_NAME)
        local targetPart = endPart or findCameraPart(folder, CAMERA_START_NAME) or findCameraPart(Workspace, CAMERA_START_NAME)
        if targetPart and (targetPart:IsA("BasePart") or targetPart:IsA("Camera")) then
                return -targetPart.CFrame.LookVector
        end
        return Vector3.new(0, 0, 1)
end

-- Optional: a HumanoidDescription for Ninja (for fallback if there's no model)
local function getNinjaDescription()
        -- Preferred: ReplicatedStorage/HumanoidDescriptions contains client-visible assets.
        -- Fall back to singular name for legacy content.
        local rFolder = ReplicatedStorage:FindFirstChild("HumanoidDescriptions")
                or ReplicatedStorage:FindFirstChild("HumanoidDescription")
        local hd = rFolder and rFolder:FindFirstChild("Ninja")
        if hd and hd:IsA("HumanoidDescription") then return hd end
        -- try deriving from a model in ServerStorage if present
        local sFolder = ServerStorage:FindFirstChild("HumanoidDescription") or ServerStorage:FindFirstChild("HumanoidDescriptions")
	local ninModel = sFolder and sFolder:FindFirstChild("Ninja")
	if ninModel then
		local hum = ninModel:FindFirstChildOfClass("Humanoid")
		if hum then
			local ok, desc = pcall(function() return hum:GetAppliedDescription() end)
			if ok and desc then
				print("[Init] Using Ninja description from ServerStorage model")
				return desc
			end
		end
	end
	return nil
end

-- Prefer a full character MODEL for Ninja (lets you use custom MeshParts)
local function getNinjaModel()
	local sFolder = ServerStorage:FindFirstChild("HumanoidDescription") or ServerStorage:FindFirstChild("HumanoidDescriptions")
	local m = sFolder and sFolder:FindFirstChild("Ninja")
	if m and m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") and m:FindFirstChild("HumanoidRootPart") then
		return m
	end
	return nil
end

-- Ensure the character can actually animate
local function ensureAnimateBits(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and not hum:FindFirstChildOfClass("Animator") then
		Instance.new("Animator", hum)
	end

	-- Accept either a LocalScript named "Animate" OR a LocalScript named "AnimateScript"
	local anim = char:FindFirstChild("Animate")
	if not (anim and anim:IsA("LocalScript")) then
		local alt = char:FindFirstChild("AnimateScript")
		if alt and alt:IsA("LocalScript") then
			alt.Name = "Animate"
			anim = alt
		end
	end

	if anim and anim:IsA("LocalScript") then return end

	-- Try to install a default Animate from places you control
	local src = ReplicatedStorage:FindFirstChild("DefaultAnimate")
	if not (src and src:IsA("LocalScript")) then
		local scs = StarterPlayer:FindFirstChild("StarterCharacterScripts")
		src = scs and scs:FindFirstChild("Animate")
	end
	if src and src:IsA("LocalScript") then
		src:Clone().Parent = char
	else
		warn("[Init] No 'Animate' LocalScript found for Ninja. Add one as ReplicatedStorage.DefaultAnimate or StarterPlayer/StarterCharacterScripts/Animate.")
	end
end

local function placeOnSpawn(char)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        local spawnPart = findSpawn()
        if hrp and spawnPart then
                local pos = spawnPart.CFrame.Position + Vector3.new(0,3,0)
                local faceDir = getEndFacing()
                hrp.CFrame = CFrame.lookAt(pos, pos + faceDir, Vector3.new(0,1,0))
                if hum then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
        end
end

local function spawnNinjaModel(plr)
	local template = getNinjaModel()
	if not template then return false end
	local clone = template:Clone()
	clone.Name = plr.Name
	clone.Parent = Workspace
	plr.Character = clone
	ensureAnimateBits(clone)
	-- place after a short tick so parts are ready
	task.defer(function()
		placeOnSpawn(clone)
	end)
	return true
end

local function spawnWithPersona(plr, personaType)
	personaType = personaType or "Roblox"
	local function afterSpawn(char)
		task.spawn(function()
			placeOnSpawn(char)
		end)
	end

	if personaType == "Ninja" then
		-- Prefer full model clone
		if spawnNinjaModel(plr) then return end
		-- Fallback to HumanoidDescription (Roblox avatar body + assets only)
		local ninjaDesc = getNinjaDescription()
		if ninjaDesc then
			local conn; conn = plr.CharacterAdded:Connect(function(char) if conn then conn:Disconnect() end afterSpawn(char) end)
			plr:LoadCharacterWithHumanoidDescription(ninjaDesc)
			return
		end
		warn("[Init] No Ninja model or HumanoidDescription found; using Roblox avatar")
	end

	-- Default: Roblox avatar
	local conn; conn = plr.CharacterAdded:Connect(function(char) if conn then conn:Disconnect() end afterSpawn(char) end)
	plr:LoadCharacter()
end

-- 5) Client tells us when to spawn (payload: {type="Roblox"|"Ninja", slot=number})
EnterDojoRE.OnServerEvent:Connect(function(plr, payload)
	local personaType = "Roblox"
	if typeof(payload) == "table" and payload.type then
		personaType = tostring(payload.type)
	end
	spawnWithPersona(plr, personaType)
end)

-- 6) Do NOT spawn on join. We wait until the client presses Enter.
Players.PlayerAdded:Connect(function(plr)
	-- Intentionally empty. Client will fire EnterDojoRE when ready.
end)