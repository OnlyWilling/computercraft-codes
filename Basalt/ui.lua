-- 引入所需的API
local basalt = require("basalt")

-- 1. 创建窗口
-- 清空屏幕
term.clear()
term.setCursorPos(1, 1)
print("===Starting UI and Shell...===")
os.sleep(2) -- 确保用户看到启动信息

local native_term = term.current()
local screenW, screenH = term.getSize()

-- 为UI创建一个窗口，占据屏幕上方大部分区域
-- window.create(parent_term, x, y, width, height)
local shell_height = 8
local ui_height = screenH - shell_height
local ui_window = window.create(term.current(), 1, 1, screenW, ui_height)

-- 为shell创建一个窗口，占据屏幕下方5行
local shell_window = window.create(term.current(), 1, ui_height + 2, screenW, shell_height - 1)

-- 2. 定义UI任务函数
local function ui_task()
    -- 将所有Basalt的绘制操作重定向到UI窗口
    local main = basalt.createFrame(ui_window)
        :setSize(ui_window.getSize()) -- 设置大小为UI窗口的大小

    -- 添加一个标题
    local label1 = main:addLabel()
        :setText("Basalt UI Panel")
        :setPosition(3, 2)

    -- 添加一个按钮，点击时在下方的shell窗口打印信息
    local btn1 = main:addButton()
        :setPosition(3, 4)
        :setSize(20, 3)
        :setText("Print to Shell")
        :onClick(function()
            -- 直接在shell窗口对象上操作
            local s_cursorX, s_cursorY = shell_window.getCursorPos()
            if s_cursorY < shell_height - 1 then
                shell_window.setCursorPos(1, s_cursorY) -- 移到行首
                shell_window.write("Button was clicked!\n")
                shell_window.setCursorPos(1, s_cursorY + 1)
            else
                shell_window.scroll(1)                         -- 如果内容多了，向上滚动
                shell_window.setCursorPos(1, shell_height - 2) -- 保持在最后一行
                shell_window.write("Button was clicked!\n")
                shell_window.setCursorPos(1, shell_height - 1)
            end
        end)
    -- 添加一个按钮，点击时退出程序
    local btn2 = main:addButton()
        :setPosition(25, 4)
        :setSize(20, 3)
        :setText("Clear Shell")
        :onClick(function()
            shell_window.clear()
            shell_window.setCursorPos(1, 1)
        end)
    local btn3 = main:addButton()
        :setPosition(14, 8)
        :setSize(20, 3)
        :setText("Exit Program")
        :onClick(function()
            -- 退出程序
            if basalt.isRunning then
                basalt.stop()
            end
        end)
    -- 启动Basalt事件循环，它只会监听和绘制在ui_window上
    basalt.run()
end

-- 3. 定义Shell任务函数
local function shell_task()
    -- 将所有shell相关的操作重定向到shell窗口
    term.redirect(shell_window)

    -- 给shell窗口一个初始提示
    shell_window.clear()
    shell_window.setCursorPos(1, 1)
    print("Standard CC Shell. Type 'exit' to stop.")

    -- 运行一个交互式shell
    os.run({}, "/rom/programs/shell.lua") -- 这里的{}表示没有传递任何参数给shell

    -- 任务结束后，恢复重定向
    term.redirect(native_term)
    print("===Shell task finished===")
    os.sleep(2) -- 给用户一点时间看到结束信息
end


-- 4. 使用 parallel API 同时运行两个任务
-- parallel.waitForAny会一直运行，直到其中一个函数返回
parallel.waitForAny(ui_task, shell_task)


-- 5. 程序结束后的清理工作
term.redirect(native_term) -- 确保终端重定向回原始终端
term.clear()
term.setCursorPos(1, 1)
print("Program terminated.")
