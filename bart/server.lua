-- ============================================================
--  Bart Membership System - Server
--  Background process handling all rednet requests
--  Usage: bart/server.lua or main run server
-- ============================================================

local network      = require "lib/network"
local member       = require "lib/member"
local security     = require "lib/security"
local tier         = require "lib/tier"
local C            = require "lib/constants"
local utils        = require "lib/utils"

local dataDir      = "data"
local serverSecret = nil

-- ============================================================
--  Init
-- ============================================================

local function init()
    print("[Bart] Initializing server...")

    if not network.init() then
        print("[Bart] W No modem found, local mode only")
    else
        print("[Bart] Network ready, host ID: " .. network.hostID())
    end

    local membersDir = fs.combine(dataDir, "members")
    if not fs.exists(membersDir) then
        fs.makeDir(membersDir)
    end

    local configPath = fs.combine(dataDir, "config.json")
    local config = utils.loadJSONFile(configPath)
    if not config then
        config = {
            serverSecret = security.generateToken(),
            defaultTier  = "dirt",
            created      = os.date("%Y-%m-%dT%H:%M:%S"),
        }
        utils.saveJSONFile(configPath, config)
        print("[Bart] First run: server secret generated")
    end

    serverSecret = config.serverSecret
    print("[Bart] Server started")
    print("[Bart] Data directory: " .. membersDir)
    print("[Bart] Press Ctrl+T to stop")
    print("")
end

-- ============================================================
--  Request handlers
-- ============================================================

local handlers = {}

--- AUTH: verify card
handlers[C.MSG.AUTH] = function(request)
    local diskID      = request.data.diskID
    local cardID      = request.data.cardID
    local token       = request.data.token

    local expectedCID = member.lookupCardID(dataDir, diskID)
    if not expectedCID then
        return { success = false, error = "Card not registered" }
    end
    if expectedCID ~= cardID then
        return { success = false, error = "Card ID mismatch" }
    end

    local m = member.loadMember(dataDir, cardID)
    if not m then
        return { success = false, error = "Member data not found" }
    end
    if not security.verifyToken(token, m.tokenHash, serverSecret) then
        return { success = false, error = "Token verification failed" }
    end
    if not m.active then
        return { success = false, error = "Card is frozen" }
    end

    local safeMember = {
        cardID     = m.cardID,
        playerName = m.playerName,
        tier       = m.tier,
        balance    = m.balance,
        points     = m.points,
        totalSpent = m.totalSpent,
        active     = m.active,
        label      = m.label,
    }
    return { success = true, data = { member = safeMember } }
end

--- CONSUME: spend
handlers[C.MSG.CONSUME] = function(request)
    local cardID = request.data.cardID
    local amount = request.data.amount
    local note   = request.data.note or ""

    if not cardID or not amount or amount <= 0 then
        return { success = false, error = "Invalid parameters" }
    end

    local m = member.loadMember(dataDir, cardID)
    if not m then
        return { success = false, error = "Member not found" }
    end
    if not m.active then
        return { success = false, error = "Card is frozen" }
    end

    local tInfo = C.TIERS[m.tier] or {}
    local finalAmt = amount
    if tInfo.discount and tInfo.discount < 1.0 then
        finalAmt = math.ceil(amount * tInfo.discount)
    end

    if m.balance < finalAmt then
        return { success = false, error = "Insufficient balance" }
    end

    m.balance = m.balance - finalAmt
    local earnedPoints = math.floor(amount * C.DEFAULT_CONFIG.pointsPerCurrency * (tInfo.pointMultiplier or 1))
    m.points = m.points + earnedPoints
    m.totalSpent = m.totalSpent + amount

    local upgraded, newTier = tier.processUpgrade(m)

    member.addHistory(m, "consume", -finalAmt, note .. " (original " .. amount .. ")")
    member.saveMember(dataDir, cardID, m)

    return {
        success = true,
        data = {
            balance      = m.balance,
            points       = m.points,
            tier         = m.tier,
            upgraded     = upgraded,
            newTier      = newTier,
            finalAmount  = finalAmt,
            earnedPoints = earnedPoints,
        }
    }
end

--- RECHARGE: top up
handlers[C.MSG.RECHARGE] = function(request)
    local cardID = request.data.cardID
    local amount = request.data.amount
    local admin  = request.data.admin or ""

    if not cardID or not amount or amount <= 0 then
        return { success = false, error = "Invalid parameters" }
    end

    local m = member.loadMember(dataDir, cardID)
    if not m then
        return { success = false, error = "Member not found" }
    end

    m.balance = m.balance + amount
    member.addHistory(m, "recharge", amount, "Admin: " .. admin)
    member.saveMember(dataDir, cardID, m)

    return {
        success = true,
        data = { balance = m.balance }
    }
end

--- QUERY: lookup
handlers[C.MSG.QUERY] = function(request)
    local cardID = request.data.cardID
    local m = member.loadMember(dataDir, cardID)
    if not m then
        return { success = false, error = "Member not found" }
    end
    return {
        success = true,
        data = {
            cardID     = m.cardID,
            playerName = m.playerName,
            tier       = m.tier,
            balance    = m.balance,
            points     = m.points,
            totalSpent = m.totalSpent,
            active     = m.active,
        }
    }
end

--- FREEZE / UNFREEZE
handlers[C.MSG.FREEZE] = function(request)
    local cardID = request.data.cardID
    local m = member.loadMember(dataDir, cardID)
    if not m then return { success = false, error = "Member not found" } end
    m.active = false
    member.addHistory(m, "freeze", 0, "Admin freeze")
    member.saveMember(dataDir, cardID, m)
    return { success = true, data = { active = false } }
end

handlers[C.MSG.UNFREEZE] = function(request)
    local cardID = request.data.cardID
    local m = member.loadMember(dataDir, cardID)
    if not m then return { success = false, error = "Member not found" } end
    m.active = true
    member.addHistory(m, "unfreeze", 0, "Admin unfreeze")
    member.saveMember(dataDir, cardID, m)
    return { success = true, data = { active = true } }
end

--- LIST_PLAYER: find all cards for a player
handlers[C.MSG.LIST_PLAYER] = function(request)
    local playerName = request.data.playerName
    if not playerName then
        return { success = false, error = "Player name required" }
    end

    local cards = member.lookupByPlayer(dataDir, playerName)
    local result = {}
    for cardID, m in pairs(cards) do
        table.insert(result, {
            cardID    = cardID,
            tier      = m.tier,
            balance   = m.balance,
            active    = m.active,
            createdAt = m.createdAt,
        })
    end
    return { success = true, data = { cards = result } }
end

-- ============================================================
--  Main loop
-- ============================================================

local function run()
    init()

    if not network.isReady() then
        print("[Bart] No network, server stopping")
        print("[Bart] Hint: connect a modem and restart")
        return
    end

    print("[Bart] Waiting for requests...")
    print("")

    local requestCount = 0
    while true do
        local req = network.waitForRequest()
        if not req then
            -- timeout or error, keep going
        else
            requestCount = requestCount + 1

            if req.type == "DISCOVER" then
                network.sendResponse(req.from, true, { type = "DISCOVER_ACK", serverID = network.hostID() })
            elseif not handlers[req.type] then
                network.sendResponse(req.from, false, nil, "Unknown request type: " .. tostring(req.type))
            else
                local handler = handlers[req.type]
                local ok, result = pcall(handler, req)
                if ok then
                    network.sendResponse(req.from, true, result.data or {})
                else
                    network.sendResponse(req.from, false, nil, "Server error: " .. tostring(result))
                end
            end

            if requestCount % 10 == 0 then
                print(string.format("[Bart] Processed %d requests", requestCount))
            end
        end
    end
end

return { run = run }
