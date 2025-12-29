local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem found") end
rednet.open(peripheral.getName(modem))
rednet.host(PROTOCOL, "NIMMT_SERVER")
print("Server registered as 'NIMMT_SERVER'")

----------------------------------------------
-- 配置与状态
----------------------------------------------
local PROTOCOL = "NIMMT"
local MAX_PLAYERS = 7 -- 牛头王支持 2-10 人，这里设7
local gameState = {
    phase = "LOBBY",
    host_id = nil,             -- 房主ID (第一个加入的人)
    rows = { {}, {}, {}, {} }, -- 4行
    players = {},              -- 玩家数据
    turn_selections = {},      -- 当前轮次玩家选中的牌
    turn_cards = {},           -- 当前轮次玩家打出的牌

    blocking_player = nil,     -- 当前卡住游戏、正在思考选行的玩家ID
    blocking_card = nil,       -- 当前卡住的那张牌的数据结构
}

--- 计算一张牌的牛头数
--- @param index number 牌的编号
--- @return number res 牌的牛头数
local function getCardScore(index)
    if index == 55 then return 7 end     -- 55号牌：7个牛头
    if index % 11 == 0 then return 5 end -- 11, 22...: 5个牛头
    if index % 10 == 0 then return 3 end -- 10, 20...: 3个牛头
    if index % 5 == 0 then return 2 end  -- 5, 15...: 2个牛头
    return 1                             -- 其他：1个牛头
end

--- 计算一整行的牛头总数
--- @param row table 输入一行牌
--- @return number res 改行牌的牛头数
local function getRowScore(row)
    local sum = 0
    for _, card in ipairs(row) do
        sum = sum + getCardScore(card)
    end
    return sum
end

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

----------------------------------------------
-- 核心逻辑：放置牌的算法 (牛头王精髓)
----------------------------------------------
local function resolveTurn()
    if #gameState.turn_cards == 0 then
        -- 广播更新后的桌面
        rednet.broadcast({ type = "UPDATE_BOARD", rows = gameState.rows }, PROTOCOL)
        sleep(1) -- 展示最终结果

        local anyPlayerID = next(gameState.players)
        if anyPlayerID and #gameState.players[anyPlayerID].hand == 0 then
            print("Round finished! Calculation scores...")
            gameState.phase = "ROUND_OVER"
            -- 这里未来可以写：重置桌面、重新发牌、计算总分等
            -- rednet.broadcast({ type = "ROUND_END" }, PROTOCOL)
        else
            gameState.phase = "SELECTION" -- 还有牌，继续下一轮
            rednet.broadcast({ type = "NEW_TURN" }, PROTOCOL)
        end
        return
    end

    local currentPlay = gameState.turn_cards[1]
    local card = currentPlay.card
    local playerID = currentPlay.id

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
        gameState.blocking_player = playerID
        gameState.blocking_card = card
        print("Card too small, strictly logic required here.")
        rednet.send(playerID, {
            type = "REQUEST_ROW_CHOICE",
            card = card,
            rows = gameState.rows -- 把当前残局发给他参考
        }, PROTOCOL)
        return
    else -- 情况B: 正常接牌
        local targetRow = gameState.rows[bestRowIndex]
        if #targetRow >= 5 then
            local penalty = getRowScore(targetRow)
            gameState.players[pid].score = gameState.players[pid].score - penalty
            print("Player " .. pid .. " exploded row " .. bestRowIndex .. " (-" .. penalty .. ")")

            gameState.rows[bestRowIndex] = { card }
            rednet.broadcast({
                type = "TOAST",
                msg = "P" .. pid .. " ate " .. penalty .. " heads!"
            }, PROTOCOL)
        else
            table.insert(targetRow, card)
        end
    end

    -- 广播更新后的桌面，让大家看到牌放进去了
    table.remove(gameState.turn_cards, 1)
    rednet.broadcast({ type = "UPDATE_BOARD", rows = gameState.rows }, PROTOCOL)
    sleep(1)      -- 停顿一下增加紧张感

    resolveTurn() -- 递归调用，开头判断打断
end

----------------------------------------------
-- 网络循环
----------------------------------------------
print("Server started on ID: " .. os.getComputerID())
print("Waiting for Host to START...")

local function net_loop()
    while true do
        local id, msg = rednet.receive(PROTOCOL)

        -- 玩家加入
        if msg.type == "JOIN" and gameState.phase == "LOBBY" then
            if not gameState.players[id] then
                gameState.players[id] = { id = id, score = 66, hand = {} }
                print("Player " .. id .. " joined.")
                -- 如果是第一个人，设为房主
                if gameState.host_id == nil then
                    gameState.host_id = id
                    print("Player " .. id .. " is now the HOST.")
                    rednet.send(id, { type = "SET_HOST" }, PROTOCOL) -- 告诉客户端你是房主
                end
                -- 广播当前人数
                local count = 0
                for _ in pairs(gameState.players) do count = count + 1 end
                rednet.broadcast({ type = "LOBBY_UPDATE", count = count }, PROTOCOL)
            end

            -- 游戏开始
        elseif msg.type == "START" and gameState.phase == "LOBBY" then
            if id == gameState.host_id then
                print("Host started the game!")
                local deck = generateDeck()

                -- 初始化桌面4行，每行随机放一张
                gameState.rows = { { table.remove(deck) }, { table.remove(deck) }, { table.remove(deck) }, { table.remove(deck) } }

                -- 发牌 (每人10张)
                for pid, p in pairs(gameState.players) do
                    p.hand = {}
                    for i = 1, 10 do table.insert(p.hand, table.remove(deck)) end
                    -- 发送手牌给个人
                    rednet.send(pid, { type = "DEAL_HAND", hand = p.hand }, PROTOCOL)
                end

                gameState.phase = "SELECTION"
                rednet.broadcast({ type = "GAME_START", rows = gameState.rows }, PROTOCOL)
            else
                rednet.send(id, { type = "ERROR", msg = "Only Host can start" }, PROTOCOL)
            end

            -- 玩家出牌
        elseif msg.type == "PLAY_CARD" and gameState.phase == "SELECTION" then
            local card = msg.card
            if type(card) ~= "number" then return end
            if not hasCard(gameState.players[id].hand, card) then
                print("Player " .. id .. " tried to cheat with card " .. card)
                return
            end
            gameState.turn_selections[id] = card -- 存入 Map，重复发送会自动覆盖旧的
            if gameState.turn_selections[id] ~= nil then
                print("Player " .. id .. " changed selection to " .. card)
                rednet.send(id, {
                    type = "TOAST",
                    msg = "Selection updated to " .. card
                }, PROTOCOL)
            else
                print("Player " .. id .. " selected " .. card)
            end
            -- 检查是否所有人都出牌了
            local readyCount = 0
            for _ in pairs(gameState.turn_selections) do readyCount = readyCount + 1 end
            local playerCount = 0
            for _ in pairs(gameState.players) do playerCount = playerCount + 1 end

            -- 可选：广播进度给所有人（如 "Waiting for players: 5/7"）
            rednet.broadcast({ type = "STATUS_UPDATE", current = readyCount, total = playerCount }, PROTOCOL)

            if readyCount >= playerCount then -- 若在角逐战模式中，当有人被淘汰后，这里ready肯定就达不到playercount了，得修改逻辑
                gameState.phase = "SHOWDOWN"
                gameState.turn_cards = {}     -- 把 Map 转回 List 以便排序结算
                for pid, c in pairs(gameState.turn_selections) do
                    table.insert(gameState.turn_cards, { id = pid, card = c })
                    local pData = gameState.players[pid]
                    local idx = hasCard(pData.hand, c)
                    if idx then
                        table.remove(pData.hand, idx)
                        rednet.send(pid, { type = "UPDATE_HAND", hand = pData.hand }, PROTOCOL)
                    end
                end
                gameState.turn_selections = {}
                table.sort(gameState.turn_cards, function(a, b) return a.card < b.card end)
                resolveTurn() -- 结算本轮
            end
        elseif msg.type == "CHOOSE_ROW" and gameState.phase == "WAITING_CHOICE" then
            if id ~= gameState.blocking_player then return end

            local rowIdx = msg.rowIndex
            if type(rowIdx) ~= "number" or rowIdx < 1 or rowIdx > 4 then return end
            print("Player " .. id .. " chose row " .. rowIdx)
            local penalty = getRowScore(gameState.rows[rowIdx])
            gameState.players[id].score = gameState.players[id].score - penalty
            rednet.broadcast({
                type = "TOAST",
                msg = "P" .. id .. " chose row " .. rowIdx .. " (-" .. penalty .. ")"
            }, PROTOCOL)

            gameState.rows[rowIdx] = { gameState.blocking_card }
            gameState.blocking_player = nil
            gameState.blocking_card = nil

            table.remove(gameState.turn_cards, 1)
            rednet.broadcast({ type = "UPDATE_BOARD", rows = gameState.rows }, PROTOCOL)

            resolveTurn()
        end
    end
end

net_loop()
