local BASE_DIR = shell.getRunningProgram():match("(.*/)") or "/"
local CONFIG_PATH = fs.combine(BASE_DIR, "msptDetector.cfg")
local defaultConfig = {
    -- -----时间配置-----
    mspt_threshold = 50,                -- MSPT 阈值
    detect_time = 5,                    -- 每次检测的持续时间（秒）
    max_failures = 5,                   -- 切换到 "severe" 状态所需的最大连续失败次数
    normal_check_interval = 5,          -- 正常状态下，每次检测间的间隔（秒）
    warning_cooldown = 10,              -- 警告状态下，每次重试前的冷却时间（秒）
    severe_check_interval = 300,        -- 严重状态下，每次检测的间隔（5分钟）
    write_speed = "slow",               -- 默认log写入速度为慢（slow/fast）
}
local spinner = { "|", "/", "-", "\\" } -- 沙漏计时动画
local dots = { ".  ", ".. ", "..." }    -- 省略号计时动画

local config = {}
local mon = nil      -- Monitor
local old_term = nil -- old term

--- 将配置表保存到文件。
--- @param configTable table 要保存的配置。
--- @param path string 要保存的路径。
--- @return boolean res 是否保存成功。
local function saveConfig(configTable, path)
    local file = fs.open(path, "w")
    if file then
        -- 使用 textutils.serialize 将 Lua 表转换为可读的字符串格式
        file.write(textutils.serialize(configTable))
        file.close()
        return true
    else
        printError("Error: Cannot write " .. path)
        return false
    end
end

--- 加载配置。如果文件不存在或损坏，则创建/重置为默认值。
--- @param path string 要读取的路径。
--- @return table tab 加载的配置。
local function loadConfig(path)
    if fs.exists(path) then
        local file, err_open = fs.open(path, "r")
        if not file then
            printError("Error: Cannot open " .. err_open)
            printError("Use default config...")
            return defaultConfig
        end

        local loadedConfig = textutils.unserialize(file.readAll())
        file.close()

        print("Loading config from " .. path)
        return loadedConfig
    else
        print("Config not found. Create default config...")
        saveConfig(defaultConfig, path)
        return defaultConfig
    end
end

--- 在单行内打印包含多种颜色的文本。
--- @param segments table 包含 {text, color} 片段的列表。
local function printColored(segments, mode)
    mode = mode or "slow" -- default slow write
    local oldColor = term.getTextColor()

    for _, part in ipairs(segments) do
        local text = part[1]
        local color = part[2]

        -- 设置颜色并打印
        term.setTextColor(color)
        if mode == "slow" then
            textutils.slowWrite(text, 30)
        else
            term.write(text)
        end

        if text:match("^%-%d%d:%d%d:%d%d%-$") then
            print()
        end
    end

    print()
    term.setTextColor(oldColor)
end

--- 在执行等待时，显示一个带有倒计时和省略号的动画。
--- @param duration number 等待的总秒数
local function sleepWithAnimation(duration)
    local T = duration / 0.5 or 10 --default sleep time
    local line_x, line_y = term.getCursorPos()

    term.setTextColor(colors.white)
    term.write("Waiting for next check in ")
    local i = 1
    local timer = duration
    local x, y = term.getCursorPos()
    for t = 1, T do
        term.setCursorPos(x, y)
        term.setTextColor(colors.blue)  -- write timer with blue color
        term.write(timer)
        term.setTextColor(colors.white) -- write dots anim with while color
        term.write(dots[i])
        i = (i % #dots) + 1
        if t % 2 == 0 then
            timer = timer - 1
        end
        os.sleep(0.5)
    end

    term.clearLine()
    term.setCursorPos(line_x, line_y)
end

--- 在监视器右上角更新全局状态指示灯。
--- @param status string 当前的状态 ("ok", "warning", "severe")
local function updateStatusIndicator(status)
    -- 保存当前光标和颜色设置
    local old_x, old_y = term.getCursorPos()
    local old_bg = term.getBackgroundColor()
    local old_fg = term.getTextColor()

    local w, h = term.getSize()
    local lightColor

    if status == "ok" then
        lightColor = colors.green
    elseif status == "warning" then
        lightColor = colors.yellow
    else -- severe
        lightColor = colors.red
    end

    -- 在右上角绘制一个带背景色的空格作为指示灯
    term.setCursorPos(w, 1)
    term.setBackgroundColor(lightColor)
    term.write(" ")

    -- 恢复光标和颜色
    term.setCursorPos(old_x, old_y)
    term.setBackgroundColor(old_bg)
    term.setTextColor(old_fg)
end

--- 返回当前时间戳
--- @return string res 用UTC时分制返回时间戳
local function getTimestamp()
    return "-" .. os.date("%H:%M:%S") .. "-"
end

--- 检测服务器MSPT是否在可接受的范围内
--- @param detect_time number 检测时间，单位秒。默认5秒
--- @param mspt_thres number 允许的最高MSPT值。默认50
--- @return boolean res 如果性能正常，返回true；如果超时，返回 nil
local function msptDetector(detect_time, mspt_thres)
    mspt_thres = mspt_thres or 50               -- default mspt threshold
    local ticks_to_sleep = detect_time * 20 + 5 -- convert time to ticks, spare 5 ticks
    local realTimeDuration = 0                  -- record real time duration (ms)
    local line_x, line_y = term.getCursorPos()  -- record first line cursor pos

    local function timerAnimation()
        term.setTextColor(colors.white)
        term.write("Checking MSPT ... ")
        local i = 1
        local x, y = term.getCursorPos()
        while true do
            term.setCursorPos(x, y)
            term.write(spinner[i])
            i = (i % #spinner) + 1
            os.sleep(0.2)
        end
    end

    local function timerMeasure()
        repeat
            local startTime_ms = os.epoch("utc")
            os.sleep(detect_time)
            local endTime_ms = os.epoch("utc")
            realTimeDuration = endTime_ms - startTime_ms
        until realTimeDuration >= 0
    end

    parallel.waitForAny(timerAnimation, timerMeasure)
    term.clearLine()
    term.setCursorPos(line_x, line_y)

    local avg_mspt = realTimeDuration / ticks_to_sleep

    if avg_mspt <= mspt_thres then
        printColored({
            { "[Good] ",                               colors.green },
            { getTimestamp(),                          colors.gray },
            { "Server performance: good. MSPT is <= ", colors.white },
            { tostring(mspt_thres),                    colors.blue }
        }, config.write_speed)
        return true
    else
        printColored({
            { "[Bad] ",                            colors.red },
            { getTimestamp(),                      colors.gray },
            { "Server performance: bad. MSPT is ", colors.white },
            { string.format("%.1f", avg_mspt),     colors.red },
            { "> ",                                colors.white },
            { tostring(mspt_thres),                colors.blue }
        }, config.write_speed)
        return false
    end
end


--- 主监控程序 状态机检测
local function dectectLoop()
    local status = "ok"
    local consecutive_failures = 0
    updateStatusIndicator(status) -- init indicator
    while true do
        if status == "ok" then
            -- ------------------- 正常状态 -------------------
            local result = msptDetector(config.detect_time, config.mspt_threshold)

            if result then
                consecutive_failures = 0
                sleepWithAnimation(config.normal_check_interval)
            else
                consecutive_failures = 1
                status = "warning"
                updateStatusIndicator(status)
                printColored({
                    { "[WARNING] ",                      colors.yellow },
                    { getTimestamp(),                    colors.gray },
                    { "MSPT: bad. Cooldown ",            colors.white },
                    { tostring(config.warning_cooldown), colors.yellow },
                    { "s.",                              colors.white }
                }, config.write_speed)
                sleepWithAnimation(config.warning_cooldown)
            end
        elseif status == "warning" then
            -- ------------------- 警告状态 -------------------
            printColored({
                { "[CHECKING] ",                  colors.orange },
                { getTimestamp(),                 colors.gray },
                { "Current check times: ",        colors.white },
                { tostring(consecutive_failures), colors.yellow },
                { ". checking...",                colors.white }
            }, config.write_speed)

            local result = msptDetector(config.detect_time, config.mspt_threshold)

            if result then
                printColored({
                    { "[RECOVERED] ",                     colors.green },
                    { getTimestamp(),                     colors.gray },
                    { "MSPT return good. Reset monitor.", colors.white }
                }, config.write_speed)
                consecutive_failures = 0
                status = "ok"
                updateStatusIndicator(status)
                sleepWithAnimation(config.normal_check_interval)
            else
                consecutive_failures = consecutive_failures + 1
                if consecutive_failures >= config.max_failures then
                    -- 连续失败次数达到上限，进入 'severe' 状态
                    status = "severe"
                    updateStatusIndicator(status)
                    printColored({
                        { "[SEVERE] ",                    colors.red },
                        { getTimestamp(),                 colors.gray },
                        { "MSPT detect bad ",             colors.white },
                        { tostring(consecutive_failures), colors.red },
                        { " times. MSPT turn ",           colors.white },
                        { "severe.",                      colors.red }
                    }, config.write_speed)
                else
                    -- 失败次数未达上限，继续留在 'warning' 状态
                    printColored({
                        { "[WARNING] ",                      colors.yellow },
                        { getTimestamp(),                    colors.gray },
                        { "MSPT: bad. Cooldown ",            colors.white },
                        { tostring(config.warning_cooldown), colors.yellow },
                        { "s.",                              colors.white }
                    }, config.write_speed)
                end
                sleepWithAnimation(config.warning_cooldown)
            end
        elseif status == "severe" then
            -- ------------------- 严重状态 -------------------
            printColored({
                { "[SEVERE] ",                            colors.red },
                { getTimestamp(),                         colors.gray },
                { "MSPT: severe. Next check in ",         colors.white },
                { tostring(config.severe_check_interval), colors.red },
                { "s.",                                   colors.white }
            }, config.write_speed)
            sleepWithAnimation(config.severe_check_interval)

            local result = msptDetector(config.detect_time, config.mspt_threshold)

            if result then
                -- 从严重状态恢复
                printColored({
                    { "[FULLY RECOVERED] ",               colors.cyan },
                    { getTimestamp(),                     colors.gray },
                    { "MSPT return good. Reset monitor.", colors.white }
                }, config.write_speed)
                consecutive_failures = 0
                status = "ok"
                updateStatusIndicator(status)
                sleepWithAnimation(config.normal_check_interval)
            end
        end
    end
end

local function keysHandler()
    while true do
        local ev, key = os.pullEvent("key")
        if key == keys.q or key == keys.escape then
            if old_term then
                term.setTextColor(colors.red)
                print("\n==== Quit MSPT Detector ====") -- in case interrupt at animation, spare [Space] here
                term.redirect(old_term)
                term.setTextColor(colors.red)
                print("==== Quit MSPT Detector ====")
                term.setTextColor(colors.white)
            else
                term.setTextColor(colors.red)
                print("==== Quit MSPT Detector ====")
                term.setTextColor(colors.white)
            end
            break
        end
    end
end

local function main()
    config = loadConfig(CONFIG_PATH)
    mon = peripheral.find("monitor") or term

    if mon ~= term then
        term.setTextColor(colors.green)
        print("==== MSPT Monitor Started. Initializing... ====") -- print at term first
        term.setTextColor(colors.white)
        old_term = term.redirect(mon)
        mon.setTextScale(0.5)
        mon.setTextColor(colors.green)
        print("\n==== MSPT Monitor Started. Initializing... ====")
        parallel.waitForAny(dectectLoop, keysHandler)
    else
        mon.setTextColor(colors.green)
        print("\n==== MSPT Monitor Started. Initializing... ====")
        parallel.waitForAny(dectectLoop, keysHandler)
    end
end

main()
