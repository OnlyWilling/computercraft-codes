--- 将配置表保存到文件。
--- @param configTable table 要保存的配置。
--- @param path string 要保存的路径。
--- @return boolean res 是否保存成功。
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

--- 加载配置。如果文件不存在或损坏，则创建/重置为默认值。
--- @param defaultConfig table 默认配置分支。
--- @param path string 要读取的路径。
--- @return table tab 加载的配置。
local function loadConfig(defaultConfig, path)
    if fs.exists(path) then
        local file, err_open = fs.open(path, "r")
        if not file then
            printError("Error: Cannot open " .. err_open)
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

return {
    -- Tools
    saveConfig = saveConfig,
    loadConfig = loadConfig,
}
