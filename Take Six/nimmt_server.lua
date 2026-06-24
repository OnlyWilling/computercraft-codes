----------------------------------------------
-- 配置与状态
----------------------------------------------
local core = require("nimmt_core")
local PROTOCOL = "NIMMT"
local MAX_PLAYERS = 7    -- 牛头王支持 2-10 人，这里设7
local MAX_BULLHEADS = 66 -- 默认模式最大吃墩牛头数
local gameState = {
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

local function broadcastScores()
    local scores = {}
    for pid, p in pairs(gameState.players) do
        table.insert(scores, { id = pid, localIndex = p.localIndex, score = p.score })
    end
    rednet.broadcast({ type = "sync_scoreUpdate", scores = scores }, PROTOCOL)
end


-- 开启新的一轮（重新发牌）
local function startNewRound()
    print("Starting NEW ROUND...")
    local deck = generateDeck()

    -- 重置桌面
    gameState.rows = { { table.remove(deck) }, { table.remove(deck) }, { table.remove(deck) }, { table.remove(deck) } }

    -- 重新发牌
    for pid, p in pairs(gameState.players) do
        p.hand = {}
        for i = 1, 10 do table.insert(p.hand, table.remove(deck)) end
        rednet.send(pid, { type = "sync_dealHand", hand = p.hand }, PROTOCOL)
    end

    gameState.phase = "SELECTION"
    -- 广播包含 "roundReset=true" 告诉客户端清空上一轮的显示
    rednet.broadcast({ type = "ev_gameStart", rows = gameState.rows, roundReset = true, playerList = gameState.playerOrder }, PROTOCOL)
    broadcastScores()
    rednet.broadcast({ type = "msg_toast", msg = "=== NEW ROUND STARTED ===" }, PROTOCOL)
end

----------------------------------------------
-- 核心逻辑：放置牌的算法 (牛头王精髓)
----------------------------------------------
local function resolveTurn()
    if #gameState.turnCards == 0 then
        os.sleep(1)
        local anyPlayerID = next(gameState.players)
        if anyPlayerID and #gameState.players[anyPlayerID].hand == 0 then
            print("Round Over. Checking scores...")
            gameState.phase = "ROUND_OVER"
            rednet.broadcast({ type = "ev_roundOver" }, PROTOCOL)
            local isGameOver = false
            for pid, p in pairs(gameState.players) do
                if p.score >= MAX_BULLHEADS then isGameOver = true end
            end

            broadcastScores()
            os.sleep(3) -- 展示分数

            if isGameOver then
                rednet.broadcast({ type = "ev_gameOver", scores = scores }, PROTOCOL)
                print("Game Over triggered.")
            else
                startNewRound() -- 分数没爆，继续下一轮
            end
        else
            gameState.phase = "SELECTION" -- 还有牌，继续下一轮
            rednet.broadcast({ type = "ev_newTurn" }, PROTOCOL)
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
        print("Waiting for Player " .. localID(pid) .. " to choose row...")
        rednet.send(pid, {
            type = "req_rowChoice",
            card = card,
            rows = gameState.rows -- 把当前残局发给他参考
        }, PROTOCOL)
        rednet.broadcast({ type = "ev_waitingStatus", targetID = pid }, PROTOCOL)
        return
    else -- 情况B: 正常接牌
        local targetRow = gameState.rows[bestRowIndex]
        if #targetRow >= 5 then
            local penalty = core.getRowBullHeads(targetRow)
            gameState.players[pid].score = gameState.players[pid].score - penalty
            broadcastScores()
            print("Player " .. localID(pid) .. " exploded row " .. bestRowIndex .. " (-" .. penalty .. ")")

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

----------------------------------------------
-- 网络循环
----------------------------------------------
local function net_loop()
    while true do
        local event, id, msg, protocol = os.pullEventRaw()

        if event == "terminate" then
            print("Server shutting down, notifying clients...")
            rednet.broadcast({ type = "ev_serverClosing", msg = "Host closed the room" }, PROTOCOL)
            return
        end

        -- 过滤非本协议事件
        if event ~= "rednet_message" or protocol ~= PROTOCOL or type(msg) ~= "table" then
            -- 玩家加入
        elseif msg.type == "act_joinRoom" and gameState.phase == "LOBBY" then
            if not gameState.players[id] then
                table.insert(gameState.playerOrder, id)
                local idx = #gameState.playerOrder
                gameState.players[id] = { id = id, score = 66, hand = {}, localIndex = idx }
                print("Player " .. localID(id) .. " joined (PC id=" .. id .. ").")
                -- 广播玩家列表（playerOrder 即为按加入顺序的 PC ID 数组）
                rednet.broadcast({ type = "sync_lobbyUpdate", playerList = gameState.playerOrder }, PROTOCOL)
                -- 如果是第一个人，设为房主
                if gameState.hostID == nil then
                    gameState.hostID = id
                    print("Player " .. localID(id) .. " is now the HOST.")
                    rednet.send(id, { type = "ev_setHost" }, PROTOCOL) -- 告诉客户端你是房主
                end
            end

            -- 游戏开始
        elseif msg.type == "act_startGame" and gameState.phase == "LOBBY" then
            if id == gameState.hostID then
                print("Host started the game!")
                startNewRound()
            else
                rednet.send(id, { type = "msg_error", msg = "Only Host can start" }, PROTOCOL)
            end

            -- 玩家出牌
        elseif msg.type == "act_playCard" and gameState.phase == "SELECTION" then
            local card = msg.card
            if type(card) ~= "number" then return end
            if not hasCard(gameState.players[id].hand, card) then
                print("Player " .. localID(id) .. " tried to cheat with card " .. card)
                return
            end

            if gameState.turnSelections[id] ~= nil then
                print("Player " .. localID(id) .. " changed selection to " .. card)
                rednet.send(id, {
                    type = "msg_toast",
                    msg = "Selection updated to " .. card
                }, PROTOCOL)
            else
                print("Player " .. localID(id) .. " selected " .. card)
            end

            gameState.turnSelections[id] = card -- 存入 Map，重复发送会自动覆盖旧的
            -- 检查是否所有人都出牌了
            local readyCount = 0
            for _ in pairs(gameState.turnSelections) do readyCount = readyCount + 1 end
            local playerCount = 0
            for _ in pairs(gameState.players) do playerCount = playerCount + 1 end

            -- 可选：广播进度给所有人（如 "Waiting for players: 5/7"）
            -- rednet.broadcast({ type = "sync_statusUpdate", current = readyCount, total = playerCount }, PROTOCOL)

            if readyCount >= playerCount then -- 若在角逐战模式中，当有人被淘汰后，这里ready肯定就达不到playercount了，得修改逻辑
                gameState.phase = "SHOWDOWN"
                gameState.turnCards = {}      -- 把 Map 转回 List 以便排序结算
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
                os.sleep(1.5) -- 稍微停顿让玩家看清大家出了什么
                resolveTurn() -- 结算本轮
            end
        elseif msg.type == "act_chooseRow" and gameState.phase == "WAITING_CHOICE" then
            if id ~= gameState.blockingPlayer then return end

            local rowIdx = msg.rowIndex
            if type(rowIdx) ~= "number" or rowIdx < 1 or rowIdx > 4 then return end
            print("Player " .. localID(id) .. " chose row " .. rowIdx)
            local penalty = core.getRowBullHeads(gameState.rows[rowIdx])
            gameState.players[id].score = gameState.players[id].score - penalty
            broadcastScores()
            rednet.broadcast({
                type = "msg_toast",
                msg = "P" .. localID(id) .. " chose row " .. rowIdx .. " (-" .. penalty .. ")"
            }, PROTOCOL)

            gameState.rows[rowIdx] = { gameState.blockingCard }
            gameState.blockingPlayer = nil
            gameState.blockingCard = nil

            table.remove(gameState.turnCards, 1)
            rednet.broadcast({ type = "sync_updateBoard", rows = gameState.rows }, PROTOCOL)

            resolveTurn()
        end
    end
end

local function heartbeat_loop()
    while true do
        os.sleep(5)
        rednet.broadcast({ type = "ev_heartbeat" }, PROTOCOL)
    end
end

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem found") end
rednet.open(peripheral.getName(modem))
rednet.host(PROTOCOL, "NIMMT_SERVER")
print("Server registered as 'NIMMT_SERVER'")
print("Server started on ID: " .. os.getComputerID())
print("Waiting for Host to START...")

parallel.waitForAny(net_loop, heartbeat_loop)
