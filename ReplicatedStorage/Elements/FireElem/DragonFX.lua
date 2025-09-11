local DragonFX = {}

function DragonFX.create()
        local part = Instance.new("Part")
        part.Name = "DragonProjectile"
        part.Size = Vector3.new(2, 2, 4)
        part.Material = Enum.Material.Neon
        part.BrickColor = BrickColor.new("Bright orange")
        part.CanCollide = false

        local fire = Instance.new("Fire")
        fire.Heat = 0
        fire.Size = 5
        fire.Color = Color3.fromRGB(255, 170, 0)
        fire.SecondaryColor = Color3.fromRGB(255, 255, 255)
        fire.Parent = part

        return part
end

return DragonFX
