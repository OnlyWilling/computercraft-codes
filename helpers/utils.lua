-- ======Collection of some useful utils======

---Generate a random string of some length
---@param length number Length of string
---@return string res Random string
local function randomString(length)
    math.randomseed((os.epoch('utc')))

    local res = ""
    for i = 1, length do
        res = res .. string.char(math.random(65, 90))
    end
    return res
end

---Determine whether the peripheral is a Chest-like machine
---@param periphId string Peripheral ID to check
---@return boolean canInitialize true if the peripheral is a Chest
local function canInitialize(periphId)
    local peripheral = peripheral.wrap(periphId)

    return not not (
        peripheral.size and
        (string.find(periphId, 'minecraft:chest_') or
            string.find(periphId, 'minecraft:trapped_chest_') or
            string.find(periphId, 'minecraft:barrel_') or
            string.find(periphId, 'minecraft:dispenser_') or
            string.find(periphId, 'minecraft:dropper_') or
            string.find(periphId, 'minecraft:hopper_') or
            (string.find(periphId, 'minecraft:') and string.find(periphId, '_shulker_box_')) or
            peripheral.size() >= 8)
    )
end

return {
    randomString = randomString,
    canInitialize = canInitialize,
}
