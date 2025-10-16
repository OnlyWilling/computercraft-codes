local function checkItemDetails(inventory)
    local item = nil
    for i = 1, inventory.size() do
        item = inventory.getItemDetail(i)
        if item then
            print(("%s (%s) in slot[%d]"):format(item.displayName, item.name, i))
            print(("Count: %d/%d"):format(item.count, item.maxCount))
        end
    end
end

local function recipeTransfer(storage, manager, fromslot, toslot)
    local num = storage.pushItems(peripheral.getName(manager), fromslot, 64, toslot)
    if num == 0 then
        print("Transfer failed!")
    else
        print(("Transferred %d item(s) from storage[%d] to manager[%d]"):format(num, fromslot, toslot))
    end
end

local function recipeTakeback(manager, storage, fromslot, toslot)
    local num = manager.pushItems(peripheral.getName(storage), fromslot, 64, toslot)
    if num == 0 then
        print("Transfer failed!")
    else
        print(("Transferred %d item(s) from manager[%d] to storage[%d]"):format(num, fromslot, toslot))
    end
end


local recipe_storage = peripheral.find("minecraft:chest")
local manager_barrel = peripheral.find("minecraft:barrel")
local manager_deployer = peripheral.find("create:deployer")

checkItemDetails(recipe_storage)


while true do
    local _, key, _ = os.pullEvent("key")
    if key == keys.one then
        recipeTransfer(recipe_storage, manager_deployer, 1, 1)
        redstone.setOutput("front", true)
        sleep(3)
        redstone.setOutput("front", false)
        recipeTakeback(manager_deployer, recipe_storage, 1, 1)
    elseif key == keys.two then
        recipeTransfer(recipe_storage, manager_deployer, 2, 1)
        redstone.setOutput("front", true)
        sleep(3)
        redstone.setOutput("front", false)
        recipeTakeback(manager_deployer, recipe_storage, 1, 2)
    elseif key == keys.q then
        term.clear()
        term.setCursorPos(1, 1)
        print("Program quit")
        break
    end
end
