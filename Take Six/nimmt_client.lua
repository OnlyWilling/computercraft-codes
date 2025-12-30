local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem found") end
rednet.open(peripheral.getName(modem))

local utils = require("utils")
local PROTOCOL = "NIMMT"
local CONFIG_FILE = shell.resolve(".nimmt_config") -- 隐藏文件，存储配置
local SERVER_ID = nil                              -- 运行可以先广播寻找服务器，或者手动输入

----------------------------------------------
-- 配置文件管理系统
----------------------------------------------
local default_config = {
    lastServerID = nil
}

local config = {
    lastServerID = nil
}

local function findServer()
    term.clear()
    term.setCursorPos(1, 1)
    print("Looking for '6 Nimmt!' Server...")

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
local myHand = {}                    -- 当前玩家手牌
local tableRows = { {}, {}, {}, {} } -- 牌局四行情况
local turnCards = {}                 -- 本轮展示的牌
local selectedHandIdx = 1            -- 选中牌的编号
local selectedRowIdx = 1             -- 选行光标 (1-4)
local stagedCard = nil               -- 当前选中卡牌
-- 状态枚举: "LOBBY", "PLAYING", "ROW_SELECT", "GAME_OVER"
local gamePhase = "LOBBY"
local isHost = false
local isLocked = false -- 是否锁定了出牌
local lobbyCount = 1
local toastMsg = ""
local toastTimer = 0
local waitingTarget = nil -- 当前正在等待谁选行

----------------------------------------------
-- UI 绘制系统
----------------------------------------------
local function drawHeader()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.clearLine()
    if toastTimer > 0 then
        term.write(" NOTE: " .. toastMsg) -- 显示临时通知
    else
        term.write(" 6 Nimmt! | Phase: " .. gamePhase)
    end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

local function drawLobby()
    term.setCursorPos(1, 3)
    print("Waiting for players...")
    print("Current Players: " .. lobbyCount)

    term.setCursorPos(1, 6)
    if isHost then
        term.setTextColor(colors.yellow)
        print("You are the HOST.")
        term.setTextColor(colors.white)
        print("Press [ENTER] to Start Game.")
    else
        print("Waiting for Host to start...")
    end
end

local function drawGame()
    -- 1. 绘制回合出牌历史 (顶部)
    term.setCursorPos(1, 2)
    term.setTextColor(colors.gray)
    term.write("Turn: ")
    for _, entry in ipairs(turnCards) do
        term.setTextColor(colors.white)
        term.write(entry.card)
        term.setTextColor(colors.cyan)
        term.write("(" .. entry.id .. ") ")
    end

    -- 2. 绘制等待信息
    if waitingTarget then
        term.setCursorPos(1, 3)
        term.setTextColor(colors.magenta)
        term.clearLine()
        term.write(">>> Waiting for Player " .. waitingTarget .. " to choose row... <<<")
    end

    -- 3. 绘制桌面 4 行
    for i = 1, 4 do
        term.setCursorPos(2, 5 + i)
        term.clearLine()

        -- 如果正在选行模式，高亮选中的行
        if gamePhase == "ROW_SELECT" and i == selectedRowIdx then
            term.setTextColor(colors.yellow)
            term.write("-> Row " .. i .. ": ")
        else
            term.setTextColor(colors.lightGray)
            term.write("   Row " .. i .. ": ")
        end

        term.setTextColor(colors.white)
        for _, card in ipairs(tableRows[i]) do
            term.write("[" .. card .. "] ")
        end
    end

    -- 4. 绘制提示信息
    term.setCursorPos(1, 12)
    term.clearLine()
    if gamePhase == "ROW_SELECT" then
        term.setTextColor(colors.red)
        print("!!! CARD TOO SMALL !!! Select a row to eat (UP/DOWN + ENTER)")
    elseif gamePhase == "PLAYING" then
        if isLocked then
            term.setTextColor(colors.green)
            print("Card sent! Waiting for others... (Backspace to withdraw)")
        else
            term.setTextColor(colors.lightBlue)
            print("Your Hand (LEFT/RIGHT + ENTER):")
        end
    end
    term.setTextColor(colors.white)

    -- 5. 绘制手牌
    term.setCursorPos(1, 14)
    term.clearLine()
    for i, card in ipairs(myHand) do
        if gamePhase == "PLAYING" then
            if card == stagedCard then
                term.setTextColor(colors.green) -- 已选中的牌显示绿色
                term.write("[" .. card .. "] ")
            elseif i == selectedHandIdx and not isLocked then
                term.setTextColor(colors.yellow)
                term.write(">" .. card .. "< ")
            else
                term.setTextColor(colors.white)
                term.write(" " .. card .. "  ")
            end
        end
    end
end

local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    drawHeader()

    if gamePhase == "LOBBY" then
        drawLobby()
    elseif gamePhase == "GAME_OVER" then
        term.setCursorPos(1, 5)
        print("GAME OVER! See Server console for scores.")
    else
        drawGame()
    end
end

----------------------------------------------
-- 网络消息处理
----------------------------------------------
local function net_loop()
    while true do
        local id, msg = rednet.receive(PROTOCOL)
        -- 过滤非本局消息
        if id == SERVER_ID then
            -- [大厅逻辑]
            if msg.type == "LOBBY_UPDATE" then
                lobbyCount = msg.count
                drawUI()
            elseif msg.type == "SET_HOST" then
                isHost = true
                drawUI()
                -- [游戏通用]
            elseif msg.type == "TOAST" then
                toastMsg = msg.msg
                toastTimer = 5 -- 显示约 5 帧或秒
                drawUI()
            elseif msg.type == "GAME_START" then
                gamePhase = "PLAYING"
                tableRows = msg.rows
                if msg.roundReset then
                    turnCards = {} -- 新一轮清空历史
                    waitingTarget = nil
                end
                drawUI()
            elseif msg.type == "DEAL_HAND" or msg.type == "UPDATE_HAND" then
                myHand = msg.hand
                table.sort(myHand)
                -- 修正光标防止越界
                if selectedHandIdx > #myHand then selectedHandIdx = math.max(1, #myHand) end
                drawUI()
            elseif msg.type == "TURN_SUMMARY" then
                turnCards = msg.cards -- 接收服务器发来的排序好的出牌列表
                stagedCard = nil      -- 结算开始了，清除自己的预选标记
                isLocked = false      -- 解锁状态
                drawUI()
            elseif msg.type == "UPDATE_BOARD" then
                tableRows = msg.rows
                drawUI()
            elseif msg.type == "SCORE_UPDATE" then
                -- 可以在这里做一个弹窗显示分数，目前简化为Toast
                toastMsg = "Scores updated!"
                toastTimer = 5
                drawUI()
            elseif msg.type == "WAITING_STATUS" then
                waitingTarget = msg.targetID
                drawUI()
                -- [选行逻辑]
            elseif msg.type == "REQUEST_ROW_CHOICE" then
                gamePhase = "ROW_SELECT"
                tableRows = msg.rows -- 更新一下残局
                waitingTarget = nil  -- 既然轮到我了，就不用显示等待别人了
                selectedRowIdx = 1
                drawUI()
                -- [新回合/结束]
            elseif msg.type == "NEW_TURN" then
                gamePhase = "PLAYING" -- 恢复出牌模式
                isLocked = false
                stagedCard = nil
                turnCards = {} -- 清空上一回合的出牌展示
                waitingTarget = nil
                drawUI()
            elseif msg.type == "ROUND_OVER" then
                gamePhase = "ROUND_OVER"
                stagedCard = nil
                drawUI()
            end
        end
    end
end

----------------------------------------------
-- 简易定时器 (处理 Toast 消失)
----------------------------------------------
local function toastTimer_loop()
    while true do
        os.sleep(0.5)
        if toastTimer > 0 then
            toastTimer = toastTimer - 1
            if toastTimer == 0 then drawUI() end -- 消息过期，重绘去除
        end
    end
end

----------------------------------------------
-- 用户输入处理
----------------------------------------------
local function input_loop()
    while true do
        local event, key = os.pullEvent("key")

        -- [阶段 A] 大厅
        if gamePhase == "LOBBY" then
            if isHost and key == keys.enter then
                rednet.send(SERVER_ID, { type = "START" }, PROTOCOL)
            end
            -- [阶段 B] 正常出牌
        elseif gamePhase == "PLAYING" then
            if isLocked then
                if key == keys.backspace then
                    isLocked = false
                    stagedCard = nil
                    drawUI()
                end
            else
                if key == keys.left and selectedHandIdx > 1 then
                    selectedHandIdx = selectedHandIdx - 1
                    drawUI()
                elseif key == keys.right and selectedHandIdx < #myHand then
                    selectedHandIdx = selectedHandIdx + 1
                    drawUI()
                elseif key == keys.enter and #myHand > 0 then
                    local card = myHand[selectedHandIdx]
                    stagedCard = card
                    isLocked = true -- 锁定操作
                    rednet.send(SERVER_ID, { type = "PLAY_CARD", card = card }, PROTOCOL)
                    toastMsg = "Sent card " .. card .. "..."
                    toastTimer = 2
                    drawUI()
                end
            end
            -- [阶段 C] 强制选行
        elseif gamePhase == "ROW_SELECT" then
            if key == keys.up and selectedRowIdx > 1 then
                selectedRowIdx = selectedRowIdx - 1
                drawUI()
            elseif key == keys.down and selectedRowIdx < 4 then
                selectedRowIdx = selectedRowIdx + 1
                drawUI()
            elseif key == keys.enter then
                rednet.send(SERVER_ID, { type = "CHOOSE_ROW", rowIndex = selectedRowIdx }, PROTOCOL)
                toastMsg = "Chose Row " .. selectedRowIdx .. ", Waiting..."
                toastTimer = 5
                drawUI()
            end
        end
    end
end

parallel.waitForAny(net_loop, input_loop, toastTimer_loop)
