-- local integrator = peripheral.wrap("redstoneIntegrator_19") or error("No integrator found", 0)
-- integrator.setOutput("top", true)
local da = peripheral.find("digital_adapter") or error("No display found", 0)
da.print("TEST HERE1")
da.setLine(2)
da.print("中文测试")
da.clearLine(2)
da.print("中文测试")

-- 创建一个包含中文字符串的表格
local myTable = {
    greeting = "你好，世界！",
    name = "中文测试"
}

-- 使用 textutils.serializeJSON 序列化这个表格
local jsonString = textutils.serializeJSON(myTable, { unicode_strings = true })
print("Serialized JSON string:")
print(jsonString)

local originString = textutils.unserializeJSON(jsonString)
print("Unserialized JSON string:")
for k,v in pairs(originString) do
    print(k, v)
end
-- print(originString)
