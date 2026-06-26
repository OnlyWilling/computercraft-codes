----------------------------------------------
-- 配置与状态
----------------------------------------------
local core          = require("nimmt_core")
local utils         = require("utils")
local PROTOCOL      = "NIMMT"
local MAX_PLAYERS   = 7  -- 牛头王支持 2-10 人，这里设7
local MAX_BULLHEADS = 66 -- 默认模式最大吃墩牛头数
local gameState     = {
    phase = "LOBBY",
    hostID = nil,              -- 房主ID (第一个加入的人)
    rows = { {}, {}, {}, {} }, -- 4行
    players = {},              -- 玩家数据
    playerOrder = {},          -- 玩家加入顺序（用于分配 localIndex）
    turnSelections = {},       -- 当前轮次玩家选中的牌
    turnCards = {},            -- 当前轮次玩家打出的牌

    blockingPlayer = nil,      -- 当前卡住游戏、正在思考选行的玩家ID
    blockingCard = nil,        -- 当前卡住的那张牌的数据结构
}

local turnTimer     = nil -- 当前回合倒计时 timer ID


-- 生成 1-104 的牌堆
local function generateDeck()
    local deck = {}
    for i = 1, 104 do table.insert(deck, i) end
    -- 洗牌算法
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

-- 辅助函数：检查手牌里有没有这张牌
local function hasCard(hand, cardVal)
    for index, c in ipairs(hand) do
        if c == cardVal then return index end -- 返回这张牌在手牌中的位置
    end
    return nil
end

local function localID(pid)
    return gameState.players[pid] and gameState.players[pid].localIndex or pid
end

-- 带标签的日志输出，自动将数字染蓝色
local function log(tag, msg)
    local tagColors = { Lobby = colors.lightBlue, Log = colors.yellow, Act = colors.orange, Error = colors.red }
    local segments = { { "[" .. tag .. "]", tagColors[tag] or colors.gray }, { utils.getTimestamp(), colors.gray } }
    for part in msg:gmatch("%S+") do
        local color = tonumber(part) and colors.blue or colors.white
        table.insert(segments, { part, color })
        table.insert(segments, { " ", colors.white })
    end
    utils.printColored(segments, "fast")
end

local function broadcastScores()
    local scores = {}
    for pid, p in pairs(gameState.players) do
        table.insert(scores, { id = pid, localIndex = p.localIndex, score = p.score })
    end
    rednet.broadcast({ type = "sync_scoreUpdate", scores = scores }, PROTOCOL)
end

-- 开启新的一轮（重新发牌）
local function startNewRound()
    log("Log", "Starting New Round...")
    local deck = generateDeck()

    -- 重置桌面
    gameState.rows = { { table.remove(deck) }, { table.remove(deck) }, { table.remove(deck) }, { table.remove(deck) } }

    -- 移除上一轮的 AFK 玩家
    for pid, p in pairs(gameState.players) do
        if p.afk then
            p.connected = false
            rednet.send(pid, { type = "msg_afk" }, PROTOCOL)
            log("Act", "Player " .. localID(pid) .. " removed for AFK")
        end
    end

    -- 重新发牌（跳过断线/AFK玩家）
    for pid, p in pairs(gameState.players) do
        if p.connected then
            p.hand = {}
            for i = 1, 10 do table.insert(p.hand, table.remove(deck)) end
            rednet.send(pid, { type = "sync_dealHand", hand = p.hand }, PROTOCOL)
        end
    end

    gameState.phase = "SELECTION"
    -- 广播包含 "roundReset=true" 告诉客户端清空上一轮的显示
    rednet.broadcast(
        { type = "ev_gameStart", rows = gameState.rows, roundReset = true, playerList = gameState.playerOrder }, PROTOCOL)
    broadcastScores()
    rednet.broadcast({ type = "msg_toast", msg = "=== NEW ROUND STARTED ===" }, PROTOCOL)
    turnTimer = os.startTimer(20)
end

----------------------------------------------
-- 核心逻辑：放置牌的算法 (牛头王精髓)
----------------------------------------------
local function resolveTurn()
    if #gameState.turnCards == 0 then
        os.sleep(1)
        local anyPlayerID = next(gameState.players)
        if anyPlayerID and #gameState.players[anyPlayerID].hand == 0 then
            log("Log", "Round Over. Checking scores...")
            gameState.phase = "ROUND_OVER"
            rednet.broadcast({ type = "ev_roundOver" }, PROTOCOL)
            local isGameOver = false
            for pid, p in pairs(gameState.players) do
                if p.score >= MAX_BULLHEADS then isGameOver = true end
            end

            broadcastScores()
            os.sleep(3) -- 展示分数

            if isGameOver then
                rednet.broadcast({ type = "ev_gameOver" }, PROTOCOL)
                log("Log", "Game Over triggered.")
            else
                startNewRound() -- 分数没爆，继续下一轮
            end
        else
            gameState.phase = "SELECTION" -- 还有牌，继续下一轮
            rednet.broadcast({ type = "ev_newTurn" }, PROTOCOL)
            turnTimer = os.startTimer(20)
        end
        return
    end

    local currentPlay = gameState.turnCards[1]
    local card = currentPlay.card
    local pid = currentPlay.id

    -- 寻找最合适的行
    local bestRowIndex = -1
    local minDiff = 105

    for i = 1, 4 do
        local row = gameState.rows[i]
        local lastCard = row[#row]

        if card > lastCard then
            local diff = card - lastCard
            if diff < minDiff then
                minDiff = diff
                bestRowIndex = i
            end
        end
    end

    -- 情况A: 牌比所有行的最后一张都小
    if bestRowIndex == -1 then
        gameState.phase = "WAITING_CHOICE"
        gameState.blockingPlayer = pid
        gameState.blockingCard = card
        log("Act", "Waiting for Player " .. localID(pid) .. " to choose row...")
        rednet.send(pid, {
            type = "req_rowChoice",
            card = card,
            rows = gameState.rows -- 把当前残局发给他参考
        }, PROTOCOL)
        rednet.broadcast({ type = "ev_waitingStatus", targetID = pid }, PROTOCOL)
        turnTimer = os.startTimer(20)
        return
    else -- 情况B: 正常接牌
        local targetRow = gameState.rows[bestRowIndex]
        if #targetRow >= 5 then
            local penalty = core.getRowBullHeads(targetRow)
            gameState.players[pid].score = gameState.players[pid].score - penalty
            broadcastScores()
            log("Log", "Player " .. localID(pid) .. " exploded row " .. bestRowIndex .. " (-" .. penalty .. ")")

            gameState.rows[bestRowIndex] = { card }
            rednet.broadcast({
                type = "msg_toast",
                msg = "P" .. localID(pid) .. " ate " .. penalty .. " heads!"
            }, PROTOCOL)
        else
            table.insert(targetRow, card)
        end
    end

    -- 广播更新后的桌面，让大家看到牌放进去了
    table.remove(gameState.turnCards, 1)
    rednet.broadcast({ type = "sync_updateBoard", rows = gameState.rows }, PROTOCOL)
    sleep(1)      -- 停顿一下增加紧张感

    resolveTurn() -- 递归调用，开头判断打断
end

-- 所有玩家出齐后进入结算阶段
local function startShowdown()
    if turnTimer then
        os.cancelTimer(turnTimer)
        turnTimer = nil
    end
    gameState.phase = "SHOWDOWN"
    gameState.turnCards = {}
    for pid, c in pairs(gameState.turnSelections) do
        table.insert(gameState.turnCards, { id = pid, card = c })
        local pData = gameState.players[pid]
        local idx = hasCard(pData.hand, c)
        if idx then
            table.remove(pData.hand, idx)
            rednet.send(pid, { type = "sync_updateHand", hand = pData.hand }, PROTOCOL)
        end
    end
    gameState.turnSelections = {}
    table.sort(gameState.turnCards, function(a, b) return a.card < b.card end)
    rednet.broadcast({ type = "sync_turnSummary", turnCards = gameState.turnCards }, PROTOCOL)
    os.sleep(1.5)
    resolveTurn()
end

-- 回合倒计时超时处理：AFK 玩家自动出牌/选行
local function handleTurnTimeout()
    local phase = gameState.phase
    turnTimer = nil
    if phase == "SELECTION" then
        -- 先自动出牌：对 connected && 未出牌 && 非 AFK 的玩家打出手牌[1]
        for pid, p in pairs(gameState.players) do
            if p.connected and not gameState.turnSelections[pid] and #p.hand > 0 then
                local card = p.hand[1]
                gameState.turnSelections[pid] = card
                p.afk = true
                log("Act", "Player " .. localID(pid) .. " AFK, auto-play " .. card)
                rednet.send(pid, { type = "msg_afk" }, PROTOCOL)
            end
        end
        -- 再统计所有已出牌人数（含刚被自动出的 AFK 玩家）
        local played = 0
        for pid, p in pairs(gameState.players) do
            if p.connected and gameState.turnSelections[pid] then
                played = played + 1
            end
        end
        local playerCount = 0
        for _, p in pairs(gameState.players) do
            if p.connected then playerCount = playerCount + 1 end
        end
        if played >= playerCount then startShowdown() end
    elseif phase == "WAITING_CHOICE" then
        local pid = gameState.blockingPlayer
        if pid and gameState.players[pid] then
            gameState.players[pid].afk = true
            log("Act", "Player " .. localID(pid) .. " AFK, auto-choose Row 1")
            rednet.send(pid, { type = "msg_afk" }, PROTOCOL)
            local penalty = core.getRowBullHeads(gameState.rows[1])
            gameState.players[pid].score = gameState.players[pid].score - penalty
            broadcastScores()
            rednet.broadcast(
                { type = "msg_toast", msg = "P" .. localID(pid) .. " (AFK) chose row 1 (-" .. penalty .. ")" }, PROTOCOL)
            gameState.rows[1] = { gameState.blockingCard }
            gameState.blockingPlayer = nil; gameState.blockingCard = nil
            table.remove(gameState.turnCards, 1)
            rednet.broadcast({ type = "sync_updateBoard", rows = gameState.rows }, PROTOCOL)
            resolveTurn()
        end
    end
end

----------------------------------------------
-- 网络循环
----------------------------------------------
local function net_loop()
    while true do
        local event, id, msg, protocol = os.pullEventRaw()

        if event == "terminate" then
            log("Error", "Server shutting down, notifying clients...")
            rednet.broadcast({ type = "ev_serverClosing", msg = "Server shutdown!" }, PROTOCOL)
            return
        end

        -- 过滤非本协议事件 + 处理回合倒计时
        if event == "timer" then
            if id == turnTimer then handleTurnTimeout() end
        elseif event ~= "rednet_message" or protocol ~= PROTOCOL or type(msg) ~= "table" then
            -- 玩家加入
        elseif msg.type == "act_joinRoom" and gameState.phase == "LOBBY" then
            if not gameState.players[id] then
                table.insert(gameState.playerOrder, id)
                local idx = #gameState.playerOrder
                gameState.players[id] = {
                    id = id,
                    score = 66,
                    hand = {},
                    localIndex = idx,
                    connected = true,
                    afk = false,
                    lastSeen =
                        os.clock()
                }
                log("Lobby", "Player " .. localID(id) .. " joined (PC id = " .. id .. ").")
                -- 广播玩家列表（playerOrder 即为按加入顺序的 PC ID 数组）
                rednet.broadcast({ type = "sync_lobbyUpdate", playerList = gameState.playerOrder }, PROTOCOL)
                -- 如果是第一个人，设为房主
                if gameState.hostID == nil then
                    gameState.hostID = id
                    log("Lobby", "Player " .. localID(id) .. " is now the HOST.")
                    rednet.send(id, { type = "ev_setHost" }, PROTOCOL) -- 告诉客户端你是房主
                end
            end

            -- 游戏开始
        elseif msg.type == "act_startGame" and gameState.phase == "LOBBY" then
            if gameState.players[id] then gameState.players[id].lastSeen = os.clock() end
            if id == gameState.hostID then
                log("Act", "Host started the game!")
                startNewRound()
            else
                rednet.send(id, { type = "msg_error", msg = "Only Host can start" }, PROTOCOL)
            end

            -- 玩家出牌
        elseif msg.type == "act_playCard" and gameState.phase == "SELECTION" then
            if gameState.players[id] then gameState.players[id].lastSeen = os.clock() end
            local card = msg.card
            if type(card) ~= "number" then return end
            if not hasCard(gameState.players[id].hand, card) then
                log("Error", "Player " .. localID(id) .. " tried to cheat with card " .. card)
                return
            end

            if gameState.turnSelections[id] ~= nil then
                log("Log", "Player " .. localID(id) .. " changed selection to " .. card)
                rednet.send(id, {
                    type = "msg_toast",
                    msg = "Selection updated to " .. card
                }, PROTOCOL)
            else
                log("Log", "Player " .. localID(id) .. " selected " .. card)
            end

            gameState.turnSelections[id] = card -- 存入 Map，重复发送会自动覆盖旧的
            -- 检查是否所有人都出牌了
            local readyCount = 0
            for _ in pairs(gameState.turnSelections) do readyCount = readyCount + 1 end
            local playerCount = 0
            for _, p in pairs(gameState.players) do
                if p.connected then playerCount = playerCount + 1 end
            end

            -- 广播在线人数（当前在线/开局总人数）
            rednet.broadcast({ type = "sync_statusUpdate", current = playerCount, total = #gameState.playerOrder }, PROTOCOL)

            if readyCount >= playerCount then
                startShowdown()
            end
        elseif msg.type == "act_chooseRow" and gameState.phase == "WAITING_CHOICE" then
            if id ~= gameState.blockingPlayer then return end
            if turnTimer then
                os.cancelTimer(turnTimer); turnTimer = nil
            end
            if gameState.players[id] then gameState.players[id].lastSeen = os.clock() end

            local rowIdx = msg.rowIndex
            if type(rowIdx) ~= "number" or rowIdx < 1 or rowIdx > 4 then return end
            log("Log", "Player " .. localID(id) .. " chose Row " .. rowIdx)
            local penalty = core.getRowBullHeads(gameState.rows[rowIdx])
            gameState.players[id].score = gameState.players[id].score - penalty
            broadcastScores()
            rednet.broadcast({
                type = "msg_toast",
                msg = "P" .. localID(id) .. " chose Row " .. rowIdx .. " (-" .. penalty .. ")"
            }, PROTOCOL)

            gameState.rows[rowIdx] = { gameState.blockingCard }
            gameState.blockingPlayer = nil
            gameState.blockingCard = nil

            table.remove(gameState.turnCards, 1)
            rednet.broadcast({ type = "sync_updateBoard", rows = gameState.rows }, PROTOCOL)

            resolveTurn()
        elseif msg.type == "act_afkResume" then
            if gameState.players[id] then
                gameState.players[id].afk = false
                gameState.players[id].connected = true
                log("Log", "Player " .. localID(id) .. " resumed from AFK")
                rednet.send(id, { type = "msg_toast", msg = "Welcome back!" }, PROTOCOL)
            end
        end
    end
end

local function heartbeat_loop()
    while true do
        os.sleep(5)
        rednet.broadcast({ type = "ev_heartbeat" }, PROTOCOL)
        -- 检测超时断线的客户端
        local now = os.clock()
        for pid, p in pairs(gameState.players) do
            if p.connected and now - p.lastSeen > 60 then
                p.connected = false
                -- 不清除 turnSelections：turnTimer(20s) 先触发时已自动出牌，清除会撤销
                log("Log", "Player " .. localID(pid) .. " timed out (PC " .. pid .. ")")
                rednet.broadcast({ type = "msg_toast", msg = "P" .. localID(pid) .. " disconnected" }, PROTOCOL)
                local onlineCount = 0
                for _, pl in pairs(gameState.players) do
                    if pl.connected then onlineCount = onlineCount + 1 end
                end
                rednet.broadcast({ type = "sync_statusUpdate", current = onlineCount, total = #gameState.playerOrder }, PROTOCOL)
                broadcastScores()
            end
        end
    end
end

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem found") end
rednet.open(peripheral.getName(modem))
rednet.host(PROTOCOL, "NIMMT_SERVER")
log("Log", "Server registered as 'NIMMT_SERVER'")
log("Log", "Server started on ID: " .. os.getComputerID())
log("Lobby", "Waiting for Host to START...")

parallel.waitForAny(net_loop, heartbeat_loop)
