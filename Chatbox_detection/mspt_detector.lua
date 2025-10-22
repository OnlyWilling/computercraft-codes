local BASE_DIR = shell.getRunningProgram():match("(.*/)") or "/"
local CONFIG_PATH = fs.combine(BASE_DIR, "msptDetector.cfg")
local defaultConfig = {
    -- -----时间配置-----
    mspt_threshold = 50,          -- MSPT 阈值
    max_failures = 3,             -- 切换到 "severe" 状态所需的最大连续失败次数
    normal_check_interval = 3,    -- 正常状态下，每次检测间的间隔（秒）
    warning_cooldown = 10,        -- 警告状态下，每次重试前的冷却时间（秒）
    severe_check_interval = 300,  -- 严重状态下，每次检测的间隔（5分钟）
    -- -----时钟配置-----
    redstone_push_side = "right", -- 同步时钟发出侧
    redstone_pull_side = "left",  -- 同步时钟监听侧
}

local config = {}
local mon = nil      -- Monitor
local relay = nil    -- Redstone relay
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
local function printColored(segments)
    local oldColor = term.getTextColor()

    for _, part in ipairs(segments) do
        local text = part[1]
        local color = part[2]

        -- 设置颜色并打印
        term.setTextColor(color)
        term.write(text)
        if text:match("^%-%d%d:%d%d:%d%d%-$") then
            print()
        end
    end

    print()
    term.setTextColor(oldColor)
end

--- 返回当前时间戳
--- @return string res 用UTC时分制返回时间戳
local function getTimestamp()
    return "-" .. os.date("%H:%M:%S") .. "-"
end

--- 检测服务器MSPT是否在可接受的范围内
--- @param mspt_thres number 允许的最高MSPT值。默认50。
--- @return event ev 如果性能正常，返回接收到的 "redstone" 事件；如果超时，返回 nil。
local function msptDetector(mspt_thres)
    mspt_thres = mspt_thres or 50 -- default mspt threshold
    local ev = nil

    function timeoutCheck()
        os.sleep(1.2 * (mspt_thres / 50)) -- allow 20% spare
    end

    function receiveTimer()
        local event = os.pullEvent("redstone")
        ev = event
    end

    if relay ~= nil then
        relay.setOutput(config.redstone_push_side, true)
        relay.setOutput(config.redstone_pull_side, false)
    end

    parallel.waitForAny(receiveTimer, timeoutCheck)

    if ev ~= nil then
        printColored({
            { "[Good] ",                                      colors.green },
            { getTimestamp(),                                 colors.gray },
            { "Server performance: good. MSPT is likely <= ", colors.white },
            { tostring(mspt_thres),                           colors.blue }
        })
        return ev
    else
        printColored({
            { "[Bad] ",                                     colors.red },
            { getTimestamp(),                               colors.gray },
            { "Server performance: bad. MSPT is likely > ", colors.white },
            { tostring(mspt_thres),                         colors.blue }
        })
        return nil
    end
end


--- 主监控程序 状态机检测
local function dectectLoop()
    local status = "ok"
    local consecutive_failures = 0
    while true do
        if status == "ok" then
            -- ------------------- 正常状态 -------------------
            local result = msptDetector(config.mspt_threshold)

            if result ~= nil then
                consecutive_failures = 0
            else
                consecutive_failures = 1
                status = "warning"
                printColored({
                    { "[WARNING] ",                      colors.yellow },
                    { getTimestamp(),                    colors.gray },
                    { "MSPT: bad. Cooldown ",            colors.white },
                    { tostring(config.warning_cooldown), colors.yellow },
                    { "s.",                              colors.white }
                })
                os.sleep(config.warning_cooldown)
            end
            os.sleep(config.normal_check_interval)
        elseif status == "warning" then
            -- ------------------- 警告状态 -------------------
            printColored({
                { "[CHECKING] ",                  colors.orange },
                { getTimestamp(),                 colors.gray },
                { "Current check times: ",        colors.white },
                { tostring(consecutive_failures), colors.yellow },
                { ". checking...",                colors.white }
            })

            local result = msptDetector(config.mspt_threshold)

            if result ~= nil then
                printColored({
                    { "[RECOVERED] ",                     colors.green },
                    { getTimestamp(),                     colors.gray },
                    { "MSPT return good. Reset monitor.", colors.white }
                })
                consecutive_failures = 0
                status = "ok"
            else
                consecutive_failures = consecutive_failures + 1
                if consecutive_failures >= config.max_failures then
                    -- 连续失败次数达到上限，进入 'severe' 状态
                    status = "severe"
                    printColored({
                        { "[SEVERE] ",                    colors.red },
                        { getTimestamp(),                 colors.gray },
                        { "MSPT detect bad ",             colors.white },
                        { tostring(consecutive_failures), colors.red },
                        { " times. MSPT turn ",           colors.white },
                        { "severe.",                      colors.red }
                    })
                else
                    -- 失败次数未达上限，继续留在 'warning' 状态
                    printColored({
                        { "[WARNING] ",                      colors.yellow },
                        { getTimestamp(),                    colors.gray },
                        { "MSPT: bad. Cooldown ",            colors.white },
                        { tostring(config.warning_cooldown), colors.yellow },
                        { "s.",                              colors.white }
                    })
                end
                os.sleep(config.warning_cooldown)
            end
            os.sleep(config.normal_check_interval)
        elseif status == "severe" then
            -- ------------------- 严重状态 -------------------
            printColored({
                { "[SEVERE] ",                            colors.red },
                { getTimestamp(),                         colors.gray },
                { "MSPT: severe. Next check in ",         colors.white },
                { tostring(config.severe_check_interval), colors.red },
                { "s.",                                   colors.white }
            })
            os.sleep(config.severe_check_interval)

            local result = msptDetector(config.mspt_threshold)

            if result ~= nil then
                -- 从严重状态恢复
                printColored({
                    { "[FULLY RECOVERED] ",               colors.cyan },
                    { getTimestamp(),                     colors.gray },
                    { "MSPT return good. Reset monitor.", colors.white }
                })
                consecutive_failures = 0
                status = "ok"
            end
            os.sleep(config.normal_check_interval)
        end
    end
end

local function keysHandler()
    while true do
        local ev, key = os.pullEvent("key")
        if key == keys.q or key == keys.escape then
            if old_term then
                term.setTextColor(colors.red)
                print("==== Quit MSPT Detector ====")
                term.redirect(old_term)
                term.clear()
                term.setCursorPos(1, 1)
                term.setTextColor(colors.red)
                print("==== Quit MSPT Detector ====")
                term.setTextColor(colors.white)
            else
                term.clear()
                term.setCursorPos(1, 1)
                term.setTextColor(colors.red)
                print("==== Quit MSPT Detector ====")
                term.setTextColor(colors.white)
            end
            break
        end
    end
end

config = loadConfig(CONFIG_PATH)
mon = peripheral.find("monitor") or term
relay = peripheral.find("redstone_relay") or nil

-- if  relay == nil then
--     error("Relay not found!")
-- end

if mon ~= term then
    term.setTextColor(colors.green)
    print("==== MSPT Monitor Started. Initializing... ====") -- print at term first
    term.setTextColor(colors.white)
    old_term = term.redirect(mon)
    mon.setTextScale(0.5)
    mon.setTextColor(colors.green)
    print("==== MSPT Monitor Started. Initializing... ====")
    parallel.waitForAny(dectectLoop, keysHandler)
else
    mon.clear()
    mon.setCursorPos(1, 1)
    mon.setTextColor(colors.green)
    print("==== MSPT Monitor Started. Initializing... ====")
    parallel.waitForAny(dectectLoop, keysHandler)
end
