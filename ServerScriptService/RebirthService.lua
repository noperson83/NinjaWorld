local ReplicatedStorage = game:GetService("ReplicatedStorage")

local rebirthEvent = ReplicatedStorage:FindFirstChild("RebirthEvent")
if rebirthEvent and not rebirthEvent:IsA("RemoteEvent") then
    rebirthEvent:Destroy()
    rebirthEvent = nil
end
if not rebirthEvent then
    rebirthEvent = Instance.new("RemoteEvent")
    rebirthEvent.Name = "RebirthEvent"
    rebirthEvent.Parent = ReplicatedStorage
end

local dataScript = script.Parent:WaitForChild("DataSavingScript")
local rebirthFunction = dataScript:WaitForChild("RebirthFunction")

rebirthEvent.OnServerEvent:Connect(function(player)
    rebirthFunction:Invoke(player)
end)
