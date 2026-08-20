-- ============================================================
--  Bart Membership System - Member Data Model
--  Uses lib/utils for persistence
-- ============================================================

local utils = require "lib/utils"

-- ============================================================
--  Load / Save member data
-- ============================================================

--- Load a member by cardID.
--- @param dataDir string data directory
--- @param cardID string card ID
--- @return table|nil member data, nil if not found
local function loadMember(dataDir, cardID)
    if not cardID then return nil end
    if cardID:match("[^%w%-]") then return nil end

    local path = fs.combine(dataDir, "members", cardID .. ".json")
    return utils.loadJSONFile(path)
end

--- Save a member by cardID.
--- @param dataDir string data directory
--- @param cardID string card ID
--- @param memberData table member data
--- @return boolean success
local function saveMember(dataDir, cardID, memberData)
    if not cardID then return false end
    if cardID:match("[^%w%-]") then return false end

    local path = fs.combine(dataDir, "members", cardID .. ".json")
    return utils.saveJSONFile(path, memberData)
end

-- ============================================================
--  Member factory
-- ============================================================

--- Create a new member record.
--- @param cardID string
--- @param playerName string
--- @param playerUUID string|nil
--- @param tier string initial tier
--- @return table member
local function newMember(cardID, playerName, playerUUID, tier)
    return {
        cardID     = cardID,
        playerName = playerName,
        playerUUID = playerUUID or "",
        label      = playerName .. "'s Card",
        tier       = tier or "dirt",
        balance    = 0,
        points     = 0,
        totalSpent = 0,
        active     = true,
        tokenHash  = "",
        createdAt  = os.date("%Y-%m-%dT%H:%M:%S"),
        history    = {},
    }
end

-- ============================================================
--  Registry (diskID <-> cardID mapping)
-- ============================================================

--- Load the diskID->cardID registry.
--- @param dataDir string
--- @return table registry
local function loadRegistry(dataDir)
    local path = fs.combine(dataDir, "registry.json")
    local reg = utils.loadJSONFile(path) or {}
    return reg
end

--- Save the registry.
--- @param dataDir string
--- @param registry table
--- @return boolean
local function saveRegistry(dataDir, registry)
    local path = fs.combine(dataDir, "registry.json")
    return utils.saveJSONFile(path, registry)
end

--- Look up cardID by diskID.
--- @param dataDir string
--- @param diskID number|string
--- @return string|nil cardID
local function lookupCardID(dataDir, diskID)
    local reg = loadRegistry(dataDir)
    return reg[tostring(diskID)]
end

--- Register a new diskID -> cardID mapping.
--- @param dataDir string
--- @param diskID number|string
--- @param cardID string
--- @return boolean
local function registerCard(dataDir, diskID, cardID)
    local reg = loadRegistry(dataDir)
    reg[tostring(diskID)] = cardID
    return saveRegistry(dataDir, reg)
end

--- Remove a diskID mapping (on freeze/loss).
--- @param dataDir string
--- @param diskID number|string
--- @return boolean
local function unregisterCard(dataDir, diskID)
    local reg = loadRegistry(dataDir)
    reg[tostring(diskID)] = nil
    return saveRegistry(dataDir, reg)
end

--- Find all cards belonging to a player.
--- @param dataDir string
--- @param playerName string
--- @return table { cardID = memberData, ... }
local function lookupByPlayer(dataDir, playerName)
    local results = {}
    local reg = loadRegistry(dataDir)
    local seen = {}

    for _, cardID in pairs(reg) do
        if not seen[cardID] then
            seen[cardID] = true
            local m = loadMember(dataDir, cardID)
            if m and m.playerName == playerName then
                results[cardID] = m
            end
        end
    end
    return results
end

-- ============================================================
--  Transaction history
-- ============================================================

--- Add a transaction entry to a member's history.
--- @param m table member data
--- @param txType string "consume"|"recharge"|"admin_adjust"|etc
--- @param amount number
--- @param note string|nil
local function addHistory(m, txType, amount, note)
    local entry = {
        type   = txType,
        amount = amount,
        time   = os.date("%Y-%m-%dT%H:%M:%S"),
        note   = note or "",
    }
    table.insert(m.history, entry)

    local maxLog = 1000
    if #m.history > maxLog then
        local newHistory = {}
        for i = #m.history - maxLog + 1, #m.history do
            table.insert(newHistory, m.history[i])
        end
        m.history = newHistory
    end
end

return {
    loadMember     = loadMember,
    saveMember     = saveMember,
    newMember      = newMember,

    loadRegistry   = loadRegistry,
    saveRegistry   = saveRegistry,
    lookupCardID   = lookupCardID,
    registerCard   = registerCard,
    unregisterCard = unregisterCard,
    lookupByPlayer = lookupByPlayer,

    addHistory     = addHistory,
}
