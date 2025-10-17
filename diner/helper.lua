local helper = {}
-- Helper: split device name string by commas or whitespace
function helper.split_device_names(s)
    local t = {}
    if not s then return t end
    for part in s:gmatch("[^,%s]+") do
        table.insert(t, part)
    end
    return t
end

-- Create mapping from index -> name and name -> index, optional peripheral.wrap
function helper.createDeviceMaps(namesString, floor, opts)
    opts = opts or {}
    local strict = opts.strict or false
    local doWrap = opts.wrap or false

    if floor <= 0 or floor > 16 then
        error("createDeviceMaps: floor must be 1-16")
    end
    if not namesString or namesString == "" then
        if strict then error("createDeviceMaps: namesString empty") end
        return {}, {}, {}
    end

    local rawNames = helper.split_device_names(namesString)
    local n = math.min(#rawNames, floor)
    local indexToName = {}
    local indexToPeripheral = {}

    for i = 1, n do
        local name = rawNames[i]
        indexToName[i] = name
        if doWrap and peripheral then
            local ok, obj = pcall(peripheral.wrap, name)
            if ok and obj then
                indexToPeripheral[i] = obj
            else
                indexToPeripheral[i] = nil
                print("Warning: cannot wrap peripheral: " .. tostring(name))
            end
        end
    end

    if #rawNames < floor then
        local msg = string.format("Note: provided device names (%d) < floor (%d). Mapped %d devices.", #rawNames, floor,
            n)
        if strict then error(msg) else print(msg) end
    elseif #rawNames > floor then
        print(string.format("Note: provided device names (%d) > floor (%d). Extra names truncated.", #rawNames, floor))
    end

    return indexToName, indexToPeripheral
end

return helper
