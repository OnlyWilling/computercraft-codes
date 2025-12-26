--- 计算一张牌的牛头数
--- @param index number 牌的编号
--- @return number res 牌的牛头数
local function getBullHeadCount(index)
    if index == 55 then return 7 end     -- 55号牌：7个牛头
    if index % 11 == 0 then return 5 end -- 11, 22...: 5个牛头
    if index % 10 == 0 then return 3 end -- 10, 20...: 3个牛头
    if index % 5 == 0 then return 2 end  -- 5, 15...: 2个牛头
    return 1                             -- 其他：1个牛头
end

local gameState = {
    phase = "LOBBY",           -- LOBBY, SELECTION, SHOWDOWN, ROUND_END
    rows = { {}, {}, {}, {} }, -- 桌上的4行牌
    players = {
        -- [id] = { name="X", hand={...}, score=0, selected_card=nil }
    },
    turn_cards = {} -- 本轮大家出的牌，用于排序结算
}

