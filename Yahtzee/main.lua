-- Yahtzee.lua

-- 初始化随机数生成器
math.randomseed(os.time())

-- 调用外部函数文件 game.lua
local Game = require("Yahtzee.game")

-- 游戏主函数
local function main()
    print("Welcome to Lua Yahtzee!")
    Game:initScorecard()

    while not Game.game_over do
        Game:startTurn()
    end

    print("\n\n!!!!!!!!!! Game Over !!!!!!!!!!")
    Game:printScorecard()
end

-- 启动游戏
main()

