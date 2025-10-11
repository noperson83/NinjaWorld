local IntroCamera = {}
IntroCamera.__index = IntroCamera

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local DEFAULT_FALLBACK_FOCUS = Vector3.new(0, 6, 0)
local DEFAULT_FALLBACK_START_OFFSET = Vector3.new(0, 7, -28)
local DEFAULT_FALLBACK_END_OFFSET = Vector3.new(0, 5, -18)
local DEFAULT_FALLBACK_UP = Vector3.new(0, 1, 0)
local DEFAULT_FALLBACK_START_FOV = 55
local DEFAULT_FALLBACK_END_FOV = 60

function IntroCamera.new(options)
        options = options or {}

        local self = setmetatable({}, IntroCamera)

        self._workspace = options.workspace or Workspace
        self._tweenService = options.tweenService or TweenService
        self._runService = options.runService or RunService

        self._startName = options.startPartName or "startPos"
        self._endName = options.endPartName or "endPos"
        self._folderName = options.folderName or "Cameras"
        self._cameraWait = options.cameraWait or 5
        self._holdPriority = (options.holdPriority or Enum.RenderPriority.Camera.Value) + 1

        self._connections = {}
        self._folderConnections = {}
        self._pendingReadyCallbacks = {}

        self._cameraFolder = nil
        self.startPart = nil
        self.endPart = nil

        self._camera = options.camera
        self._fallbackFocusPoint = options.fallbackFocusPoint
        self._fallbackStartOffset = options.fallbackStartOffset
        self._fallbackEndOffset = options.fallbackEndOffset
        self._fallbackUpVector = options.fallbackUpVector
        self._fallbackStartCFrame = options.fallbackStartCFrame
        self._fallbackEndCFrame = options.fallbackEndCFrame
        self._fallbackStartFOV = options.fallbackStartFOV
        self._fallbackEndFOV = options.fallbackEndFOV
        self._fallbackParts = nil

        self._holdKey = nil
        self._holdCameraConn = nil
        self._holdDeadline = nil
        self._focusProvider = nil

        self:_refreshCameraFolder()
        self:_refreshParts()
        self:_startListeners()

        return self
end

function IntroCamera:destroy()
        self:releaseHold()
        for _, conn in ipairs(self._connections) do
                conn:Disconnect()
        end
        self._connections = {}

        self:_disconnectFolderListeners()
        self._pendingReadyCallbacks = {}
        self._focusProvider = nil

        self:_destroyFallbackParts()
end

function IntroCamera:getCurrentCamera()
        local current = self._workspace.CurrentCamera
        if current then
                self._camera = current
        end
        return self._camera
end

function IntroCamera:waitForCamera(timeout)
        local deadline = os.clock() + (timeout or self._cameraWait or 5)
        repeat
                local camera = self:getCurrentCamera()
                if camera then
                        return camera
                end
                task.wait(0.05)
        until os.clock() >= deadline

        warn("IntroCamera: Unable to resolve CurrentCamera before intro sequence")
        return self:getCurrentCamera()
end

function IntroCamera:waitForParts(timeout, requireEnd)
        local deadline = os.clock() + (timeout or self._cameraWait or 5)
        repeat
                local startPart, endPart = self:_refreshParts()
                if startPart and (not requireEnd or endPart) then
                        return startPart, endPart
                end
                task.wait(0.05)
        until os.clock() >= deadline

        return self.startPart, self.endPart
end

function IntroCamera:applyStartCamera()
        local camera = self:waitForCamera()
        if not camera then
                return false
        end

        local startPart = self.startPart or select(1, self:waitForParts(nil, false))
        if not startPart and not self._focusProvider then
                return false
        end

        camera.CameraType = Enum.CameraType.Scriptable
        return self:_applyCameraFrame(camera, startPart)
end

function IntroCamera:holdStartCamera(duration)
        local camera = self:getCurrentCamera() or self:waitForCamera()
        if not camera then
                return false
        end

        local startPart = self.startPart or select(1, self:waitForParts(nil, false))
        if not startPart and not self._focusProvider then
                warn("IntroCamera: Unable to hold start camera because start part is missing")
                return false
        end

        self:applyStartCamera()

        duration = duration or math.huge
        if duration <= 0 then
                return true
        end

        self:_unbindHold()

        if duration == math.huge then
                self._holdDeadline = nil
        else
                self._holdDeadline = os.clock() + duration
        end

        local key = self._holdKey or "IntroCameraHold"
        self._holdKey = key

        self._runService:BindToRenderStep(key, self._holdPriority, function()
                self._camera = self._workspace.CurrentCamera or self._camera
                local currentCamera = self._camera
                if currentCamera then
                        currentCamera.CameraType = Enum.CameraType.Scriptable
                        local activeStart = (self.startPart and self.startPart.Parent) and self.startPart or nil
                        self:_applyCameraFrame(currentCamera, activeStart)
                end
                if self._holdDeadline and os.clock() >= self._holdDeadline then
                        self:_unbindHold()
                end
        end)

        if self._holdCameraConn then
                self._holdCameraConn:Disconnect()
                self._holdCameraConn = nil
        end
        self._holdCameraConn = self._workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
                self._camera = self._workspace.CurrentCamera or self._camera
                local currentCamera = self._camera
                if currentCamera then
                        currentCamera.CameraType = Enum.CameraType.Scriptable
                        local activeStart = (self.startPart and self.startPart.Parent) and self.startPart or nil
                        self:_applyCameraFrame(currentCamera, activeStart)
                end
        end)

        return true
end

function IntroCamera:tweenToEnd(duration, easingStyle, easingDirection)
        self:releaseHold()
        local camera = self:waitForCamera()
        if not camera then
                return false
        end

        local endPart = self.endPart or select(2, self:waitForParts(nil, true))
        if not endPart then
                warn("IntroCamera: Unable to tween to end camera because end part is missing")
                return false
        end

        local tweenInfo = TweenInfo.new(duration or 1.6, easingStyle or Enum.EasingStyle.Quad, easingDirection or Enum.EasingDirection.Out)
        local tween = self._tweenService:Create(camera, tweenInfo, {
                CFrame = self:_faceCFrame(endPart),
                FieldOfView = self:_partFOV(endPart, camera),
        })
        tween:Play()
        return true, tween
end

function IntroCamera:onReady(callback)
        if typeof(callback) ~= "function" then
                return function() end
        end

        if self.startPart then
                task.defer(callback, self.startPart, self.endPart)
                return function() end
        end

        table.insert(self._pendingReadyCallbacks, callback)
        local active = true
        return function()
                if not active then
                        return
                end
                active = false
                for index, fn in ipairs(self._pendingReadyCallbacks) do
                        if fn == callback then
                                table.remove(self._pendingReadyCallbacks, index)
                                break
                        end
                end
        end
end

function IntroCamera:_startListeners()
        table.insert(self._connections, self._workspace.DescendantAdded:Connect(function(descendant)
                if not descendant then
                        return
                end

                if descendant.Name == self._folderName then
                        self:_refreshCameraFolder(true)
                        self:_refreshParts()
                        return
                end

                if descendant.Name ~= self._startName and descendant.Name ~= self._endName then
                        return
                end

                if not self._cameraFolder or descendant:IsDescendantOf(self._cameraFolder) then
                        self:_refreshParts()
                end
        end))

        table.insert(self._connections, self._workspace.DescendantRemoving:Connect(function(descendant)
                if not descendant then
                        return
                end

                local withinFolder = self._cameraFolder and descendant:IsDescendantOf(self._cameraFolder)
                local isTrackedPart = descendant == self.startPart or descendant == self.endPart

                if descendant == self._cameraFolder or withinFolder or isTrackedPart then
                        if descendant == self._cameraFolder then
                                self._cameraFolder = nil
                                self:_disconnectFolderListeners()
                        end
                        self:_refreshParts()
                end
        end))
end

function IntroCamera:_refreshCameraFolder(force)
        local folder = self._cameraFolder
        if not force and folder and folder.Parent then
                return folder
        end

        local function folderHasCameraParts(candidate)
                if not candidate then
                        return false
                end

                if self:_findPart(candidate, self._startName) then
                        return true
                end

                if self:_findPart(candidate, self._endName) then
                        return true
                end

                return false
        end

        local function findFolder()
                local direct = self._workspace:FindFirstChild(self._folderName)
                if folderHasCameraParts(direct) then
                        return direct
                end

                local fallback = direct
                for _, descendant in ipairs(self._workspace:GetDescendants()) do
                        if descendant.Name == self._folderName then
                                if folderHasCameraParts(descendant) then
                                        return descendant
                                end
                                if not fallback then
                                        fallback = descendant
                                end
                        end
                end

                return fallback
        end

        folder = findFolder()
        if folder then
                self._cameraFolder = folder
                self:_connectFolderListeners(folder)
                return folder
        end

        self._cameraFolder = nil
        return nil
end

function IntroCamera:_connectFolderListeners(folder)
        self:_disconnectFolderListeners()

        if not folder then
                return
        end

        table.insert(self._folderConnections, folder.DescendantAdded:Connect(function(child)
                if child and (child.Name == self._startName or child.Name == self._endName) then
                        self:_refreshParts()
                end
        end))

        table.insert(self._folderConnections, folder.DescendantRemoving:Connect(function(child)
                if child and (child == self.startPart or child == self.endPart) then
                        self:_refreshParts()
                end
        end))
end

function IntroCamera:_disconnectFolderListeners()
        for _, conn in ipairs(self._folderConnections) do
                conn:Disconnect()
        end
        self._folderConnections = {}
end

function IntroCamera:_refreshParts()
        local folder = self:_refreshCameraFolder()

        local newStart = self:_findPart(folder, self._startName)
        local newEnd = self:_findPart(folder, self._endName)

        local startIsFallback = self:_isFallbackPart(newStart)
        local endIsFallback = self:_isFallbackPart(newEnd)

        if not newStart or startIsFallback then
                local fallbackStart, fallbackEnd = self:_ensureFallbackParts()
                if fallbackStart then
                        newStart = fallbackStart
                        startIsFallback = true
                end
                if (not newEnd or endIsFallback) and fallbackEnd then
                        newEnd = fallbackEnd
                        endIsFallback = true
                end
        elseif not newEnd or endIsFallback then
                local _, fallbackEnd = self:_ensureFallbackParts()
                if fallbackEnd then
                        newEnd = fallbackEnd
                        endIsFallback = true
                end
        end

        if not startIsFallback and not endIsFallback then
                self:_releaseFallbackPartsIfUnused(newStart, newEnd)
        end

        local startChanged = newStart ~= self.startPart
        local endChanged = newEnd ~= self.endPart

        self.startPart = newStart
        self.endPart = newEnd

        if startChanged or endChanged then
                self:_reportCameraStatus(startChanged, endChanged)
                if self.startPart then
                        self:_flushReadyCallbacks(self.startPart, self.endPart)
                end
        end

        return self.startPart, self.endPart
end

function IntroCamera:_ensureFallbackParts()
        local startCamera = self:_getFallbackPart("start")
        local endCamera = self:_getFallbackPart("end")
        return startCamera, endCamera
end

function IntroCamera:_releaseFallbackPartsIfUnused(currentStart, currentEnd)
        if not self._fallbackParts then
                return
        end

        if self:_isFallbackPart(currentStart) or self:_isFallbackPart(currentEnd) then
                return
        end

        self:_destroyFallbackParts()
end

function IntroCamera:_destroyFallbackParts()
        if not self._fallbackParts then
                return
        end

        for key, part in pairs(self._fallbackParts) do
                if part then
                        part:Destroy()
                end
                self._fallbackParts[key] = nil
        end

        self._fallbackParts = nil
end

function IntroCamera:_isFallbackPart(part)
        if not part or not self._fallbackParts then
                return false
        end

        for _, candidate in pairs(self._fallbackParts) do
                if candidate == part then
                        return true
                end
        end

        return false
end

function IntroCamera:_getFallbackPart(which)
        self._fallbackParts = self._fallbackParts or {}

        local key = which == "end" and "end" or "start"
        local existing = self._fallbackParts[key]

        if not (existing and existing.Parent == nil and existing:IsA("Camera")) then
                if existing then
                        existing:Destroy()
                end

                existing = Instance.new("Camera")
                existing.Name = string.format("%sFallback", key)
                existing.Archivable = false
                existing.Parent = nil
                self._fallbackParts[key] = existing
        end

        existing.CFrame = self:_computeFallbackCFrame(key)
        local fallbackFOV = self:_getFallbackFOV(key)
        if fallbackFOV then
                existing.FieldOfView = fallbackFOV
        end

        return existing
end

function IntroCamera:_computeFallbackCFrame(which)
        if which == "start" and self._fallbackStartCFrame then
                return self._fallbackStartCFrame
        elseif which == "end" and self._fallbackEndCFrame then
                return self._fallbackEndCFrame
        end

        local focus = self._fallbackFocusPoint or DEFAULT_FALLBACK_FOCUS
        local up = self._fallbackUpVector or DEFAULT_FALLBACK_UP
        local offset

        if which == "start" then
                offset = self._fallbackStartOffset or DEFAULT_FALLBACK_START_OFFSET
        else
                offset = self._fallbackEndOffset or DEFAULT_FALLBACK_END_OFFSET
        end

        return CFrame.lookAt(focus + offset, focus, up)
end

function IntroCamera:_getFallbackFOV(which)
        if which == "start" then
                return self._fallbackStartFOV or DEFAULT_FALLBACK_START_FOV
        end

        if which == "end" then
                return self._fallbackEndFOV or DEFAULT_FALLBACK_END_FOV
        end

        return DEFAULT_FALLBACK_START_FOV
end

function IntroCamera:_reportCameraStatus(startChanged, endChanged)
        local messages = {}

        local function partLabel(part)
                if not part then
                        return nil
                end

                if typeof(part) == "Instance" then
                        local ok, fullName = pcall(function()
                                return part:GetFullName()
                        end)
                        if ok then
                                return fullName
                        end
                        return part.Name
                end

                return tostring(part)
        end

        if startChanged then
                local label = partLabel(self.startPart)
                if label then
                        table.insert(messages, string.format("start camera loaded: %s", label))
                else
                        table.insert(messages, "start camera removed")
                end
        end

        if endChanged then
                local label = partLabel(self.endPart)
                if label then
                        table.insert(messages, string.format("end camera loaded: %s", label))
                else
                        table.insert(messages, "end camera removed")
                end
        end

        if #messages > 0 then
                print(string.format("[IntroCamera] %s", table.concat(messages, "; ")))
        end
end

function IntroCamera:_flushReadyCallbacks(startPart, endPart)
        if #self._pendingReadyCallbacks == 0 then
                return
        end

        local callbacks = self._pendingReadyCallbacks
        self._pendingReadyCallbacks = {}
        for _, callback in ipairs(callbacks) do
                task.defer(callback, startPart, endPart)
        end
end

function IntroCamera:_findPart(container, name)
        local function resolve(from)
                if not from then
                        return nil
                end

                local part = from:FindFirstChild(name)
                if not part then
                        part = from:FindFirstChild(name, true)
                end

                if part and (part:IsA("BasePart") or part:IsA("Camera")) then
                        return part
                end

                return nil
        end

        local part = resolve(container)
        if part then
                return part
        end

        if container ~= self._workspace then
                return resolve(self._workspace)
        end

        return nil
end

function IntroCamera:_partAttr(part, name, default)
        if not part then
                return default
        end
        local value = part:GetAttribute(name)
        if typeof(value) == "number" then
                return value
        end
        return default
end

function IntroCamera:_faceCFrame(part)
	if not part then
		local camera = self:getCurrentCamera()
		return camera and camera.CFrame or CFrame.new()
	end

	if part:IsA("Camera") then
		return part.CFrame
	end

	local forward = part.CFrame.LookVector
	local up = part.CFrame.UpVector
	local dist = self:_partAttr(part, "Dist", 0)
	local height = self:_partAttr(part, "Height", 0)
	local ahead = self:_partAttr(part, "Ahead", 10)
	local position = part.Position - forward * dist + up * height
	local target = part.Position + forward * ahead
	return CFrame.lookAt(position, target, up)
end

function IntroCamera:_partFOV(part, camera)
        local cam = camera or self:getCurrentCamera()
        local defaultFOV = cam and cam.FieldOfView or 70
        if part and part:IsA("Camera") then
                return part.FieldOfView
        end
        return self:_partAttr(part, "FOV", defaultFOV)
end

function IntroCamera:_resolveCameraFrame(camera, startPart)
        local provider = self._focusProvider
        local providerCFrame
        local providerFOV

        if provider then
                local ok, resultCFrame, resultFOV = pcall(provider, self, camera, startPart)
                if ok then
                        if typeof(resultCFrame) == "CFrame" then
                                providerCFrame = resultCFrame
                        end
                        if typeof(resultFOV) == "number" then
                                providerFOV = resultFOV
                        end
                else
                        warn("IntroCamera focus provider error:", resultCFrame)
                end
        end

        local defaultCFrame
        local defaultFOV = nil

        if startPart and startPart.Parent then
                defaultCFrame = self:_faceCFrame(startPart)
                defaultFOV = self:_partFOV(startPart, camera)
        else
                local cam = camera or self:getCurrentCamera()
                if cam then
                        defaultCFrame = cam.CFrame
                        defaultFOV = cam.FieldOfView
                else
                        defaultCFrame = CFrame.new()
                        defaultFOV = 70
                end
        end

        return providerCFrame or defaultCFrame, providerFOV or defaultFOV
end

function IntroCamera:_applyCameraFrame(camera, startPart)
        if not camera then
                return false
        end

        local cframe, fov = self:_resolveCameraFrame(camera, startPart)
        if cframe then
                camera.CFrame = cframe
        end
        if fov then
                camera.FieldOfView = fov
        end
        return true
end

function IntroCamera:setFocusProvider(provider)
        if provider ~= nil and typeof(provider) ~= "function" then
                error("IntroCamera:setFocusProvider expects a function or nil", 2)
        end

        self._focusProvider = provider
        local camera = self:getCurrentCamera()
        if camera then
                local startPart = (self.startPart and self.startPart.Parent) and self.startPart or nil
                self:_applyCameraFrame(camera, startPart)
        end
end

function IntroCamera:_unbindHold()
        if self._holdKey then
                self._runService:UnbindFromRenderStep(self._holdKey)
                self._holdKey = nil
        end
        if self._holdCameraConn then
                self._holdCameraConn:Disconnect()
                self._holdCameraConn = nil
        end
        self._holdDeadline = nil
end

function IntroCamera:releaseHold()
        local hadHold = self._holdKey ~= nil or self._holdCameraConn ~= nil
        self:_unbindHold()
        return hadHold
end

return IntroCamera

