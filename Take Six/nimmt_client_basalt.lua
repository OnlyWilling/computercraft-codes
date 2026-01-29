local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem found") end
rednet.open(peripheral.getName(modem))

local utils = require("utils")
local basalt = require("basalt")
local PROTOCOL = "NIMMT"
local CONFIG_FILE = shell.resolve(".nimmt_config") -- 隐藏文件，存储配置
local SERVER_ID = nil                              -- 运行可以先广播寻找服务器，或者手动输入

----------------------------------------------
-- 配置文件管理系统
----------------------------------------------
local default_config = { lastServerID = nil }
local config = { lastServerID = nil }

local function findServer()
    term.clear()
    term.setCursorPos(1, 1)
    print("Looking for [6 Nimmt] Server...")

    local id = rednet.lookup(PROTOCOL, "NIMMT_SERVER")
    if id then
        print("Auto-detected Server ID: " .. id)
        return id
    end

    config = utils.loadConfig(default_config, CONFIG_FILE)
    if config.lastServerID then
        print("No server broadcast found.")
        term.write("Use last known ID " .. config.lastServerID .. "? (Y/n): ")
        local input = term.read()
        if input == "" or input:lower() == "y" then
            return config.lastServerID
        end
    end

    print("Could not find server automatically.")
    term.write("Please enter Server ID manually: ")
    return tonumber(term.read())
end

----------------------------------------------
-- 初始化自组网
----------------------------------------------
term.clear()
term.setCursorPos(1, 1)
print("--- 6 Nimmt! Client ---")
-- 执行查找
SERVER_ID = findServer()
if SERVER_ID then
    config.lastServerID = SERVER_ID
    utils.saveConfig(config, CONFIG_FILE)
else
    error("Server Not Found!")
end

print("Connecting to ID: " .. SERVER_ID .. "...")
rednet.send(SERVER_ID, { type = "JOIN" }, PROTOCOL)

----------------------------------------------
-- 客户端状态
----------------------------------------------
local gameState = {
    -- 基础连接信息
    gamePhase = "LOBBY",
    isHost = false,
    lobbyCount = 1,
    -- 消息提示
    toastMsg = "",
    toastTimer = 0,
    -- UI 交互状态
    selectedHandIdx = 1,            -- 选中牌的编号
    selectedRowIdx = 1,             -- 选行光标 (1-4)
    stagedCard = nil,               -- 当前选中卡牌
    waitingTarget = nil,            -- 当前正在等待谁选行
    isLocked = false,               -- 是否锁定了出牌
    -- 游戏内数据
    hand = {},                      -- 当前玩家手牌
    tableRows = { {}, {}, {}, {} }, -- 牌局四行情况
    turnCards = {},                 -- 本轮展示的牌
}

-------------------------------------------------------------------------
-- Basalt UI 布局构建
-------------------------------------------------------------------------

-- [大厅界面层级结构]
-- title: 标题文本栏
-- buttonArea: 按钮选项区
local lobbyFrame = basalt.createFrame()
    :setForeground(colors.white):setBackground(colors.black)

local title = lobbyFrame:addLabel()
    :setPosition("{parent.width / 2 - 4}", 2)

lobbyFrame:addLabel():setText("Server ID:"):setPosition(4, 6)
local inputServer = lobbyFrame:addInput({
        placeholder = "Room ID",
        placeholderColor = colors.gray,
    })
    :setPosition(15, 6):setSize(10, 1)
    :setBackground(colors.black):setForeground(colors.white)

local lblStatus = lobbyFrame:addLabel()
    :setPosition("parent.w / 2 - 10", 10)
    :setForeground(colors.lightGray)
    :setText("Status: Not Connected")

local btnJoin = lobbyFrame:addButton()
    :setPosition("parent.w / 2 - 8", 12):setSize(16, 3)
    :setBackground(colors.blue)
    :setText("Join Room")
    :onClick(function()
        local sID = tonumber(inputServer:getValue())
        if not sID then
            showToast("Invalid Server ID", 2, colors.red)
            return
        end
        SERVER_ID = sID
        rednet.send(SERVER_ID, { type = "JOIN_ROOM" }, PROTOCOL)
        lblStatus:setText("Status: Connecting...")
    end)

-- 开始游戏按钮 (仅房主可见，默认隐藏)
local btnStartGame = lobbyFrame:addButton()
    :setText("START GAME")
    :setPosition("parent.w / 2 - 8", 16)
    :setSize(16, 3)
    :setBackground(colors.green)
    :hide()
    :onClick(function()
        rednet.send(SERVER_ID, { type = "START_GAME" }, PROTOCOL)
    end)

-- [游戏界面层级结构]
-- header: 顶部信息栏
-- boardArea: 中间游戏区 (显示4行)
-- infoArea: 也就是TurnCards，显示本轮出牌
-- handArea: 底部手牌区
local gameFrame = basalt.createFrame()
    :setForeground(colors.white):setBackground(colors.black)

local header = gameFrame:addFrame()
    :setPosition(1, 1):setSize("{parent.width}", 1)
    :setBackground(colors.blue)

local titleLabel = header:addLabel()
    :setPosition(2, 2)
    :setForeground(colors.white)
    :setText("6 Nimmt! Room: ?")

local statusLabel = header:addLabel()
    :setPosition("{parent.width - 20}", 2)
    :setForeground(colors.yellow)
    :setText("Phase: LOBBY")

local boardArea = gameFrame:addFrame()
    :setPosition(1, 8):setSize("{parent.width}", 12)
    :setBackground(colors.black)

local infoArea = gameFrame:addFrame()
    :setPosition(1, 4):setSize("{parent.width}", 4)
    :setBackground(colors.gray)
local infoLbl = infoArea:addLabel()
    :setPosition(2, 2)
    :setText("Turn Cards:")

local handArea = gameFrame:addFrame()
    :setPosition(1, "{parent.height - 5}"):setSize("{parent.width}", 6)
    :setBackground(colors.black)
local handLbl = handArea:addLabel()
    :setPosition(2, 1):setForeground(colors.lightBlue)
    :setText("Your Hand:")

-- 消息提示框 (Toast / Modal)
local toastFrame = gameFrame:addFrame({ visible = false })
    :setPosition("{parent.width / 2 - 15}", "{parent.height / 2 - 2}"):setZ(10):setSize(30, 5)
    :setBackground(colors.red)
local toastLabel = toastFrame:addLabel()
    :setPosition(2, 2):setSize("{parent.width}", 3)
    :setForeground(colors.white)
    :setText("Notification")

-------------------------------------------------------------------------
-- UI 组件封装 (Helper Functions)
-------------------------------------------------------------------------

-- 显示 Toast 消息
local function showToast(msg, duration, color)
    toastFrame:setBackground(color or colors.red)
    toastLabel:setText(msg)
    toastFrame.visible = true
    -- 使用 Basalt 的内置定时任务
    basalt.schedule(function()
        os.sleep(duration or 2)
        toastFrame.visible = false
    end)
end

-- 切换界面至游戏界面
local function switchToGame()
    lobbyFrame.visible = false
    gameFrame.visible = true
    showToast("Game Started!", 2, colors.green)
end

-- 绘制一张卡牌 (Card Widget)
-- parent: 父容器
-- x, y: 坐标
-- value: 牌面数值
-- onClickFunc: 点击回调
-- isSelected: 是否高亮
local function createCard(parent, x, y, value, onClickFunc, isSelected)
    local bgCol = isSelected and colors.yellow or colors.white
    local fgCol = isSelected and colors.black or colors.black

    -- 牛头数颜色处理
    local score = 1
    if value == 55 then
        score = 7; bgCol = colors.red; fgCol = colors.white
    elseif value % 11 == 0 then
        score = 5; bgCol = colors.orange
    elseif value % 10 == 0 then
        score = 3; bgCol = colors.lightBlue
    elseif value % 5 == 0 then
        score = 2; bgCol = colors.cyan
    end

    -- 卡牌主体
    local card = parent:addButton()
        :setPosition(x, y)
        :setSize(4, 3) -- 宽4 高3 的小方块
        :setBackground(bgCol)
        :setForeground(fgCol)
        :setText(tostring(value))

    if onClickFunc then
        card:onClick(onClickFunc)
    end

    -- 装饰：牛头标记（可选，简单用字符表示）
    -- 这里省略复杂绘图，用颜色区分足以
    return card
end

-------------------------------------------------------------------------
-- 动态 UI 更新逻辑
-------------------------------------------------------------------------

-- 刷新手牌区
local function updateHandUI()
    handArea:removeChild() -- 清空旧牌
    handArea:addLabel():setPosition(2, 1):setForeground(colors.lightBlue):setText("Your Hand:")

    local handX = 2
    local handY = 2

    for i, cardVal in ipairs(gameState.hand) do
        -- 判断这张牌是否被锁定了(已出)
        local isLocked = (cardVal == gameState.stagedCard)
        createCard(handArea, handX, handY, cardVal, function()
            -- 点击事件
            if gameState.phase == "PLAYING" and not gameState.stagedCard then
                gameState.stagedCard = cardVal
                rednet.send(SERVER_ID, { type = "PLAY_CARD", card = cardVal }, PROTOCOL)
                showToast("Card Sent!", 2, colors.green)
                updateHandUI() -- 刷新以显示锁定状态
            end
        end, isLocked)         -- 如果被锁定，传入高亮参数
        handX = handX + 5      -- 间隔
    end
end

-- 刷新中央牌桌区
local function updateBoardUI()
    boardArea:removeChild()
    for i = 1, 4 do
        local rowY = 1 + (i - 1) * 3
        -- 行号标签
        local lbl = boardArea:addButton() -- 用Button做标签，方便点击
            :setPosition(2, rowY + 1):setSize(6, 1)
            :setBackground(colors.black)
            :setForeground(gameState.phase == "ROW_SELECT" and colors.yellow or colors.gray)
            :setText("Row " .. i)
        -- 如果处于选行阶段，点击行号触发
        if gameState.phase == "ROW_SELECT" then
            lbl:setBackground(colors.blue):setForeground(colors.white)
            lbl:onClick(function()
                rednet.send(SERVER_ID, { type = "CHOOSE_ROW", rowIndex = i }, PROTOCOL)
                gameState.phase = "WAITING"
                showToast("Row Selected", 2, colors.green)
                updateBoardUI()
            end)
        end
        -- 绘制该行的牌
        local rowData = gameState.tableRows[i]
        local rowX = 9
        for _, cVal in ipairs(rowData) do
            createCard(boardArea, rowX, rowY, cVal, nil, false)
            rowX = rowX + 5
        end
    end
end

-- 刷新顶部历史/状态区
local function updateInfoUI()
    infoArea:removeChild()
    infoArea:addLabel():setPosition(2, 2)
        :setText("Current Turn:")

    local x = 14
    for _, entry in ipairs(gameState.turnCards) do
        -- 小卡片展示
        local bg = colors.lightGray
        if entry.id == os.getComputerID() then bg = colors.green end

        local btn = infoArea:addButton():setPosition(x, 1):setSize(4, 3):setBackground(bg):setText(entry.card)
        x = x + 5
    end

    statusLabel:setText("Phase: " .. gameState.gamePhase)

    if gameState.waitingTarget then
        infoArea:addLabel():setPosition(2, 4):setForeground(colors.magenta)
            :setText("Waiting P" .. gameState.waitingTarget .. " to choose row...")
    end
end

-- 总刷新入口
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
handlers["LOBBY_UPDATE"] = function(msg)
    gameState.lobbyCount = msg.count
    titleLabel:setText("Room Players: " .. msg.count)
    if gameState.isHost then
        -- 如果是房主，显示开始按钮
        local startBtn = header:addButton():setPosition("{parent.width - 10}", 1):setSize(8, 3)
            :setText("START"):setBackground(colors.green)
            :onClick(function(self)
                rednet.send(SERVER_ID, { type = "START" }, PROTOCOL)
                self:destroy()
            end)
    end
end
handlers["SET_HOST"] = function(msg)
    gameState.isHost = true
end
-- [游戏通用]
handlers["TOAST"] = function(msg)
    showToast(msg.msg, 5, colors.orange)
end
handlers["GAME_START"] = function(msg)
    gameState.gamePhase = "PLAYING"
    gameState.tableRows = msg.rows
    if msg.roundReset then
        gameState.turnCards = {} -- 新一轮清空历史
        gameState.hand = {}
        gameState.waitingTarget = nil
    end
    refreshAll()
end
handlers["UPDATE_HAND"] = function(msg)
    gameState.hand = msg.hand
    table.sort(gameState.hand)
    -- 修正光标防止越界
    if gameState.selectedHandIdx > #gameState.hand then
        gameState.selectedHandIdx = math.max(1,
            #gameState.hand)
    end
    updateHandUI()
end
handlers["TURN_SUMMARY"] = function(msg)
    gameState.turnCards = msg.cards -- 接收服务器发来的排序好的出牌列表
    gameState.stagedCard = nil      -- 结算开始了，清除自己的预选标记
    gameState.isLocked = false      -- 解锁状态
    updateInfoUI()
end
handlers["UPDATE_BOARD"] = function(msg)
    gameState.tableRows = msg.rows
    updateBoardUI()
end
handlers["SCORE_UPDATE"] = function(msg)
    -- 可以在这里做一个弹窗显示分数，目前简化为Toast
    gameState.toastMsg = "Scores updated!"
    gameState.toastTimer = 5
end
handlers["WAITING_STATUS"] = function(msg)
    gameState.waitingTarget = msg.targetID
end
-- [选行逻辑]
handlers["REQUEST_ROW_CHOICE"] = function(msg)
    gameState.gamePhase = "ROW_SELECT"
    gameState.tableRows = msg.rows -- 更新一下残局
    gameState.waitingTarget = nil  -- 既然轮到我了，就不用显示等待别人了
    gameState.selectedRowIdx = 1
    showToast("Choose a Row!", 5, colors.red)
    refreshAll()
end
-- [新回合/结束]
handlers["NEW_TURN"] = function(msg)
    gameState.gamePhase = "PLAYING" -- 恢复出牌模式
    gameState.isLocked = false
    gameState.stagedCard = nil
    gameState.turnCards = {} -- 清空上一回合的出牌展示
    gameState.waitingTarget = nil
    refreshAll()
end
handlers["ROUND_OVER"] = function(msg)
    gameState.gamePhase = "ROUND_OVER"
    gameState.stagedCard = nil
end

-------------------------------------------------------------------------
-- 网络事件处理 (Event Listeners)
-------------------------------------------------------------------------
-- 核心逻辑：监听 rednet_message 事件
basalt.onEvent("rednet_message", function(event, senderID, msg, protocol)
    -- 过滤：只处理来自服务器 且 协议正确的消息
    if senderID == SERVER_ID and protocol == PROTOCOL then
        local func = handlers[msg.type]
        if func then
            titleLabel:setText("Roger")
            func(msg)
        else
            -- 未知的消息类型，可以在开发时打印日志
            print("Unknown message type: " .. msg.type)
        end
    end
end)

----------------------------------------------
-- 用户输入处理
----------------------------------------------
basalt.onEvent("key", function(event, key)

end)

refreshAll()    -- 初始绘制
basalt.update() -- 启动 Basalt 主循环，接管一切
basalt.run()
