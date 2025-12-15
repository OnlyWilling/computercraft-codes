-- liar.lua
-- Liar's Bar Server - FINAL PERFECT VERSION
-- 修复：质疑后仍可出牌/质疑空气、last_play 未清空
-- 新增：每人独立轮盘、强制出完手牌自动揭示、音效完整、状态永不残留

local modem = peripheral.find("modem")
if not modem then error("Wireless Modem required") end
rednet.open(peripheral.getName(modem))

-- 扬声器支持
local speaker = peripheral.find("speaker")
local function playSound(name, vol)
    if speaker then speaker.playSound(name, vol or 1) end
end

print("Liar's Bar Server running at ID:", os.getComputerID())

----------------------------------------------
-- 配置
----------------------------------------------
local PROTOCOL = "LIARS_BAR_FINAL"
local MAX_PLAYERS = 4
local TIMEOUT_ACTION = 25
local MAX_PLAY_PER_TURN = 3

----------------------------------------------
-- 全局状态
----------------------------------------------
local players = {}      -- [seat] = {id, name, alive, hand, bullet_idx, live_bullet}
local rednet_map = {}   -- [computer_id] → seat

local gameState = {
    phase = "LOBBY",     -- LOBBY, ACTION, REVEAL, SHOOT, GAME_OVER
    turn_seat = 1,
    target_card = "",
    table_stack = 0,
    table_pile = {},     -- 本轮所有出过的牌（用于强制揭示时显示）
    last_play = nil,     -- 上一次出牌记录
    was_force_round_end = false,
    deadline = 0
}

----------------------------------------------
-- 工具函数
----------------------------------------------
local function broadcast(type, payload)
    rednet.broadcast({type = type, payload = payload}, PROTOCOL)
end

local function sendPrivate(seat, type, payload)
    local p = players[seat]
    if p and p.id then
        rednet.send(p.id, {type = type, payload = payload}, PROTOCOL)
    end
end

local function generateDeck()
    local deck = {}
    local types = {"A", "K", "Q", "J", "JK"}
    for _, t in ipairs(types) do
        for i=1,4 do table.insert(deck, t) end
    end
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

local function dealCards()
    local deck = generateDeck()
    local ptr = 1
    for seat=1, MAX_PLAYERS do
        if players[seat] and players[seat].alive then
            players[seat].hand = {}
            for i=1,5 do
                table.insert(players[seat].hand, deck[ptr])
                ptr = ptr + 1
            end
            sendPrivate(seat, "PRIVATE_HAND", {hand = players[seat].hand})
        end
    end
end

local function initRoulette(seat)
    players[seat].bullet_idx = 0
    players[seat].live_bullet = math.random(1,6)
end

local function getNextAlive(seat)
    local s = seat
    for _=1,4 do
        s = (s % 4) + 1
        if players[s] and players[s].alive then return s end
    end
    return seat
end

-- 关键修复：彻底清空桌面 + last_play
local function clearDesk()
    gameState.table_pile = {}
    gameState.table_stack = 0
    gameState.last_play = nil          -- 必须清空！
end

local function rollNewTarget()
    local t = {"A", "K", "Q", "J"}
    gameState.target_card = t[math.random(4)]
end

local function syncState()
    local summary = {}
    for seat=1,MAX_PLAYERS do
        local p = players[seat]
        if p then
            summary[seat] = {
                name = p.name,
                alive = p.alive,
                card_count = #p.hand,
                gun_status = (p.bullet_idx or 0).."/6"
            }
        end
    end

    broadcast("GAME_STATE", {
        phase = gameState.phase,
        turn_seat = gameState.turn_seat,
        target_card = gameState.target_card,
        table_stack = gameState.table_stack,
        last_play = gameState.last_play,
        players = summary
    })
end

local function startRound()
    gameState.phase = "ACTION"
    rollNewTarget()
    clearDesk()                        -- 确保干净
    gameState.was_force_round_end = false
    gameState.deadline = os.clock() + TIMEOUT_ACTION
    syncState()
    playSound("block.note_block.harp", 0.8)
end

----------------------------------------------
-- 开枪逻辑（每人独立轮盘）
----------------------------------------------
local function executeShooting(victim)
    local p = players[victim]
    p.bullet_idx = p.bullet_idx + 1

    local isBang = (p.bullet_idx == p.live_bullet) or (p.bullet_idx >= 6)
    local result = isBang and "BANG" or "CLICK"

    broadcast("EVENT_SHOOT", {victim = victim, result = result})

    if isBang then
        playSound("entity.generic.explode")
    else
        playSound("block.iron_trapdoor.close", 0.7)
    end

    sleep(3)

    -- 无论结果如何，先彻底清桌（关键！）
    clearDesk()

    if isBang then
        p.alive = false
        local aliveCount = 0
        local winner = ""
        for _, pl in pairs(players) do
            if pl.alive then aliveCount = aliveCount + 1; winner = pl.name end
        end

        if aliveCount <= 1 then
            broadcast("GAME_OVER", {winner = winner})
            gameState.phase = "GAME_OVER"
            syncState()
            playSound("entity.ender_dragon.death")
            return
        end

        -- 有人死 → 重置所有人生还者的轮盘 + 重新发牌
        for s=1,MAX_PLAYERS do
            if players[s] and players[s].alive then
                initRoulette(s)
            end
        end
        local nextSeat = getNextAlive(victim)
        gameState.turn_seat = nextSeat
        dealCards()
        startRound()
        return
    end

    -- CLICK 存活
    if gameState.was_force_round_end then
        gameState.was_force_round_end = false
        local nextSeat = getNextAlive(victim)
        gameState.turn_seat = nextSeat
        dealCards()
        startRound()
        return
    end

    -- 普通继续
    local nextSeat = getNextAlive(victim)
    gameState.turn_seat = nextSeat
    gameState.phase = "ACTION"
    gameState.deadline = os.clock() + TIMEOUT_ACTION
    syncState()
    playSound("block.note_block.harp", 0.8)
end

----------------------------------------------
-- 主循环
----------------------------------------------
local function gameLoop()
    while true do
        if gameState.phase == "LOBBY" then
            local count = 0
            for i=1,MAX_PLAYERS do if players[i] then count = count + 1 end end
            if count == MAX_PLAYERS then
                print("All 4 players joined. Game starting!")
                for s=1,MAX_PLAYERS do initRoulette(s) end
                dealCards()
                startRound()
            end
        end

        if gameState.phase == "ACTION" and os.clock() > gameState.deadline then
            gameState.deadline = os.clock() + 10
            print("Timeout - Player", gameState.turn_seat, "thinking too long...")
        end

        sleep(0.2)
    end
end

----------------------------------------------
-- 网络事件处理
----------------------------------------------
local function netLoop()
    while true do
        local _, id, msg, proto = os.pullEvent("rednet_message")
        if proto ~= PROTOCOL or not msg or not msg.type then goto continue end

        -- 加入大厅
        if msg.type == "JOIN_REQUEST" and gameState.phase == "LOBBY" then
            if rednet_map[id] then goto continue end

            local seat = nil
            for s=1,MAX_PLAYERS do
                if not players[s] then seat = s; break end
            end
            if not seat then goto continue end

            players[seat] = {
                id = id,
                name = "P"..seat,
                alive = true,
                hand = {},
                bullet_idx = 0,
                live_bullet = math.random(1,6)
            }
            rednet_map[id] = seat
            sendPrivate(seat, "JOIN_ACK", {seat = seat})
            syncState()
            print("Player joined: P"..seat.." (ID:"..id..")")
        else
            -- 游戏内操作
            local seat = rednet_map[id]
            if not seat or not players[seat] or not players[seat].alive then goto continue end
            if gameState.phase ~= "ACTION" or seat ~= gameState.turn_seat then goto continue end

            local p = players[seat]

            -- 出牌
            if msg.type == "ACTION_PLAY" then
                local cards = msg.payload.cards or {}
                if #cards == 0 then goto continue end

                local toPlay = {}
                for i=1,math.min(#cards, MAX_PLAY_PER_TURN) do table.insert(toPlay, cards[i]) end

                -- 从手牌移除并加入桌面堆
                for _, c in ipairs(toPlay) do
                    for i=#p.hand,1,-1 do
                        if p.hand[i] == c then
                            table.remove(p.hand, i)
                            table.insert(gameState.table_pile, c)
                            break
                        end
                    end
                end

                sendPrivate(seat, "PRIVATE_HAND", {hand = p.hand})

                gameState.last_play = {seat = seat, count = #toPlay, cards = toPlay}
                gameState.table_stack = gameState.table_stack + #toPlay

                local nextSeat = getNextAlive(seat)
                gameState.turn_seat = nextSeat
                gameState.deadline = os.clock() + TIMEOUT_ACTION
                syncState()
                playSound("block.note_block.pling", 1.2)

                -- 出完手牌 → 强制揭示
                if #p.hand == 0 then
                    gameState.phase = "REVEAL"
                    gameState.was_force_round_end = true

                    broadcast("EVENT_FORCE_REVEAL", {
                        emptied_player = seat,
                        next_player = nextSeat,
                        table_cards = gameState.table_pile
                    })
                    sleep(1.5)

                    local isLiar = false
                    for _,c in ipairs(toPlay) do
                        if c ~= gameState.target_card and c ~= "JK" then isLiar = true; break end
                    end

                    broadcast("EVENT_REVEAL", {
                        challenger = nextSeat,
                        victim = seat,
                        actual_cards = gameState.table_pile,
                        is_liar = isLiar
                    })
                    playSound("block.bell.use", 1.5)
                    sleep(2.5)

                    local loser = isLiar and seat or nextSeat
                    executeShooting(loser)
                end

            -- 质疑
            elseif msg.type == "ACTION_LIAR" and gameState.last_play then
                local prev = gameState.last_play

                playSound("block.bell.use", 1.5)
                broadcast("EVENT_CALL_LIAR", {challenger = seat})
                gameState.phase = "REVEAL"
                gameState.was_force_round_end = false
                sleep(1.5)

                local isLiar = false
                for _,c in ipairs(prev.cards) do
                    if c ~= gameState.target_card and c ~= "JK" then isLiar = true; break end
                end

                broadcast("EVENT_REVEAL", {
                    challenger = seat,
                    victim = prev.seat,
                    actual_cards = prev.cards,
                    is_liar = isLiar
                })
                sleep(2.5)

                local loser = isLiar and prev.seat or seat
                executeShooting(loser)
            end
        end

        ::continue::
    end
end

parallel.waitForAny(gameLoop, netLoop)