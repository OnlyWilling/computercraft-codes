--- 外设扫描与缓存工具（pamon/lib/peripheral）
--- 从 aegis-autocraft 解耦的外设层，提供批量并行扫描、存储/流体读取、缓存管理。
--- 依赖：CC 内置 `peripheral`、`parallel`、`fs` API。
---
--- 用法示例：
---   local p = require "pamon.lib.peripheral"
---   local inv = p.scanStorages({"chest_0", "chest_1"})
---   local cached = p.getCachedStorages({"chest_0", "chest_1"})  -- 4s TTL

local SYSTEM_SIDES = {
    top    = true,
    bottom = true,
    left   = true,
    right  = true,
    front  = true,
    back   = true,
}

--- 判断外设名是否为系统侧边（top/bottom/left/right/front/back）。
--- @param name string 外设名
--- @return boolean
local function isSystemSide(name)
    return SYSTEM_SIDES[name] == true
end

-- ============================================================
--  批量并行扫描
-- ============================================================

local _batchScanBusy = false

--- 批量并行扫描外设。
--- 按每批最多 64 个设备分组，组内通过 parallel.waitForAll 并发调用。
--- @param names table 外设名列表（数组），例如 {"chest_0", "chest_1"}
--- @param method string 要调用的方法名，例如 "list", "tanks", "size"
--- @param withSize boolean|nil 是否同时获取该外设的 size() 信息
--- @return table scanned 扫描结果表 `{ [外设名] = { data = ..., size = ... }, ... }`
local function batchPeripheralScan(names, method, withSize)
    local out = {}
    if #names == 0 then return out end
    while _batchScanBusy do sleep(0.05) end
    _batchScanBusy = true

    local i = 1
    while i <= #names do
        local hi = math.min(i + 63, #names)
        local tasks = {}
        for j = i, hi do
            local nm = names[j]
            tasks[#tasks + 1] = function()
                local p = peripheral.wrap(nm)
                if p and p[method] then
                    local e = {}
                    local ok, res = pcall(p[method])
                    if ok then e.data = res end
                    if withSize and p.size then
                        local ok2, sz = pcall(p.size)
                        if ok2 then e.size = sz end
                    end
                    out[nm] = e
                end
            end
        end
        local okAll, errAll = pcall(parallel.waitForAll, table.unpack(tasks))
        if not okAll then
            _batchScanBusy = false
            error(errAll, 0)
        end
        i = hi + 1
    end

    _batchScanBusy = false
    return out
end

-- ============================================================
--  存储外设扫描
-- ============================================================

--- 扫描指定存储外设，返回汇总库存。
--- 对每个外设调用 list() 获取物品列表，按物品名累加数量。
--- @param names table 外设名列表
--- @return table inventory   物品库存映射 `{ ["minecraft:iron_ingot"] = 64, ... }`
--- @return number totalItems 所有物品总件数
--- @return number vaultCount 已响应的存储设备数
--- @return number freeSlots  空闲槽位数
--- @return number totalSlots 总槽位数
local function scanStorages(names)
    local inventory = {}
    local totalItems, vaultsCount = 0, 0
    local totalSlots, usedSlots = 0, 0

    local filtered = {}
    for _, nm in ipairs(names) do
        if nm and not isSystemSide(nm) then filtered[#filtered + 1] = nm end
    end

    local scanned = batchPeripheralScan(filtered, "list", true)
    for _, nm in ipairs(filtered) do
        local e = scanned[nm]
        if e then
            vaultsCount = vaultsCount + 1
            if e.size then totalSlots = totalSlots + e.size end
            if e.data then
                for _, item in pairs(e.data) do
                    if item then
                        inventory[item.name] = (inventory[item.name] or 0) + item.count
                        totalItems = totalItems + item.count
                        usedSlots = usedSlots + 1
                    end
                end
            end
        end
    end

    local freeSlots = totalSlots - usedSlots
    return inventory, totalItems, vaultsCount, freeSlots, totalSlots
end

--- 扫描额外来源的外设（非存储，但提供物品的来源）。
--- 调用 list() 获取物品，并入到已有 inventory 中。
--- @param names table 外设名列表
--- @param inventory table 要并入的目标库存映射（会被原地修改）
--- @return number addedItems 增加的物品总数
local function scanProviderSources(names, inventory)
    local added = 0
    local scanned = batchPeripheralScan(names, "list")
    for _, nm in ipairs(names) do
        local e = scanned[nm]
        if e and e.data then
            for _, item in pairs(e.data) do
                if item then
                    inventory[item.name] = (inventory[item.name] or 0) + item.count
                    added = added + item.count
                end
            end
        end
    end
    return added
end

-- ============================================================
--  缓存层
-- ============================================================

local _stInvCache, _stInvCacheT = nil, -100   --- 存储库存缓存（TTL 4s）

--- 使所有外设缓存失效。
--- 下次调用 getCached* 时会强制重新扫描。
local function invalidateCache()
    _stInvCacheT = -100
end

--- 获取缓存的存储库存（TTL = 4 秒）。
--- @param names table 外设名列表
--- @return table inventory   物品库存映射
--- @return number totalItems 所有物品总件数
--- @return number vaultCount 已响应的存储设备数
--- @return number freeSlots  空闲槽位数
--- @return number totalSlots 总槽位数
local function getCachedStorages(names)
    local now = os.clock()
    if _stInvCache and (now - _stInvCacheT) < 4 then
        return _stInvCache[1], _stInvCache[2], _stInvCache[3], _stInvCache[4], _stInvCache[5]
    end
    local a, b, c, d, e = scanStorages(names)
    _stInvCache = { a, b, c, d, e }
    _stInvCacheT = now
    return a, b, c, d, e
end

-- ============================================================
--  实用工具
-- ============================================================

--- 在指定存储列表中查找第一个有足够空闲槽位（≥16）的外设。
--- @param names table 外设名列表
--- @return table|nil storageObj 外设对象（有 pullItems/list/size 方法），或 nil
local function findFreeSpaceStorage(names)
    for _, stoName in ipairs(names) do
        local sto = peripheral.wrap(stoName)
        if sto and sto.pullItems and sto.list and sto.size then
            local okS, sz = pcall(sto.size)
            local okL, lst = pcall(sto.list)
            if okS and okL and sz and lst then
                local used = 0
                for _ in pairs(lst) do used = used + 1 end
                if sz - used >= 16 then return sto end
            end
        end
    end
    return nil
end

--- 将 turtle 的全部 16 格物品卸到有空位的存储中。
--- @param turtleName string turtle 名
--- @param storageNames table 可用的存储外设名列表
--- @return boolean res 是否至少成功找到存储
local function blindUnloadTurtle(turtleName, storageNames)
    local sto = findFreeSpaceStorage(storageNames)
    if not sto then return false end
    for slot = 1, 16 do pcall(sto.pullItems, turtleName, slot, 64) end
    return true
end

return {
    -- Scan
    batchPeripheralScan = batchPeripheralScan,
    scanStorages        = scanStorages,
    scanProviderSources = scanProviderSources,
    -- Cache
    invalidateCache        = invalidateCache,
    getCachedStorages      = getCachedStorages,

    -- Utility
    findFreeSpaceStorage = findFreeSpaceStorage,
    blindUnloadTurtle    = blindUnloadTurtle,

    -- Constants
    isSystemSide = isSystemSide,
}
