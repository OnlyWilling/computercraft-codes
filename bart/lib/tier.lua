-- ============================================================
--  Bart Membership System - Tier Upgrade Logic
-- ============================================================

local C = require "lib/constants"

-- ============================================================
--  Tier info lookup
-- ============================================================

--- Get tier config by name.
--- @param tierName string "dirt"|"iron"|etc
--- @return table|nil
local function getTier(tierName)
    return C.TIERS[tierName]
end

--- Get the next tier name.
--- @param tierName string current tier
--- @return string|nil next tier, nil if max
local function nextTier(tierName)
    local current = C.TIERS[tierName]
    if not current then return nil end

    local nextIndex = current.index + 1
    for name, info in pairs(C.TIERS) do
        if info.index == nextIndex and info.threshold >= 0 then
            return name
        end
    end
    return nil
end

-- ============================================================
--  Upgrade checks
-- ============================================================

--- Calculate tier based on total spent.
--- @param totalSpent number
--- @return string tierName
local function calculateTier(totalSpent)
    local best = "dirt"
    for name, info in pairs(C.TIERS) do
        if info.threshold >= 0 and totalSpent >= info.threshold then
            if info.index >= C.TIERS[best].index then
                best = name
            end
        end
    end
    return best
end

--- Check if member qualifies for upgrade.
--- @param currentTier string
--- @param totalSpent number
--- @return string|nil newTier
local function checkUpgrade(currentTier, totalSpent)
    local next = nextTier(currentTier)
    if not next then return nil end

    local nextInfo = C.TIERS[next]
    if nextInfo.threshold >= 0 and totalSpent >= nextInfo.threshold then
        return next
    end
    return nil
end

--- Process upgrade after purchase. Mutates member.tier.
--- @param m table member data
--- @return boolean upgraded
--- @return string|nil newTier
local function processUpgrade(m)
    local newTier = checkUpgrade(m.tier, m.totalSpent)
    if newTier then
        m.tier = newTier
        return true, newTier
    end
    return false, nil
end

--- Manually set a member's tier (admin).
--- @param m table member data
--- @param newTier string
--- @return boolean success
local function setTier(m, newTier)
    if not C.TIERS[newTier] then
        return false
    end
    m.tier = newTier
    return true
end

return {
    getTier        = getTier,
    nextTier       = nextTier,
    calculateTier  = calculateTier,
    checkUpgrade   = checkUpgrade,
    processUpgrade = processUpgrade,
    setTier        = setTier,
}
