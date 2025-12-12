-- ===函数区===

-- 引入所需的API
local basalt = require("basalt")
local bimg_player = require("bimg_player")

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

local video_monitor = peripheral.find("monitor") or shell_window
local BASE_DIR = shell.getRunningProgram():match("(.*/)") or "/"
local program_file = fs.combine(BASE_DIR, "bimg_play_env.lua")
local video_path = "demo.bimg"

video_monitor.clear()
video_monitor.setCursorPos(1, 1)
video_monitor.write("Monitor Found")


-- 2. 定义UI任务函数
local function ui_task()
    -- 将所有Basalt的绘制操作重定向到UI窗口
    local main = basalt.createFrame(ui_window)
        :setSize(ui_window.getSize()) -- 设置大小为UI窗口的大小
    local monitor_frame = basalt.createFrame({
            background = colors.black,
        }):setTerm(video_monitor)
        :setSize(video_monitor.getSize())
    -- 添加一个标题
    local label1 = main:addLabel()
        :setText("Bimg Controler")
        :setPosition(3, 2)

    -- 添加一个按钮，点击时在下方的shell窗口打印信息
    local btn1 = main:addButton()
        :setPosition(3, 3)
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
    local btn2 = main:addButton()
        :setPosition(25, 3)
        :setSize(20, 3)
        :setText("Clear Shell")
        :onClick(function()
            shell_window.clear()
            shell_window.setCursorPos(1, 1)
        end)
    local btn3 = main:addButton()
        :setPosition(3, 7)
        :setSize(20, 3)
        :setText("Play Bimg")
        :onClick(function(self)
            local state = true
            if state then
                self:setText("Stop Play")
            else
                frame:destroy()
                self:setText("Play Bimg")
            end
            state = not state
            local frame = monitor_frame:addFrame()
                :setSize(video_monitor.getSize())
            local options = {}
            options.path = video_path
            options.loop = "-l"
            -- options.display = peripheral.getName(video_monitor)
            local bimg_env = setmetatable({}, { __index = _G })
            bimg_env.bimg_options = options
            local program = frame:addProgram({
                    y = 2,
                }):setSize(video_monitor.getSize())
                :execute(program_file, bimg_env)
                :onDone(function()
                    frame:destroy()
                    self:setText("Play Bimg")
                end)
            frame:addLabel({
                x = 2,
                y = 1,
                text = "Bimg Player",
                foreground = colors.lightBlue
            })
            frame:addButton({
                x = monitor_frame.get("width"),
                y = 1,
                width = 1,
                height = 1,
                text = "X",
                background = colors.red,
                foreground = colors.white
            }):onClick(function()
                frame:destroy()
                self:setText("Play Bimg")
            end)
        end)

    local btn4 = main:addButton()
        :setPosition(25, 7)
        :setSize(20, 3)
        :setText("Exit Program")
        :onClick(function()
            -- 退出程序
            if basalt.isRunning then
                shell_window.write("===Shell task finished===")
                os.sleep(2)
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
    local shell_env = setmetatable({}, { __index = _G })

    -- 给shell窗口一个初始提示
    shell_window.clear()
    shell_window.setCursorPos(1, 1)
    print("Standard CC Shell. Type 'exit' to stop.")

    -- 运行一个交互式shell
    os.run(shell_env, '/rom/programs/shell.lua')

    -- 任务结束后，恢复重定向
    term.redirect(native_term)
    print("===Shell task finished===")
    os.sleep(2) -- 给用户一点时间看到结束信息
end


-- 4. 使用 parallel API 同时运行两个任务
-- parallel.waitForAny会一直运行，直到其中一个函数返回
parallel.waitForAny(ui_task, shell_task)


-- 5. 程序结束后的清理工作
term.redirect(native_term)
term.clear()
term.setCursorPos(1, 1)
print("Program terminated.")
