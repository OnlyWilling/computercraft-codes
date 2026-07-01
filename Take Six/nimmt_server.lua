----------------------------------------------
-- 配置与状态
----------------------------------------------
local core          = require("nimmt_core")
local utils         = require("utils")
local basalt        = require("basalt")
local PROTOCOL      = "NIMMT"
local MAX_PLAYERS   = 7  -- 牛头王支持 2-10 人，这里设7
local MAX_BULLHEADS = 66 -- 默认模式最大吃墩牛头数
local MAX_ROOMS     = 3  -- 最大同时房间数
local nextRoomID    = 1
local rooms         = {} -- rooms[roomID] = { state = RoomState }
local playerRoom    = {} -- playerID → roomID（消息路由用）

local function newRoomState(roomID, hostID)
    return {
        roomID         = roomID,
        hostID         = hostID,
        phase          = "LOBBY",  -- LOBBY / SELECTION / SHOWDOWN / WAITING_CHOICE / ROUND_OVER
        rows           = { {}, {}, {}, {} },
        players        = {},
        playerOrder    = {},
        turnSelections = {},
        turnCards      = {},
        blockingPlayer = nil,
        blockingCard   = nil,
        turnTimer      = nil,
    }
end

----------------------------------------------
-- Basalt 标签界面 (TabControl + Display)
----------------------------------------------
local mainFrame = basalt.createFrame()
    :setSize(51, 19)
    :setBackground(colors.black)

local tabControl = mainFrame:addTabControl({
    x = 1,
    y = 1,
    width = 51,
    height = 17,
    headerBackground = colors.gray,
    activeTabBackground = colors.white,
    activeTabTextColor = colors.black,
})

local tabDisplays = {} -- tabKey → { display = ..., win = ... }

local tabConfigs = {
    { key = "main", title = " Main " },
    { key = "1",    title = " Room#1 " },
    { key = "2",    title = " Room#2 " },
    { key = "3",    title = " Room#3 " },
}

for _, cfg in ipairs(tabConfigs) do
    local tab = tabControl:newTab(cfg.title)
    local display = tab:addDisplay({
        x = 1,
        y = 1,
        width = 49,
        height = 15,
        background = colors.black,
    })
    local win = display:getWindow()
    win.setBackgroundColor(colors.black)
    win.clear()
    win.setCursorPos(1, 1)
    tabDisplays[cfg.key] = { display = display, win = win }
end

-- 状态栏
local statusLabel = mainFrame:addLabel({
    x = 1,
    y = 18,
    width = 51,
    height = 1,
    background = colors.blue,
    foreground = colors.white,
    text = " Server: NIMMT | Rooms: 0/3",
})

-- Quit 按钮（点击触发 basalt.stop → 劫持版本自动通知所有客户端）
mainFrame:addButton()
    :setPosition(43, 19):setSize(8, 1)
    :setBackground(colors.red):setForeground(colors.white)
    :setText(" [Quit] ")
    :onClick(function() basalt.stop() end)

-- 状态栏更新函数
local function updateStatusBar()
    local active = 0
    local totalPlayers = 0
    for _, room in pairs(rooms) do
        active = active + 1
        totalPlayers = totalPlayers + #room.state.players
    end
    statusLabel:setText(" Server: NIMMT | Rooms: " ..
    active .. "/3 | Players: " .. totalPlayers .. "  |  [1/2/3]Tab [0]Main")
end

-- 日志行间前进（超出行高则滚动）
local function nextLine(win)
    local _, h = win.getSize()
    local _, y = win.getCursorPos()
    if y >= h then
        win.scroll(1)
        win.setCursorPos(1, y)
    else
        win.setCursorPos(1, y + 1)
    end
end

local tagColors = { Lobby = colors.lightBlue, Log = colors.yellow, Act = colors.orange, Error = colors.red }

-- 日志输出：写入对应 Tab 的 Display Window（实时彩色输出 + 自动滚动）
-- roomID = nil 表示系统消息（Main 标签）, 1/2/3 表示对应房间
-- 每条日志拆为两行（时间戳行 + 消息行），还原原始 printColored 的换行格式
local function log(roomID, tag, msg)
    local timestamp = utils.getTimestamp()
    local key = roomID and tostring(roomID) or "main"
    local td = tabDisplays[key]
    if not td then return end
    local win = td.win
    local tagColor = tagColors[tag] or colors.gray

    -- Line 1: [TAG]-HH:MM:SS-
    win.setTextColor(tagColor)
    win.write("[" .. tag .. "]")
    win.setTextColor(colors.gray)
    win.write(timestamp)
    nextLine(win)

    -- Line 2: 消息正文（数字蓝色，其余白色）
    local first = true
    for part in msg:gmatch("%S+") do
        local color = tonumber(part) and colors.blue or colors.white
        win.setTextColor(color)
        if first then
            win.write(part)
            first = false
        else
            win.write(" " .. part)
        end
    end
    nextLine(win)
end

local function localID(pid, rs)
    return rs.players[pid] and rs.players[pid].localIndex or pid
end

----------------------------------------------
-- 房间生命周期管理
----------------------------------------------
-- 房间内广播（自动附带 roomID，客户端据此过滤）
local function roomBroadcast(room, msg)
    msg.roomID = room.state.roomID
    rednet.broadcast(msg, PROTOCOL)
end

-- 将玩家加入房间（同时注册 playerRoom 映射、广播 sync_lobbyUpdate）
local function addPlayerToRoom(room, playerID)
    local rs = room.state
    table.insert(rs.playerOrder, playerID)
    local idx = #rs.playerOrder
    rs.players[playerID] = {
        id = playerID,
        score = 66,
        hand = {},
        localIndex = idx,
        connected = true,
        afk = false,
        lastSeen = os.clock(),
    }
    playerRoom[playerID] = rs.roomID
    roomBroadcast(room, { type = "sync_lobbyUpdate", playerList = rs.playerOrder })
    log(rs.roomID, "Lobby", "Player " .. idx .. " joined (PC id = " .. playerID .. ").")
end

-- 创建新房间，hostID 为创建者
local function createRoom(hostID)
    local roomID = nextRoomID
    nextRoomID = nextRoomID + 1
    rooms[roomID] = { state = newRoomState(roomID, hostID) }
    log(nil, "Lobby", "Room #" .. roomID .. " created. (Host: PC " .. hostID .. ")")
    return roomID
end

-- 销毁房间（取消 timer、通知玩家、清理）
local function destroyRoom(roomID)
    local room = rooms[roomID]
    if not room then return end
    local rs = room.state
    if rs.turnTimer then
        os.cancelTimer(rs.turnTimer); rs.turnTimer = nil
    end
    for pid in pairs(rs.players) do
        rednet.send(pid, { type = "ev_serverClosing", msg = "Room closed" }, PROTOCOL)
        playerRoom[pid] = nil
    end
    rooms[roomID] = nil
    log(nil, "Log", "Room #" .. roomID .. " destroyed.")
end

-- 从房间移除玩家（移交房主 → 空房自动销毁）
local function removePlayerFromRoom(playerID)
    local roomID = playerRoom[playerID]
    if not roomID then return end
    local room = rooms[roomID]
    if not room then
        playerRoom[playerID] = nil; return
    end
    local rs = room.state
    rs.players[playerID] = nil
    for i, pid in ipairs(rs.playerOrder) do
        if pid == playerID then
            table.remove(rs.playerOrder, i); break
        end
    end
    playerRoom[playerID] = nil
    -- 移交房主
    if room.state.hostID == playerID then
        local newHost = next(rs.players)
        if newHost then
            room.state.hostID = newHost
            rednet.send(newHost, { type = "ev_setHost" }, PROTOCOL)
            roomBroadcast(room, { type = "msg_toast", msg = "Host transferred" })
        end
    end
    roomBroadcast(room, { type = "sync_lobbyUpdate", playerList = rs.playerOrder })
    if next(rs.players) == nil then destroyRoom(roomID) end
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
-- 游戏核心函数（操作指定房间的数据）
----------------------------------------------

local function broadcastScores(room)
    local rs = room.state
    local scores = {}
    for pid, p in pairs(rs.players) do
        table.insert(scores, { id = pid, localIndex = p.localIndex, score = p.score })
    end
    roomBroadcast(room, { type = "sync_scoreUpdate", scores = scores })
end

local function startNewRound(room)
    local rs = room.state
    log(rs.roomID, "Log", "Starting New Round...")
    local deck = generateDeck()

    rs.rows = { { table.remove(deck) }, { table.remove(deck) }, { table.remove(deck) }, { table.remove(deck) } }

    for pid, p in pairs(rs.players) do
        if p.afk then
            p.connected = false
            rednet.send(pid, { type = "msg_afk" }, PROTOCOL)
            log(rs.roomID, "Act", "Player " .. localID(pid, rs) .. " removed for AFK")
        end
    end

    for pid, p in pairs(rs.players) do
        if p.connected then
            p.hand = {}
            for i = 1, 10 do table.insert(p.hand, table.remove(deck)) end
            rednet.send(pid, { type = "sync_dealHand", hand = p.hand }, PROTOCOL)
        end
    end

    rs.phase = "SELECTION"
    roomBroadcast(room, { type = "ev_gameStart", rows = rs.rows, roundReset = true, playerList = rs.playerOrder })
    broadcastScores(room)
    roomBroadcast(room, { type = "msg_toast", msg = "=== NEW ROUND STARTED ===" })
    rs.turnTimer = os.startTimer(20)
end

----------------------------------------------
-- 核心逻辑：放置牌的算法 (牛头王精髓)
----------------------------------------------
local function resolveTurn(room)
    local rs = room.state
    if #rs.turnCards == 0 then
        os.sleep(1)
        local anyPlayerID = next(rs.players)
        if anyPlayerID and #rs.players[anyPlayerID].hand == 0 then
            log(rs.roomID, "Log", "Round Over. Checking scores...")
            rs.phase = "ROUND_OVER"
            roomBroadcast(room, { type = "ev_roundOver" })
            local isGameOver = false
            for pid, p in pairs(rs.players) do
                if p.score >= MAX_BULLHEADS then isGameOver = true end
            end

            broadcastScores(room)
            os.sleep(3)

            if isGameOver then
                roomBroadcast(room, { type = "ev_gameOver" })
                log(rs.roomID, "Log", "Game Over triggered.")
            else
                startNewRound(room)
            end
        else
            rs.phase = "SELECTION"
            roomBroadcast(room, { type = "ev_newTurn" })
            rs.turnTimer = os.startTimer(20)
        end
        return
    end

    local currentPlay = rs.turnCards[1]
    local card = currentPlay.card
    local pid = currentPlay.id

    local bestRowIndex = -1
    local minDiff = 105

    for i = 1, 4 do
        local row = rs.rows[i]
        local lastCard = row[#row]

        if card > lastCard then
            local diff = card - lastCard
            if diff < minDiff then
                minDiff = diff
                bestRowIndex = i
            end
        end
    end

    if bestRowIndex == -1 then
        rs.phase = "WAITING_CHOICE"
        rs.blockingPlayer = pid
        rs.blockingCard = card
        log(rs.roomID, "Act", "Waiting for Player " .. localID(pid, rs) .. " to choose row...")
        rednet.send(pid, {
            type = "req_rowChoice",
            card = card,
            rows = rs.rows
        }, PROTOCOL)
        roomBroadcast(room, { type = "ev_waitingStatus", targetID = pid })
        rs.turnTimer = os.startTimer(20)
        return
    else
        local targetRow = rs.rows[bestRowIndex]
        if #targetRow >= 5 then
            local penalty = core.getRowBullHeads(targetRow)
            rs.players[pid].score = rs.players[pid].score - penalty
            broadcastScores(room)
            log(rs.roomID, "Log",
                "Player " .. localID(pid, rs) .. " exploded row " .. bestRowIndex .. " (-" .. penalty .. ")")
            rs.rows[bestRowIndex] = { card }
            roomBroadcast(room, { type = "msg_toast", msg = "P" .. localID(pid, rs) .. " ate " .. penalty .. " heads!" })
        else
            table.insert(targetRow, card)
        end
    end

    table.remove(rs.turnCards, 1)
    roomBroadcast(room, { type = "sync_updateBoard", rows = rs.rows })
    sleep(1)

    resolveTurn(room)
end

local function startShowdown(room)
    local rs = room.state
    if rs.turnTimer then
        os.cancelTimer(rs.turnTimer)
        rs.turnTimer = nil
    end
    rs.phase = "SHOWDOWN"
    rs.turnCards = {}
    for pid, c in pairs(rs.turnSelections) do
        table.insert(rs.turnCards, { id = pid, card = c })
        local pData = rs.players[pid]
        local idx = hasCard(pData.hand, c)
        if idx then
            table.remove(pData.hand, idx)
            rednet.send(pid, { type = "sync_updateHand", hand = pData.hand }, PROTOCOL)
        end
    end
    rs.turnSelections = {}
    table.sort(rs.turnCards, function(a, b) return a.card < b.card end)
    roomBroadcast(room, { type = "sync_turnSummary", turnCards = rs.turnCards })
    os.sleep(1.5)
    resolveTurn(room)
end

local function handleTurnTimeout(room)
    local rs = room.state
    local phase = rs.phase
    rs.turnTimer = nil
    if phase == "SELECTION" then
        for pid, p in pairs(rs.players) do
            if p.connected and not rs.turnSelections[pid] and #p.hand > 0 then
                local card = p.hand[1]
                rs.turnSelections[pid] = card
                p.afk = true
                log(rs.roomID, "Act", "Player " .. localID(pid, rs) .. " AFK, auto-play " .. card)
                rednet.send(pid, { type = "msg_afk" }, PROTOCOL)
            end
        end
        local played = 0
        for pid, p in pairs(rs.players) do
            if p.connected and rs.turnSelections[pid] then
                played = played + 1
            end
        end
        local playerCount = 0
        for _, p in pairs(rs.players) do
            if p.connected then playerCount = playerCount + 1 end
        end
        if played >= playerCount then startShowdown(room) end
    elseif phase == "WAITING_CHOICE" then
        local pid = rs.blockingPlayer
        if pid and rs.players[pid] then
            rs.players[pid].afk = true
            log(rs.roomID, "Act", "Player " .. localID(pid, rs) .. " AFK, auto-choose Row 1")
            rednet.send(pid, { type = "msg_afk" }, PROTOCOL)
            local penalty = core.getRowBullHeads(rs.rows[1])
            rs.players[pid].score = rs.players[pid].score - penalty
            broadcastScores(room)
            roomBroadcast(room,
                { type = "msg_toast", msg = "P" .. localID(pid, rs) .. " (AFK) chose row 1 (-" .. penalty .. ")" })
            rs.rows[1] = { rs.blockingCard }
            rs.blockingPlayer = nil; rs.blockingCard = nil
            table.remove(rs.turnCards, 1)
            roomBroadcast(room, { type = "sync_updateBoard", rows = rs.rows })
            resolveTurn(room)
        end
    end
end

----------------------------------------------
-- 消息分发：按房间路由游戏消息
----------------------------------------------
local function handleRoomMessage(room, pid, msg)
    local rs = room.state
    if rs.players[pid] then rs.players[pid].lastSeen = os.clock() end

    if msg.type == "act_startGame" and rs.phase == "LOBBY" then
        if pid ~= room.state.hostID then
            rednet.send(pid, { type = "msg_error", msg = "Only Host can start" }, PROTOCOL)
            return
        end
        log(rs.roomID, "Act", "Host started the game!")
        startNewRound(room)
    elseif msg.type == "act_playCard" and rs.phase == "SELECTION" then
        local card = msg.card
        if type(card) ~= "number" then return end
        if not hasCard(rs.players[pid].hand, card) then
            log(rs.roomID, "Error", "Player " .. localID(pid, rs) .. " tried to cheat with card " .. card)
            return
        end
        if rs.turnSelections[pid] ~= nil then
            log(rs.roomID, "Log", "Player " .. localID(pid, rs) .. " changed selection to " .. card)
            rednet.send(pid, { type = "msg_toast", msg = "Selection updated to " .. card }, PROTOCOL)
        else
            log(rs.roomID, "Log", "Player " .. localID(pid, rs) .. " selected " .. card)
        end
        rs.turnSelections[pid] = card
        local readyCount = 0
        for _ in pairs(rs.turnSelections) do readyCount = readyCount + 1 end
        local playerCount = 0
        for _, p in pairs(rs.players) do if p.connected then playerCount = playerCount + 1 end end
        roomBroadcast(room, { type = "sync_statusUpdate", current = playerCount, total = #rs.playerOrder })
        if readyCount >= playerCount then startShowdown(room) end
    elseif msg.type == "act_chooseRow" and rs.phase == "WAITING_CHOICE" then
        if pid ~= rs.blockingPlayer then return end
        if rs.turnTimer then
            os.cancelTimer(rs.turnTimer); rs.turnTimer = nil
        end
        local rowIdx = msg.rowIndex
        if type(rowIdx) ~= "number" or rowIdx < 1 or rowIdx > 4 then return end
        log(rs.roomID, "Log", "Player " .. localID(pid, rs) .. " chose Row " .. rowIdx)
        local penalty = core.getRowBullHeads(rs.rows[rowIdx])
        rs.players[pid].score = rs.players[pid].score - penalty
        broadcastScores(room)
        roomBroadcast(room,
            { type = "msg_toast", msg = "P" .. localID(pid, rs) .. " chose Row " .. rowIdx .. " (-" .. penalty .. ")" })
        rs.rows[rowIdx] = { rs.blockingCard }
        rs.blockingPlayer = nil; rs.blockingCard = nil
        table.remove(rs.turnCards, 1)
        roomBroadcast(room, { type = "sync_updateBoard", rows = rs.rows })
        resolveTurn(room)
    elseif msg.type == "act_afkResume" then
        if rs.players[pid] then
            rs.players[pid].afk = false
            rs.players[pid].connected = true
            log(rs.roomID, "Log", "Player " .. localID(pid, rs) .. " resumed from AFK")
            rednet.send(pid, { type = "msg_toast", msg = "Welcome back!" }, PROTOCOL)
        end
    elseif msg.type == "act_leaveRoom" then
        removePlayerFromRoom(pid)
    end
end

-- 加入 / 创建房间
local function handleJoinRoom(playerID, msg)
    if playerRoom[playerID] then return end

    if msg.roomId then
        local room = rooms[msg.roomId]
        if not room then
            rednet.send(playerID, { type = "msg_error", msg = "Room not found" }, PROTOCOL)
            return
        end
        if room.state.phase ~= "LOBBY" then
            rednet.send(playerID, { type = "msg_error", msg = "Game already started" }, PROTOCOL)
            return
        end
        if #room.state.players >= MAX_PLAYERS then
            rednet.send(playerID, { type = "msg_error", msg = "Room full" }, PROTOCOL)
            return
        end
        addPlayerToRoom(room, playerID)
    else
        if next(rooms) and #rooms >= MAX_ROOMS then
            rednet.send(playerID, { type = "msg_error", msg = "Max rooms (3) reached, try again later" }, PROTOCOL)
            return
        end
        local roomID = createRoom(playerID)
        addPlayerToRoom(rooms[roomID], playerID)
        rednet.send(playerID, { type = "ev_setHost" }, PROTOCOL)
    end
end

-- 房间列表查询
local function handleRoomListRequest(playerID)
    local available = {}
    for roomID, room in pairs(rooms) do
        if room.state.phase == "LOBBY" then
            table.insert(available, {
                id = roomID,
                players = #room.state.players,
                maxPlayers = MAX_PLAYERS,
                phase = room.state.phase,
            })
        end
    end
    rednet.send(playerID, { type = "sync_roomList", rooms = available }, PROTOCOL)
end

----------------------------------------------
-- Basalt 事件注册（替代 net_loop + heartbeat_loop）
----------------------------------------------

-- 劫持 basalt.stop()：Basalt 收到 terminate 后会直接调用它，
-- 且不派发 onEvent("terminate", ...) 注册的回调。
-- 在这里插入关闭广播，确保客户端收到 ev_serverClosing。
do
    local originalStop = basalt.stop
    function basalt.stop()
        log(nil, "Error", "Server shutting down, notifying clients...")
        rednet.broadcast({ type = "ev_serverClosing", msg = "Server shutdown!" }, PROTOCOL)
        for _, room in pairs(rooms) do
            if room.state.turnTimer then os.cancelTimer(room.state.turnTimer) end
        end
        originalStop()
    end
end

-- 标签页切换快捷键
basalt.onEvent("key", function(key)
    if key == keys.one then
        tabControl:setActiveTab(2)
    elseif key == keys.two then
        tabControl:setActiveTab(3)
    elseif key == keys.three then
        tabControl:setActiveTab(4)
    elseif key == keys.zero then
        tabControl:setActiveTab(1)
    end
end)

-- 回合倒计时
basalt.onEvent("timer", function(timerID)
    for _, room in pairs(rooms) do
        if room.state.turnTimer == timerID then
            handleTurnTimeout(room)
            break
        end
    end
end)

-- Rednet 消息分发
basalt.onEvent("rednet_message", function(senderID, msg, protocol)
    if protocol ~= PROTOCOL or type(msg) ~= "table" then return end
    if msg.type == "act_joinRoom" then
        handleJoinRoom(senderID, msg)
    elseif msg.type == "req_roomList" then
        handleRoomListRequest(senderID)
    else
        local room = playerRoom[senderID] and rooms[playerRoom[senderID]]
        if not room then return end
        handleRoomMessage(room, senderID, msg)
    end
end)

-- 心跳检测（后台协程）
basalt.schedule(function()
    while true do
        os.sleep(5)
        rednet.broadcast({ type = "ev_heartbeat" }, PROTOCOL)
        local now = os.clock()
        for roomID, room in pairs(rooms) do
            local rs = room.state
            local changed = false
            for pid, p in pairs(rs.players) do
                if p.connected and now - p.lastSeen > 60 then
                    p.connected = false
                    log(roomID, "Log", "Player " .. localID(pid, rs) .. " timed out (PC " .. pid .. ")")
                    roomBroadcast(room, { type = "msg_toast", msg = "P" .. localID(pid, rs) .. " disconnected" })
                    changed = true
                end
            end
            if changed then
                local onlineCount = 0
                for _, p in pairs(rs.players) do
                    if p.connected then onlineCount = onlineCount + 1 end
                end
                roomBroadcast(room, { type = "sync_statusUpdate", current = onlineCount, total = #rs.playerOrder })
                broadcastScores(room)
                updateStatusBar()
            end
        end
    end
end)

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem found") end
rednet.open(peripheral.getName(modem))
rednet.host(PROTOCOL, "NIMMT_SERVER")
log(nil, "Log", "Server registered as 'NIMMT_SERVER'")
log(nil, "Log", "Server started on ID: " .. os.getComputerID())

log(nil, "Lobby", "Server ready. Use client to Create or Join a room.")

basalt.run()
