local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem found") end
rednet.open(peripheral.getName(modem))

local PROTOCOL = "NIMMT"
local SERVER_ID = nil -- 运行可以先广播寻找服务器，或者手动输入

print("Enter Server ID:")
SERVER_ID = tonumber(read())

rednet.send(SERVER_ID, { type = "JOIN" }, PROTOCOL)

local myHand = {}                    -- 当前玩家手牌
local tableRows = { {}, {}, {}, {} } -- 牌局四行情况
local selectedIndex = 1              -- 选中牌的编号
local isSelectingRow = false         -- 小行状态标记

local function drawUI()
    term.clear()
    term.setCursorPos(1, 1)
    print("--- 6 Nimmt! (Client) ---")

    -- 绘制桌面
    for i = 1, 4 do
        term.setCursorPos(2, 3 + i)
        write("Row " .. i .. ": ")
        for _, card in ipairs(tableRows[i]) do
            write("[" .. card .. "] ")
        end
    end

    -- 绘制手牌
    local hY = 10
    term.setCursorPos(2, hY)
    print("Your Hand (Arrow Keys to Select, Enter to Play):")
    for i, card in ipairs(myHand) do
        if i == selectedIndex then
            term.setTextColor(colors.yellow)
            write(">" .. card .. "< ")
        else
            term.setTextColor(colors.white)
            write(" " .. card .. "  ")
        end
    end
    term.setTextColor(colors.white)
end

-- 接收网络
local function net_loop()
    while true do
        local id, msg = rednet.receive(PROTOCOL)
        if msg.type == "DEAL_HAND" then
            myHand = msg.hand
            table.sort(myHand) -- 手牌自动排序方便查看
            drawUI()
        elseif msg.type == "GAME_START" or msg.type == "UPDATE_BOARD" then
            tableRows = msg.rows
            drawUI()
        elseif msg.type == "REQUEST_ROW_CHOICE" then
            isSelectingRow = true
            tableRows = msg.rows -- 更新一下最新的残局
            drawUI()
            term.setCursorPos(1, 15)
            print("CARD TOO SMALL! Choose a row to eat (1-4)!")
            -- 这里可以写个逻辑把光标移到 Row 1
        end
    end
end

-- 处理输入
local function client_interact()
    while true do
        if isSelectingRow then
            local event, key = os.pullEvent("key")
            isSelectingRow = false
            print("Row has been chosen...")
            -- 这里写选择 1-4 行的逻辑
            -- 按上下键选择行，按 Enter 发送 {type="CHOOSE_ROW", rowIndex=...}
            -- 发送完后 isSelectingRow = false，并在屏幕显示 "Waiting..."
        else
            local event, key = os.pullEvent("key")
            if key == keys.left and selectedIndex > 1 then
                selectedIndex = selectedIndex - 1
                drawUI()
            elseif key == keys.right and selectedIndex < #myHand then
                selectedIndex = selectedIndex + 1
                drawUI()
            elseif key == keys.enter then
                -- 出牌
                local cardToPlay = table.remove(myHand, selectedIndex)
                if selectedIndex > #myHand then selectedIndex = #myHand end -- 修正光标

                rednet.send(SERVER_ID, { type = "PLAY_CARD", card = cardToPlay }, PROTOCOL)
                term.setCursorPos(1, 15)
                print("Card " .. cardToPlay .. " sent! Waiting...")
                drawUI()
            end
        end
    end
end

-- 启动并行循环：接收网络消息 + 处理按键
parallel.waitForAny(net_loop, client_interact)
