local BeastFX = {}

function BeastFX.create()
        local aura = Instance.new("Part")
        aura.Name = "BeastAura"
        aura.Shape = Enum.PartType.Ball
        aura.Size = Vector3.new(8, 8, 8)
        aura.Transparency = 0.7
        aura.Material = Enum.Material.Neon
        aura.BrickColor = BrickColor.new("Earth green")
        aura.CanCollide = false
        aura.Anchored = true

        local smoke = Instance.new("Smoke")
        smoke.Color = Color3.fromRGB(80, 255, 80)
        smoke.Opacity = 0.3
        smoke.Size = 5
        smoke.RiseVelocity = 0
        smoke.Parent = aura

        return aura
end

return BeastFX
