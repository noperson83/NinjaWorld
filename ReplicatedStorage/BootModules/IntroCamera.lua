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
        self._cameraWait = options.cameraWait or 5
        self._holdPriority = (options.holdPriority or Enum.RenderPriority.Camera.Value) + 1

        self._connections = {}
        self._folderConnections = {}
        self._pendingReadyCallbacks = {}

        self._cameraFolder = nil
        self.startPart = nil
        self.endPart = nil

        self._camera = options.camera
        self._holdKey = nil
        self._holdCameraConn = nil
        self._holdDeadline = nil

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
                if self.startPart and self.startPart.Parent then
                        self:applyStartCamera()
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
                if self.startPart then
                        self:applyStartCamera()
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
        table.insert(self._connections, self._workspace.ChildAdded:Connect(function(child)
                if child and child.Name == self._folderName then
                        self:_refreshCameraFolder()
                        self:_refreshParts()
                end
        end))

        table.insert(self._connections, self._workspace.ChildRemoved:Connect(function(child)
                if child == self._cameraFolder then
                        self._cameraFolder = nil
                        self:_disconnectFolderListeners()
                        self:_refreshParts()
                end
        end))
end

function IntroCamera:_refreshCameraFolder()
        local folder = self._cameraFolder
        if folder and folder.Parent then
                return folder
        end

        folder = self._workspace:FindFirstChild(self._folderName)
        if folder then
                self._cameraFolder = folder
                self:_connectFolderListeners(folder)
                return folder
        end

        return nil
end

function IntroCamera:_connectFolderListeners(folder)
        self:_disconnectFolderListeners()

        if not folder then
                return
        end

        table.insert(self._folderConnections, folder.ChildAdded:Connect(function(child)
                if child and (child.Name == self._startName or child.Name == self._endName) then
                        self:_refreshParts()
                end
        end))

        table.insert(self._folderConnections, folder.ChildRemoved:Connect(function(child)
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

        local part = container:FindFirstChild(name)
        if part and part:IsA("BasePart") then
                return part
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
        self._holdDeadline = nil
end

function IntroCamera:releaseHold()
        local hadHold = self._holdKey ~= nil or self._holdCameraConn ~= nil
        self:_unbindHold()
        return hadHold
end

return IntroCamera

