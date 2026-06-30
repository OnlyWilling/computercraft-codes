local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem found") end
rednet.open(peripheral.getName(modem))

local utils               = require("utils")
local core                = require("nimmt_core")
local basalt              = require("basalt")

local PROTOCOL            = "NIMMT"
local CONFIG_FILE         = "./nimmt.cfg"
local BIMG_PATH           = "./bimg/nimmt_logo.bimg"
local SERVER_ID           = nil
local PLAYER_COLORS       = { colors.red, colors.orange, colors.yellow, colors.green, colors.cyan, colors.blue, colors
    .purple }

local default_config      = { lastServerID = nil, debug = false }

local playerColorMap      = {} -- PC ID → {localID, color} 映射表
local config              = utils.loadConfig(default_config, CONFIG_FILE)

local timerLastServerMsg  = 0 -- os.clock() 时间戳，连接时初始化，用于心跳超时检测

-- 待定连接状态：doConnect 后先不设置 SERVER_ID，收到 sync_lobbyUpdate 才确认
local pendingServerID     = nil
local timerPendingConnect = nil
local joinServerID        = nil -- Join 流程中缓存的服务器 ID（用于 req_roomList / act_joinRoom）

----------------------------------------------
-- 客户端状态
----------------------------------------------
local gameState = {
    gamePhase       = "MENU",
    roomID          = nil,  -- 当前所在房间号（由 sync_lobbyUpdate 设置）
    isHost          = false,
    lobbyCount      = 0,
    myID            = os.getComputerID(),
    selectedHandIdx = 1,
    selectedRowIdx  = 1,
    stagedCard      = nil,
    waitingTarget   = nil,
    isLocked        = false,
    hand            = {},
    tableRows       = { {}, {}, {}, {} },
    turnCards       = {},
    isAFK           = false,
    turnTimer       = 0,
}

----------------------------------------------
-- 连接辅助
----------------------------------------------
-- DEBUG: 记录所有 rednet 消息到文件，排查连接问题
local function NIMMT_DEBUG(msg)
    if not config.debug then return end
    local f = fs.open(shell.resolve("./nimmt_debug.txt"), "a")
    if f then
        f.writeLine(os.clock() .. " " .. tostring(msg))
        f.close()
    end
end

local function doConnect(sID, roomId)
    NIMMT_DEBUG("doConnect to " .. tostring(sID) .. (roomId and (" room=" .. roomId) or ""))
    local msg = { type = "act_joinRoom" }
    if roomId then msg.roomId = roomId end
    rednet.send(sID, msg, PROTOCOL)
    pendingServerID = sID
    timerPendingConnect = os.clock()
end

-------------------------------------------------------------------------
-- Basalt UI 布局
-------------------------------------------------------------------------

-- ========================
-- [菜单界面] menuFrame
-- ========================
local menuFrame = basalt.createFrame()
    :setForeground(colors.white):setBackground(colors.black)
    :setZ(1)

-- LOGO Image
menuFrame:addImage({
    bimg = utils.loadBimgImage(BIMG_PATH)
})
    :setPosition("{parent.width / 2 - 4}", 5)
    :setForeground(colors.yellow)

-- 状态提示行（连接中/错误信息）
local menuStatusLbl = menuFrame:addLabel()
    :setPosition("{parent.width / 2 - 12}", 11)
    :setSize(26, 1)
    :setForeground(colors.lightGray)
    :setText("")

-- 前向声明，供 Join Game 按钮的回调引用
local joinModal

menuFrame:addButton()
    :setPosition("{parent.width / 2 - 14}", 13):setSize(13, 3)
    :setBackground(colors.green):setForeground(colors.black)
    :setText("Create Game")
    :onClick(function()
        if pendingServerID then return end
        basalt.schedule(function()
            menuStatusLbl:setForeground(colors.yellow):setText("Searching...")
            local id = rednet.lookup(PROTOCOL, "NIMMT_SERVER")
            NIMMT_DEBUG("lookup result: " .. tostring(id))
            if not id and config.lastServerID then
                id = config.lastServerID
            end
            if id then
                doConnect(id)
            else
                menuStatusLbl:setForeground(colors.red):setText("Server not found!")
            end
        end)
    end)

menuFrame:addButton()
    :setPosition("{parent.width / 2 - 14}", 17):setSize(27, 3)
    :setBackground(colors.red):setForeground(colors.white)
    :setText("Quit Game")
    :onClick(function()
        if rednet.isOpen(peripheral.getName(modem)) then
            rednet.close(peripheral.getName(modem))
        end
        basalt.stop()
    end)

menuFrame:addButton()
    :setPosition("{parent.width / 2 + 1}", 13):setSize(12, 3)
    :setBackground(colors.blue):setForeground(colors.white)
    :setText("Join Game")
    :onClick(function()
        basalt.schedule(function()
            joinServerID = rednet.lookup(PROTOCOL, "NIMMT_SERVER")
            if not joinServerID and config.lastServerID then
                joinServerID = config.lastServerID
            end
            if not joinServerID then
                menuStatusLbl:setForeground(colors.red):setText("Server not found!")
                return
            end
            rednet.send(joinServerID, { type = "req_roomList" }, PROTOCOL)
            joinModal.visible = true
        end)
    end)

-- 可用房间列表缓存（供 Connect 按钮读取选中房间的 ID）
local availableRooms = {}

-- Join Game 模态框（房间列表，默认隐藏，z=4 浮在按钮上）
joinModal = menuFrame:addFrame()
    :setPosition("{math.floor(parent.width / 2) - 12}", "{math.floor(parent.height / 2) - 7}")
    :setSize(26, 15)
    :setBackground(colors.gray):setZ(4)
joinModal.visible = false

joinModal:addLabel()
    :setPosition(3, 2)
    :setForeground(colors.white)
    :setText("Available Rooms:")

local roomList = joinModal:addList({
        selectable      = true,
        multiSelection  = false,
    })
    :setPosition(3, 3):setSize(21, 7)
    :setBackground(colors.black):setForeground(colors.white)
    :setSelectedBackground(colors.blue):setSelectedForeground(colors.white)

joinModal:addButton()
    :setPosition(3, 11):setSize(7, 1)
    :setBackground(colors.orange):setForeground(colors.white)
    :setText("Refresh")
    :onClick(function()
        if not joinServerID then
            basalt.schedule(function()
                joinServerID = rednet.lookup(PROTOCOL, "NIMMT_SERVER")
                if joinServerID then
                    roomList:clear(); roomList:addItem("Loading...")
                    rednet.send(joinServerID, { type = "req_roomList" }, PROTOCOL)
                end
            end)
        else
            roomList:clear(); roomList:addItem("Loading...")
            basalt.schedule(function()
                rednet.send(joinServerID, { type = "req_roomList" }, PROTOCOL)
            end)
        end
    end)

joinModal:addButton()
    :setPosition(12, 11):setSize(7, 1)
    :setBackground(colors.lime):setForeground(colors.black)
    :setText("Connect")
    :onClick(function()
        if pendingServerID then return end
        local idx = roomList:getSelectedIndex()
        if not idx or not availableRooms[idx] then
            menuStatusLbl:setForeground(colors.red):setText("Select a room first!")
            return
        end
        joinModal.visible = false
        local roomId = availableRooms[idx].id
        menuStatusLbl:setForeground(colors.yellow):setText("Joining Room #" .. roomId .. "...")
        doConnect(joinServerID, roomId)
    end)

joinModal:addButton()
    :setPosition(3, 13):setSize(8, 1)
    :setBackground(colors.red):setForeground(colors.white)
    :setText("Cancel")
    :onClick(function() joinModal.visible = false end)

-- ========================
-- [房间大厅] roomFrame
-- ========================
local roomFrame = basalt.createFrame()
    :setForeground(colors.white):setBackground(colors.black)
    :setZ(3)
roomFrame.visible = false

local roomHeader = roomFrame:addFrame()
    :setPosition(1, 1):setSize("{parent.width}", 2)
    :setBackground(colors.blue)

roomHeader:addLabel():setPosition(2, 1):setForeground(colors.white):setText("6 Nimmt!")

local lblRoomID = roomHeader:addLabel()
    :setPosition(12, 1):setForeground(colors.yellow):setText("Room: ---")

local lblPlayerCount = roomFrame:addLabel()
    :setPosition(4, 5):setForeground(colors.white):setText("Players: 0 connected")

roomFrame:addLabel()
    :setPosition(4, 7):setForeground(colors.cyan)
    :setText("Your ID: " .. os.getComputerID())

local lblHostBadge = roomFrame:addLabel()
    :setPosition(4, 9):setForeground(colors.yellow):setText("")

local lblWaiting = roomFrame:addLabel()
    :setPosition(4, 11):setForeground(colors.lightGray):setText("Waiting for host to start...")

local btnRoomStart = roomFrame:addButton()
    :setPosition("{parent.width / 2 - 7}", 13):setSize(15, 3)
    :setBackground(colors.green):setForeground(colors.black):setText("START GAME")
    :onClick(function()
        rednet.send(SERVER_ID, { type = "act_startGame" }, PROTOCOL)
    end)
btnRoomStart.visible = false

-- ========================
-- [游戏界面] gameFrame
-- ========================
local gameFrame = basalt.createFrame()
    :setForeground(colors.white):setBackground(colors.black)
gameFrame.visible = false

local infoArea = gameFrame:addFrame()
    :setPosition(1, 1):setSize("{parent.width}", 3):setBackground(colors.lightGray)

local boardArea = gameFrame:addFrame()
    :setPosition(1, 4):setSize(36, 12):setBackground(colors.black)

local handArea = gameFrame:addFrame()
    :setPosition(1, "{parent.height - 3}"):setSize("{parent.width}", 4):setBackground(colors.black)

handArea:addLabel():setPosition(2, 1):setForeground(colors.lightBlue):setText("Your Hand:")

-- Toast 通知框
local toastFrame = gameFrame:addFrame()
    :setPosition("{math.floor(parent.width / 2) - 13}", "{math.floor(parent.height / 2) - 2}"):setZ(10):setSize(26, 4)
    :setBackground(colors.red)
toastFrame.visible = false

local toastLabel = toastFrame:addLabel()
    :setPosition(2, 2):setSize("{parent.width - 2}", 3):setForeground(colors.white):setText("")

-- 分数展示覆盖层（轮末显示，z=8 低于 toast）
local scoreOverlay = gameFrame:addFrame()
    :setPosition(38, 4):setZ(8):setSize(14, 12)
    :setBackground(colors.gray)

scoreOverlay:addLabel()
    :setPosition(1, 1)
    :setForeground(colors.yellow)
    :setText("= Scoreboard =")

local scoreFooterLbl1 = scoreOverlay:addLabel()
    :setPosition(1, "{parent.height - 2}")
    :setForeground(colors.orange)
    :setText("6 Nimmt")

local scoreFooterLbl2 = scoreOverlay:addLabel()
    :setPosition(1, "{parent.height - 1}")
    :setForeground(colors.blue)
    :setText("Players:")

local scoreFooterLbl3 = scoreOverlay:addLabel()
    :setPosition(1, "{parent.height}")
    :setForeground(colors.magenta)
    :setText("Phase: PLAYING")

local scoreListFrame = scoreOverlay:addFrame()
    :setPosition(1, 2):setSize("{parent.width}", "{parent.height - 4}")
    :setBackground(colors.gray)

scoreListFrame:addLabel()
    :setPosition(1, "{parent.height}")
    :setForeground(colors.yellow)
    :setText("==============")

-- 回合倒计时标签（gameFrame 顶层，右上角）
local turnTimer = gameFrame:addLabel()
    :setPosition("{parent.width - 9}", 1):setZ(10)
    :setForeground(colors.magenta)
    :setText("")

-------------------------------------------------------------------------
-- 断线重置（断线/房间解散时调用，重置所有状态并退回菜单）
-- 注意：定义在 UI 变量之后才会添加
-------------------------------------------------------------------------
local function onServerDisconnected(reason)
    SERVER_ID               = nil
    joinServerID            = nil
    pendingServerID         = nil
    timerPendingConnect     = nil
    gameState.gamePhase     = "MENU"
    gameState.roomID        = nil
    gameState.isHost        = false
    gameState.lobbyCount    = 0
    gameState.hand          = {}
    gameState.tableRows     = { {}, {}, {}, {} }
    gameState.turnCards     = {}
    gameState.stagedCard    = nil
    gameState.waitingTarget = nil
    gameState.isAFK         = false
    gameState.turnTimer     = 0
    playerColorMap          = {}
    lblHostBadge:setText("")
    lblWaiting.visible   = true
    btnRoomStart.visible = false
    lblRoomID:setText("Room: ---")
    lblPlayerCount:setText("Players: 0 connected")
    gameFrame.visible = false
    roomFrame.visible = false
    menuFrame.visible = true
    basalt.setActiveFrame(menuFrame, true)
    menuStatusLbl:setForeground(colors.red):setText(reason or "Room discarded")
end

-------------------------------------------------------------------------
-- UI 组件封装 (Helper Functions)
-------------------------------------------------------------------------

local toastButton = nil -- AFK toast 的按钮引用，用于清理

local function showToast(msg, duration, color, buttonConfig)
    if gameState.isAFK then return end -- AFK状态下 不显示其他toast msg

    if toastButton and not toastButton._destroyed then
        toastButton:destroy() -- 清理旧按钮
        toastButton = nil
    end

    toastFrame:setBackground(color or colors.red)
    toastLabel:setText(msg)
    toastFrame:setSize(26, buttonConfig and 6 or 4)
    toastFrame.visible = true

    if buttonConfig then
        toastButton = toastFrame:addButton()
            :setPosition(buttonConfig.x or 9, buttonConfig.y or 4)
            :setSize(buttonConfig.w or 8, 3)
            :setBackground(buttonConfig.bg or colors.lime)
            :setForeground(buttonConfig.fg or colors.black)
            :setText(buttonConfig.text or "OK")
            :onClick(function()
                if buttonConfig.onClick then buttonConfig.onClick() end
            end)
    end

    if duration and duration > 0 then
        basalt.schedule(function()
            os.sleep(duration)
            toastFrame.visible = false
        end)
    end
end

-- 绘制一张卡牌
local function createCard(parent, x, y, size_w, size_h, value, onClickFunc, isSelected)
    local bgCol = isSelected and colors.yellow or colors.white
    local fgCol = colors.black

    local bulls = core.getBullHeadCount(value)
    if bulls == 7 then
        bgCol = colors.red; fgCol = colors.white
    elseif bulls == 5 then
        bgCol = colors.orange
    elseif bulls == 3 then
        bgCol = colors.cyan
    elseif bulls == 2 then
        bgCol = colors.lightBlue
    end

    local card = parent:addButton()
        :setPosition(x, y):setSize(size_w, size_h)
        :setBackground(bgCol):setForeground(fgCol)
        :setText(tostring(value))

    if onClickFunc then card:onClick(onClickFunc) end
    return card
end

-------------------------------------------------------------------------
-- 动态 UI 更新逻辑
-------------------------------------------------------------------------
local function updateInfoUI()
    infoArea:clear()

    local infoX = 8
    for _, entry in ipairs(gameState.turnCards) do
        createCard(infoArea, infoX, 1, 4, 2, entry.card, nil, false)
        -- 玩家 ID 标签：局内 ID + 对应颜色
        local pinfo = playerColorMap[entry.id]
        local localID = pinfo and pinfo.localID or "?"
        local tagColor = pinfo and pinfo.color or colors.gray
        local txtColor = colors.black
        infoArea:addButton():setPosition(infoX, 3):setSize(4, 1)
            :setBackground(tagColor):setForeground(txtColor)
            :setText("P" .. tostring(localID))
        infoX = infoX + 6
    end

    if gameState.waitingTarget then
        local pinfo = playerColorMap[gameState.waitingTarget]
        local localID = pinfo and pinfo.localID or gameState.waitingTarget
        infoArea:addLabel():setPosition("{parent.width - 28}", 1):setForeground(colors.magenta)
            :setText("Waiting P" .. tostring(localID) .. " to choose row...")
    end
end

local function updateBoardUI()
    boardArea:clear()
    for i = 1, 4 do
        local rowY = 1 + (i - 1) * 3
        local lbl = boardArea:addButton()
            :setPosition(2, rowY + 1):setSize(5, 1)
            :setBackground(gameState.gamePhase == "ROW_SELECT" and colors.blue or colors.black)
            :setForeground(gameState.gamePhase == "ROW_SELECT" and colors.white or colors.gray)
            :setText("Row " .. i)
        if gameState.gamePhase == "ROW_SELECT" then
            lbl:onClick(function()
                if gameState.isAFK then return end
                rednet.send(SERVER_ID, { type = "act_chooseRow", rowIndex = i }, PROTOCOL)
                gameState.gamePhase = "WAITING"
                showToast("Row Selected", 2, colors.green)
                updateBoardUI()
                updateInfoUI()
            end)
        end
        local rowX = 8
        for _, cVal in ipairs(gameState.tableRows[i]) do
            createCard(boardArea, rowX, rowY, 4, 3, cVal, nil, false)
            rowX = rowX + 5
        end
    end
end

local function updateHandUI()
    handArea:clear()
    handArea:addLabel():setPosition(2, 1):setForeground(colors.lightBlue):setText("Your Hand:")

    local handX = 2
    for _, cardVal in ipairs(gameState.hand) do
        local isSelected = (cardVal == gameState.stagedCard)
        createCard(handArea, handX, 2, 4, 3, cardVal, function()
            if gameState.gamePhase == "PLAYING" and not gameState.stagedCard and not gameState.isAFK then
                gameState.stagedCard = cardVal
                rednet.send(SERVER_ID, { type = "act_playCard", card = cardVal }, PROTOCOL)
                showToast("Card Sent!", 2, colors.green)
                updateHandUI()
            end
        end, isSelected)
        handX = handX + 5
    end
end

local function refreshAll()
    updateHandUI()
    updateBoardUI()
    updateInfoUI()
end

----------------------------------------------
-- 交互函数分发表
----------------------------------------------
local handlers = {}

-- [大厅逻辑]
handlers["sync_lobbyUpdate"] = function(msg)
    -- 保存房间号
    if msg.roomID then gameState.roomID = msg.roomID end
    -- 构建玩家颜色映射表
    if msg.playerList then
        playerColorMap = {}
        for i, pcID in ipairs(msg.playerList) do
            playerColorMap[pcID] = {
                localID = i,
                color = PLAYER_COLORS[i] or colors.gray
            }
        end
    end
    gameState.lobbyCount = msg.playerList and #msg.playerList or 0
    -- 首次收到 lobbyUpdate，从菜单切换到房间大厅
    if gameState.gamePhase == "MENU" then
        gameState.gamePhase = "LOBBY"
        menuFrame.visible = false
        roomFrame.visible = true
        basalt.setActiveFrame(roomFrame, true)
    end
    local roomLabel = gameState.roomID and ("Room #" .. gameState.roomID) or tostring(SERVER_ID)
    lblRoomID:setText("Room: " .. roomLabel)
    lblPlayerCount:setText("Players: " .. gameState.lobbyCount .. " connected")
end

handlers["ev_setHost"] = function(msg)
    gameState.isHost = true
    lblHostBadge:setText("You are the HOST")
    lblWaiting.visible = false
    btnRoomStart.visible = true
end

-- [房间列表查询]
handlers["sync_roomList"] = function(msg)
    roomList:clear()
    availableRooms = {}
    if not msg.rooms or #msg.rooms == 0 then
        roomList:addItem("(No rooms available)")
        return
    end
    for _, r in ipairs(msg.rooms) do
        table.insert(availableRooms, r)
        roomList:addItem("Room #" .. r.id .. "  (" .. r.players .. "/" .. r.maxPlayers .. ")")
    end
end

-- [游戏通用]
handlers["msg_toast"] = function(msg)
    showToast(msg.msg, 2, colors.orange)
end

-- AFK 提示：复用 showToast 显示确认按钮
handlers["msg_afk"] = function(msg)
    showToast("== AFK Confirmed==", nil, colors.red, {
        text = "Continue",
        x = 9,
        y = 4,
        w = 8,
        onClick = function()
            gameState.isAFK = false
            rednet.send(SERVER_ID, { type = "act_afkResume" }, PROTOCOL)
            toastFrame.visible = false
        end
    })
    gameState.isAFK = true
end

handlers["ev_gameStart"] = function(msg)
    -- 游戏开始时也更新玩家颜色映射（确保游戏阶段映射正确）
    if msg.playerList then
        playerColorMap = {}
        for i, pcID in ipairs(msg.playerList) do
            playerColorMap[pcID] = {
                localID = i,
                color = PLAYER_COLORS[i] or colors.gray
            }
        end
    end
    gameState.gamePhase = "PLAYING"
    gameState.tableRows = msg.rows
    if msg.roundReset then
        gameState.turnCards = {}
        gameState.waitingTarget = nil
    end
    roomFrame.visible = false
    gameFrame.visible = true
    basalt.setActiveFrame(gameFrame, true)
    gameState.turnTimer = 20
    refreshAll()
end

handlers["sync_dealHand"] = function(msg)
    gameState.hand = msg.hand
    table.sort(gameState.hand)
    updateHandUI()
end

handlers["sync_updateHand"] = function(msg)
    gameState.hand = msg.hand
    table.sort(gameState.hand)
    if gameState.selectedHandIdx > #gameState.hand then
        gameState.selectedHandIdx = math.max(1, #gameState.hand)
    end
    updateHandUI()
end

handlers["sync_turnSummary"] = function(msg)
    gameState.turnCards = msg.turnCards
    gameState.stagedCard = nil
    gameState.isLocked = false
    updateInfoUI()
end

handlers["sync_updateBoard"] = function(msg)
    gameState.tableRows = msg.rows
    updateBoardUI()
end

handlers["sync_scoreUpdate"] = function(msg)
    scoreListFrame:clear()
    local sorted = {}
    for _, entry in ipairs(msg.scores) do
        table.insert(sorted, entry)
    end
    table.sort(sorted, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return (a.localIndex or 0) < (b.localIndex or 0)
    end)
    for i, entry in ipairs(sorted) do
        local pinfo = playerColorMap[entry.id]
        local localID = pinfo and pinfo.localID or entry.localIndex or "?"
        local color = pinfo and pinfo.color or colors.gray
        local isMe = (entry.id == os.getComputerID())
        -- 彩色 P-tag 按钮
        scoreListFrame:addButton():setPosition(2, i):setSize(4, 1)
            :setBackground(color):setForeground(colors.black):setText("P" .. tostring(localID))
        -- 分数文字
        scoreListFrame:addLabel():setPosition(7, i)
            :setForeground(isMe and colors.yellow or colors.white)
            :setText(tostring(entry.score))
    end
    -- scoreFooterLbl3:setText("Phase: ROUND OVER")
end

handlers["sync_statusUpdate"] = function(msg)
    scoreFooterLbl2:setText("Players: " .. msg.current .. "/" .. msg.total)
end

handlers["ev_waitingStatus"] = function(msg)
    gameState.waitingTarget = msg.targetID
    updateInfoUI()
end

-- [选行逻辑]
handlers["req_rowChoice"] = function(msg)
    gameState.gamePhase = "ROW_SELECT"
    gameState.tableRows = msg.rows
    gameState.waitingTarget = nil
    gameState.selectedRowIdx = 1
    showToast("Choose a Row!", 2, colors.red)
    refreshAll()
end

-- [新回合/结束]
handlers["ev_newTurn"] = function(msg)
    gameState.gamePhase = "PLAYING"
    gameState.isLocked = false
    gameState.stagedCard = nil
    gameState.turnCards = {}
    gameState.waitingTarget = nil
    gameState.turnTimer = 20
    scoreFooterLbl3:setText("Phase: PLAYING")
    refreshAll()
end

handlers["ev_roundOver"] = function(msg)
    gameState.gamePhase = "ROUND_OVER"
    gameState.stagedCard = nil
    gameState.turnTimer = 0
    scoreFooterLbl3:setText("Phase: ROUND OVER")
end

handlers["ev_gameOver"] = function(msg)
    gameState.gamePhase = "GAME_OVER"
    gameState.turnTimer = 0
    scoreFooterLbl3:setText("== GAME OVER ==")
end

-- 服务器主动广播关闭（Ctrl+T / 正常关机）
handlers["ev_serverClosing"] = function(msg)
    onServerDisconnected(msg.msg or "Room discarded")
end

-- 心跳：更新最后收到消息的时间戳
handlers["ev_heartbeat"] = function(msg)
    timerLastServerMsg = os.clock()
end

-------------------------------------------------------------------------
-- 网络事件处理
-------------------------------------------------------------------------
basalt.onEvent("rednet_message", function(senderID, msg, protocol)
    NIMMT_DEBUG(string.format("from=%s type=%s proto=%s", tostring(senderID), tostring(msg.type), tostring(protocol)))
    if protocol ~= PROTOCOL then return end

    -- 房间列表查询响应（即使在连接前也可接收）
    if msg.type == "sync_roomList" then
        local func = handlers[msg.type]
        if func then func(msg) end
        return
    end

    -- 待定连接：收到 sync_lobbyUpdate 即确认连接成功
    if pendingServerID and senderID == pendingServerID and msg.type == "sync_lobbyUpdate" then
        NIMMT_DEBUG("pending confirmed! server=" .. senderID)
        SERVER_ID = senderID
        timerLastServerMsg = os.clock()
        config.lastServerID = senderID
        utils.saveConfig(config, CONFIG_FILE)
        pendingServerID = nil
        timerPendingConnect = nil
        local func = handlers[msg.type]
        if func then func(msg) end
        return
    end

    -- 已建立连接的正常消息处理（按 roomID 过滤广播）
    if senderID == SERVER_ID then
        timerLastServerMsg = os.clock()
        if msg.roomID and msg.roomID ~= gameState.roomID then return end
        local func = handlers[msg.type]
        if func then
            func(msg)
        else
            print("Unknown msg: " .. tostring(msg.type))
        end
    end
end)

basalt.onEvent("key", function(key) end)

-- 超时检测循环：连接超时(4s) + 心跳超时(10s)
basalt.schedule(function()
    while true do
        os.sleep(2)
        -- 待定连接 4s 超时
        if pendingServerID and (os.clock() - timerPendingConnect) > 4 then
            NIMMT_DEBUG("pending timeout for " .. tostring(pendingServerID))
            pendingServerID = nil
            timerPendingConnect = nil
            menuStatusLbl:setForeground(colors.red):setText("Connection timed out!")
        end
        -- 已建立连接的心跳超时（10s 无任何消息）
        if SERVER_ID and (os.clock() - timerLastServerMsg) > 10 then
            onServerDisconnected("Connection lost")
        end
    end
end)

-- 回合倒计时更新（每 1s 递减）
basalt.schedule(function()
    while true do
        os.sleep(1)
        if gameState.turnTimer > 0 then
            gameState.turnTimer = gameState.turnTimer - 1
            if turnTimer and not turnTimer._destroyed then
                turnTimer:setText(gameState.turnTimer > 0 and "Time: " .. gameState.turnTimer .. "s" or "")
            end
        end
    end
end)

basalt.run()
