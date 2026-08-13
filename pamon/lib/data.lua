--- 数据持久化工具（pamon/lib/data）
--- 从 aegis-autocraft 解耦的数据层，提供 JSON 解析、文件加载（带备份恢复）、原子保存。
--- 依赖：CC 内置 `fs`、`textutils` API。
---
--- 用法示例：
---   local d = require "pamon.lib.data"
---   local cfg = d.loadDataFile("config.json")     -- 自动 .bak 恢复
---   local ok, err = d.saveJsonFile("data.json", {a=1})

-- ============================================================
--  内部状态
-- ============================================================

--- 跟踪每个文件的条目数，用于防止意外数据丢失（条目数锐减时阻止保存）。
local _savedCounts = {}

--- 标记最近一次 loadDataFile 是否从 .bak 备份恢复。
local _restoredFromBak = false

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

-- ============================================================
--  文件加载（带备份恢复）
-- ============================================================

--- 加载 JSON 文件，自带备份恢复机制。
---
--- 流程：读取文件 → parseJSON
---   - 成功 → 创建 .bak 备份，返回数据
---   - 损坏 → 尝试从 .bak 恢复（损坏文件另存为 .corrupt 保留）
---   - 均失败 → 返回 nil
---
--- @param path string 文件路径
--- @return table|nil parsed 解析后的数据，失败返回 nil
--- @return boolean restored 是否从备份恢复
function loadDataFile(path)
    if not fs.exists(path) then return nil end
    local fh = fs.open(path, "r")
    if not fh then return nil end
    local raw = fh.readAll() or ""
    fh.close()
    local parsed = parseJSON(raw)
    local bak = path .. ".bak"

    -- 正常解析成功
    if type(parsed) == "table" and next(parsed) ~= nil then
        local n = 0
        for _ in pairs(parsed) do n = n + 1 end
        _savedCounts[path] = n
        -- 清除空的 .bak
        if fs.exists(bak) and fs.getSize(bak) == 0 then pcall(fs.delete, bak) end
        -- 创建 .bak 备份（磁盘空间充足时）
        if not fs.exists(bak) then
            local free = fs.getFreeSpace("/") or 0
            if free > #raw + 4096 then
                local bh = fs.open(bak, "w")
                if bh then bh.write(raw); bh.close() end
            end
        end
        return parsed, false
    end

    -- 解析失败 → 保留损坏文件
    if #raw > 2 and parsed == nil then
        pcall(fs.delete, path .. ".corrupt")
        pcall(fs.copy, path, path .. ".corrupt")
    end

    -- 尝试从 .bak 恢复
    if fs.exists(bak) then
        local bh = fs.open(bak, "r")
        if bh then
            local bp = parseJSON(bh.readAll() or "")
            bh.close()
            if type(bp) == "table" and next(bp) ~= nil then
                local n = 0
                for _ in pairs(bp) do n = n + 1 end
                _savedCounts[path] = n
                _restoredFromBak = true
                return bp, true
            end
        end
    end

    if type(parsed) == "table" then _savedCounts[path] = 0 end
    return parsed, false
end

--- 检查最近一次 loadDataFile 是否从 .bak 备份恢复。
--- @return boolean
local function wasRestoredFromBak()
    return _restoredFromBak
end

--- 重置"从备份恢复"标记。
local function resetRestoredFlag()
    _restoredFromBak = false
end

-- ============================================================
--  文件保存（原子写入 + 数据保护）
-- ============================================================

--- 原子方式保存 JSON 文件到磁盘。
---
--- 安全机制：
---   1. 先写入 .new 临时文件
---   2. 写入成功后才覆盖原文件
---   3. 写失败会清理并重试
---   4. 如果条目数比上次减少 50% 以上且 ≥5 条，阻止保存（防误删除）
---   5. 保存成功且空间充裕时更新 .bak 备份
---
--- @param path string 文件路径
--- @param tbl table 要保存的数据
--- @return boolean success 是否保存成功
--- @return string|nil errorMsg 失败时的错误信息
function saveJsonFile(path, tbl)
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    local prev = _savedCounts[path]
    -- 防误删保护：条目数锐减到一半以下时阻止
    if prev and prev >= 5 and n < prev * 0.5 then
        return false, "SAVE BLOCKED: " .. fs.getName(path) .. " " .. prev .. "->" .. n
    end
    local okS, data = pcall(textutils.serializeJSON, tbl)
    if not (okS and type(data) == "string") then
        return false, "SERIALIZE FAIL: " .. fs.getName(path)
    end
    local tmp = path .. ".new"
    local function tryWrite()
        local okT = pcall(function()
            local fh = fs.open(tmp, "w")
            if not fh then error("open") end
            fh.write(data)
            fh.close()
        end)
        return okT and fs.exists(tmp) and fs.getSize(tmp) >= #data
    end
    local okW = tryWrite()
    if not okW then
        pcall(fs.delete, tmp)
        pcall(fs.delete, path .. ".bak")
        okW = tryWrite()
    end
    if not okW then
        pcall(fs.delete, tmp)
        return false, "SAVE FAIL (disk space?): " .. fs.getName(path)
    end
    fs.delete(path)
    fs.move(tmp, path)
    local free = fs.getFreeSpace("/") or 0
    if free > fs.getSize(path) + 4096 then
        pcall(fs.delete, path .. ".bak")
        pcall(fs.copy, path, path .. ".bak")
    end
    _savedCounts[path] = n
    return true, nil
end

-- ============================================================
--  初始化默认配置文件
-- ============================================================

--- 创建不存在的默认配置文件。
--- @param defaults table 默认文件列表 `{ { path="file.json", content="{}" }, ... }`
function initDataFiles(defaults)
    for _, entry in ipairs(defaults or {}) do
        local path, data = entry[1], entry[2]
        if not fs.exists(path) then
            local fh = fs.open(path, "w")
            if fh then fh.write(data); fh.close() end
        end
    end
end

return {
    parseJSON      = parseJSON,
    loadDataFile   = loadDataFile,
    saveJsonFile   = saveJsonFile,
    initDataFiles  = initDataFiles,

    wasRestoredFromBak = wasRestoredFromBak,
    resetRestoredFlag  = resetRestoredFlag,
}
