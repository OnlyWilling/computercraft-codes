local fruits = { test_num = 123, "Apple", "Banana", "Orange", ["color"]="Blue"}
print("TEST HERE".."\t"..fruits["color"])
fruits[5] = "Grape"   -- 不连续的索引
fruits["color"] = "Red" -- 字符串索引
function fruits:dummy(dice)
    print(dice[2])
    print("TEST HERE 2:"..self.test_num)
    self["color"] = "Green"
    print("TEST HERE".."\t"..self["color"])
end
print("TEST HERE".."\t"..fruits["color"])

print("--- USE ipairs ---")
for index, value in ipairs(fruits) do
    print(index, value)
end
-- 输出:
-- --- 使用 ipairs ---
-- 1   Apple
-- 2   Banana
-- 3   Orange
-- (遍历在索引3之后就停止了，因为索引4是nil)

print("--- USE pairs ---")
for key, value in pairs(fruits) do
    print(key, value)
end
-- 可能的输出 (顺序不保证):
-- --- 使用 pairs ---
-- 1   Apple
-- 2   Banana
-- 3   Orange
-- color Red
-- 5   Grape
fruits:dummy({1,2})