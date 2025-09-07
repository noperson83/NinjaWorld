local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AbilityMetadata = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("AbilityMetadata"))

local AbilityUI = {}

function AbilityUI.init(config, bootUI)
    local root = bootUI and bootUI.root
    if not root then return end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(0.3,0.4)
    frame.Position = UDim2.fromScale(0.35,0.3)
    frame.BackgroundColor3 = Color3.fromRGB(40,40,42)
    frame.Visible = true
    frame.Parent = root

    local layout = Instance.new("UIListLayout")
    layout.Parent = frame

    local learnRF = ReplicatedStorage:WaitForChild("LearnAbility")

    for ability, info in pairs(AbilityMetadata) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1,0,0,40)
        btn.Text = ability .. " (" .. info.cost .. " Coins)"
        btn.Parent = frame
        btn.Activated:Connect(function()
            learnRF:InvokeServer(ability)
        end)
    end

    return frame
end

return AbilityUI
