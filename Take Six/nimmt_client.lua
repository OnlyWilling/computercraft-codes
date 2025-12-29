local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem found") end
rednet.open(peripheral.getName(modem))

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

local function saveConfig(configTable, path)
    local file = fs.open(path, "w")
    if file then
        file.write(textutils.serialize(configTable))
        file.close()
        return true
    else
        printError("Error: Cannot write " .. path)
        return false
    end
end

-- 加载配置
local function loadConfig()
    if fs.exists(CONFIG_FILE) then
        local file, err_open = fs.open(CONFIG_FILE, "r")
        if not file then
            printError("Error: Cannot open " .. err_open)
            printError("Use default config...")
            return default_config
        end
        local data = textutils.unserialize(file.readAll())
        file.close()
        print("Loading config from " .. CONFIG_FILE)
        return data
    else
        print("Config not found. Create default config...")
        saveConfig(default_config, CONFIG_FILE)
        return default_config
    end
end

local function findServer()
    term.clear()
    term.setCursorPos(1, 1)
    print("Looking for '6 Nimmt!' Server...")

    -- 1. 尝试通过 Rednet DNS 查找
    -- lookup 返回一个列表 {id1, id2...}，我们取第一个
    local id = rednet.lookup(PROTOCOL, "NIMMT_SERVER")

    if id then
        print("Auto-detected Server ID: " .. id)
        return id
    end

    -- 2. 如果没找到，检查是否有上次存的 ID
    if config.lastServerID then
        print("No server broadcast found.")
        write("Use last known ID " .. config.lastServerID .. "? (Y/n): ")
        local input = read()
        if input == "" or input:lower() == "y" then
            return config.lastServerID
        end
    end

    -- 3. 彻底找不到，手动输入
    print("Could not find server automatically.")
    write("Please enter Server ID manually: ")
    return tonumber(read())
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
    saveConfig(config, CONFIG_FILE)
else
    error("Invalid Server ID")
end

print("Connecting to ID: " .. SERVER_ID .. "...")
rednet.send(SERVER_ID, { type = "JOIN" }, PROTOCOL)

----------------------------------------------
-- 客户端状态
----------------------------------------------
local myHand = {}                    -- 当前玩家手牌
local tableRows = { {}, {}, {}, {} } -- 牌局四行情况
local selectedHandIdx = 1            -- 选中牌的编号
local selectedRowIdx = 1             -- 选行光标 (1-4)
local stagedCard = nil               -- 当前选中卡牌
-- 状态枚举: "LOBBY", "PLAYING", "ROW_SELECT", "GAME_OVER"
local gamePhase = "LOBBY"
local isHost = false
local lobbyCount = 1
local toastMsg = ""
local toastTimer = 0

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
    -- 1. 绘制桌面 4 行
    for i = 1, 4 do
        term.setCursorPos(2, 3 + i)
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

    -- 2. 绘制提示信息
    term.setCursorPos(1, 10)
    term.clearLine()
    if gamePhase == "ROW_SELECT" then
        term.setTextColor(colors.red)
        print("!!! CARD TOO SMALL !!! Select a row to eat (UP/DOWN + ENTER)")
    elseif gamePhase == "PLAYING" then
        term.setTextColor(colors.lightBlue)
        print("Your Hand (LEFT/RIGHT + ENTER):")
    end
    term.setTextColor(colors.white)

    -- 3. 绘制手牌
    term.setCursorPos(1, 12)
    term.clearLine()
    for i, card in ipairs(myHand) do
        if gamePhase == "PLAYING" then
            if card == stagedCard then
                term.setTextColor(colors.green) -- 已选中的牌显示绿色
                term.write("[" .. card .. "] ")
            elseif i == selectedHandIdx then
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
                drawUI()
            elseif msg.type == "DEAL_HAND" or msg.type == "UPDATE_HAND" then
                myHand = msg.hand
                table.sort(myHand)
                -- 修正光标防止越界
                if selectedHandIdx > #myHand then selectedHandIdx = math.max(1, #myHand) end
                drawUI()
            elseif msg.type == "UPDATE_BOARD" then
                tableRows = msg.rows
                drawUI()
                -- [选行逻辑]
            elseif msg.type == "REQUEST_ROW_CHOICE" then
                gamePhase = "ROW_SELECT"
                tableRows = msg.rows -- 更新一下残局
                selectedRowIdx = 1
                drawUI()
                -- [新回合/结束]
            elseif msg.type == "NEW_TURN" then
                gamePhase = "PLAYING" -- 恢复出牌模式
                stagedCard = nil
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
            if key == keys.left and selectedHandIdx > 1 then
                selectedHandIdx = selectedHandIdx - 1
                drawUI()
            elseif key == keys.right and selectedHandIdx < #myHand then
                selectedHandIdx = selectedHandIdx + 1
                drawUI()
            elseif key == keys.enter and #myHand > 0 then
                local card = myHand[selectedHandIdx]
                stagedCard = card
                rednet.send(SERVER_ID, { type = "PLAY_CARD", card = card }, PROTOCOL)
                toastMsg = "Sent card " .. card .. "..."
                toastTimer = 2
                drawUI()
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
