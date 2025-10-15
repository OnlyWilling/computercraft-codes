local GManager = {}

-- Create sanitized global variables for each device for easy reference
function GManager.sanitize_name_for_var(name)
    if not name then return "" end
    -- replace non-alphanumeric with underscore, uppercase the name
    local s = name:gsub("[^%w]", "_"):gsub("__+", "_"):upper()
    return s
end

function GManager.bind_global_index(indexToName, indexToPeripheral)
    for i = 1, #indexToName do
        local name = indexToName[i]
        local sanitized = sanitize_name_for_var(name)
        local varName = "DEV_" .. sanitized
        local shortVar = "dev" .. tostring(i)
        -- assign global and short variables if possible
        local periph = indexToPeripheral[i]
        if not periph and name then
            local ok, obj = pcall(peripheral.wrap, name)
            if ok then periph = obj end
        end
        _G[varName] = periph
        _G[shortVar] = periph
        -- print a summary line
        print(string.format("Mapped %d -> %s  as %s / %s", i, tostring(name), varName, shortVar))
    end
end

return GManager
