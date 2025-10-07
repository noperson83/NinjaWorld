local IntroCamera = {}
IntroCamera.__index = IntroCamera

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

function IntroCamera.new(options)
        options = options or {}

        local self = setmetatable({}, IntroCamera)

        self._workspace = options.workspace or Workspace
        self._replicatedStorage = options.replicatedStorage or ReplicatedStorage
        self._tweenService = options.tweenService or TweenService
        self._runService = options.runService or RunService

        self._startName = options.startPartName or "startPos"
        self._endName = options.endPartName or "endPos"
        self._folderName = options.folderName or "Cameras"
        self._fallbackFolderName = options.fallbackFolderName or "PersonaIntroCameraParts"
        self._cameraWait = options.cameraWait or 5
        self._holdPriority = (options.holdPriority or Enum.RenderPriority.Camera.Value) + 1

        self._connections = {}
        self._pendingReadyCallbacks = {}

        self._workspaceFolder = nil
        self._fallbackFolder = nil
        self.startPart = nil
        self.endPart = nil
        self._camera = options.camera
        self._holdKey = nil
        self._holdCameraConn = nil
        self._fallbackPartsConn = nil

        self:_refreshFolders()
        self:_refreshParts()
        self:_startListeners()

        return self
end

function IntroCamera:destroy()
        self:_unbindHold()
        for _, conn in ipairs(self._connections) do
                conn:Disconnect()
        end
        self._connections = {}
        if self._fallbackPartsConn then
                self._fallbackPartsConn:Disconnect()
                self._fallbackPartsConn = nil
        end
        self._pendingReadyCallbacks = {}
end

function IntroCamera:getCurrentCamera()
        local current = self._workspace.CurrentCamera
        if current then
                self._camera = current
                return current
        end

        if self._camera and self._camera.Parent then
                return self._camera
        end

        local fallback = self._workspace:FindFirstChildOfClass("Camera")
        if fallback then
                self._camera = fallback
                return fallback
        end

        return nil
end

function IntroCamera:waitForCamera(timeout)
        local camera = self:getCurrentCamera()
        if camera then
                return camera
        end

        local waitTime = timeout or self._cameraWait or 5
        local ok, found = pcall(function()
                return self._workspace:WaitForChild("Camera", waitTime)
        end)
        if ok and found then
                self._camera = found
                if self._workspace.CurrentCamera ~= found then
                        self._workspace.CurrentCamera = found
                end
                return found
        end

        local deadline = os.clock() + waitTime
        repeat
                task.wait(0.05)
                camera = self:getCurrentCamera()
                if camera then
                        return camera
                end
        until os.clock() >= deadline

        warn("IntroCamera: Unable to resolve CurrentCamera before intro sequence")
        return camera
end

function IntroCamera:waitForParts(timeout, requireEnd)
        self:_refreshParts()
        local startPart = self.startPart
        local endPart = self.endPart
        if startPart and (not requireEnd or endPart) then
                return startPart, endPart
        end

        local deadline = os.clock() + (timeout or self._cameraWait or 5)
        repeat
                task.wait(0.05)
                self:_refreshParts()
                startPart = self.startPart
                endPart = self.endPart
                if startPart and (not requireEnd or endPart) then
                        return startPart, endPart
                end
        until os.clock() >= deadline

        return startPart, endPart
end

function IntroCamera:applyStartCamera()
        local camera = self:waitForCamera()
        if not camera then
                return false
        end

        local startPart = self.startPart or select(1, self:waitForParts(nil, false))
        if not startPart then
                return false
        end

        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = self:_faceCFrame(startPart)
        camera.FieldOfView = self:_partFOV(startPart, camera)
        return true
end

function IntroCamera:holdStartCamera(duration)
        local camera = self:getCurrentCamera() or self:waitForCamera()
        if not camera then
                return false
        end

        local startPart = self.startPart or select(1, self:waitForParts(nil, false))
        if not startPart then
                warn("IntroCamera: Unable to hold start camera because start part is missing")
                return false
        end

        self:applyStartCamera()

        duration = duration or 0.3
        if duration <= 0 then
                return true
        end

        self:_unbindHold()

        local key = self._holdKey or "IntroCameraHold"
        self._holdKey = key
        local deadline = os.clock() + duration

        self._runService:BindToRenderStep(key, self._holdPriority, function()
                self._camera = self._workspace.CurrentCamera or self._camera
                if not (self.startPart and self.startPart.Parent) then
                        self:_refreshParts()
                end
                if self.startPart then
                        self:applyStartCamera()
                else
                        self._runService:UnbindFromRenderStep(key)
                        self._holdKey = nil
                end
                if os.clock() >= deadline then
                        self._runService:UnbindFromRenderStep(key)
                        self._holdKey = nil
                end
        end)

        if self._holdCameraConn then
                        self._holdCameraConn:Disconnect()
                        self._holdCameraConn = nil
        end
        self._holdCameraConn = self._workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
                self._camera = self._workspace.CurrentCamera or self._camera
                if self.startPart then
                        self:applyStartCamera()
                end
        end)

        return true
end

function IntroCamera:tweenToEnd(duration, easingStyle, easingDirection)
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

function IntroCamera:_refreshFolders()
        self:_resolveWorkspaceFolder()
        self:_resolveFallbackFolder()
end

function IntroCamera:_startListeners()
        table.insert(self._connections, self._workspace.DescendantAdded:Connect(function(inst)
                if not inst then
                        return
                end
                if inst.Name == self._folderName then
                        self._workspaceFolder = inst
                        self:_refreshParts()
                        return
                end
                if inst.Name == self._startName or inst.Name == self._endName then
                        if self:_isInCameraFolder(inst) then
                                self:_refreshParts()
                        end
                end
        end))

        table.insert(self._connections, self._workspace.DescendantRemoving:Connect(function(inst)
                if inst == self._workspaceFolder then
                        self._workspaceFolder = nil
                        task.defer(function()
                                self:_refreshParts()
                        end)
                        return
                end

                if inst == self.startPart or inst == self.endPart then
                        task.defer(function()
                                self:_refreshParts()
                        end)
                end
        end))

        table.insert(self._connections, self._replicatedStorage.ChildAdded:Connect(function(child)
                if child and child.Name == self._fallbackFolderName then
                        self._fallbackFolder = child
                        self:_connectFallbackListener(child)
                        self:_refreshParts()
                end
        end))

        local fallback = self:_resolveFallbackFolder()
        if fallback then
                self:_connectFallbackListener(fallback)
        end
end

function IntroCamera:_connectFallbackListener(folder)
        if self._fallbackPartsConn then
                self._fallbackPartsConn:Disconnect()
                self._fallbackPartsConn = nil
        end

        if folder then
                self._fallbackPartsConn = folder.ChildAdded:Connect(function(child)
                        if child and (child.Name == self._startName or child.Name == self._endName) then
                                self:_refreshParts()
                        end
                end)
        end
end

function IntroCamera:_resolveWorkspaceFolder()
        local folder = self._workspaceFolder
        if folder and folder.Parent then
                        return folder
        end

        local direct = self._workspace:FindFirstChild(self._folderName)
        if direct and direct.Parent then
                self._workspaceFolder = direct
                return direct
        end

        local descendant = self._workspace:FindFirstChild(self._folderName, true)
        if descendant and descendant.Parent then
                self._workspaceFolder = descendant
                return descendant
        end

        return nil
end

function IntroCamera:_resolveFallbackFolder()
        local folder = self._fallbackFolder
        if folder and folder.Parent then
                return folder
        end

        folder = self._replicatedStorage:FindFirstChild(self._fallbackFolderName)
        if folder then
                self._fallbackFolder = folder
                self:_connectFallbackListener(folder)
                return folder
        end

        return nil
end

function IntroCamera:_isInCameraFolder(inst)
        local folder = self:_resolveWorkspaceFolder()
        if not folder then
                return false
        end
        return inst == folder or inst:IsDescendantOf(folder)
end

function IntroCamera:_refreshParts()
        local workspaceFolder = self:_resolveWorkspaceFolder()
        local fallbackFolder = self:_resolveFallbackFolder()

        local newStart = self:_findPart(workspaceFolder, self._startName) or self:_findPart(fallbackFolder, self._startName)
        local newEnd = self:_findPart(workspaceFolder, self._endName) or self:_findPart(fallbackFolder, self._endName)

        local startChanged = newStart ~= self.startPart
        local endChanged = newEnd ~= self.endPart

        self.startPart = newStart
        self.endPart = newEnd

        if startChanged or endChanged then
                if self.startPart then
                        self:_flushReadyCallbacks(self.startPart, self.endPart)
                end
        end

        return self.startPart, self.endPart
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
        if not container then
                return nil
        end

        local direct = container:FindFirstChild(name)
        if direct and direct:IsA("BasePart") then
                return direct
        end

        local descendant = container:FindFirstChild(name, true)
        if descendant and descendant:IsA("BasePart") then
                return descendant
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
        return self:_partAttr(part, "FOV", defaultFOV)
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
end

return IntroCamera
