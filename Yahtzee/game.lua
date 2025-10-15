-- Import scoring.lua
local Scoring = require("scoring")

-- 游戏状态表
local Game = {
    dice = {0, 0, 0, 0, 0}, -- 存储5个骰子的点数
    rolls_left = 3,         -- 每回合剩余投掷次数
    turn = 1,               -- 当前回合数
    scorecard = {},         -- 计分板
    game_over = false
}

-- 初始化计分板
-- 每个计分项包含分数(score)和是否已使用(used)
function Game:initScorecard()
    self.scorecard = {
        -- 上半部分
        ones   = { score = 0, used = false, name = "ones" },
        twos   = { score = 0, used = false, name = "twos" },
        threes = { score = 0, used = false, name = "threes" },
        fours  = { score = 0, used = false, name = "fours" },
        fives  = { score = 0, used = false, name = "fives" },
        sixes  = { score = 0, used = false, name = "sixes" },
        -- 下半部分
        three_of_a_kind = { score = 0, used = false, name = "three_of_a_kind" },
        four_of_a_kind  = { score = 0, used = false, name = "four_of_a_kind" },
        full_house      = { score = 0, used = false, name = "full_house" },
        small_straight  = { score = 0, used = false, name = "small_straight" },
        large_straight  = { score = 0, used = false, name = "large_straight" },
        yahtzee         = { score = 0, used = false, name = "yahtzee" },
        chance          = { score = 0, used = false, name = "chance" }
    }
end

-- 投掷骰子
-- hold_indices: 一个包含要保留的骰子索引的表 (例如 {1, 3, 5})
function Game:rollDice(hold_indices)
    if self.rolls_left > 0 then
        print("--- Roll Dices ---")
        local holds = {}
        for _, index in ipairs(hold_indices or {}) do
            holds[index] = true
        end

        for i = 1, 5 do
            if not holds[i] then
                self.dice[i] = math.random(1, 6)
            end
        end
        self.rolls_left = self.rolls_left - 1
    else
        print("Rolls in this turn has consumed up!")
    end
end

-- 显示当前骰子
function Game:printDice()
    local dice_str = "Current dices: "
    for i = 1, 5 do
        dice_str = dice_str .. "[" .. self.dice[i] .. "] "
    end
    print(dice_str)
    print("Indeices:       1   2   3   4   5")
end

-- 将得分应用到计分板
function Game:applyScore(category)
    if self.scorecard[category] and not self.scorecard[category].used then
        local score = 0
        if category == "ones"   then score = Scoring.calculateUpper(self.dice, 1)
        elseif category == "twos"   then score = Scoring.calculateUpper(self.dice, 2)
        elseif category == "threes" then score = Scoring.calculateUpper(self.dice, 3)
        elseif category == "fours"  then score = Scoring.calculateUpper(self.dice, 4)
        elseif category == "fives"  then score = Scoring.calculateUpper(self.dice, 5)
        elseif category == "sixes"  then score = Scoring.calculateUpper(self.dice, 6)
        elseif category == "three_of_a_kind" then score = Scoring.calculateNOfAKind(self.dice, 3)
        elseif category == "four_of_a_kind"  then score = Scoring.calculateNOfAKind(self.dice, 4)
        elseif category == "full_house"      then score = Scoring.calculateFullHouse(self.dice)
        elseif category == "small_straight"  then score = Scoring.calculateSmallStraight(self.dice)
        elseif category == "large_straight"  then score = Scoring.calculateLargeStraight(self.dice)
        elseif category == "yahtzee"         then score = Scoring.calculateYahtzee(self.dice)
        elseif category == "chance"          then score = Scoring.sum_dice(self.dice)
        end

        self.scorecard[category].score = score
        self.scorecard[category].used = true
        print(string.format("At '%s' score: %d", self.scorecard[category].name, score))
        return true
    else
        print("Invalid or used item!")
        return false
    end
end

-- 显示计分板
function Game:printScorecard()
    print("\n========== Scorecard ==========")
    local upper_total = 0
    local lower_total = 0

    local upper_keys = {"ones", "twos", "threes", "fours", "fives", "sixes"}
    local lower_keys = {"three_of_a_kind", "four_of_a_kind", "full_house", "small_straight", "large_straight", "yahtzee", "chance"}

    print("--- Upper total ---")
    for _, key in ipairs(upper_keys) do
        local item = self.scorecard[key]
        if item.used then
            print(string.format("%-18s: %d", key, item.score))
            upper_total = upper_total + item.score
        else
            print(string.format("%-18s: (empty)", key))
        end
    end
    print(string.format("Upper total: %d", upper_total))

    local bonus = (upper_total >= 63) and 35 or 0
    if bonus > 0 then
        print(string.format("Bonus: %d", bonus))
    end

    print("\n--- Lower total ---")
    for _, key in ipairs(lower_keys) do
        local item = self.scorecard[key]
        if item.used then
            print(string.format("%-18s: %d", key, item.score))
            lower_total = lower_total + item.score
        else
            print(string.format("%-18s: (empty)", key))
        end
    end

    local final_score = upper_total + bonus + lower_total
    print("\n--- Total ---")
    print(string.format("Total: %d", final_score))
    print("============================\n")
end

-- 开始一个新回合
function Game:startTurn()
    print(string.format("\n####### Turn %d #######", self.turn))
    self.rolls_left = 3
    self.dice = {0,0,0,0,0}

    -- 第一次投掷
    self:rollDice({})
    self:printDice()

    -- 第二、三次投掷
    for i = 1, 2 do
        if self.rolls_left > 0 then
            print(string.format("Left %d reroll times. Enter indeices to maintain OR just enter to reroll all dices:", self.rolls_left))
            local input = io.read()
            if input == "score" then break end -- 提前计分
            
            local holds = {}
            for digit in input:gmatch("%d") do
                table.insert(holds, tonumber(digit))
            end
            
            self:rollDice(holds)
            self:printDice()
        end
    end

    -- 选择计分项目
    print("\nRoll finished!! Choose one item to fill:")
    self:printScorecard()
    
    while true do
        local category = io.read()
        if self:applyScore(category) then
            break
        else
            print("Please enter another item:")
        end
    end

    self.turn = self.turn + 1
    if self.turn > 13 then
        self.game_over = true
    end
end

return Game