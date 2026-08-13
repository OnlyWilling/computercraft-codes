--- 物料传输管理工具（pamon/lib/mgmt）
--- 从 aegis-autocraft 解耦的 MgmtGroups 传输层，提供 IO 解析、物品/流体搬运、供应源查询。
--- 依赖：CC 内置 `peripheral` API。
---
--- 用法示例：
---   local m = require "pamon.lib.mgmt"
---   local srcs = m.mgmtIOList(group, true)
---   local ok   = m.mgmtMoveSlot("chest_0", 1, "chest_1", 64)

-- ============================================================
--  IO 查询工具
-- ============================================================

--- 从 group 中解析输入或输出设备名列表。
--- 优先使用 inputs/outputs 数组；回退到 input/output 单值；"STORAGE" 表示主存储。
--- @param group table MgmtGroup 对象
--- @param isInput boolean true=取输入端列表, false=取输出端列表
--- @return table 设备名列表（数组），例如 {"chest_0"} 或 {"STORAGE"}
local function mgmtIOList(group, isInput)
    local lst = isInput and group.inputs or group.outputs
    if type(lst) == "table" and #lst > 0 then return lst end
    local s = isInput and group.input or group.output
    if not s or s == "" or s == "STORAGE" then return { "STORAGE" } end
    return { s }
end

--- 判断 IO 列表是否指向主存储（空列表或首个元素为 "STORAGE"）。
--- @param lst table 设备名列表
--- @return boolean
local function mgmtListIsStorage(lst)
    return (#lst == 0) or (lst[1] == "STORAGE")
end

-- ============================================================
--  物品传输
-- ============================================================

--- 在源设备和目标设备之间移动单个槽位的物品。
--- 先尝试 src.pushItems，失败则回退到 dst.pullItems。
--- @param srcName string 源外设名
--- @param srcSlot number 源槽位
--- @param destName string 目标外设名
--- @param amount number 移动数量
--- @return number moved 实际移动的数量
local function mgmtMoveSlot(srcName, srcSlot, destName, amount)
    local srcP = peripheral.wrap(srcName)
    if srcP and srcP.pushItems then
        local ok, mv = pcall(srcP.pushItems, destName, srcSlot, amount)
        if ok and mv and mv > 0 then return mv end
    end

    local dstP = peripheral.wrap(destName)
    if dstP and dstP.pullItems then
        local ok2, mv2 = pcall(dstP.pullItems, srcName, srcSlot, amount)
        if ok2 and mv2 and mv2 > 0 then return mv2 end
    end
    return 0
end

--- 在指定设备列表中统计某物品的总数。
--- @param srcNames table 外设名列表
--- @param itemName string 物品名（如 "minecraft:iron_ingot"）
--- @return number total 总数
local function mgmtCountItem(srcNames, itemName)
    local total = 0
    for _, nm in ipairs(srcNames) do
        local p = peripheral.wrap(nm)
        if p and p.list then
            local ok, items = pcall(p.list)
            if ok and items then
                for _, si in pairs(items) do
                    if si and si.name == itemName then total = total + si.count end
                end
            end
        end
    end
    return total
end

--- 从源设备批量移出指定物品到目标。
--- 目标可为 "STORAGE"（自动轮询 storageList）或具体外设名。
--- @param srcName string 源外设名
--- @param dest string 目标外设名或 "STORAGE"
--- @param itemName string 物品名
--- @param amount number 欲移动数量
--- @param storageList table storageList 外设名列表（dest="STORAGE" 时使用）
--- @return number moved 实际移动的数量
local function mgmtMoveFromDev(srcName, dest, itemName, amount, storageList)
    if amount <= 0 then return 0 end
    local p = peripheral.wrap(srcName)
    if not (p and p.list) then return 0 end
    local ok, items = pcall(p.list)
    if not (ok and items) then return 0 end
    local moved = 0
    for sl, si in pairs(items) do
        if moved >= amount then break end
        if si and si.name == itemName then
            local want = math.min(amount - moved, si.count)
            if dest == "STORAGE" then
                for _, sn in ipairs(storageList) do
                    if want <= 0 then break end
                    local mv = mgmtMoveSlot(srcName, sl, sn, want)
                    if mv > 0 then moved = moved + mv; want = want - mv end
                end
            else
                local mv = mgmtMoveSlot(srcName, sl, dest, want)
                if mv > 0 then moved = moved + mv end
            end
        end
    end
    return moved
end

--- 在多个输入源之间轮询分配，均匀搬运物品到目标。
--- 使用 rr.i 作为轮询游标（调用者需初始化 rr = { i = 0 }）。
--- @param inputs table 输入源外设名列表
--- @param dest string 目标外设名或 "STORAGE"
--- @param itemName string 物品名
--- @param amount number 欲移动数量
--- @param storageList table storageList 外设名列表
--- @param rr table 轮询状态 `{ i = 0 }`（会被修改）
--- @return number moved 实际移动的数量
local function mgmtDrawEven(inputs, dest, itemName, amount, storageList, rr)
    local moved = 0
    local n = #inputs
    if n == 0 or amount <= 0 then return 0 end
    while moved < amount do
        local cycleMoved = 0
        local chunk = math.max(1, math.ceil((amount - moved) / n))
        for _ = 1, n do
            if moved >= amount then break end
            rr.i = (rr.i % n) + 1
            local mv = mgmtMoveFromDev(inputs[rr.i], dest, itemName,
                math.min(amount - moved, chunk), storageList)
            if mv > 0 then moved = moved + mv; cycleMoved = cycleMoved + mv end
        end
        if cycleMoved == 0 then break end
    end
    return moved
end

-- ============================================================
--  供应源查询
-- ============================================================

--- 获取 MgmtGroups 中标记为 provider 的输入端设备列表。
--- 这些设备既非主存储也非流体储罐，是"额外的物料来源"，
--- 在库存扫描时（getStorageInventory）会被额外纳入。
--- @param mgmtGroups table MgmtGroups 数组
--- @param configStorages table 存储配置表 `{ ["chest_0"] = true, ... }`
--- @return table 设备名列表（数组）
local function providerSources(mgmtGroups, configStorages)
    local out, seen = {}, {}
    for _, g in ipairs(mgmtGroups or {}) do
        if g.provider and not g.paused then
            for _, src in ipairs(mgmtIOList(g, true)) do
                if src and src ~= "" and src ~= "STORAGE"
                        and not configStorages[src]
                        and not seen[src] then
                    seen[src] = true
                    out[#out + 1] = src
                end
            end
        end
    end
    return out
end

return {
    -- IO
    mgmtIOList       = mgmtIOList,
    mgmtListIsStorage = mgmtListIsStorage,

    -- Item transfer
    mgmtMoveSlot     = mgmtMoveSlot,
    mgmtCountItem    = mgmtCountItem,
    mgmtMoveFromDev  = mgmtMoveFromDev,
    mgmtDrawEven     = mgmtDrawEven,

    -- Provider
    providerSources  = providerSources,
}
