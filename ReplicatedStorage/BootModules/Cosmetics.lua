local Cosmetics = {}

-- Creates a very small persona selection GUI and handles spawning once a
-- choice is made.  The intro GUI comes from BootUI.init and is hidden after
-- the server spawns our character.
function Cosmetics.init(config)
        local Players = game:GetService("Players")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")

        local player = Players.LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui")
        local enterDojo = ReplicatedStorage:WaitForChild("EnterDojoRE")

        -- Simple GUI container
        local gui = Instance.new("ScreenGui")
        gui.Name = "PersonaGui"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 110
        gui.Parent = playerGui

        local root = Instance.new("Frame")
        root.Size = UDim2.fromScale(1,1)
        root.BackgroundTransparency = 1
        root.Parent = gui

        -- Buttons for persona selection
        local ninjaButton = Instance.new("TextButton")
        ninjaButton.Size = UDim2.fromOffset(200,50)
        ninjaButton.Position = UDim2.fromScale(0.5,0.45)
        ninjaButton.AnchorPoint = Vector2.new(0.5,0.5)
        ninjaButton.Text = "Ninja"
        ninjaButton.Parent = root

        local robloxButton = Instance.new("TextButton")
        robloxButton.Size = UDim2.fromOffset(200,50)
        robloxButton.Position = UDim2.fromScale(0.5,0.55)
        robloxButton.AnchorPoint = Vector2.new(0.5,0.5)
        robloxButton.Text = "Roblox"
        robloxButton.Parent = root

        local confirmButton = Instance.new("TextButton")
        confirmButton.Size = UDim2.fromOffset(200,50)
        confirmButton.Position = UDim2.fromScale(0.5,0.7)
        confirmButton.AnchorPoint = Vector2.new(0.5,0.5)
        confirmButton.Text = "Enter Dojo"
        confirmButton.Parent = root

        local chosenPersona = "Roblox"
        local function updateSelection()
                ninjaButton.BackgroundColor3 = (chosenPersona == "Ninja") and Color3.fromRGB(0,170,0) or Color3.fromRGB(255,255,255)
                robloxButton.BackgroundColor3 = (chosenPersona == "Roblox") and Color3.fromRGB(0,170,0) or Color3.fromRGB(255,255,255)
        end

        ninjaButton.MouseButton1Click:Connect(function()
                chosenPersona = "Ninja"
                updateSelection()
        end)

        robloxButton.MouseButton1Click:Connect(function()
                chosenPersona = "Roblox"
                updateSelection()
        end)

        updateSelection()

        confirmButton.MouseButton1Click:Connect(function()
                gui.Enabled = false
                enterDojo:FireServer({type = chosenPersona})

                -- Wait for the server to spawn our character before clearing intro UI
                local introGui = playerGui:FindFirstChild("IntroGui")
                local conn
                conn = player.CharacterAdded:Connect(function()
                        if conn then conn:Disconnect() end
                        if introGui then introGui.Enabled = false introGui:Destroy() end
                        gui:Destroy()
                end)
        end)

        print("Cosmetics module initialized for", config.gameName)
end

return Cosmetics
