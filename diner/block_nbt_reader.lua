local reader = peripheral.find("blockReader") or error("No block reader found", 0)
local mon = peripheral.find("monitor") or term.native()
local data = reader.getBlockData()
term.redirect(mon)
mon.setTextScale(0.5)

for k, v in pairs(data) do
    local vType = type(v)
    print(("Key: %s  Type: %s"):format(k, vType))
    if vType == "table" then
        print("Table " .. k .. " has")
        for index, value in pairs(v) do
            print(index)
            if type(value) == "table" and (index == "Items" or "tag") then
                for n, m in pairs(value) do
                    print(n)
                    if type(m) == "table" then
                        for a, b in pairs(m) do
                            if n == "Ingredients" then
                                for r, t in pairs(b) do
                                    print("  Ingredients has", r)
                                end
                            else
                                print("  ", a, b)
                            end
                        end
                    end
                end
            end
        end
    end
    print("------")
end

while true do
    local _, key, _ = os.pullEvent("key")

    if key == keys.q then
        term.clear()
        term.setCursorPos(1, 1)
        print("Program quit")
        break
    end
end
