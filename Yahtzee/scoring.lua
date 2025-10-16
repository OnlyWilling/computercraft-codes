-- 计分逻辑
local Scoring = {}

-- 统计每个点数出现的次数
local function count_dice(dice)
    local counts = { [1]=0, [2]=0, [3]=0, [4]=0, [5]=0, [6]=0 }
    for _, value in ipairs(dice) do
        counts[value] = counts[value] + 1
    end
    return counts
end

-- 上半部分计分 (一点到六点)
function Scoring.calculateUpper(dice, number)
    local total = 0
    for _, value in ipairs(dice) do
        if value == number then
            total = total + number
        end
    end
    return total
end

-- 三条/四条
function Scoring.calculateNOfAKind(dice, n)
    local counts = count_dice(dice)
    for _, count in pairs(counts) do
        if count >= n then
            return Scoring.sum_dice(dice) -- 按规则，三条/四条的分数是所有骰子总和
        end
    end
    return 0
end

-- 葫芦 (三条 + 一对)
function Scoring.calculateFullHouse(dice)
    local counts = count_dice(dice)
    local has_three = false
    local has_two = false
    for _, count in pairs(counts) do
        if count == 3 then has_three = true end
        if count == 2 then has_two = true end
    end
    if has_three and has_two then
        return 25
    end
    return 0
end

-- 小顺 (4个连续的骰子)
function Scoring.calculateSmallStraight(dice)
    local unique_dice = {}
    local temp = {}
    for _, d in ipairs(dice) do
        if not temp[d] then
            table.insert(unique_dice, d)
            temp[d] = true
        end
    end
    table.sort(unique_dice)

    if #unique_dice < 4 then return 0 end

    for i = 1, #unique_dice - 3 do
        if unique_dice[i+1] == unique_dice[i] + 1 and
           unique_dice[i+2] == unique_dice[i] + 2 and
           unique_dice[i+3] == unique_dice[i] + 3 then
            return 30
        end
    end
    return 0
end

-- 大顺 (5个连续的骰子)
function Scoring.calculateLargeStraight(dice)
    local sorted_dice = {}
    for _, d in ipairs(dice) do table.insert(sorted_dice, d) end
    table.sort(sorted_dice)

    for i = 1, #sorted_dice - 1 do
        if sorted_dice[i+1] ~= sorted_dice[i] + 1 then
            return 0
        end
    end
    return 40
end

-- 快艇 (5个相同的骰子)
function Scoring.calculateYahtzee(dice)
    local counts = count_dice(dice)
    for _, count in pairs(counts) do
        if count == 5 then
            return 50
        end
    end
    return 0
end

-- 计算骰子点数总和
function Scoring.sum_dice(dice)
    local sum = 0
    for _, value in ipairs(dice) do
        sum = sum + value
    end
    return sum
end

return Scoring