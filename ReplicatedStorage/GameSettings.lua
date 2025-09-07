local GameSettings = {}

-- ================================================================================
-- Game Information
-- These settings affect text that you see in game
-- ================================================================================

GameSettings.gameName = "Ninja World EXP 3000"
GameSettings.developerName = "DrNoperson"

GameSettings.levelUpMessage = "You Leveled Up!"

-- ================================================================================
-- Game Numbers and Stats
-- These numbers affect how fast players go and how much faster they increase each level
-- ================================================================================

-- Starting data values
GameSettings.startUpgrades = 1
GameSettings.startPoints = 0
GameSettings.startCoins = 100

-- Maximum number of persona slots available to each player
GameSettings.maxSlots = 9

GameSettings.pointsName = "Points"
GameSettings.upgradeName = "Upgrades"

-- Multiplier determines how much players need to move before a level; 1 = small amount of movement, 3 much more movement
local growthModifier = 1.2
-- How fast a player starts with 0 levels
local startMoveSpeed = 7
-- The amount of WalkSpeed added per level
local speedBoostPerLevel = 3
-- The amount of JumpPower added per level
local jumpBoostPerLevel = 2
-- Base jump power
local startJumpPower = 1
-- Health increase per level
local healthBoostPerLevel = 10
-- Base health
local startHealth = 100

function GameSettings.upgradeCost(upgrades)
	return (40 * growthModifier) * growthModifier^upgrades
end

function GameSettings.movementSpeed(level)
	return (speedBoostPerLevel * level) + startMoveSpeed
end

function GameSettings.jumpPower(level)
	return (jumpBoostPerLevel * level) + startJumpPower
end

function GameSettings.health(level)
	return (healthBoostPerLevel * level) + startHealth
end

function GameSettings.staminaUpgradeCost(upgrades)
	return (30 * growthModifier) * growthModifier^upgrades
end

-- Codes used to redeem for in-game badges
GameSettings.codes = {
	"testcode"
}

-- ================================================================================

return GameSettings
