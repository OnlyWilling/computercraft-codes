-- ============================================================
--  Bart Membership System - Admin Panel
--  Basalt UI: Issue/Reissue/Query/Freeze/Recharge
-- ============================================================

local basalt  = require "basalt"
local disk    = require "bart.lib.disk"
local member  = require "bart.lib.member"
local tier    = require "bart.lib.tier"
local C       = require "bart.lib.constants"
local dataDir = "data"

-- ============================================================
--  UI: Issue new card
-- ============================================================

local function showIssueCard(frame)
    frame:clear()

    local y = 2
    frame:addLabel():setPosition(3, y):setText("=== Issue New Card ===")
    y = y + 2

    frame:addLabel():setPosition(3, y):setText("Disk side:")
    local sideInput = frame:addInput():setPosition(16, y):setSize(10, 1):setText("top")
    y = y + 2

    frame:addLabel():setPosition(3, y):setText("Player name:")
    local nameInput = frame:addInput():setPosition(16, y):setSize(20, 1)
    y = y + 2

    frame:addLabel():setPosition(3, y):setText("Tier (blank=default):")
    local tierInput = frame:addInput():setPosition(26, y):setSize(10, 1)
    y = y + 2

    local resultLabel = frame:addLabel():setPosition(3, y + 2):setSize(60, 3):setText("")

    frame:addButton():setPosition(3, y):setSize(12, 1):setText("Issue"):onClick(function()
        local side = sideInput:getText()
        local pname = nameInput:getText()
        if pname == "" then
            resultLabel:setText("Please enter player name")
            return
        end

        local pTier = tierInput:getText()
        if pTier == "" then pTier = nil end
        if pTier and not C.TIERS[pTier] then
            resultLabel:setText("Invalid tier: " .. pTier)
            return
        end

        local res, err = disk.issueCard(side, dataDir, "test_secret", pname, nil, pTier)
        if res then
            resultLabel:setText("Card issued!\nCardID: " .. res.cardID .. "\nDiskID: " .. res.diskID)
            resultLabel:setBackground(colors.green)
        else
            resultLabel:setText("Failed: " .. (err or "Unknown error"))
            resultLabel:setBackground(colors.red)
        end
    end)

    frame:addButton():setPosition(18, y):setSize(12, 1):setText("Back"):onClick(function()
        showMainMenu(frame)
    end)
end

-- ============================================================
--  UI: Reissue card
-- ============================================================

local function showReissue(frame)
    frame:clear()

    local y = 2
    frame:addLabel():setPosition(3, y):setText("=== Reissue Card ===")
    y = y + 2

    frame:addLabel():setPosition(3, y):setText("Old cardID:")
    local oldInput = frame:addInput():setPosition(16, y):setSize(20, 1)
    y = y + 2

    frame:addLabel():setPosition(3, y):setText("New disk side:")
    local sideInput = frame:addInput():setPosition(18, y):setSize(10, 1):setText("top")
    y = y + 2

    frame:addLabel():setPosition(3, y):setText("New label (optional):")
    local labelInput = frame:addInput():setPosition(26, y):setSize(20, 1)
    y = y + 2

    local resultLabel = frame:addLabel():setPosition(3, y + 2):setSize(60, 4):setText("")

    frame:addButton():setPosition(3, y):setSize(12, 1):setText("Reissue"):onClick(function()
        local oldCID = oldInput:getText()
        if oldCID == "" then
            resultLabel:setText("Please enter old cardID")
            return
        end

        local newLabel = labelInput:getText()
        if newLabel == "" then newLabel = nil end

        local res, err = disk.reissueCard(sideInput:getText(), dataDir, "test_secret", oldCID, newLabel)
        if res then
            resultLabel:setText("Reissued!\nNew cardID: " .. res.cardID .. "\nPlayer: " .. res.playerName)
            resultLabel:setBackground(colors.green)
        else
            resultLabel:setText("Failed: " .. (err or "Unknown error"))
            resultLabel:setBackground(colors.red)
        end
    end)

    frame:addButton():setPosition(18, y):setSize(12, 1):setText("Back"):onClick(function()
        showMainMenu(frame)
    end)
end

-- ============================================================
--  UI: Query member
-- ============================================================

local function showQuery(frame)
    frame:clear()

    local y = 2
    frame:addLabel():setPosition(3, y):setText("=== Query Member ===")
    y = y + 2

    frame:addLabel():setPosition(3, y):setText("CardID:")
    local cidInput = frame:addInput():setPosition(16, y):setSize(20, 1)
    y = y + 2

    local infoLabel = frame:addLabel():setPosition(3, y + 1):setSize(60, 10):setText("")

    frame:addButton():setPosition(3, y):setSize(12, 1):setText("Query"):onClick(function()
        local cid = cidInput:getText()
        if cid == "" then
            infoLabel:setText("Please enter cardID")
            return
        end

        local m = member.loadMember(dataDir, cid)
        if not m then
            infoLabel:setText("Member not found")
            infoLabel:setBackground(colors.red)
            return
        end

        local status = "Active"
        if not m.active then status = "Frozen" end

        local tInfo = C.TIERS[m.tier] or {}
        infoLabel:setText(string.format(
            "CardID:  %s\nPlayer:  %s\nTier:    %s (%s)\nBalance: $%d\nPoints:  %d\nStatus:  %s\nSpent:   $%d",
            m.cardID, m.playerName, tInfo.label or m.tier, m.tier:upper(),
            m.balance, m.points, status, m.totalSpent
        ))
        infoLabel:setBackground(colors.black)
    end)

    frame:addButton():setPosition(18, y):setSize(12, 1):setText("Back"):onClick(function()
        showMainMenu(frame)
    end)
end

-- ============================================================
--  UI: Freeze / Unfreeze
-- ============================================================

local function showFreeze(frame)
    frame:clear()

    local y = 2
    frame:addLabel():setPosition(3, y):setText("=== Freeze / Unfreeze ===")
    y = y + 2

    frame:addLabel():setPosition(3, y):setText("CardID:")
    local cidInput = frame:addInput():setPosition(16, y):setSize(20, 1)
    y = y + 2

    local resultLabel = frame:addLabel():setPosition(3, y + 1):setSize(60, 3):setText("")

    frame:addButton():setPosition(3, y):setSize(12, 1):setText("Freeze"):onClick(function()
        local cid = cidInput:getText()
        if cid == "" then
            resultLabel:setText("Please enter cardID")
            return
        end
        local m = member.loadMember(dataDir, cid)
        if not m then
            resultLabel:setText("Member not found")
            return
        end
        m.active = false
        member.saveMember(dataDir, cid, m)
        resultLabel:setText("Frozen card: " .. cid)
        resultLabel:setBackground(colors.red)
    end)

    frame:addButton():setPosition(18, y):setSize(12, 1):setText("Unfreeze"):onClick(function()
        local cid = cidInput:getText()
        if cid == "" then
            resultLabel:setText("Please enter cardID")
            return
        end
        local m = member.loadMember(dataDir, cid)
        if not m then
            resultLabel:setText("Member not found")
            return
        end
        m.active = true
        member.saveMember(dataDir, cid, m)
        resultLabel:setText("Unfrozen card: " .. cid)
        resultLabel:setBackground(colors.green)
    end)

    frame:addButton():setPosition(34, y):setSize(12, 1):setText("Back"):onClick(function()
        showMainMenu(frame)
    end)
end

-- ============================================================
--  UI: Recharge
-- ============================================================

local function showRecharge(frame)
    frame:clear()

    local y = 2
    frame:addLabel():setPosition(3, y):setText("=== Recharge ===")
    y = y + 2

    frame:addLabel():setPosition(3, y):setText("CardID:")
    local cidInput = frame:addInput():setPosition(16, y):setSize(20, 1)
    y = y + 2

    frame:addLabel():setPosition(3, y):setText("Amount:")
    local amtInput = frame:addInput():setPosition(16, y):setSize(10, 1):setInputType("number")
    y = y + 2

    frame:addLabel():setPosition(3, y):setText("Note:")
    local noteInput = frame:addInput():setPosition(16, y):setSize(20, 1)
    y = y + 2

    local resultLabel = frame:addLabel():setPosition(3, y + 1):setSize(60, 3):setText("")

    frame:addButton():setPosition(3, y):setSize(12, 1):setText("Recharge"):onClick(function()
        local cid = cidInput:getText()
        local amt = tonumber(amtInput:getText()) or 0
        if cid == "" or amt <= 0 then
            resultLabel:setText("Please enter a valid cardID and amount")
            return
        end

        local m = member.loadMember(dataDir, cid)
        if not m then
            resultLabel:setText("Member not found")
            return
        end

        m.balance = m.balance + amt
        member.addHistory(m, "recharge", amt, noteInput:getText())
        member.saveMember(dataDir, cid, m)
        resultLabel:setText(string.format("Recharged! New balance: $%d", m.balance))
        resultLabel:setBackground(colors.green)
    end)

    frame:addButton():setPosition(18, y):setSize(12, 1):setText("Back"):onClick(function()
        showMainMenu(frame)
    end)
end

-- ============================================================
--  UI: Main menu
-- ============================================================

local function showMainMenu(frame)
    frame:clear()

    local w, h = frame:getSize()
    local cx = math.floor(w / 2)
    local y = 3

    frame:addLabel():setPosition(cx - 10, y):setText("=== Bart Admin Panel ===")
    y = y + 2

    local buttons = {
        { "Issue Card",      function() showIssueCard(frame) end },
        { "Reissue Card",    function() showReissue(frame) end },
        { "Query Member",    function() showQuery(frame) end },
        { "Freeze/Unfreeze", function() showFreeze(frame) end },
        { "Recharge",        function() showRecharge(frame) end },
        { "Exit",            function() frame:close() end },
    }

    for _, btn in ipairs(buttons) do
        frame:addButton():setPosition(cx - 8, y):setSize(16, 1):setText(btn[1]):onClick(btn[2])
        y = y + 2
    end
end

-- ============================================================
--  Launch
-- ============================================================

local function run()
    local frame = basalt.createFrame():setTitle("Bart Membership - Admin")
    showMainMenu(frame)
    basalt.autoUpdate()
end

return { run = run }
