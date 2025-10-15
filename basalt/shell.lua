-- 引入所需的API
local basalt = require("basalt")
local shell = require("shell")

-- 1. 创建窗口
-- 清空屏幕
term.clear()
term.setCursorPos(1, 1)

local screenW, screenH = term.getSize()

-- 为UI创建一个窗口，占据屏幕上方大部分区域
-- window.create(parent_term, x, y, width, height)
local ui_height = screenH - 6
local ui_window = window.create(term.current(), 1, 1, screenW, ui_height)

-- 为shell创建一个窗口，占据屏幕下方5行
local shell_window = window.create(term.current(), 1, ui_height + 2, screenW, 5)

-- 2. 定义UI任务函数
local function ui_task()
    -- 将所有Basalt的绘制操作重定向到UI窗口
    local main = basalt.createFrame(ui_window)
        :setSize(ui_window.getSize()) -- 设置大小为UI窗口的大小

    -- 添加一个标题
    main:addLabel()
        :setText("Basalt UI Panel")
        :setPosition(3, 2)
        
    -- 添加一个按钮，点击时在下方的shell窗口打印信息
    main:addButton()
        :setText("Print to Shell")
        :setPosition(3, 4)
        :onClick(function()
            -- 直接在shell窗口对象上操作
            local s_cursorX, s_cursorY = shell_window.getCursorPos()
            shell_window.setCursorPos(1, s_cursorY) -- 移到行首
            shell_window.write("Button was clicked!\n")
            shell_window.setCursorPos(1, s_cursorY + 1) -- 换行
            shell_window.scroll(1) -- 如果内容多了，向上滚动
        end)

    -- 启动Basalt事件循环，它只会监听和绘制在ui_window上
    basalt.run()
end

-- 3. 定义Shell任务函数
local function shell_task()
    -- 将所有shell相关的操作重定向到shell窗口
    local old_term = term.redirect(shell_window)
    
    -- 给shell窗口一个初始提示
    shell_window.clear()
    shell_window.setCursorPos(1, 1)
    print("Standard CC Shell. Type 'exit' to stop.")

    -- 运行一个交互式shell
    shell.run()

    -- 任务结束后，恢复重定向
    term.redirect(old_term)
    print("Shell task finished.")
end


-- 4. 使用 parallel API 同时运行两个任务
print("Starting UI and Shell...")
-- parallel.waitForAny会一直运行，直到其中一个函数返回
parallel.waitForAny(ui_task, shell_task)


-- 5. 程序结束后的清理工作
term.clear()
term.setCursorPos(1, 1)
print("Program terminated.")

