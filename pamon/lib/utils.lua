-- ============================================================
--  LUA config 解析
-- ============================================================

--- 将配置表保存到文件。
--- @param config table 要保存的配置。
--- @param path string 要保存的路径。
--- @return boolean res 是否保存成功。
local function saveConfigFile(config, path)
    path = shell.resolve(path)
    local file = fs.open(path, "w")
    if file then
        file.write(textutils.serialize(config))
        file.close()
        return true
    else
        printError("[Error] Cannot write " .. path)
        return false
    end
end

--- 加载配置。如果文件不存在或损坏，则创建/重置为默认值。
--- @param path string 要读取的路径。
--- @return table|nil tab 加载的配置。
local function loadConfigFile(path)
    path = shell.resolve(path)
    if fs.exists(path) then
        local file, err = fs.open(path, "rb")
        if not file then
            printError("[Error] Cannot open " .. path)
            return nil
        end
        local data = textutils.unserialize(file.readAll())
        file.close()
        return data
    else
        printError("[Error] Cannot find " .. path)
        return nil
    end
end

-- ============================================================
--  LUA bimg 图片解析
-- ============================================================

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

-- ============================================================
--  printlog 自用
-- ============================================================

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

-- ============================================================
--  JSON 解析
-- ============================================================

--- 解析 JSON 字符串，兼容空数组。
--- @param str string JSON 字符串
--- @return table|nil res 解析结果
local function parseJSON(str)
    local res = textutils.unserializeJSON(str)
    if res == textutils.empty_json_array then return {} end
    return res
end

--- 加载 JSON 文件
--- @param path string 文件路径
--- @return table|nil parsed 解析后的数据，失败返回 nil
local function loadJSONFile(path)
    path = shell.resolve(path)
    if not fs.exists(path) then return nil end

    local f = fs.open(path, "r")
    if not f then return nil end

    local raw = f.readAll() or ""
    f.close()

    local parsed = parseJSON(raw)
    if type(parsed) == "table" and next(parsed) ~= nil then return parsed end
end

--- 保存 JSON 文件
--- @param path string 文件路径
--- @param tbl table 要保存的数据
--- @return boolean res 是否保存成功
local function saveJSONFile(path, tbl)
    path = shell.resolve(path)
    local file = fs.open(path, "w")
    if file then
        file.write(textutils.serializeJSON(tbl))
        file.close()
        return true
    else
        printError("[Error] Cannot write " .. path)
        return false
    end
end

-- ============================================================
--  物品分组管理
-- ============================================================

local _itemGroups = {} --- itemName → groupName（反向查找）
local _groupItems = {} --- groupName → { itemName, ... }（正向查找）

--- 从 JSON 文件加载物品分组，自动构建正向索引。
--- @param path string 文件路径
--- @return table itemGroups 反向查找表 `{ ["item"] = "group", ... }`
--- @return table groupItems 正向查找表 `{ ["group"] = {"item1", "item2"}, ... }`
local function loadItemGroups(path)
    path = shell.resolve(path)

    if fs.exists(path) then
        _itemGroups = loadJSONFile(path) or {}
    else
        _itemGroups = {}
    end

    -- 自动构建正向索引
    _groupItems = {}
    for item, group in pairs(_itemGroups) do
        if not _groupItems[group] then _groupItems[group] = {} end
        table.insert(_groupItems[group], item)
    end

    return _itemGroups, _groupItems
end

--- 查询物品所属分组。
--- @param itemName string 物品名
--- @return string|nil 分组名
local function getItemGroup(itemName)
    return _itemGroups[itemName]
end

--- 查询分组包含的所有物品。
--- @param groupName string 分组名
--- @return table|nil 物品名列表
local function getGroupItems(groupName)
    return _groupItems[groupName]
end

return {
    -- Lua Config
    saveConfig = saveConfigFile,
    loadConfig = loadConfigFile,

    -- Bimg loader
    loadBimgImage = loadBimgImage,

    -- Log manager
    printColored = printColored,
    nextLine = nextLine,
    getTimestamp = getTimestamp,

    -- JSON
    loadJSONFile = loadJSONFile,
    saveJSONFile = saveJSONFile,

    -- Item groups
    loadItemGroups = loadItemGroups,
    getItemGroup = getItemGroup,
    getGroupItems = getGroupItems,
}
