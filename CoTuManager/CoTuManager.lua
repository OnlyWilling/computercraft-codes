-- Stockpile Client Inventory Manager (configured + debug viewer)
-- - Local managed inventory list (configurable via TUI)
-- - Ensures scan(list) is called before get_content()
-- - Debug logging to stockpile_debug.jsonl
-- - Debug viewer in TUI (press 'd')

local serverId = 73
local scanInterval = 30
local protocol = "stockpile"
local receiveTimeout = 5
local productionInterval = 15  -- 后台自动生产调度周期（秒）
local turtleProtocol = "factory" -- 海龟通信协议，避免与 stockpile 混淆
local running = true            -- 全局运行标志，用于并发循环退出

-- 默认库存列表（示例，请使用 InvEditor 配置实际的库存ID）
-- 例如: {"minecraft:chest_1", "minecraft:barrel_2", "create:item_vault_3"}
local defaultInventories = {}

math.randomseed(os.time())

local debug_log_file = "stockpile_debug.jsonl"
local config_file = "stockpile_config.lua"
local recipes_file = "recipes.json"
local managedInvs = {}

-- 新增：配方和海龟管理
local recipes = {}
local turtles = {}  -- {turtle_id={inv, addr, status="idle"/"busy", tasks=0}}
local pending_requests = {}  -- {uuid={cmd, callback}}
local cached_inventory = {}  -- 缓存的聚合库存数据 {item_id: total_count}
local last_raw_content = nil  -- 最近一次 get_content 的原始数据缓存

-- Lightweight Lua-style serializer producing compact table literals.
local function luaSerialize(val)
    local t = type(val)
    if t == "string" then
        -- %q produces a quoted string with escapes
        return string.format('%q', val)
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "table" then
        -- detect array-like
        local isArray = true
        local max = 0
        for k,_ in pairs(val) do
            if type(k) ~= "number" then isArray = false end
            if type(k) == "number" and k > max then max = k end
        end
        local parts = {}
        if isArray then
            -- iterate numeric indices in order
            for i=1, max do
                table.insert(parts, luaSerialize(val[i]))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        else
            for k,v in pairs(val) do
                local key
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    key = k
                else
                    key = "[" .. luaSerialize(k) .. "]"
                end
                table.insert(parts, key .. "=" .. luaSerialize(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return "nil"
    end
end

local function safeSerialize(obj)
    -- Prefer producing compact Lua literals for tables (server expects Lua syntax)
    if type(obj) == "table" then
        -- If textutils.serialize exists but may produce multiline output, use luaSerialize for compactness
        return luaSerialize(obj)
    elseif type(obj) == "string" then
        return string.format('%q', obj)
    else
        return tostring(obj)
    end
end

local function appendDebugEntry(entry)
    pcall(function()
        local fh = fs.open(debug_log_file, "a")
        fh.writeLine(safeSerialize(entry))
        fh.close()
    end)
end

local function loadConfig()
    if fs.exists(config_file) then
        local ok, res = pcall(dofile, config_file)
        if ok and type(res) == "table" then managedInvs = res else managedInvs = {} end
    else managedInvs = {} end
end

local function saveConfig()
    pcall(function()
        local fh = fs.open(config_file, "w")
        fh.writeLine("return {")
        for _, v in ipairs(managedInvs) do fh.writeLine("    \"" .. tostring(v) .. "\",") end
        fh.writeLine("}")
        fh.close()
    end)
end

-- 新增：配方管理
local function loadRecipes()
    if fs.exists(recipes_file) then
        local file = fs.open(recipes_file, "r")
        local content = file.readAll()
        file.close()
        local config = textutils.unserializeJSON(content)
        recipes = config.recipes or {}
    end
end

local function saveRecipes()
    local file = fs.open(recipes_file, "w")
    file.write(textutils.serializeJSON({recipes = recipes}))
    file.close()
end

local function configureManagedInvs()
    local dirty = false
    local function listEntries()
        term.clear(); term.setCursorPos(1,1)
        print("Inventory Manager Configuration")
        print("-------------------------------")
        if #managedInvs == 0 then print("<empty>") end
        for i, v in ipairs(managedInvs) do print(string.format("%3d: %s", i, v)) end
        print("")
    end

    listEntries()
    print("Commands:")
    print("  l                   list entries")
    print("  a <inventory_id>    add inventory id to managed list")
    print("  e <index>           edit entry at index")
    print("  m <from> <to>       move entry from index 'from' to position 'to'")
    print("  d <index>           delete entry by index")
    print("  s                   save config")
    print("  q                   quit (prompts to save if modified)")

    while true do
        write("cmd> ")
        local line = read()
        if not line then break end
        local cmd, rest = line:match("^(%S+)%s*(.*)$")
        if not cmd then print("Invalid command"); goto continue end

        if cmd == "l" then
            listEntries()
        elseif cmd == "a" then
            if rest and rest ~= "" then
                table.insert(managedInvs, rest)
                dirty = true
                print("Added: " .. rest)
            else print("Usage: a <inventory_id>") end
        elseif cmd == "e" then
            local idx = tonumber(rest)
            if idx and managedInvs[idx] then
                write("New value for index "..idx..": ")
                local nv = read()
                if nv and nv ~= "" then
                    managedInvs[idx] = nv
                    dirty = true
                    print("Updated index "..idx)
                else print("No change") end
            else print("Invalid index") end
        elseif cmd == "m" then
            local a,b = rest:match("^(%d+)%s+(%d+)$")
            a = tonumber(a); b = tonumber(b)
            if a and b and managedInvs[a] then
                local val = table.remove(managedInvs, a)
                if b <= 0 then b = 1 end
                if b > #managedInvs+1 then b = #managedInvs+1 end
                table.insert(managedInvs, b, val)
                dirty = true
                print(string.format("Moved index %d to %d", a, b))
            else print("Usage: m <from> <to>") end
        elseif cmd == "d" then
            local idx = tonumber(rest)
            if idx and managedInvs[idx] then
                table.remove(managedInvs, idx)
                dirty = true
                print("Removed index " .. idx)
            else print("Invalid index") end
        elseif cmd == "s" then
            saveConfig(); dirty = false; print("Saved.")
        elseif cmd == "q" then
            if dirty then
                write("You have unsaved changes. Save before quitting? (y/n) ")
                local ans = read()
                if ans and ans:lower():sub(1,1) == 'y' then saveConfig(); print("Saved.") end
            end
            break
        else
            print("Unknown command")
        end
        ::continue::
    end
    term.clear()
end

-- 新增：配方编辑功能
local function input_number(prompt)
    while true do
        print(prompt)
        local input = read()
        local num = tonumber(input)
        if num and num > 0 then return num end
        print("Invalid number, try again")
    end
end

-- 工作台插槽(3x3)到海龟插槽(4x4)的转换
local function workbench_to_turtle_slot(workbench_slot)
    local conversion = {
        [1] = 1,  [2] = 2,  [3] = 3,
        [4] = 5,  [5] = 6,  [6] = 7,
        [7] = 9,  [8] = 10, [9] = 11
    }
    return conversion[workbench_slot]
end

local function turtle_to_workbench_slot(turtle_slot)
    local reverse_conversion = {
        [1] = 1,  [2] = 2,  [3] = 3,
        [5] = 4,  [6] = 5,  [7] = 6,
        [9] = 7,  [10] = 8, [11] = 9
    }
    return reverse_conversion[turtle_slot] or turtle_slot
end

local function input_slots()
    local slots = {}
    print("Enter workbench slot numbers (1-9, comma-separated):")
    print("Workbench layout: 1 2 3")
    print("                  4 5 6")
    print("                  7 8 9")
    local input = read()
    for slot in input:gmatch("%d+") do
        local num = tonumber(slot)
        if num and num >= 1 and num <= 9 then
            local turtle_slot = workbench_to_turtle_slot(num)
            table.insert(slots, turtle_slot)
        else
            print("Invalid workbench slot: " .. slot .. " (must be 1-9)")
            return nil
        end
    end
    return slots
end

local function manageRecipes()
    local function draw_menu(options, selected)
        term.clear()
        term.setCursorPos(1, 1)
        print("=== Recipe Manager ===")
        for i, opt in ipairs(options) do
            if i == selected then
                print("> " .. opt)
            else
                print("  " .. opt)
            end
        end
        print("Use UP/DOWN to select, ENTER to confirm")
    end

    local function add_recipe()
        term.clear()
        term.setCursorPos(1, 1)
        print("=== Add Recipe ===")
        local recipe = {output = {}, inputs = {}}
        recipe.id = input_number("Enter recipe ID:")
        for _, r in ipairs(recipes) do
            if r.id == recipe.id then
                print("ID already exists!")
                os.sleep(2)
                return
            end
        end
        print("Enter output item (e.g., minecraft:oak_stairs):")
        recipe.output.item = read()
        recipe.output.qty_per_craft = input_number("Enter quantity per craft:")
        recipe.output.target_stock = input_number("Enter target stock:")
        print("Enter product inventory (e.g., minecraft:chest_1):")
        recipe.product_inv = read()
        local input_count = input_number("Enter number of different input materials:")
        for i = 1, input_count do
            print("Input material " .. i .. ":")
            local input = {}
            print("Enter item (e.g., minecraft:oak_planks):")
            input.item = read()
            input.slots = input_slots()
            if input.slots then
                input.qty = #input.slots
                print("Auto-calculated quantity: " .. input.qty .. " (1 per slot)")
                table.insert(recipe.inputs, input)
            else
                print("Invalid slots, aborting")
                os.sleep(2)
                return
            end
        end
        table.insert(recipes, recipe)
        saveRecipes()
        print("Recipe added!")
        os.sleep(2)
    end

    local function view_recipes()
        term.clear()
        term.setCursorPos(1, 1)
        print("=== Recipe List ===")
        if #recipes == 0 then
            print("No recipes configured")
        else
            for _, recipe in ipairs(recipes) do
                print("ID: " .. recipe.id)
                print("Output: " .. recipe.output.item .. " x" .. recipe.output.qty_per_craft)
                print("Target Stock: " .. recipe.output.target_stock)
                print("Product Inv: " .. recipe.product_inv)
                print("Inputs:")
                for _, input in ipairs(recipe.inputs) do
                    local workbench_slots = {}
                    for _, turtle_slot in ipairs(input.slots) do
                        table.insert(workbench_slots, turtle_to_workbench_slot(turtle_slot))
                    end
                    print("  " .. input.item .. " x" .. input.qty .. " (slots: " .. table.concat(workbench_slots, ",") .. ")")
                end
                print("---")
            end
        end
        print("Press any key to return")
        os.pullEvent("key")
    end

    local function delete_recipe()
        term.clear()
        term.setCursorPos(1, 1)
        print("=== Delete Recipe ===")
        if #recipes == 0 then
            print("No recipes to delete")
            os.sleep(2)
            return
        end
        for i, recipe in ipairs(recipes) do
            print(i .. ": ID=" .. recipe.id .. ", Output=" .. recipe.output.item)
        end
        local index = input_number("Enter recipe number to delete (1-" .. #recipes .. "):")
        if recipes[index] then
            table.remove(recipes, index)
            saveRecipes()
            print("Recipe deleted!")
        else
            print("Invalid recipe number")
        end
        os.sleep(2)
    end

    local function check_materials()
        term.clear()
        term.setCursorPos(1, 1)
        print("=== Material Check ===")
        if #recipes == 0 then
            print("No recipes configured")
            print("Press any key to return")
            os.pullEvent("key")
            return
        end
        
        print("Checking materials for all recipes...")
        print("")
        
        for _, recipe in ipairs(recipes) do
            print("Recipe " .. recipe.id .. " (" .. recipe.output.item .. "):")
            local all_ok = true
            for _, input in ipairs(recipe.inputs) do
                local available = cached_inventory[input.item] or 0
                local needed = input.qty
                local status = available >= needed and "OK" or "SHORTAGE"
                if available < needed then all_ok = false end
                print(string.format("  %s: %d/%d [%s]", input.item, available, needed, status))
            end
            print("  Overall: " .. (all_ok and "CAN CRAFT" or "MISSING MATERIALS"))
            print("")
        end
        
        print("Press any key to return")
        os.pullEvent("key")
    end

    local options = {"View Recipes", "Check Materials", "Add Recipe", "Delete Recipe", "Back"}
    local selected = 1
    while true do
        draw_menu(options, selected)
        local _, key = os.pullEvent("key")
        if key == keys.up then
            selected = math.max(1, selected - 1)
        elseif key == keys.down then
            selected = math.min(#options, selected + 1)
        elseif key == keys.enter then
            if selected == 1 then view_recipes()
            elseif selected == 2 then check_materials()
            elseif selected == 3 then add_recipe()
            elseif selected == 4 then delete_recipe()
            elseif selected == 5 then break end
        end
    end
    term.clear()
end

-- 新增：查看海龟状态
local function viewTurtleStatus()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Turtle Status ===")
    print("")
    
    if next(turtles) == nil then
        print("No turtles registered")
        print("")
        print("Turtles need to send a register message:")
        print('  {type="register", turtle_id=<id>, inv=<inv_name>}')
    else
        local total = 0
        local idle = 0
        local busy = 0
        
        for addr, turtle in pairs(turtles) do
            total = total + 1
            if turtle.status == "idle" then idle = idle + 1 else busy = busy + 1 end
            print(string.format("Turtle addr=%d:", addr))
            if turtle.turtle_id then print(string.format("  Turtle ID: %s", tostring(turtle.turtle_id))) end
            print(string.format("  Inventory: %s", tostring(turtle.inv)))
            print(string.format("  Status: %s", turtle.status))
            print(string.format("  Tasks: %d", turtle.tasks))
            print("")
        end
        
        print(string.format("Summary: %d total, %d idle, %d busy", total, idle, busy))
    end
    
    print("")
    print("Press any key to return")
    os.pullEvent("key")
end

local function showDebugPage()
    while true do
        term.clear(); term.setCursorPos(1,1)
        print("Stockpile Debug Viewer")
        print("---------------------")
        if not fs.exists(debug_log_file) then
            print("No debug log found: " .. debug_log_file)
        else
            local fh = fs.open(debug_log_file, "r")
            local content = fh.readAll()
            fh.close()
            local lines = {}
            local pos = 1
            while true do
                local s, e = content:find("\n", pos, true)
                if not s then
                    if pos <= #content then table.insert(lines, content:sub(pos)) end
                    break
                end
                table.insert(lines, content:sub(pos, s-1))
                pos = e + 1
            end
            local start = 1
            if #lines > 20 then start = #lines - 19 end
            for i = start, #lines do print(lines[i]) end
        end
        print("")
        print("Press Enter to refresh, q+Enter to quit")
        local line = read()
        if line and line:lower():match("^q") then term.clear(); break end
    end
end

-- Open modem and rednet
local modem = peripheral.find("modem")
if not modem then error("No modem found. Please attach a modem to the computer.") end
local modemName = peripheral.getName(modem)
if modemName then
    local ok, err = pcall(rednet.open, modemName)
    if not ok then error("Failed to open rednet: " .. tostring(err)) end
else error("Unable to determine modem name for rednet.open") end

-- 主动声明海龟通信协议，方便海龟通过协议发送
pcall(function()
    rednet.host(turtleProtocol, "factory_manager")
    appendDebugEntry({type = "host_protocol", protocol = turtleProtocol, name = "factory_manager", time = os.time()})
end)

-- 新增：UUID生成
local function generate_uuid()
    return math.random(1, 2^32)
end

-- 新增：查找最适合的存储位置（基于原始响应数据）
local function find_best_storage_inv(item, raw_content)
    if not raw_content or not raw_content.item_index or not raw_content.item_index[item] then
        return nil
    end
    
    local best_inv, best_space = nil, 0
    for inv_name, inv_data in pairs(raw_content.item_index[item]) do
        if type(inv_data) == "table" and inv_name ~= "stack_size" and inv_name ~= "nbt" and inv_name ~= "total" and inv_name ~= "part_filled_slots" then
            local used_space = 0
            if inv_data.slots then
                for _, slot_data in pairs(inv_data.slots) do
                    if type(slot_data) == "table" and slot_data.count then
                        used_space = used_space + slot_data.count
                    end
                end
            elseif type(inv_data) == "number" then
                used_space = inv_data
            end
            
            local stack_size = raw_content.item_index[item].stack_size or 64
            local max_capacity = stack_size * 27  -- 假设箱子27格
            local available_space = max_capacity - used_space
            if available_space > best_space then
                best_inv, best_space = inv_name, available_space
            end
        end
    end
    return best_inv
end

-- 新增：查找库存充足的源位置
local function find_source_inv(item, needed_qty, raw_content)
    if not raw_content or not raw_content.item_index or not raw_content.item_index[item] then
        return nil
    end
    
    local best_inv, best_count = nil, 0
    for inv_name, inv_data in pairs(raw_content.item_index[item]) do
        if type(inv_data) == "table" and inv_name ~= "stack_size" and inv_name ~= "nbt" and inv_name ~= "total" and inv_name ~= "part_filled_slots" then
            local count = 0
            if inv_data.slots then
                for _, slot_data in pairs(inv_data.slots) do
                    if type(slot_data) == "table" and slot_data.count then
                        count = count + slot_data.count
                    end
                end
            elseif type(inv_data) == "number" then
                count = inv_data
            end
            
            if count >= needed_qty and count > best_count then
                best_inv, best_count = inv_name, count
            end
        end
    end
    return best_inv
end

-- 新增：移动物品到海龟前方容器（同步等待完成）
local function move_inputs_to_container(container_inv, recipe, crafts, raw_content)
    print("Moving materials to " .. container_inv .. " for " .. crafts .. " crafts")
    
    -- 统计每种材料的总需求
    local material_needs = {}  -- {item_id = total_qty}
    for _, input in ipairs(recipe.inputs) do
        local total_qty = input.qty * crafts
        material_needs[input.item] = (material_needs[input.item] or 0) + total_qty
    end
    
    -- 为每种材料找到源库存并移动
    for item, total_qty in pairs(material_needs) do
        print("  Moving " .. total_qty .. " x " .. item)
        
        -- 可能需要从多个库存收集
        local remaining = total_qty
        local sources = {}  -- 记录所有可能的源
        
        if raw_content and raw_content.item_index and raw_content.item_index[item] then
            for inv_name, inv_data in pairs(raw_content.item_index[item]) do
                if type(inv_data) == "table" and inv_name ~= "stack_size" and inv_name ~= "nbt" 
                   and inv_name ~= "total" and inv_name ~= "part_filled_slots" then
                    local available = 0
                    if inv_data.slots then
                        for _, qty in pairs(inv_data.slots) do
                            if type(qty) == "number" then available = available + qty end
                        end
                    elseif type(inv_data) == "number" then
                        available = inv_data
                    end
                    if available > 0 then
                        table.insert(sources, {inv = inv_name, qty = available})
                    end
                end
            end
        end
        
        -- 按可用数量排序（优先使用库存多的）
        table.sort(sources, function(a, b) return a.qty > b.qty end)
        
        -- 从各个源移动材料
        for _, source in ipairs(sources) do
            if remaining <= 0 then break end
            local move_qty = math.min(remaining, source.qty)
            
            local cmd = string.format("move_item({%q}, {%q}, %q, %d)", 
                source.inv, container_inv, item, move_qty)
            local res, err = sendCommand(cmd)
            
            if res then
                print("    Moved " .. move_qty .. " from " .. source.inv)
                remaining = remaining - move_qty
            else
                print("    Failed to move from " .. source.inv .. ": " .. tostring(err))
            end
        end
        
        if remaining > 0 then
            print("  Warning: Still need " .. remaining .. " x " .. item)
            return false
        end
    end
    
    return true
end

-- 新增：计算生产需求
local function compute_demands(raw_content)
    local tasks = {}
    for _, recipe in ipairs(recipes) do
        -- 计算当前产品总量
        local total_product = 0
        if cached_inventory[recipe.output.item] then
            total_product = cached_inventory[recipe.output.item]
        end
        
        if total_product < recipe.output.target_stock then
            local needed_product = recipe.output.target_stock - total_product
            local max_crafts_needed = math.ceil(needed_product / recipe.output.qty_per_craft)
            
            -- 计算单次最大合成量
            local max_crafts_per_batch = 64
            for _, input in ipairs(recipe.inputs) do
                local max_per_slot = math.floor(64 / input.qty)
                max_crafts_per_batch = math.min(max_crafts_per_batch, max_per_slot)
            end
            
            -- 检查原材料是否充足
            local available_crafts = max_crafts_per_batch
            for _, input in ipairs(recipe.inputs) do
                local available_raw = cached_inventory[input.item] or 0
                local max_from_raw = math.floor(available_raw / (input.qty * max_crafts_per_batch))
                available_crafts = math.min(available_crafts, max_from_raw * max_crafts_per_batch)
            end
            
            local crafts_to_do = math.min(max_crafts_needed, available_crafts)
            if crafts_to_do > 0 then
                table.insert(tasks, {
                    recipe = recipe,
                    crafts = crafts_to_do,
                    total_output = crafts_to_do * recipe.output.qty_per_craft
                })
            end
        end
    end
    return tasks
end

-- 新增：查找空闲海龟
local function find_idle_turtle()
    local best, best_tasks = nil, math.huge
    for id, turtle in pairs(turtles) do
        if turtle.status == "idle" and turtle.tasks < best_tasks then
            best, best_tasks = turtle, turtle.tasks
        end
    end
    return best
end

-- 新增：分配任务
local function assign_task(task, raw_content)
    local turtle = find_idle_turtle()
    if not turtle then
        print("No idle turtle available for task")
        return false
    end
    
    print("Assigning task to turtle " .. turtle.addr)
    
    -- 1. 移动材料到海龟前方容器
    local success = move_inputs_to_container(turtle.inv, task.recipe, task.crafts, raw_content)
    if not success then
        print("Failed to move materials to turtle container")
        return false
    end
    
    -- 2. 发送任务给海龟（包含最小配方和数量）
    rednet.send(turtle.addr, {
        type = "task",
        recipe = task.recipe,
        crafts = task.crafts
    }, turtleProtocol)
    
    turtle.status = "busy"
    turtle.tasks = turtle.tasks + 1
    
    print("Task assigned: " .. task.crafts .. " crafts of " .. task.recipe.output.item)
    appendDebugEntry({
        type = "task_assigned", 
        turtle = turtle.addr, 
        recipe_id = task.recipe.id,
        crafts = task.crafts,
        time = os.time()
    })
    
    return true
end

local function sendCommand(cmd)
    local uuid = generate_uuid()
    local commandTable = {cmd, uuid}
    pcall(function() print("Sending command: " .. safeSerialize(commandTable)) end)
    rednet.send(serverId, commandTable, protocol)
    appendDebugEntry({type = "sent_command", time = os.time(), server = serverId, protocol = protocol, command = commandTable})

    local deadline = (os.epoch and os.epoch("utc") or 0) + (receiveTimeout * 1000)
    while true do
        local remaining_ms = deadline - (os.epoch and os.epoch("utc") or 0)
        if remaining_ms <= 0 then
            pcall(function() print("Timeout waiting for response from server") end)
            return nil, "Timeout"
        end
        local id, message, proto = rednet.receive(protocol, math.max(0.05, remaining_ms / 1000))
        if id and id == serverId and type(message) == "table" and message[2] == uuid then
            pcall(function() print("Received response: " .. safeSerialize(message)) end)
            appendDebugEntry({type = "received_response", time = os.time(), server = serverId, uuid = uuid})
            return message[1]
        end
        -- otherwise continue until timeout
    end
end

-- 新增：异步网络消息处理（用于海龟通信和后台任务）
-- 注意：主菜单已经直接处理 rednet_message 事件，这个函数主要用于非菜单场景
local function handle_network_async()
    local id, msg, proto = rednet.receive(nil, 0.1)  -- 非阻塞接收
    if not msg then return end
    
    appendDebugEntry({type = "async_message", from = id, protocol = proto or "unknown", time = os.time()})
    
    -- 处理海龟注册（如果不在菜单中）
    if type(msg) == "table" and msg.type == "register" then
        turtles[msg.turtle_id] = {
            inv = msg.inv,
            addr = id,
            status = "idle",
            tasks = 0
        }
        print("Registered turtle: " .. msg.turtle_id .. " (" .. msg.inv .. ")")
        appendDebugEntry({type = "turtle_registered", turtle_id = msg.turtle_id, inv = msg.inv})
        return
    end
    
    -- 处理海龟任务结果（如果不在菜单中）
    if type(msg) == "table" and msg.type == "result" then
        local turtle = turtles[id]
        if turtle then
            if msg.success then
                print("Task completed by turtle " .. id)
                print("  Product: " .. msg.total_output .. "x " .. msg.recipe.output.item)
                appendDebugEntry({type = "task_completed", turtle = id, success = true, output = msg.total_output})
                
                -- 移动产品从海龟容器到目标库存
                print("  Moving products to " .. msg.recipe.product_inv)
                local cmd = string.format("move_item({%q}, {%q}, %q, %d)", 
                    turtle.inv, msg.recipe.product_inv, msg.recipe.output.item, msg.total_output)
                local res, err = sendCommand(cmd)
                
                if res then
                    print("  Products moved successfully")
                else
                    print("  Failed to move products: " .. tostring(err))
                end
            else
                print("Task failed by turtle " .. id .. ": " .. (msg.error or "Unknown error"))
                appendDebugEntry({type = "task_failed", turtle = id, error = msg.error})
            end
            turtle.status = "idle"
            turtle.tasks = turtle.tasks - 1
        end
        return
    end
end

local function scanInventories(list)
    -- Build the scan command:
    -- Stockpile expects: scan({"minecraft:chest_1", "minecraft:barrel_2"})
    -- A Lua table literal with quoted inventory IDs
    local function buildScanCmd(invList)
        if type(invList) == "string" then
            -- Single inventory ID passed as string
            return "scan({" .. luaSerialize(invList) .. "})"
        end
        if type(invList) == "table" then
            -- List of inventory IDs
            return "scan(" .. luaSerialize(invList) .. ")"
        end
        return "scan({})"
    end

    local cmd = buildScanCmd(list)
    local res, err = sendCommand(cmd)
    if not res then 
        print("Scan failed: " .. tostring(err))
        appendDebugEntry({type = "scan_error", error = err, command = cmd})
    end
    return res
end

local function getContent()
    local cmd = "get_content()"
    local res, err = sendCommand(cmd)
    if not res then print("get_content failed: " .. tostring(err)); return {} end
    return res
end

local function getRawContent()
    local cmd = "get_content()"
    local res, err = sendCommand(cmd)
    if not res then return nil end
    return res
end

local function displayInventory(content)
    term.clear(); term.setCursorPos(1,1)
    print("Stockpile Inventory Manager")
    print("---------------------------")
    print("Current Storage Content (Merged Items and Counts):")
    print("")
    local sorted = {}
    for k,v in pairs(content) do table.insert(sorted, {id=k, count=v}) end
    table.sort(sorted, function(a,b) return tostring(a.id) < tostring(b.id) end)
    for _, it in ipairs(sorted) do
        local c = it.count
        local cs = (type(c)=="table") and safeSerialize(c) or tostring(c or 0)
        print(it.id .. ": " .. cs)
    end
    print("")
end


-- Aggregate server raw content (item_index / inv_index) into item_id -> total_count
local function aggregateRawContent(raw)
    local agg = {}
    if not raw then return agg end

    -- Prefer using inv_index when available (more explicit per-slot counts)
    if raw.inv_index and type(raw.inv_index) == "table" then
        for inv, invData in pairs(raw.inv_index) do
            if type(invData) == "table" then
                for slot, slotData in pairs(invData) do
                    if slot == "size" then goto continue_slot end
                    if type(slotData) == "table" then
                        for itemid, cnt in pairs(slotData) do
                            if type(cnt) == "number" then
                                agg[itemid] = (agg[itemid] or 0) + cnt
                            end
                        end
                    end
                    ::continue_slot::
                end
            end
        end
    end

    -- If inv_index produced nothing, or to be safe, also sum from item_index
    if (not raw.inv_index or next(agg) == nil) and raw.item_index and type(raw.item_index) == "table" then
        local function sumNumbers(t)
            local s = 0
            for _, v in pairs(t) do
                if type(v) == "number" then s = s + v
                elseif type(v) == "table" then s = s + sumNumbers(v) end
            end
            return s
        end
        for itemid, itemData in pairs(raw.item_index) do
            if type(itemData) == "table" then
                -- skip metadata keys commonly present
                local total = 0
                for k, v in pairs(itemData) do
                    if k == "stack_size" or k == "part_filled_slots" or k == "nbt" then
                        -- skip
                    else
                        if type(v) == "number" then total = total + v
                        elseif type(v) == "table" then total = total + sumNumbers(v)
                        end
                    end
                end
                if total > 0 then agg[itemid] = (agg[itemid] or 0) + total end
            end
        end
    end

    return agg
end

loadConfig()

local function ensureScanList()
    if managedInvs and #managedInvs > 0 then 
        return managedInvs 
    end
    
    -- 如果没有配置，返回空列表并提示用户
    if #defaultInventories == 0 then
        print("Warning: No inventories configured!")
        print("Please use 'InvEditor' to add inventory IDs.")
        print("Example: minecraft:chest_1, create:item_vault_2")
        return {}
    end
    
    return defaultInventories
end

-- 后台服务：周期扫描与生产调度 + 海龟消息处理
local function background_service()
    appendDebugEntry({type = "bg_service_start", time = os.time(), scanInterval = scanInterval, productionInterval = productionInterval})
    local function now_ms() return (os.epoch and os.epoch("utc")) or 0 end
    local next_scan = now_ms() + 1000 -- 1s 后首次扫描
    local next_prod = now_ms() + (productionInterval * 1000)

    while running do
        local now = now_ms()
        local timeout_ms = math.max(0, math.min(500, math.min(next_scan - now, next_prod - now)))
        local id, msg, proto = rednet.receive(turtleProtocol, timeout_ms / 1000)

        if id then
            appendDebugEntry({type = "bg_rednet", from = id, protocol = proto or turtleProtocol, msg_type = type(msg) == "table" and msg.type or type(msg)})
            if type(msg) == "table" and msg.type == "register" then
                -- 校验字段
                if type(msg.inv) ~= "string" or msg.inv == "" or (msg.turtle_id ~= nil and type(msg.turtle_id) ~= "number" and type(msg.turtle_id) ~= "string") then
                    local err = "invalid register payload: need inv:string and optional turtle_id:number/string"
                    appendDebugEntry({type = "turtle_register_invalid", addr = id, payload = msg, error = err})
                    rednet.send(id, { type = "register_ack", ok = false, error = err }, turtleProtocol)
                else
                    -- 以网络地址为键，避免后续 result 按 sender_id 查找不到
                    turtles[id] = { inv = msg.inv, addr = id, turtle_id = msg.turtle_id, status = "idle", tasks = 0 }
                    print("Registered turtle addr=" .. tostring(id) .. ", id=" .. tostring(msg.turtle_id) .. " (" .. tostring(msg.inv) .. ")")
                    appendDebugEntry({type = "turtle_registered", addr = id, turtle_id = msg.turtle_id, inv = msg.inv})
                    -- 显式回执，便于海龟端确认注册成功
                    rednet.send(id, { type = "register_ack", ok = true }, turtleProtocol)
                end
            elseif type(msg) == "table" and msg.type == "result" then
                local t = turtles[id]
                if t then
                    if msg.success then
                        print("Task completed by turtle " .. id)
                        print("  Product: " .. tostring(msg.total_output) .. "x " .. tostring(msg.recipe.output.item))
                        appendDebugEntry({type = "task_completed", turtle = id, success = true, output = msg.total_output})
                        local move_cmd = string.format("move_item({%q}, {%q}, %q, %d)", t.inv, msg.recipe.product_inv, msg.recipe.output.item, msg.total_output)
                        local res, err = sendCommand(move_cmd)
                        if not res then
                            print("  Failed to move products: " .. tostring(err))
                            appendDebugEntry({type = "product_move_failed", error = err})
                        end
                    else
                        print("Task failed by turtle " .. id .. ": " .. (msg.error or "Unknown error"))
                        appendDebugEntry({type = "task_failed", turtle = id, error = msg.error})
                    end
                    t.status = "idle"
                    t.tasks = math.max(0, (t.tasks or 0) - 1)
                end
            end
        end

        now = now_ms()
        if now >= next_scan then
            local list = ensureScanList()
            if #list > 0 then
                local ok = scanInventories(list)
                if ok then
                    local raw = getRawContent()
                    if raw then
                        last_raw_content = raw
                        cached_inventory = aggregateRawContent(raw)
                        appendDebugEntry({type = "bg_scan_update", time = os.time(), inv_count = #list, item_count = (cached_inventory and (function(tbl) local n=0 for _ in pairs(tbl) do n=n+1 end return n end)(cached_inventory) or 0)})
                    end
                end
            else
                appendDebugEntry({type = "bg_scan_skip_no_invs", time = os.time()})
            end
            next_scan = now + (scanInterval * 1000)
        end

        if now >= next_prod then
            local raw = last_raw_content or getRawContent()
            if raw then
                cached_inventory = aggregateRawContent(raw)
                local tasks = compute_demands(raw)
                if #tasks > 0 then
                    for _, task in ipairs(tasks) do
                        if not find_idle_turtle() then break end
                        assign_task(task, raw)
                    end
                end
            end
            next_prod = now + (productionInterval * 1000)
        end
    end
    appendDebugEntry({type = "bg_service_stop", time = os.time()})
end

local function mainMenu()
    local items = {"StockShower", "RecipeManager", "TurtleStatus", "AutoProduction", "InvEditor", "DebugShower", "Exit"}
    local idx = 1
    while true do
        term.clear(); term.setCursorPos(1,1)
        print("Stockpile Factory Manager")
        print("-------------------------")
        local turtle_count = 0
        for _ in pairs(turtles) do turtle_count = turtle_count + 1 end
        print("Recipes: " .. #recipes .. " | Turtles: " .. turtle_count)
        print("")
        for i, it in ipairs(items) do
            if i == idx then
                print(string.format(" > %s", it))
            else
                print(string.format("   %s", it))
            end
        end
        print("")
        print("Use Up/Down to navigate, Enter to select")

        local event, param = os.pullEvent("key")
        if event == "key" then
            local k = (keys and keys.getName) and keys.getName(param) or tostring(param)
            if k == "up" then idx = idx - 1 if idx < 1 then idx = #items end
            elseif k == "down" then idx = idx + 1 if idx > #items then idx = 1 end
            elseif k == "enter" or k == "return" then
                return items[idx]
            end
        end
    end
end

-- 新增：自动生产界面
local function autoProductionMenu()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Auto Production ===")
    print("Scanning and checking production needs...")
    print("")
    
    -- 扫描库存
    local scanList = ensureScanList()
    
    -- 检查是否有配置的库存
    if #scanList == 0 then
        print("ERROR: No inventories configured!")
        print("")
        print("Please configure inventories first:")
        print("1. Go to 'InvEditor'")
        print("2. Add inventory IDs (e.g., minecraft:chest_1)")
        print("")
        print("Press any key to return")
        os.pullEvent("key")
        return
    end
    
    print("Scanning inventories: " .. table.concat(scanList, ", "))
    local scanResult = scanInventories(scanList)
    appendDebugEntry({type = "auto_scan", time = os.time(), list = scanList, result = scanResult})
    
    -- 检查扫描结果
    if type(scanResult) == "string" and scanResult:find("Error") then
        print("")
        print("ERROR: Scan failed!")
        print("Reason: " .. scanResult)
        print("")
        print("Common causes:")
        print("- Invalid inventory ID format")
        print("- Inventory doesn't exist in the world")
        print("- Stockpile server not responding")
        print("")
        print("Please check your inventory IDs in 'InvEditor'")
        print("Format should be: minecraft:chest_1, create:item_vault_2, etc.")
        print("")
        print("Press any key to return")
        os.pullEvent("key")
        return
    end
    
    -- 获取原始内容
    local raw = getRawContent()
    if not raw then
        print("Failed to get inventory content!")
        print("Press any key to return")
        os.pullEvent("key")
        return
    end
    
    -- 更新缓存库存
    cached_inventory = aggregateRawContent(raw)
    
    -- 显示库存状态
    print("Current Inventory Status:")
    for _, recipe in ipairs(recipes) do
        local current = cached_inventory[recipe.output.item] or 0
        local target = recipe.output.target_stock
        local status = current >= target and "OK" or "NEED"
        print(string.format("  %s: %d/%d [%s]", recipe.output.item, current, target, status))
    end
    print("")
    
    -- 计算需求
    local tasks = compute_demands(raw)
    
    if #tasks == 0 then
        print("No production needed. All stocks are sufficient!")
    else
        print("Production tasks to assign: " .. #tasks)
        for _, task in ipairs(tasks) do
            print("  - " .. task.crafts .. " crafts of " .. task.recipe.output.item .. " (+" .. task.total_output .. ")")
        end
        print("")
        
        -- 分配任务
        local idle_turtles = 0
        for _, turtle in pairs(turtles) do
            if turtle.status == "idle" then idle_turtles = idle_turtles + 1 end
        end
        
        if idle_turtles == 0 then
            print("Warning: No idle turtles available!")
        else
            print("Assigning tasks to " .. idle_turtles .. " idle turtle(s)...")
            for _, task in ipairs(tasks) do
                assign_task(task, raw)
            end
        end
    end
    
    print("")
    print("Press any key to return")
    os.pullEvent("key")
end

-- UI 循环，与后台并发运行
local function ui_loop()
    while true do
        local choice = mainMenu()
        if choice == "StockShower" then
            local scanList = ensureScanList()
            if #scanList == 0 then
                term.clear(); term.setCursorPos(1, 1)
                print("ERROR: No inventories configured!\n\nPlease use 'InvEditor' to add inventory IDs first.\nExample: minecraft:chest_1, create:item_vault_2\n\nPress any key to return")
                os.pullEvent("key")
            else
                print("Scanning: " .. table.concat(scanList, ", "))
                local scanResult = scanInventories(scanList)
                appendDebugEntry({type = "manual_scan", time = os.time(), list = scanList, result = scanResult})
                if type(scanResult) == "string" and scanResult:find("Error") then
                    term.clear(); term.setCursorPos(1, 1)
                    print("Scan Error!\n\n" .. scanResult .. "\n\nPlease check your inventory IDs in 'InvEditor'\nPress any key to return")
                    os.pullEvent("key")
                else
                    local raw = getRawContent()
                    cached_inventory = aggregateRawContent(raw)
                    displayInventory(cached_inventory)
                    os.pullEvent("key")
                end
            end
        elseif choice == "RecipeManager" then
            manageRecipes()
        elseif choice == "TurtleStatus" then
            viewTurtleStatus()
        elseif choice == "AutoProduction" then
            autoProductionMenu()
        elseif choice == "InvEditor" then
            configureManagedInvs()
        elseif choice == "DebugShower" then
            showDebugPage()
        elseif choice == "Exit" then
            running = false
            -- 触发后台循环退出
            pcall(os.queueEvent, "terminate")
            term.clear()
            return
        end
    end
end

local function main()
    print("Starting Stockpile Factory Manager (serverId=" .. tostring(serverId) .. ")")
    loadConfig()
    loadRecipes()
    -- 并发运行后台服务与 UI
    parallel.waitForAny(background_service, ui_loop)
end

main()