-- 一个模仿机械动力工厂仪表的自动补货lua程序(需使有线连接)、
--a lua application simulating Factory gague in create mod(all inventories shoud connect computer with wire)
-- ====================== USER CONFIG ======================
local CONFIG = {
    --材料来源容器的前缀
    storage_types = 
    { "minecraft:chest", 
      "minecraft:barrel",
      "create:item_vault"
    },
    target_types  = { "numismatics:vendor" },
    --目标容器前缀
    rules = {
        ["minecraft:diamond_helmet"] = 4,
        ["minecraft:diamond_chestplate"] = 4,
        ["minecraft:diamond_leggings"] = 4,
        ["minecraft:diamond_boots"] = 4
    },
    --需要维持的物品名称和数量
    check_interval = 1,
    --补货时间间隔
}
-- ========================================================

-- 自动寻找第一个有线调制解调器并打开网络
local modem_side = nil
for _, side in ipairs({"top","bottom","left","right","front","back"}) do
    if peripheral.isPresent(side) and peripheral.getType(side) == "modem" then
        modem_side = side
        rednet.open(side)
        print("Modem found and opened on side: " .. side)
        break
    end
end
if not modem_side then error("No wired modem found!") end

local storages = {}
local targets  = {}

-- 安全统计 table 长度
local function tableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- 只接受“真实方块名称”的函数（过滤 back/left/top 等方向名）
local function isRealPeripheralName(name)
    return not (
        name == "top"    or name == "bottom" or
        name == "left"   or name == "right"  or
        name == "front"  or name == "back"   or
        name:match("^modem_") or name:match("^monitor_")
    )
end

local function discoverDevices()
    storages = {}
    targets  = {}

    for _, name in ipairs(peripheral.getNames()) do
        if not isRealPeripheralName(name) then goto continue end

        local p = peripheral.wrap(name)
        local typ = peripheral.getType(name)

        for _, st in ipairs(CONFIG.storage_types) do
            if typ == st then table.insert(storages, p) end
        end
        for _, tt in ipairs(CONFIG.target_types) do
            if typ == tt then table.insert(targets, p) end
        end

        ::continue::
    end

    print("Found " .. #storages .. " storage container(s)")
    print("Found " .. #targets  .. " target machine(s)")
end

local function countItem(container, itemName)
    local total = 0
    local list = container.list and container.list() or {}
    for _, stack in pairs(list) do
        if stack.name == itemName then
            total = total + stack.count
        end
    end
    return total
end

discoverDevices()
if #targets == 0 then error("No target machines found!") end
if #storages == 0 then error("No storage containers found!") end

print("Universal Restocker started - monitoring " .. tableCount(CONFIG.rules) .. " item(s)")

while true do
    print("\n=== Check at " .. os.date("%H:%M:%S") .. " ===")
    local total_moved = 0

    for item_name, target_per_machine in pairs(CONFIG.rules) do
        local total_in_targets = 0
        local machines_needing = {}

        for _, machine in ipairs(targets) do
            local has = countItem(machine, item_name)
            total_in_targets = total_in_targets + has
            if has < target_per_machine then
                table.insert(machines_needing, {
                    machine = machine,
                    name    = peripheral.getName(machine),
                    has     = has,
                    need    = target_per_machine - has
                })
            end
        end

        local total_needed = #targets * target_per_machine
        print(string.format("%s: %d/%d (%d need refill)",
            item_name, total_in_targets, total_needed, #machines_needing))

        for _, entry in ipairs(machines_needing) do
            local need = entry.need
            -- 遍历所有存储容器
            for _, storage in ipairs(storages) do
                if need <= 0 then break end

                -- 使用 list() 遍历存储容器所有槽位，找到匹配物品的槽位
                local storage_list = storage.list()
                for slot, stack in pairs(storage_list) do
                    if need <= 0 then break end
                    if stack.name == item_name then
                        -- 找到槽位！从这个槽位精准推送
                        local pushed = storage.pushItems(entry.name, slot, need)
                        need = need - pushed
                        total_moved = total_moved + pushed
                    end
                end
            end
            print(string.format("  -> %s: %d -> %d", entry.name, entry.has, entry.has + entry.need - need))
        end
    end

    if total_moved == 0 then
        print("All machines perfectly stocked")
    else
        print("Total moved this cycle: " .. total_moved)
    end

    print("Next check in " .. CONFIG.check_interval .. " seconds")
    sleep(CONFIG.check_interval)
end