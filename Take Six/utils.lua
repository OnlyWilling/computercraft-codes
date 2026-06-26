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
--- @param segments table 包含 {text, color} 片段的列表。
--- @param mode string 决定打印动画的速度
local function printColored(segments, mode)
    mode = mode or "slow" -- default slow write
    local oldColor = term.getTextColor()

    for _, part in ipairs(segments) do
        -- 设置颜色并打印
        term.setTextColor(part[2])
        if mode == "slow" then
            textutils.slowWrite(part[1], 30)
        else
            term.write(part[1])
        end

        if part[1]:match("^%-%d%d:%d%d:%d%d%-$") then
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

return {
    -- Tools
    saveConfig = saveConfig,
    loadConfig = loadConfig,
    loadBimgImage = loadBimgImage,
    printColored = printColored,
    getTimestamp = getTimestamp,
}
