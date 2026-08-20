-- ============================================================
--  Bart Membership System - Disk Operations
--  Physical disk read/write, issue, verify, reissue
-- ============================================================

local security  = require "lib/security"
local member    = require "lib/member"
local C         = require "lib/constants"

-- ============================================================
--  Disk file read/write
-- ============================================================

local CARD_FILE = "card.json"

--- Read card data from a physical disk.
--- @param side string peripheral side (e.g. "left", "top")
--- @return table|nil cardData { cardID, token, label }
--- @return string|nil err
local function readCard(side)
    if not peripheral.isPresent(side) then
        return nil, "No disk drive found"
    end

    local disk = peripheral.wrap(side)
    if not disk.isDiskPresent() then
        return nil, "No disk inserted"
    end

    if not disk.hasData() then
        return nil, "Blank disk (no data area)"
    end

    local mountPath = disk.getMountPath()
    local filePath = fs.combine(mountPath, CARD_FILE)

    if not fs.exists(filePath) then
        return nil, "Not a valid membership card"
    end

    local fh = fs.open(filePath, "r")
    if not fh then
        return nil, "Cannot read card data"
    end

    local raw = fh.readAll()
    fh.close()

    local ok, cardData = pcall(textutils.unserialize, raw)
    if not ok or type(cardData) ~= "table" then
        return nil, "Card data corrupted"
    end

    if not cardData.cardID or not cardData.token then
        return nil, "Invalid card data format"
    end

    return cardData, nil
end

--- Write card data to a disk.
--- @param side string peripheral side
--- @param cardData table { cardID, token, label }
--- @return boolean success
--- @return string|nil err
local function writeCard(side, cardData)
    if not peripheral.isPresent(side) then
        return false, "No disk drive found"
    end

    local disk = peripheral.wrap(side)
    if not disk.isDiskPresent() then
        return false, "No disk inserted"
    end

    if not disk.hasData() then
        local ok = pcall(disk.createDataDisk, os.epoch("local") or "")
        if not ok then
            return false, "Cannot format disk"
        end
    end

    local mountPath = disk.getMountPath()
    local filePath = fs.combine(mountPath, CARD_FILE)

    local fh = fs.open(filePath, "w")
    if not fh then
        return false, "Cannot write card data"
    end

    fh.write(textutils.serialize(cardData))
    fh.close()

    return true, nil
end

--- Set the disk label (minecraft item name).
--- @param side string
--- @param label string
local function setDiskLabel(side, label)
    if not peripheral.isPresent(side) then
        return false, "No disk drive found"
    end

    local disk = peripheral.wrap(side)
    if not disk.isDiskPresent() then
        return false, "No disk inserted"
    end

    disk.setLabel(label)
    return true, nil
end

--- Get the disk ID.
--- @param side string
--- @return number|nil diskID
local function getDiskID(side)
    if not peripheral.isPresent(side) then
        return nil, "No disk drive found"
    end

    local disk = peripheral.wrap(side)
    if not disk.isDiskPresent() then
        return nil, "No disk inserted"
    end

    return disk.getID()
end

--- Get the disk label.
--- @param side string
--- @return string|nil label
local function getDiskLabel(side)
    if not peripheral.isPresent(side) then
        return nil
    end
    local disk = peripheral.wrap(side)
    if not disk.isDiskPresent() then
        return nil
    end
    return disk.getLabel()
end

-- ============================================================
--  Issue a new card
-- ============================================================

--- Issue a new membership card.
--- Flow:
---   1. Read diskID
---   2. Generate cardID + token
---   3. Write to server database
---   4. Write card.json to disk
---   5. Set disk label
--- @param side string
--- @param dataDir string
--- @param serverSecret string
--- @param playerName string
--- @param playerUUID string|nil
--- @param tier string|nil (default dirt)
--- @return table|nil result { cardID, diskID, label }
--- @return string|nil err
local function issueCard(side, dataDir, serverSecret, playerName, playerUUID, tier)
    local diskID = getDiskID(side)
    if not diskID then
        return nil, "Cannot read disk ID"
    end

    local existingCID = member.lookupCardID(dataDir, diskID)
    if existingCID then
        return nil, "Disk is already a card (" .. existingCID .. ")"
    end

    local cardID = security.generateCardID()
    local token = security.generateToken()
    local tokenHash = security.hashToken(token, serverSecret)

    local m = member.newMember(cardID, playerName, playerUUID, tier or C.DEFAULT_CONFIG.defaultTier)
    m.tokenHash = tokenHash
    m.label = playerName .. "'s Card"

    local ok = member.saveMember(dataDir, cardID, m)
    if not ok then
        return nil, "Failed to write member data"
    end

    ok = member.registerCard(dataDir, diskID, cardID)
    if not ok then
        return nil, "Failed to register card mapping"
    end

    local cardData = {
        cardID  = cardID,
        token   = token,
        label   = m.label,
        version = 1,
    }

    ok = writeCard(side, cardData)
    if not ok then
        return nil, "Failed to write to disk (try re-issuing)"
    end

    setDiskLabel(side, m.label)

    return {
        cardID = cardID,
        diskID = diskID,
        label  = m.label,
    }, nil
end

-- ============================================================
--  Verify a card
-- ============================================================

--- Verify a membership card against the server database.
--- Flow:
---   1. Read card.json from disk
---   2. Check registry (diskID -> cardID)
---   3. Verify tokenHash
---   4. Check active status
--- @param side string
--- @param dataDir string
--- @param serverSecret string
--- @return table|nil result { cardData, member, diskID }
--- @return string|nil err
local function verifyCard(side, dataDir, serverSecret)
    local cardData, err = readCard(side)
    if not cardData then
        return nil, err
    end

    local diskID = getDiskID(side)
    if not diskID then
        return nil, "Cannot read disk ID"
    end

    local expectedCID = member.lookupCardID(dataDir, diskID)
    if not expectedCID then
        return nil, "Card not registered in system"
    end

    if expectedCID ~= cardData.cardID then
        return nil, "Card ID mismatch (may be tampered)"
    end

    local m = member.loadMember(dataDir, cardData.cardID)
    if not m then
        return nil, "Member data not found"
    end

    if not security.verifyToken(cardData.token, m.tokenHash, serverSecret) then
        return nil, "Card verification failed (data may be tampered)"
    end

    if not m.active then
        return nil, "Card is frozen or deactivated"
    end

    return {
        cardData = cardData,
        member   = m,
        diskID   = diskID,
    }, nil
end

-- ============================================================
--  Reissue a card
-- ============================================================

--- Reissue a new card (old card frozen).
--- Flow:
---   1. Freeze old card
---   2. Generate new cardID + token
---   3. Inherit old card data
---   4. Write to new disk
---   5. Register new mapping
--- @param side string (new blank disk)
--- @param dataDir string
--- @param serverSecret string
--- @param oldCardID string
--- @param newLabel string|nil
--- @return table|nil result { cardID, diskID, playerName }
--- @return string|nil err
local function reissueCard(side, dataDir, serverSecret, oldCardID, newLabel)
    local oldMember = member.loadMember(dataDir, oldCardID)
    if not oldMember then
        return nil, "Old card data not found"
    end

    oldMember.active = false
    member.saveMember(dataDir, oldCardID, oldMember)

    local newDiskID = getDiskID(side)
    if not newDiskID then
        return nil, "Cannot read new disk ID"
    end

    local newCardID    = security.generateCardID()
    local newToken     = security.generateToken()
    local newTokenHash = security.hashToken(newToken, serverSecret)

    local newM         = member.newMember(newCardID, oldMember.playerName, oldMember.playerUUID, oldMember.tier)
    newM.balance       = oldMember.balance
    newM.points        = oldMember.points
    newM.totalSpent    = oldMember.totalSpent
    newM.tokenHash     = newTokenHash
    newM.label         = newLabel or (oldMember.playerName .. "'s Card (reissue)")

    member.addHistory(newM, "reissue", 0, "Reissued from " .. oldCardID)

    member.saveMember(dataDir, newCardID, newM)
    member.registerCard(dataDir, newDiskID, newCardID)

    local cardData = {
        cardID  = newCardID,
        token   = newToken,
        label   = newM.label,
        version = 1,
    }
    writeCard(side, cardData)
    setDiskLabel(side, newM.label)

    return {
        cardID     = newCardID,
        diskID     = newDiskID,
        playerName = oldMember.playerName,
        label      = newM.label,
    }, nil
end

return {
    readCard     = readCard,
    writeCard    = writeCard,
    getDiskID    = getDiskID,
    getDiskLabel = getDiskLabel,
    setDiskLabel = setDiskLabel,
    issueCard    = issueCard,
    verifyCard   = verifyCard,
    reissueCard  = reissueCard,
}
