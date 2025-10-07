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
local function findSpawn()
	-- Preferred: a BasePart named DojoSpawn anywhere in the map
	local named = Workspace:FindFirstChild("DojoSpawn", true)
	if named and named:IsA("BasePart") then return named end
	-- Any SpawnLocation
	for _,d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") then return d end
	end
	-- A BasePart called exactly "SpawnLocation"
	for _,d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "SpawnLocation" then return d end
	end
	return nil
end

local function findCamerasFolder()
        local function isCameraContainer(inst)
                return inst and inst.Name == "Cameras"
        end

        local direct = Workspace:FindFirstChild("Cameras")
        if isCameraContainer(direct) then
                return direct
        end

        local descendant = Workspace:FindFirstChild("Cameras", true)
        if isCameraContainer(descendant) then
                return descendant
        end

        local deadline = os.clock() + 5
        local found
        local conn
        conn = Workspace.DescendantAdded:Connect(function(inst)
                if not found and isCameraContainer(inst) then
                        found = inst
                end
        end)

        repeat
                if found then break end
                task.wait(0.1)
                local candidate = Workspace:FindFirstChild("Cameras", true)
                if isCameraContainer(candidate) then
                        found = candidate
                        break
                end
        until os.clock() >= deadline

        if conn then
                conn:Disconnect()
        end

        return found
end

local introCameraFolder = ReplicatedStorage:FindFirstChild("PersonaIntroCameraParts")
if not introCameraFolder then
        introCameraFolder = Instance.new("Folder")
        introCameraFolder.Name = "PersonaIntroCameraParts"
        introCameraFolder.Parent = ReplicatedStorage
end

local function cloneCameraPart(source)
        if not (source and source:IsA("BasePart")) then
                return nil
        end

        local existing = introCameraFolder:FindFirstChild(source.Name)
        if existing then
                existing:Destroy()
        end

        local clone
        local ok, err = pcall(function()
                clone = source:Clone()
        end)

        if not ok or not clone then
                -- Some camera parts (especially the ones provided by Roblox templates)
                -- ship with Archivable=false, which causes :Clone() to error/return nil.
                -- Fall back to manually constructing a simple BasePart that keeps the
                -- important transform/visual data so the client still has something to
                -- drive the intro camera with.
                local className = source.ClassName
                ok, err = pcall(function()
                        clone = Instance.new(className)
                end)

                if not ok or not (clone and clone:IsA("BasePart")) then
                        clone = Instance.new("Part")
                end

                clone.Name = source.Name
                clone.Size = source.Size
                clone.CFrame = source.CFrame
                clone.Color = source.Color
                clone.Material = source.Material
                clone.Transparency = source.Transparency
                clone.Reflectance = source.Reflectance
                clone.CastShadow = source.CastShadow

                if clone:IsA("Part") and source:IsA("Part") then
                        clone.Shape = source.Shape
                elseif clone:IsA("MeshPart") and source:IsA("MeshPart") then
                        clone.MeshId = source.MeshId
                        clone.TextureID = source.TextureID
                        clone.DoubleSided = source.DoubleSided
                end

                for attrName, attrValue in pairs(source:GetAttributes()) do
                        clone:SetAttribute(attrName, attrValue)
                end
        else
                clone.Name = source.Name
        end

        clone.Anchored = true
        clone.CanCollide = false
        clone.Parent = introCameraFolder
        return clone
end

local function findCameraPart(container, name)
        if not container then
                return nil
        end

        local direct = container:FindFirstChild(name)
        if direct and direct:IsA("BasePart") then
                return direct
        end

        for _, descendant in ipairs(container:GetDescendants()) do
                if descendant.Name == name and descendant:IsA("BasePart") then
                        return descendant
                end
        end

        return nil
end

local function ensureFallbackIntroCameraParts()
        local existingStart = introCameraFolder:FindFirstChild("startPos")
        local existingEnd = introCameraFolder:FindFirstChild("endPos")

        if existingStart and existingEnd then
                return false
        end

        local spawnPart = findSpawn()
        local baseCF = spawnPart and spawnPart.CFrame or CFrame.new(0, 0, 0)
        local forward = spawnPart and baseCF.LookVector or Vector3.new(0, 0, -1)
        local right = spawnPart and baseCF.RightVector or Vector3.new(1, 0, 0)
        local up = Vector3.new(0, 1, 0)
        local created = false

        local function createCameraPart(name, position, lookTarget, attributes)
                local direction = lookTarget - position
                local distance = direction.Magnitude
                if distance <= 0.01 then
                        local safeForward = forward
                        if safeForward.Magnitude <= 0.001 then
                                safeForward = Vector3.new(0, 0, -1)
                        end
                        distance = 10
                        direction = safeForward.Unit * distance
                else
                        direction = direction.Unit * distance
                end

                local part = Instance.new("Part")
                part.Name = name
                part.Anchored = true
                part.CanCollide = false
                part.CanQuery = false
                part.CanTouch = false
                part.CastShadow = false
                part.Transparency = 1
                part.Size = Vector3.new(2, 2, 2)
                part.CFrame = CFrame.lookAt(position, position + direction, up)

                part:SetAttribute("Ahead", distance)
                if attributes then
                        for key, value in pairs(attributes) do
                                part:SetAttribute(key, value)
                        end
                end

                part.Parent = introCameraFolder
                return part
        end

        if not existingStart then
                local startPosition = baseCF.Position - forward * 24 + up * 16 + right * 6
                local lookTarget = baseCF.Position + up * 4
                createCameraPart("startPos", startPosition, lookTarget, {
                        FOV = 55,
                })
                created = true
        end

        if not existingEnd then
                local endPosition = baseCF.Position - forward * 10 + up * 8 - right * 3
                local lookTarget = baseCF.Position + forward * 6 + up * 3
                createCameraPart("endPos", endPosition, lookTarget, {
                        FOV = 60,
                })
                created = true
        end

        return created
end

local function syncIntroCameraParts()
        local cams = findCamerasFolder()
        local synced = false
        if cams then
                local startPart = findCameraPart(cams, "startPos")
                if cloneCameraPart(startPart) then
                        synced = true
                end
                local endPart = findCameraPart(cams, "endPos")
                if cloneCameraPart(endPart) then
                        synced = true
                end
        end

        if ensureFallbackIntroCameraParts() then
                synced = true
        end

        return synced
end

task.spawn(function()
        local attempts = 0
        while attempts < 10 do
                if syncIntroCameraParts() then
                        break
                end
                attempts += 1
                task.wait(1)
        end
end)

Workspace.DescendantAdded:Connect(function(inst)
        if not inst then
                return
        end
        if inst.Name == "Cameras" or inst.Name == "startPos" or inst.Name == "endPos" then
                task.defer(syncIntroCameraParts)
        end
end)

local function getEndFacing()
        local cams = findCamerasFolder()
        local endPos = cams and cams:FindFirstChild("endPos")
        if endPos and endPos:IsA("BasePart") then
                -- Camera looks along endPos.LookVector; to face the camera, use the opposite.
                return -endPos.CFrame.LookVector
        end
        return Vector3.new(0,0,1)
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