local dinerManager = require("dinerManager")
dinerManager:init()
dinerManager:checkItemDetails()

while true do
    local _, key, _ = os.pullEvent("key")
    if key == keys.one then
        dinerManager:recipeTransfer(1)
        dinerManager:recipeWaitForChange()
        dinerManager:recipeTakeback(1)
    elseif key == keys.two then
        dinerManager:recipeTransfer(2)
        dinerManager:recipeWaitForChange()
        dinerManager:recipeTakeback(2)
    elseif key == keys.three then
        dinerManager:recipeTransfer(3)
        dinerManager:recipeWaitForChange()
        dinerManager:recipeTakeback(3)
    elseif key == keys.four then
        dinerManager:recipeTransfer(4)
        dinerManager:recipeWaitForChange()
        dinerManager:recipeTakeback(4)
        -- callForIngredients(integrator, "top")
    elseif key == keys.q then
        term.clear()
        term.setCursorPos(1, 1)
        print("Program quit")
        break
    else
        print("Invalid key. Press 1-4 to transfer recipes, or Q to quit.")
    end
end
