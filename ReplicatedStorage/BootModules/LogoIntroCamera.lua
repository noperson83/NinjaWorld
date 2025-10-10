local LogoIntroCamera = {}
LogoIntroCamera.__index = LogoIntroCamera

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local DEFAULT_FOLDER_PATH = {"Camera", "ElemLogos"}

local function isNumber(value)
	return typeof(value) == "number"
end

function LogoIntroCamera.new(introCamera, options)
	assert(introCamera, "LogoIntroCamera requires an IntroCamera instance")

	options = options or {}

	local self = setmetatable({}, LogoIntroCamera)

	self._introCamera = introCamera
	self._workspace = options.workspace or Workspace
	self._tweenService = options.tweenService or TweenService
	self._logoFolderPath = options.logoFolderPath or DEFAULT_FOLDER_PATH
	self._maxTargets = options.maxTargets or 10
	self._cycleInterval = options.cycleInterval or 4.5
	self._transitionTime = options.transitionTime or 1.2
	self._defaultDistance = options.defaultDistance or 18
	self._defaultHeight = options.defaultHeight or 3
	self._defaultAhead = options.defaultAhead or 0
	self._defaultFOV = options.defaultFOV or 40
	self._folderWaitTimeout = options.folderWaitTimeout or 10
	self._random = options.random or Random.new()

        self._connections = {}
        self._activeTweens = {}
        self._targets = {}
        self._currentTarget = nil
        self._logoFolder = nil
        self._cycleTask = nil
        self._resumeTask = nil
        self._running = false
        self._paused = false

        self._cframeValue = Instance.new("CFrameValue")
        self._fovValue = Instance.new("NumberValue")
        self._focusCallback = function()
                local cframeValue = self._cframeValue
                local fovValue = self._fovValue

                if not cframeValue then
                        return nil
                end

                if fovValue then
                        return cframeValue.Value, fovValue.Value
                end

                return cframeValue.Value
        end

	local currentCamera = introCamera.getCurrentCamera and introCamera:getCurrentCamera()
	if currentCamera then
		self._cframeValue.Value = currentCamera.CFrame
		self._fovValue.Value = currentCamera.FieldOfView
	else
		self._cframeValue.Value = CFrame.new()
		self._fovValue.Value = self._defaultFOV
	end

	return self
end

function LogoIntroCamera:start()
        if self._running then
                return
        end

        self._running = true
        self._paused = false

        self:_applyFocusProvider()

        task.spawn(function()
                self:_initialize()
        end)
end

function LogoIntroCamera:stop()
        if not self._running then
                return
        end

        self._running = false
        self._paused = false

        self:_cancelCycle()
        self:_cancelResumeTask()

        for _, tween in ipairs(self._activeTweens) do
                tween:Cancel()
        end
        self._activeTweens = {}

        self:_disconnect()

        self:_applyFocusProvider()
end

function LogoIntroCamera:destroy()
        self:stop()

        if self._cframeValue then
                self._cframeValue:Destroy()
		self._cframeValue = nil
	end

	if self._fovValue then
		self._fovValue:Destroy()
		self._fovValue = nil
	end

        self._targets = {}
        self._logoFolder = nil
        self._currentTarget = nil
end

function LogoIntroCamera:pause()
        if not self._running or self._paused then
                return
        end

        self._paused = true
        self:_cancelCycle()
        self:_cancelResumeTask()

        for _, tween in ipairs(self._activeTweens) do
                tween:Cancel()
        end
        self._activeTweens = {}

        self:_applyFocusProvider()
end

function LogoIntroCamera:resume()
        if not self._running or not self._paused then
                return
        end

        self._paused = false
        self:_cancelResumeTask()
        self:_applyFocusProvider()

        if not self._currentTarget or not self:_isValidTarget(self._currentTarget) then
                self:_refreshTargets(true)
        else
                self:_moveToTarget(self._currentTarget, true)
        end
end

function LogoIntroCamera:pauseForReplay(resumeDelay)
        if not self._running then
                return
        end

        self:pause()

        if typeof(resumeDelay) == "number" and resumeDelay > 0 and resumeDelay < math.huge then
                self:_cancelResumeTask()
                self._resumeTask = task.delay(resumeDelay, function()
                        self._resumeTask = nil
                        if self._running then
                                self:resume()
                        end
                end)
        end
end

function LogoIntroCamera:_initialize()
        local folder = self:_resolveLogoFolder()
        if not folder then
                return
        end

        if not self._running then
                return
        end

        self._logoFolder = folder
        self:_connectFolder(folder)
        self:_refreshTargets(true)
end

function LogoIntroCamera:_resolveLogoFolder()
	local current = self._workspace
	for _, name in ipairs(self._logoFolderPath) do
		if not current then
			return nil
		end

		local child = current:FindFirstChild(name)
		if not child then
			local ok, result = pcall(function()
				return current:WaitForChild(name, self._folderWaitTimeout)
			end)
			if ok then
				child = result
			end
		end

		if not child then
			return nil
		end

		current = child
	end

	return current
end

function LogoIntroCamera:_connectFolder(folder)
	self:_disconnect()

	if not folder then
		return
	end

	table.insert(self._connections, folder.ChildAdded:Connect(function()
		self:_refreshTargets()
	end))
	table.insert(self._connections, folder.ChildRemoved:Connect(function()
		self:_refreshTargets()
	end))
end

function LogoIntroCamera:_disconnect()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	self._connections = {}
end

function LogoIntroCamera:_refreshTargets(forceImmediate)
	local folder = self._logoFolder
	if not folder or not folder.Parent then
		self._targets = {}
		return
	end

	local targets = {}
	for _, child in ipairs(folder:GetChildren()) do
		local part = self:_resolvePart(child)
		if part then
			table.insert(targets, part)
		end
	end

	table.sort(targets, function(a, b)
		return a.Name < b.Name
	end)

	if self._maxTargets > 0 and #targets > self._maxTargets then
		while #targets > self._maxTargets do
			table.remove(targets)
		end
	end

	self._targets = targets

	if not self._running then
		return
	end

	if not forceImmediate and self._currentTarget and self:_isValidTarget(self._currentTarget) then
		return
	end

	if #self._targets == 0 then
		return
	end

	self:_moveToTarget(self:_pickRandomTarget(self._currentTarget), forceImmediate)
end

function LogoIntroCamera:_resolvePart(object)
	if not object then
		return nil
	end

	if object:IsA("BasePart") then
		return object
	end

	if object:IsA("Model") then
		local primary = object.PrimaryPart
		if primary then
			return primary
		end
		return object:FindFirstChildWhichIsA("BasePart", true)
	end

	if typeof(object.FindFirstChildWhichIsA) == "function" then
		return object:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

function LogoIntroCamera:_isValidTarget(part)
	if not part or not part.Parent then
		return false
	end

	local folder = self._logoFolder
	if not folder then
		return false
	end

	return part:IsDescendantOf(folder)
end

function LogoIntroCamera:_pickRandomTarget(exclude)
	local available = {}
	for _, part in ipairs(self._targets) do
		if self:_isValidTarget(part) and part ~= exclude then
			table.insert(available, part)
		end
	end

	if #available == 0 then
		if exclude and self:_isValidTarget(exclude) then
			return exclude
		end
		for _, part in ipairs(self._targets) do
			if self:_isValidTarget(part) then
				return part
			end
		end
		return nil
	end

	return available[self._random:NextInteger(1, #available)]
end

function LogoIntroCamera:_getNumberAttribute(object, name, default)
	if not object then
		return default
	end

	local value = object:GetAttribute(name)
	if isNumber(value) then
		return value
	end

	local parent = object.Parent
	if parent then
		local parentValue = parent:GetAttribute(name)
		if isNumber(parentValue) then
			return parentValue
		end
	end

	return default
end

function LogoIntroCamera:_computeTargetCFrame(part)
	if not part then
		return nil
	end

	local distance = self:_getNumberAttribute(part, "IntroDistance", self._defaultDistance)
	local height = self:_getNumberAttribute(part, "IntroHeight", self._defaultHeight)
	local ahead = self:_getNumberAttribute(part, "IntroAhead", self._defaultAhead)

	local forward = part.CFrame.LookVector
	local up = part.CFrame.UpVector
	local origin = part.Position - forward * distance + up * height
	local focus = part.Position + forward * ahead

	return CFrame.lookAt(origin, focus, up)
end

function LogoIntroCamera:_computeTargetFOV(part)
	return self:_getNumberAttribute(part, "IntroFOV", self._defaultFOV)
end

function LogoIntroCamera:_moveToTarget(targetPart, instant)
	if not self._running then
		return
	end

	local part = self:_resolvePart(targetPart)
	if not part or not self:_isValidTarget(part) then
		self:_refreshTargets(true)
		return
	end

	local cameraCFrame = self:_computeTargetCFrame(part)
	if not cameraCFrame then
		return
	end

	local cameraFOV = self:_computeTargetFOV(part)
	local duration = instant and 0 or self._transitionTime

	if duration <= 0 then
		self._cframeValue.Value = cameraCFrame
		self._fovValue.Value = cameraFOV
	else
		self:_playTween(self._cframeValue, {Value = cameraCFrame}, duration)
		self:_playTween(self._fovValue, {Value = cameraFOV}, duration)
	end

        self._currentTarget = part
        if self._paused then
                self:_cancelCycle()
        else
                self:_scheduleNextCycle()
        end
end

function LogoIntroCamera:_scheduleNextCycle()
        self:_cancelCycle()

        if not self._running or self._paused or self._cycleInterval <= 0 then
                return
        end

        self._cycleTask = task.delay(self._cycleInterval, function()
                self._cycleTask = nil
		if not self._running then
			return
		end
		self:_moveToTarget(self:_pickRandomTarget(self._currentTarget), false)
	end)
end

function LogoIntroCamera:_playTween(target, properties, duration)
        if not target then
                return nil
        end

	if duration <= 0 then
		for key, value in pairs(properties) do
			target[key] = value
		end
		return nil
	end

	local tween = self._tweenService:Create(target, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), properties)
	table.insert(self._activeTweens, tween)
	tween.Completed:Connect(function()
		for index, active in ipairs(self._activeTweens) do
			if active == tween then
				table.remove(self._activeTweens, index)
				break
			end
		end
	end)
        tween:Play()
        return tween
end

function LogoIntroCamera:_applyFocusProvider()
        local introCamera = self._introCamera
        if not introCamera or typeof(introCamera.setFocusProvider) ~= "function" then
                return
        end

        if not self._running or self._paused then
                introCamera:setFocusProvider(nil)
                return
        end

        introCamera:setFocusProvider(self._focusCallback)
end

function LogoIntroCamera:_cancelCycle()
        if self._cycleTask then
                task.cancel(self._cycleTask)
                self._cycleTask = nil
        end
end

function LogoIntroCamera:_cancelResumeTask()
        if self._resumeTask then
                task.cancel(self._resumeTask)
                self._resumeTask = nil
        end
end

return LogoIntroCamera
