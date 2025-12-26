local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem found") end
rednet.open(peripheral.getName(modem))

----------------------------------------------
-- 配置与状态
----------------------------------------------
local PROTOCOL = "NIMMT"
local MAX_PLAYERS = 7 -- 牛头王支持 2-10 人，这里设7
local gameState = {
    phase = "LOBBY",
    rows = { {}, {}, {}, {} }, -- 4行
    players = {},              -- 玩家数据
    turn_selections = {},      -- 当前轮次玩家选中的牌
    turn_cards = {},           -- 当前轮次玩家打出的牌

    blocking_player = nil,     -- 当前卡住游戏、正在思考选行的玩家ID
    blocking_card = nil,       -- 当前卡住的那张牌的数据结构
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
        end
    end
    -- 1. 对玩家出的牌按从小到大排序，这里规则函数会比对turn_cards中不同玩家打出card的大小，最终呈现升序
    table.sort(gameState.turn_cards, function(a, b) return a.card < b.card end)

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

    -- 情况A: 牌比所有行的最后一张都小 (需要由玩家选行，为简化V1版本，暂时自动吃掉牛头最少的一行)
    if bestRowIndex == -1 then
        -- TODO: 发送请求给客户端让玩家选行
        -- 更新状态，进入“中断等待”模式
        gameState.phase = "WAITING_CHOICE"
        gameState.blocking_player = playerID
        gameState.blocking_card = card
        -- V1简化逻辑：自动吃掉分数最少的那一行
        rednet.send(playerID, {
            type = "REQUEST_ROW_CHOICE",
            card = card,
            rows = gameState.rows -- 把当前残局发给他参考
        }, PROTOCOL)
        print("Card too small, strictly logic required here.")
        bestRowIndex = 1                        -- 临时占位逻辑
        gameState.rows[bestRowIndex] = { card } -- 吃掉旧的，放入新的
        -- 这里应该给玩家扣血

        -- 情况B: 正常接牌
    else
        local targetRow = gameState.rows[bestRowIndex]
        if #targetRow >= 5 then
            -- 爆了！吃掉这一行
            gameState.rows[bestRowIndex] = { card }
            -- 这里应该给玩家扣血
        else
            table.insert(targetRow, card)
        end
    end

    -- 广播更新后的桌面，让大家看到牌放进去了
    rednet.broadcast({ type = "UPDATE_BOARD", rows = gameState.rows }, PROTOCOL)
    sleep(1) -- 停顿一下增加紧张感
    table.remove(gameState.turn_cards, 1)

    resolveTurn() -- 递归调用，开头判断打断
end

----------------------------------------------
-- 网络循环
----------------------------------------------
print("Server started on ID: " .. os.getComputerID())

local function net_loop()
    while true do
        local id, msg = rednet.receive(PROTOCOL)

        -- 玩家加入
        if msg.type == "JOIN" then
            if not gameState.players[id] then
                gameState.players[id] = { id = id, score = 0, hand = {} }
                print("Player " .. id .. " joined.")
                rednet.send(id, { type = "WELCOME" }, PROTOCOL)
            end

            -- 游戏开始
        elseif msg.type == "START" and gameState.phase == "LOBBY" then
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

            -- 玩家出牌
        elseif msg.type == "PLAY_CARD" and gameState.phase == "SELECTION" then
            local player = gameState.players[id]
            local card = msg.card

            -- 【防作弊检查 1】：牌必须是合法的数字
            if type(card) ~= "number" then return end

            -- 【防作弊检查 2】：玩家手里必须真的有这张牌
            if not hasCard(player.hand, card) then
                print("Player " .. id .. " tried to cheat with card " .. card)
                return -- 直接忽略作弊请求
            end

            gameState.turn_selections[id] = card -- 存入 Map，重复发送会自动覆盖旧的

            -- 检查是否所有人都出牌了
            local readyCount = 0
            for _ in pairs(gameState.turn_selections) do readyCount = readyCount + 1 end
            local playerCount = 0
            for _ in pairs(gameState.players) do playerCount = playerCount + 1 end

            -- 可选：广播进度给所有人（如 "Waiting for players: 5/7"）
            rednet.broadcast({ type = "STATUS_UPDATE", current = readyCount, total = playerCount }, PROTOCOL)

            if readyCount >= playerCount then
                gameState.phase = "SHOWDOWN"

                -- 把 Map 转回 List 以便排序结算
                gameState.turn_cards = {}
                for pid, c in pairs(gameState.turn_selections) do
                    table.insert(gameState.turn_cards, { id = pid, card = c })
                    -- 【重要】在这里才真正从玩家手牌里扣掉这张牌
                    local idx = hasCard(gameState.players[pid].hand, c)
                    if idx then
                        -- 告诉特定玩家：你的手牌变了，请刷新 UI
                        table.remove(gameState.players[pid].hand, idx)
                        rednet.send(pid, { type = "UPDATE_HAND", hand = gameState.players[pid].hand }, PROTOCOL)
                    end
                end
                gameState.turn_selections = {}
                resolveTurn() -- 结算本轮
            end
        elseif msg.type == "CHOOSE_ROW" and gameState.phase == "WAITING_CHOICE" then
            if id ~= gameState.blocking_player then return end

            local rowIdx = msg.rowIndex
            if type(rowIdx) ~= "number" or rowIdx < 1 or rowIdx > 4 then return end
            print("Player " .. id .. " chose row " .. rowIdx)

            -- 3. 执行吃牌逻辑
            -- 扣分 (略，建议把计算牛头的逻辑封装函数)
            -- gameState.players[id].score -= countBullHeads(gameState.rows[rowIdx])

            -- 把那一行换成当前这张牌
            local card = gameState.blocking_card
            gameState.rows[rowIdx] = { card }

            -- 4. 清除阻塞状态
            gameState.blocking_player = nil
            gameState.blocking_card = nil

            -- 移除队列头部那个已经处理完的牌
            table.remove(gameState.processing_queue, 1)
            rednet.broadcast({ type = "UPDATE_BOARD", rows = gameState.rows }, PROTOCOL)

            -- 5. 【恢复执行】：继续处理队列里剩下的人
            processShowdownQueue()
        end
    end
end

net_loop()
