local dinerManager = {}

function dinerManager:init()
    self.recipe_storage = peripheral.find("minecraft:chest")
    self.manager_deployer = peripheral.find("create:deployer")
    self.relay = peripheral.find("redstone_relay")
end

function dinerManager:checkItemDetails()
    local item = nil
    for i = 1, self.recipe_storage.size() do
        item = self.recipe_storage.getItemDetail(i)
        if item then
            print(("%s (%s) in slot[%d]"):format(item.displayName, item.name, i))
            print(("Count: %d/%d"):format(item.count, item.maxCount))
        end
    end
end

function dinerManager:recipeTransfer(fromslot)
    local num = self.recipe_storage.pushItems(peripheral.getName(self.manager_deployer), fromslot, 64, 1)
    if num == 0 then
        print("Transfer failed!")
        return false
    else
        print(("Transferred %d item(s) from storage[%d] to manager[%d]"):format(num, fromslot, 1))
        return true
    end
end

function dinerManager:recipeTakeback(toslot)
    local num = self.manager_deployer.pushItems(peripheral.getName(self.recipe_storage), 1, 64, toslot)
    if num == 0 then
        print("Transfer failed!")
        return false
    else
        print(("Transferred %d item(s) from manager[%d] to storage[%d]"):format(num, 1, toslot))
        return true
    end
end

function dinerManager:recipeWaitForChange() -- Trigger Gear Box
    self.relay.setOutput("front", true)
    os.sleep(0.5)
    self.relay.setOutput("front", false)
end

function dinerManager:callForIngredients(integrator, direction)
    integrator.setOutput(direction, true)
    os.sleep(0.2)
    integrator.setOutput(direction, false)
end

return dinerManager