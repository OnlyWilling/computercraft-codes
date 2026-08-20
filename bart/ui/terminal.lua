-- ============================================================
--  Bart Membership System - Member Terminal
--  Basalt UI: Swipe card -> Verify -> Consume/Query
-- ============================================================

local basalt  = require "basalt"
local disk    = require "bart.lib.disk"
local member  = require "bart.lib.member"
local tier    = require "bart.lib.tier"
local network = require "bart.lib.network"
local C       = require "bart.lib.constants"
local utils   = require "bart.lib.utils"

-- ============================================================
--  State
-- ============================================================

local _serverID = nil
local _dataDir  = "data"
local _secret   = "test_secret"

-- ============================================================
--  Swipe and verify
-- ============================================================

local function swipeCard(side)
    if _serverID then
        local diskID = disk.getDiskID(side)
        if not diskID then return nil, "Cannot read disk" end

        local cardData, err = disk.readCard(side)
        if not cardData then return nil, err end

        local res, rerr = network.sendRequest(_serverID, C.MSG.AUTH, {
            diskID = diskID,
            cardID = cardData.cardID,
            token  = cardData.token,
        }, 5)

        if not res then
            return nil, rerr or "Server not responding"
        end

        return {
            cardData = cardData,
            member   = res.member,
            diskID   = diskID,
        }, nil
    else
        return disk.verifyCard(side, _dataDir, _secret)
    end
end

-- ============================================================
--  UI: Spend / Consume
-- ============================================================

local function showConsume(frame, verifyResult)
    frame:clear()

    local m = verifyResult.member
    local y = 3

    frame:addLabel():setPosition(3, y):setText("| Spend")
    y = y + 2

    frame:addLabel():setPosition(3, y):setText(string.format("Holder: %s    Balance: $%d", m.playerName, m.balance))
    y = y + 2

    local tInfo = C.TIERS[m.tier] or {}
    local discountStr = ""
    if tInfo.discount and tInfo.discount < 1.0 then
        discountStr = string.format(" (%s: %.0f%% off)", tInfo.label, (1 - tInfo.discount) * 100)
    end
    frame:addLabel():setPosition(3, y):setSize(50, 1):setText("Amount:" .. discountStr)
    local amtInput = frame:addInput():setPosition(16, y):setSize(10, 1):setInputType("number")
    y = y + 2

    frame:addLabel():setPosition(3, y):setText("Item/Note:")
    local noteInput = frame:addInput():setPosition(16, y):setSize(20, 1)
    y = y + 2

    local resultLabel = frame:addLabel():setPosition(3, y + 1):setSize(60, 4):setText("")

    frame:addButton():setPosition(3, y):setSize(12, 1):setText("Confirm"):onClick(function()
        local rawAmt = tonumber(amtInput:getText()) or 0
        if rawAmt <= 0 then
            resultLabel:setText("Please enter a valid amount")
            return
        end

        local finalAmt = rawAmt
        if tInfo.discount and tInfo.discount < 1.0 then
            finalAmt = math.ceil(rawAmt * tInfo.discount)
        end

        if m.balance < finalAmt then
            resultLabel:setText(string.format("Insufficient! Need $%d, have $%d", finalAmt, m.balance))
            resultLabel:setBackground(colors.red)
            return
        end

        -- Deduct
        m.balance = m.balance - finalAmt
        local earnedPoints = math.floor(rawAmt * C.DEFAULT_CONFIG.pointsPerCurrency * (tInfo.pointMultiplier or 1))
        m.points = m.points + earnedPoints
        m.totalSpent = m.totalSpent + rawAmt

        local upgraded, newTier = tier.processUpgrade(m)

        local note = string.format("%s (raw$%d", noteInput:getText() or "", rawAmt)
        if finalAmt ~= rawAmt then
            note = note .. string.format(",after discount$%d)", finalAmt)
        else
            note = note .. ")"
        end
        member.addHistory(m, "consume", -finalAmt, note)

        -- Save via utils
        local path = fs.combine(_dataDir, "members", m.cardID .. ".json")
        utils.saveJSONFile(path, m)

        local msg = string.format("Spent $%d\nBalance: $%d    Points earned: %d", finalAmt, m.balance, earnedPoints)
        if upgraded then
            local tName = C.TIERS[newTier].label or newTier
            msg = msg .. string.format("\n! Upgraded to %s!", tName)
        end
        resultLabel:setText(msg)
        resultLabel:setBackground(colors.green)
    end)

    frame:addButton():setPosition(18, y):setSize(12, 1):setText("Back"):onClick(function()
        showCardInfo(frame, verifyResult)
    end)
end

-- ============================================================
--  UI: Card info display
-- ============================================================

local function showCardInfo(frame, verifyResult)
    frame:clear()

    local m = verifyResult.member
    local cd = verifyResult.cardData

    local w, h = frame:getSize()
    local y = 2

    local tInfo = C.TIERS[m.tier] or {}
    local status = "Active"
    if not m.active then status = "Frozen" end

    frame:addLabel():setPosition(3, y):setText("+--------------------------+"):setBackground(colors.black)
    y = y + 1
    frame:addLabel():setPosition(3, y):setText("|   Bart Card   " .. (tInfo.label or ""))
    y = y + 1
    frame:addLabel():setPosition(3, y):setText("|")
    y = y + 1
    frame:addLabel():setPosition(3, y):setText("|   " .. (m.playerName or ""))
    y = y + 1
    frame:addLabel():setPosition(3, y):setText("+--------------------------+")
    y = y + 2

    frame:addLabel():setPosition(3, y):setText(string.format("Tier:  %s (%s)", tInfo.label or m.tier, m.tier:upper()))
    y = y + 1
    frame:addLabel():setPosition(3, y):setText(string.format("Balance: $%d", m.balance))
    y = y + 1
    frame:addLabel():setPosition(3, y):setText(string.format("Points: %d", m.points))
    y = y + 1
    frame:addLabel():setPosition(3, y):setText(string.format("Total spent: $%d", m.totalSpent))
    y = y + 1
    frame:addLabel():setPosition(3, y):setText(string.format("Status: %s", status))
    y = y + 2

    if tInfo.discount and tInfo.discount < 1.0 then
        frame:addLabel():setPosition(3, y):setText(string.format(">>> %.0f%% discount on purchases", (1 - tInfo.discount) * 100))
        y = y + 1
        if tInfo.pointMultiplier and tInfo.pointMultiplier > 1 then
            frame:addLabel():setPosition(3, y):setText(string.format(">>> %dx points multiplier", tInfo.pointMultiplier))
            y = y + 1
        end
        y = y + 1
    end

    frame:addButton():setPosition(3, y):setSize(12, 1):setText("Spend"):onClick(function()
        showConsume(frame, verifyResult)
    end)

    frame:addButton():setPosition(18, y):setSize(12, 1):setText("Eject"):onClick(function()
        showWaitCard(frame)
    end)
end

-- ============================================================
--  UI: Wait for card
-- ============================================================

local function showWaitCard(frame)
    frame:clear()

    local w, h = frame:getSize()
    local cx = math.floor(w / 2)
    local y = 5

    frame:addLabel():setPosition(cx - 12, y):setText("+--------------------------+")
    y = y + 1
    frame:addLabel():setPosition(cx - 12, y):setText("|   Bart Terminal          |")
    y = y + 1
    frame:addLabel():setPosition(cx - 12, y):setText("|                          |")
    y = y + 1
    frame:addLabel():setPosition(cx - 12, y):setText("|   Please insert card...  |")
    y = y + 1
    frame:addLabel():setPosition(cx - 12, y):setText("+--------------------------+")
    y = y + 2

    local statusLabel = frame:addLabel():setPosition(cx - 12, y):setSize(40, 3):setText("")

    local checkSide = "top"
    local function pollDisk()
        if not peripheral.isPresent(checkSide) or not peripheral.wrap(checkSide).isDiskPresent() then
            statusLabel:setText("Waiting for disk...")
            return true
        end

        statusLabel:setText("Reading card...")

        local res, err = swipeCard(checkSide)
        if res then
            showCardInfo(frame, res)
            return false
        else
            statusLabel:setText("Card error: " .. (err or ""))
            statusLabel:setBackground(colors.red)
            return true
        end
    end

    pollDisk()

    frame:addButton():setPosition(cx - 8, y + 3):setSize(16, 1):setText("Refresh"):onClick(function()
        pollDisk()
    end)

    frame:addButton():setPosition(cx - 8, y + 5):setSize(16, 1):setText("Exit"):onClick(function()
        frame:close()
    end)
end

-- ============================================================
--  Launch terminal
-- ============================================================

local function run(serverID, dataDir, secret)
    _serverID = serverID
    if dataDir then _dataDir = dataDir end
    if secret then _secret = secret end

    local frame = basalt.createFrame():setTitle("Bart Terminal")
    showWaitCard(frame)
    basalt.autoUpdate()
end

return { run = run }
