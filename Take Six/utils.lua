--- 将配置表保存到文件。
--- @param configTable table 要保存的配置。
--- @param path string 要保存的路径。
--- @return boolean res 是否保存成功。
local function saveConfig(configTable, path)
    local file = fs.open(shell.resolve(path), "w")
    if file then
        file.write(textutils.serialize(configTable))
        file.close()
        return true
    else
        printError("Error: Cannot write " .. path)
        return false
    end
end

--- 加载配置。如果文件不存在或损坏，则创建/重置为默认值。
--- @param defaultConfig table 默认配置分支。
--- @param path string 要读取的路径。
--- @return table tab 加载的配置。
local function loadConfig(defaultConfig, path)
    if fs.exists(shell.resolve(path)) then
        local file, err = fs.open(shell.resolve(path), "rb")
        if not file then
            printError("Error: Cannot open " .. path)
            printError("Use default config...")
            return defaultConfig
        end
        local data = textutils.unserialize(file.readAll())
        file.close()
        print("Loading config from " .. path)
        return data
    else
        print("Config not found. Create default config...")
        saveConfig(defaultConfig, path)
        return defaultConfig
    end
end

--- 读取bimg图片文件。如果文件不存在，则error中断。
--- @param path string 要读取的路径。
--- @return table img bimg图片数据。
local function loadBimgImage(path)
    local file, err = fs.open(shell.resolve(path), "rb")
    if not file then
        error("Cannot open file: " .. err)
    end
    local data = file.readAll()
    file.close()
    local success, img = pcall(textutils.unserialize, data)
    if not success then
        error("Invalid BIMG file: " .. img)
    end

    return img
end

--- 在单行内打印包含多种颜色的文本。
--- @param target table|nil 输出目标：nil → term（终端），或一个拥有 write()/setTextColor()/getTextColor() 的窗口对象
--- @param mode string 决定打印动画的速度（仅 target=nil 时有效）
--- @param segments table 包含 {text, color} 片段的列表。
local function printColored(target, mode, autoSpace, segments)
    local t = target or term
    mode = mode or "slow"
    autoSpace = autoSpace or true
    local oldColor = t.getTextColor()

    for _, part in ipairs(segments) do
        t.setTextColor(part[2])
        if autoSpace then
            if mode == "slow" and not target then
                textutils.slowWrite(part[1], 30)
            else
                t.write(part[1])
            end
            autoSpace = false
        else
            if mode == "slow" and not target then
                textutils.slowWrite(" " .. part[1], 30)
            else
                t.write(" " .. part[1])
            end
        end
    end

    -- 写 term 时保留旧行为的 final print() 换行
    -- 写 window 时不加换行，由调用者的 nextLine 控制
    if not target then
        print()
    end

    t.setTextColor(oldColor)
end

--- 将窗口光标推进一行（超出高度时自动上滚）
--- @param win table 窗口对象，需支持 getSize() / getCursorPos() / scroll() / setCursorPos()
local function nextLine(win)
    local _, h = win.getSize()
    local _, y = win.getCursorPos()
    if y >= h then
        win.scroll(1)
        win.setCursorPos(1, y)
    else
        win.setCursorPos(1, y + 1)
    end
end

--- 返回当前时间戳
--- @return string res 用UTC时分制返回时间戳
local function getTimestamp()
    return "-" .. os.date("%H:%M:%S") .. "-"
end

return {
    -- Tools
    saveConfig = saveConfig,
    loadConfig = loadConfig,
    loadBimgImage = loadBimgImage,
    printColored = printColored,
    nextLine = nextLine,
    getTimestamp = getTimestamp,
}
