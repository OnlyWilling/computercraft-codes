-- game.lua
-- Liar's Bar Client
-- 保持：上家指示下移、选择策略（最多3张，选择第4张自动取消最早选中）、显示每人独立轮盘0/6起
-- 骗子酒馆游戏客户端 需要无线调制解调器
-- 主机启动后自动寻找主机
local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem found") end
rednet.open(peripheral.getName(modem))

local PROTOCOL = "LIARS_BAR_FINAL"
local SERVER_ID = nil
local MY_SEAT = nil

-- 颜色
local C_BG = colors.gray
local C_PANEL = colors.lightGray
local C_SEL = colors.orange
local C_OVERLAY_LIAR = colors.red
local C_OVERLAY_TRUTH = colors.lime
local C_OVERLAY_WRONG = colors.yellow
local C_BTN_PLAY = colors.lime
local C_BTN_LIAR = colors.red

-- 状态
local gameState = {
    phase = "CONNECTING",
    players = {},
    round_info = { table_stack = 0, target_card = "", turn_seat = 0 },
    my_hand = {},
    selected_cards = {}, -- index -> true/false
    selected_order = {}, -- 按选择顺序保存索引（用于自动取消最早选中）
    last_play = nil
}
local playerOverlays = {}

-- 绘图辅助
local function clear()
    term.setBackgroundColor(C_BG)
    term.clear()
end

local function drawBox(x, y, w, h, bg)
    term.setBackgroundColor(bg)
    for i = 0, h - 1 do
        term.setCursorPos(x, y + i)
        term.write(string.rep(" ", w))
    end
end

local function drawText(x, y, txt, fg, bg)
    if bg then term.setBackgroundColor(bg) end
    if fg then term.setTextColor(fg) end
    term.setCursorPos(x, y)
    term.write(txt)
end

local function centerTextInBox(x, y, w, h, txt, fg, bg)
    local cy = y + math.floor(h / 2)
    local cx = x + math.floor((w - #txt) / 2)
    drawText(cx, cy, txt, fg, bg)
end

-- 绘制单张牌
local function drawCard(x, y, text, isHidden, isSelected)
    local bg = isHidden and colors.brown or (isSelected and C_SEL or colors.white)
    local fg = isHidden and colors.lightGray or colors.black
    drawBox(x, y, 3, 3, bg)
    if isHidden then
        drawText(x + 1, y + 1, "?", fg, bg)
    else
        local off = (#text == 1) and 1 or 0
        drawText(x + off, y + 1, text, fg, bg)
    end
end

-- 绘制玩家区域
local function drawPlayerArea(seatId, x, y, w, h, isMe)
    local p = gameState.players[seatId]
    if not p then
        drawBox(x, y, w, h, C_BG)
        drawText(x, y + 1, "Waiting...", colors.lightGray, C_BG)
        return
    end

    local ov = playerOverlays[seatId]
    if ov then
        drawBox(x, y, w, h, ov.color)
        centerTextInBox(x, y, w, h, ov.text, colors.black, ov.color)
        return
    end

    local isTurn = (gameState.round_info.turn_seat == seatId)
    local bg = isTurn and colors.cyan or C_PANEL
    if not p.alive then bg = colors.red end
    drawBox(x, y, w, h, bg)

    local nameStr = isMe and "YOU" or p.name
    if not p.alive then nameStr = "DEAD" end
    local gunStr = "Gun:(" .. (p.gun_status or "?") .. ")"

    drawText(x + 1, y, nameStr, colors.black, bg)
    drawText(x + w - #gunStr, y, gunStr, colors.red, bg)

    local startX = x + 1
    local cardY = y + 1

    if isMe then
        for i, card in ipairs(gameState.my_hand) do
            local cx = startX + (i - 1) * 4
            if cx + 3 < x + w then
                drawCard(cx, cardY, card, false, gameState.selected_cards[i])
            end
        end
    else
        local count = p.card_count or 0
        for i = 1, count do
            local cx = startX + (i - 1) * 4
            if cx + 3 < x + w then
                drawCard(cx, cardY, "?", true, false)
            end
        end
    end
end

-- 主界面布局
local function drawMainUI()
    if not MY_SEAT then return end

    local opponents = {
        { off = 1, y = 2 }, { off = 2, y = 7 }, { off = 3, y = 12 }
    }
    for _, op in ipairs(opponents) do
        local seat = (MY_SEAT + op.off - 1) % 4 + 1
        drawPlayerArea(seat, 2, op.y, 24, 4, false)
    end

    drawPlayerArea(MY_SEAT, 2, 16, 24, 4, true)

    local rx = 28
    drawBox(rx, 2, 22, 4, colors.brown)
    centerTextInBox(rx, 2, 22, 2, "TARGET: " .. (gameState.round_info.target_card or "?"), colors.white, colors.brown)
    centerTextInBox(rx, 4, 22, 2, "POT: " .. (gameState.round_info.table_stack or 0), colors.yellow, colors.brown)

    -- 上家出牌指示（下移）
    if gameState.last_play then
        local lp = gameState.last_play
        drawText(rx, 12, "<- Last Play:", colors.lightGray, C_BG)
        for i = 1, lp.count do
            drawCard(rx + (i - 1) * 4, 13, "?", true, false)
        end
    end

    local isActionPhase = (gameState.phase == "ACTION")
    local isMyTurn = (gameState.round_info.turn_seat == MY_SEAT)
    local canPlay = isActionPhase and isMyTurn
    local canLiar = (gameState.round_info.table_stack > 0) and (gameState.phase == "ACTION")

    drawBox(rx, 16, 10, 3, canPlay and C_BTN_PLAY or colors.gray)
    centerTextInBox(rx, 16, 10, 3, "PLAY", colors.black, canPlay and C_BTN_PLAY or colors.gray)

    drawBox(rx + 12, 16, 10, 3, canLiar and C_BTN_LIAR or colors.gray)
    centerTextInBox(rx + 12, 16, 10, 3, "LIAR", colors.white, canLiar and C_BTN_LIAR or colors.gray)
end

-- UI 循环
local function uiLoop()
    while true do
        clear()
        if gameState.phase == "CONNECTING" then
            centerTextInBox(1, 9, 51, 1, "Searching for Server...", colors.yellow, C_BG)
        else
            drawMainUI()
        end
        sleep(0.08)
    end
end

-- 网络循环
local function networkLoop()
    rednet.broadcast({ type = "JOIN_REQUEST" }, PROTOCOL)

    while true do
        local id, msg = rednet.receive(PROTOCOL)
        if msg then
            if SERVER_ID == nil then SERVER_ID = id end

            if msg.type == "JOIN_ACK" then
                MY_SEAT = msg.payload.seat
                gameState.phase = "LOBBY"
            elseif msg.type == "GAME_STATE" then
                local p = msg.payload
                gameState.phase = p.phase
                gameState.players = p.players
                gameState.round_info = {
                    target_card = p.target_card,
                    table_stack = p.table_stack,
                    turn_seat = p.turn_seat
                }
                gameState.last_play = p.last_play

                if p.phase == "ACTION" then
                    playerOverlays = {}
                end
            elseif msg.type == "PRIVATE_HAND" then
                gameState.my_hand = msg.payload.hand
                gameState.selected_cards = {}
                gameState.selected_order = {}
            elseif msg.type == "EVENT_FORCE_REVEAL" then
                local d = msg.payload
                playerOverlays[d.emptied_player] = { text = "ALL REVEAL", color = C_OVERLAY_WRONG }
                -- 可扩展：弹窗显示 d.table_cards
            elseif msg.type == "EVENT_CALL_LIAR" then
                playerOverlays[msg.payload.challenger] = { text = "^ LIAR ^", color = C_OVERLAY_LIAR }
            elseif msg.type == "EVENT_REVEAL" then
                local p = msg.payload
                if p.is_liar then
                    playerOverlays[p.victim] = { text = "CAUGHT!", color = C_OVERLAY_WRONG }
                    playerOverlays[p.challenger] = { text = "CORRECT", color = C_OVERLAY_TRUTH }
                else
                    playerOverlays[p.victim] = { text = "TRUTH", color = C_OVERLAY_TRUTH }
                    playerOverlays[p.challenger] = { text = "WRONG", color = C_OVERLAY_WRONG }
                end
            elseif msg.type == "EVENT_SHOOT" then
                local txt = (msg.payload.result == "BANG") and "BANG!!!" or "*CLICK*"
                local col = (msg.payload.result == "BANG") and colors.red or colors.lightGray
                playerOverlays[msg.payload.victim] = { text = txt, color = col }
            end
        end
    end
end

-- 输入循环（选择管理：最多3张，选择第4自动取消最早一张）
local function inputLoop()
    while true do
        local _, btn, x, y = os.pullEvent("mouse_click")

        local canAct = SERVER_ID and (gameState.phase == "ACTION") and (gameState.round_info.turn_seat == MY_SEAT)

        if btn == 1 then
            -- 选牌区域 (Y=17..19)
            if canAct and y >= 17 and y <= 19 and x >= 3 and x <= 26 then
                local idx = math.floor((x - 3) / 4) + 1
                if idx >= 1 and idx <= #gameState.my_hand then
                    if gameState.selected_cards[idx] then
                        -- 取消选中
                        gameState.selected_cards[idx] = nil
                        for i = 1, #gameState.selected_order do
                            if gameState.selected_order[i] == idx then
                                table.remove(gameState.selected_order, i)
                                break
                            end
                        end
                    else
                        -- 若已选3张，则取消最早选中
                        if #gameState.selected_order >= 3 then
                            local oldest = table.remove(gameState.selected_order, 1)
                            if oldest then gameState.selected_cards[oldest] = nil end
                        end
                        -- 添加新选中
                        gameState.selected_cards[idx] = true
                        table.insert(gameState.selected_order, idx)
                    end
                end
            end

            -- 按钮区 (Y=16..18)
            if canAct and y >= 16 and y <= 18 then
                -- PLAY (28..37)
                if x >= 28 and x <= 37 then
                    local toSend = {}
                    for i = 1, math.min(3, #gameState.selected_order) do
                        local idx = gameState.selected_order[i]
                        if idx and gameState.my_hand[idx] then
                            table.insert(toSend, gameState.my_hand[idx])
                        end
                    end
                    if #toSend > 0 then
                        rednet.send(SERVER_ID, { type = "ACTION_PLAY", payload = { cards = toSend } }, PROTOCOL)
                        -- 发送后清空本地选中（等待服务器 PRIVATE_HAND 更新）
                        gameState.selected_cards = {}
                        gameState.selected_order = {}
                    end
                end

                -- LIAR (40..49)
                if x >= 40 and x <= 49 and gameState.round_info.table_stack > 0 then
                    rednet.send(SERVER_ID, { type = "ACTION_LIAR", payload = {} }, PROTOCOL)
                end
            end
        end
    end
end

parallel.waitForAny(uiLoop, networkLoop, inputLoop)
