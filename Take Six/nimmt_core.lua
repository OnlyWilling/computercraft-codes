--- 计算一张牌的牛头数
--- @param cardNum number 牌的编号 (1-104)
--- @return number res 牛头数
local function getBullHeadCount(cardNum)
    if cardNum == 55 then return 7 end
    if cardNum % 11 == 0 then return 5 end
    if cardNum % 10 == 0 then return 3 end
    if cardNum % 5 == 0 then return 2 end
    return 1
end

--- 计算一整行牌的牛头总数
--- @param row table 一行牌的数值列表
--- @return number sum 该行牛头总数
local function getRowBullHeads(row)
    local sum = 0
    for _, card in ipairs(row) do
        sum = sum + getBullHeadCount(card)
    end
    return sum
end

return {
    getBullHeadCount = getBullHeadCount,
    getRowBullHeads  = getRowBullHeads,
}
