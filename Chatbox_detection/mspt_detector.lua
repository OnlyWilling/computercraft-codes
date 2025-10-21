local config = {
    mspt_threshold = 50,         -- MSPT 阈值
    max_failures = 3,            -- 切换到 "severe" 状态所需的最大连续失败次数
    normal_check_interval = 3,   -- 正常状态下，每次检测间的间隔（秒）
    warning_cooldown = 10,       -- 警告状态下，每次重试前的冷却时间（秒）
    severe_check_interval = 300, -- 严重状态下，每次检测的间隔（5分钟）
}

---
-- 在单行内打印包含多种颜色的文本。
-- @param segments table - 一个包含 {text, color} 片段的列表。
---
local function printColored(segments)
    local oldColor = term.getTextColor()

    for _, part in ipairs(segments) do
        local text = part[1]
        local color = part[2]

        -- 设置颜色并打印
        term.setTextColor(color)
        term.write(text)
    end

    print()
    term.setTextColor(oldColor)
end

---
-- 检测服务器MSPT是否在可接受的范围内
-- @param mspt_thres (number, optional) - 允许的最高MSPT值。默认50。
-- @param ticks_per_signal (number, optional) - 外部红石计时器设置为多少个tick触发一次。默认20 (1秒)。
-- @return event or nil - 如果性能正常，返回接收到的 "redstone" 事件；如果超时，返回 nil。
---
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

    parallel.waitForAny(receiveTimer, timeoutCheck)

    if ev ~= nil then
        printColored({
            { "[Good] ",                                      colors.green },
            { "Server performance: good. MSPT is likely <= ", colors.white },
            { tostring(mspt_thres),                           colors.blue }
        })
        return ev
    else
        printColored({
            { "[Bad] ",                                     colors.red },
            { "Server performance: bad. MSPT is likely > ", colors.white },
            { tostring(mspt_thres),                         colors.blue }
        })
        return nil
    end
end

-- =========================================================================
--  主监控程序
-- =========================================================================
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
                    { os.date(),                                                    colors.gray },
                    { " [WARNING] ",                                                colors.yellow },
                    { "MSPT check failed for the 1st time. Entering cooldown for ", colors.white },
                    { config.warning_cooldown,                                      colors.yellow },
                    { " seconds.",                                                  colors.white }
                })
                os.sleep(config.warning_cooldown)
            end
            os.sleep(config.normal_check_interval)
        elseif status == "warning" then
            -- ------------------- 警告状态 -------------------
            printColored({
                { os.date(),                        colors.gray },
                { " [RE-CHECKING] ",                colors.orange },
                { "Current consecutive failures: ", colors.white },
                { tostring(consecutive_failures),   colors.yellow },
                { ". Performing check...",          colors.white }
            })

            local result = msptDetector(config.mspt_threshold)

            if result ~= nil then
                printColored({
                    { os.date(),                                               colors.gray },
                    { " [RECOVERED] ",                                         colors.green },
                    { "MSPT is back to normal. Resuming standard monitoring.", colors.white }
                })
                consecutive_failures = 0
                status = "ok"
            else
                consecutive_failures = consecutive_failures + 1
                if consecutive_failures >= config.max_failures then
                    -- 连续失败次数达到上限，进入 'severe' 状态
                    status = "severe"
                    printColored({
                        { os.date(),                                          colors.gray },
                        { " [SEVERE] ",                                       colors.red },
                        { "MSPT check has failed ",                           colors.white },
                        { tostring(consecutive_failures),                     colors.red },
                        { " times in a row. Server performance is critical.", colors.white }
                    })
                else
                    -- 失败次数未达上限，继续留在 'warning' 状态
                    printColored({
                        { os.date(),                        colors.gray },
                        { " [WARNING] ",                    colors.yellow },
                        { "MSPT check failed again (",      colors.white },
                        { tostring(consecutive_failures),   colors.yellow },
                        { " consecutive). Cooling down...", colors.white }
                    })
                    os.sleep(config.warning_cooldown)
                end
            end
            os.sleep(config.normal_check_interval)
        elseif status == "severe" then
            -- ------------------- 严重状态 -------------------
            printColored({
                { os.date(),                                      colors.gray },
                { " [SEVERE] ",                                   colors.red },
                { "Monitoring interval extended. Next check in ", colors.white },
                { config.severe_check_interval,                   colors.red },
                { " seconds.",                                    colors.white }
            })
            os.sleep(config.severe_check_interval)

            local result = msptDetector(config.mspt_threshold)

            if result ~= nil then
                -- 从严重状态恢复
                printColored({
                    { os.date(),                                                             colors.gray },
                    { " [FULLY RECOVERED] ",                                                 colors.cyan },
                    { "Server has recovered from severe state. Resuming normal monitoring.", colors.white }
                })
                consecutive_failures = 0
                status = "ok"
            else
                -- 仍然处于严重状态，循环将继续从本块开始
                printColored({
                    { os.date(),                                                           colors.gray },
                    { " [SEVERE] ",                                                        colors.red },
                    { "Post-interval check failed. Server remains in critical condition.", colors.white }
                })
            end
            os.sleep(config.normal_check_interval)
        end
    end
end

local function keysHandler()
    while true do
        local ev, key = os.pullEvent("key")
        if key == keys.q or key == keys.escape then
            term.clear()
            term.setCursorPos(1, 1)
            break
        end
    end
end

print("====MSPT Monitor Started. Initializing...====")
parallel.waitForAny(dectectLoop, keysHandler)
