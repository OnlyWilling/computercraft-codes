-- 歌词显示软件
local function loadRemoteFont(url)
    local response = http.get(url)
    if not response then
        error("无法连接到字体服务器")
    end
  
    if response.getResponseCode() ~= 200 then
        error("字体服务器返回错误: " .. response.getResponseCode())
    end
  
    local content = response.readAll()
    response.close()
  
    local sandbox = {}
    local chunk, err = load(content, "=remoteFont", "t", sandbox)
    if not chunk then
        error("加载字体失败: " .. err)
    end
  
    local success, result = pcall(chunk)
    if not success then
        error("执行字体脚本失败: " .. result)
    end
  
    return sandbox.font or sandbox[1] or result
end

-- 显示单个字符的函数
local function displayChar(charMap, x, y, textColor, backgroundColor)
    local origTextColor = term.getTextColor()
    local origBackgroundColor = term.getBackgroundColor()
  
    term.setTextColor(textColor)
    term.setBackgroundColor(backgroundColor)
  
    for row = 1, #charMap do
        term.setCursorPos(x, y + row - 1)
        local line = charMap[row]
      
        for col = 1, #line do
            local byte = string.byte(line, col)
          
            if byte < 128 then
                term.setTextColor(backgroundColor)
                term.setBackgroundColor(textColor)
                term.write(string.char(byte + 128))
            else
                term.setTextColor(textColor)
                term.setBackgroundColor(backgroundColor)
                term.write(string.char(byte))
            end
        end
    end
  
    term.setTextColor(origTextColor)
    term.setBackgroundColor(origBackgroundColor)
end

-- 显示UTF-8字符串的函数
local function displayUtf8String(str, font, x, y, textColor, backgroundColor)
    local function utf8codes(str)
        local i = 1
        return function()
            if i > #str then return end
          
            local b1 = string.byte(str, i)
            i = i + 1
          
            if b1 < 0x80 then
                return b1
            elseif b1 >= 0xC0 and b1 < 0xE0 then
                local b2 = string.byte(str, i) or 0
                i = i + 1
                return (b1 - 0xC0) * 64 + (b2 - 0x80)
            elseif b1 >= 0xE0 and b1 < 0xF0 then
                local b2 = string.byte(str, i) or 0
                i = i + 1
                local b3 = string.byte(str, i) or 0
                i = i + 1
                return (b1 - 0xE0) * 4096 + (b2 - 0x80) * 64 + (b3 - 0x80)
            else
                return 32
            end
        end
    end

    local cursorX = x
  
    for code in utf8codes(str) do
        local charMap = font[code]
        if not charMap then
            charMap = font[32] or {{"\x80"}}
        end
      
        displayChar(charMap, cursorX, y, textColor, backgroundColor)
        cursorX = cursorX + #charMap[1]
    end
end

-- 解析歌词时间
local function parseTime(timeStr)
    local minutes, seconds, milliseconds = timeStr:match("(%d+):(%d+)%.(%d+)")
    if minutes and seconds and milliseconds then
        return tonumber(minutes) * 60 + tonumber(seconds) + tonumber(milliseconds) / 1000
    end
    return 0
end

-- 解析歌词内容
local function parseLyrics(lyricStr)
    local lyrics = {}
    if not lyricStr or lyricStr == "" then return lyrics end
    
    for line in lyricStr:gmatch("[^\r\n]+") do
        if line:match("%[.+%]") then
            local timeStr = line:match("%[(.+)%]")
            local text = line:match("%].*$")
            if text then text = text:sub(2) else text = "" end
            
            -- 过滤掉作词、作曲等元信息
            if timeStr and not timeStr:match("by:") and not timeStr:match("offset:") and not text:match("作词") and not text:match("作曲") then
                local time = parseTime(timeStr)
                table.insert(lyrics, {time = time, text = text})
            end
        end
    end
    
    -- 按时间排序
    table.sort(lyrics, function(a, b) return a.time < b.time end)
    return lyrics
end

-- 计算字符串宽度
local function getStringWidth(str, font)
    local width = 0
    local function utf8codes(s)
        local i = 1
        return function()
            if i > #s then return end
            local b1 = string.byte(s, i)
            i = i + 1
            if b1 < 0x80 then
                return b1
            elseif b1 >= 0xC0 and b1 < 0xE0 then
                local b2 = string.byte(s, i) or 0
                i = i + 1
                return (b1 - 0xC0) * 64 + (b2 - 0x80)
            elseif b1 >= 0xE0 and b1 < 0xF0 then
                local b2 = string.byte(s, i) or 0
                i = i + 1
                local b3 = string.byte(s, i) or 0
                i = i + 1
                return (b1 - 0xE0) * 4096 + (b2 - 0x80) * 64 + (b3 - 0x80)
            else
                return 32
            end
        end
    end
    
    for code in utf8codes(str) do
        local charMap = font[code] or font[32]
        width = width + #charMap[1]
    end
    return width
end

-- 获取当前应该显示的歌词索引
local function getCurrentLyricIndex(lyricPairs, currentTime)
    local currentIndex = 1
    for i = 1, #lyricPairs do
        if lyricPairs[i].time <= currentTime then
            currentIndex = i
        else
            break
        end
    end
    return currentIndex
end

-- 解析颜色参数
local function parseColor(colorStr)
    local colorsMap = {
        white = colors.white,
        orange = colors.orange,
        magenta = colors.magenta,
        lightBlue = colors.lightBlue,
        yellow = colors.yellow,
        lime = colors.lime,
        pink = colors.pink,
        gray = colors.gray,
        lightGray = colors.lightGray,
        cyan = colors.cyan,
        purple = colors.purple,
        blue = colors.blue,
        brown = colors.brown,
        green = colors.green,
        red = colors.red,
        black = colors.black
    }
    
    return colorsMap[colorStr] or colors.white
end

-- 主显示函数
local function displayLyrics(url, notzh, fontType, colorsConfig)
    -- 选择字体
    local fontUrl
    if fontType == "12px" then
        fontUrl = "https://git.liulikeji.cn/xingluo/ComputerCraft-Utf8/raw/branch/main/fonts/fusion-pixel-12px-proportional-zh_hans.lua"
    else
        fontUrl = "https://git.liulikeji.cn/xingluo/ComputerCraft-Utf8/raw/branch/main/fonts/fusion-pixel-8px-proportional-zh_hans.lua"
    end
    
    local font = loadRemoteFont(fontUrl)
    
    -- 获取歌词数据
    local response = http.get(url)
    if not response then
        print("1 无法连接到服务器 URL: "..url)
        return
    end
    
    if response.getResponseCode() ~= 200 then
        print("服务器返回错误: " .. response.getResponseCode())
        response.close()
        return
    end
    
    local content = response.readAll()
    response.close()
    
    -- 解析JSON数据
    local data = textutils.unserialiseJSON(content)
    if not data or not data.lrc or not data.lrc.lyric then
        print("2 无法解析歌词数据 URL: "..url)
        return
    end
    
    -- 解析歌词
    local lyrics = parseLyrics(data.lrc.lyric)
    local tlyrics = {}
    if not notzh and data.tlyric and data.tlyric.lyric then
        tlyrics = parseLyrics(data.tlyric.lyric)
    end
    
    if #lyrics == 0 and #tlyrics == 0 then
        print("3 没有找到有效歌词 URL: "..url)
        print(textutils.serialiseJSON(data))
        return
    end

    -- 构建时间索引映射
    local timeIndexMap = {}
    for i, lyric in ipairs(lyrics) do
        local timeKey = string.format("%.3f", lyric.time)
        timeIndexMap[timeKey] = {original = i}
    end
    
    for i, lyric in ipairs(tlyrics) do
        local timeKey = string.format("%.3f", lyric.time)
        if timeIndexMap[timeKey] then
            timeIndexMap[timeKey].translation = i
        else
            timeIndexMap[timeKey] = {translation = i}
        end
    end
    
    -- 构建歌词对数组
    local lyricPairs = {}
    local allTimes = {}
    for timeKey, _ in pairs(timeIndexMap) do
        table.insert(allTimes, tonumber(timeKey))
    end
    table.sort(allTimes)

    for _, time in ipairs(allTimes) do
        local timeKey = string.format("%.3f", time)
        local indices = timeIndexMap[timeKey]
        
        local originalText = ""
        local translationText = ""
        
        if indices.original then
            originalText = lyrics[indices.original].text or ""
        end
        
        if indices.translation then
            translationText = tlyrics[indices.translation].text or ""
        end
        
        table.insert(lyricPairs, {
            time = time,
            original = originalText,
            translation = translationText
        })
    end
    
    if #lyricPairs == 0 then
        print("没有找到匹配的歌词对 URL: "..url)
        return
    end

    -- 计算显示参数
    local screenWidth, screenHeight = term.getSize()
    local fontHeight = #font[32]  -- 使用空格字符获取字体高度
    
    -- 检查是否有翻译歌词
    local hasTranslation = false
    if not notzh then
        for _, pair in ipairs(lyricPairs) do
            if pair.translation and pair.translation ~= "" then
                hasTranslation = true
                break
            end
        end
    end
    
    -- 根据是否显示翻译来计算行高
    local lyricPairHeight
    if notzh or not hasTranslation then
        lyricPairHeight = fontHeight + 1  -- 只有原文的高度
    else
        lyricPairHeight = fontHeight * 2 + 1  -- 原文+翻译的高度
    end
    
    local maxLyricPairs = math.floor(screenHeight / lyricPairHeight)
    local visibleLyricPairs = math.max(1, maxLyricPairs)  -- 确保至少显示1对
    
    -- 显示循环
    while true do
        -- 获取当前播放时间
        local currentTime = _G.getPlay - 1 or 0  -- 直接获取_G.getPlay的值
        
        -- 获取当前歌词索引
        local currentIndex = getCurrentLyricIndex(lyricPairs, currentTime)
        term.setBackgroundColor(colorsConfig.background)
        -- 清屏
        term.clear()
        
        -- 计算显示范围 - 真正的居中显示策略
        local startPairIndex, endPairIndex

        if visibleLyricPairs < 3 then
            -- 当可显示歌词少于3个时，优先显示当前和下一个歌词
            startPairIndex = currentIndex
            endPairIndex = math.min(#lyricPairs, startPairIndex + visibleLyricPairs - 1)
            
            -- 如果显示空间还有剩余，尝试向前补充显示前面的歌词
            if endPairIndex - startPairIndex + 1 < visibleLyricPairs then
                local remainingSpace = visibleLyricPairs - (endPairIndex - startPairIndex + 1)
                startPairIndex = math.max(1, startPairIndex - remainingSpace)
                endPairIndex = math.min(#lyricPairs, startPairIndex + visibleLyricPairs - 1)
            end
        else
            -- 当可显示歌词3个或更多时，采用真正的居中显示策略
            -- 计算当前歌词上方和下方应该显示的歌词数量
            local aboveCount, belowCount
            if visibleLyricPairs % 2 == 1 then
                -- 奇数个显示位置：上下数量相等
                local halfCount = math.floor(visibleLyricPairs / 2)
                aboveCount = halfCount
                belowCount = halfCount
            else
                -- 偶数个显示位置：上面少一个，下面多一个（如你要求的4个和5个）
                aboveCount = math.floor(visibleLyricPairs / 2) - 1
                belowCount = math.floor(visibleLyricPairs / 2)
            end
            
            -- 计算起始和结束索引
            startPairIndex = math.max(1, currentIndex - aboveCount)
            endPairIndex = math.min(#lyricPairs, currentIndex + belowCount)
            
            -- 边界调整：如果前面不够显示，向后补充
            if currentIndex - startPairIndex < aboveCount then
                local needMore = aboveCount - (currentIndex - startPairIndex)
                endPairIndex = math.min(#lyricPairs, endPairIndex + needMore)
            end
            
            -- 边界调整：如果后面不够显示，向前补充
            if endPairIndex - currentIndex < belowCount then
                local needMore = belowCount - (endPairIndex - currentIndex)
                startPairIndex = math.max(1, startPairIndex - needMore)
            end
            
            -- 最终调整确保显示足够的行数
            if endPairIndex - startPairIndex + 1 < visibleLyricPairs then
                if startPairIndex > 1 then
                    startPairIndex = math.max(1, endPairIndex - visibleLyricPairs + 1)
                else
                    endPairIndex = math.min(#lyricPairs, startPairIndex + visibleLyricPairs - 1)
                end
            end
        end

        
        local startY = 2

        -- 显示歌词对
        for i = startPairIndex, endPairIndex do
            local lyricPair = lyricPairs[i]
            
            -- 计算Y坐标 - 根据是否显示翻译动态计算
            local pairY
            if notzh or not hasTranslation then
                -- 不显示翻译时，每行只占一个字体高度
                pairY = startY + (i - startPairIndex) * (fontHeight + 1)
            else
                -- 显示翻译时，每对歌词占两个字体高度
                pairY = startY + (i - startPairIndex) * (fontHeight * 2 + 1)
            end
            
            -- 设置颜色
            local textColor = colorsConfig.normalMain
            local translationColor = colorsConfig.normalSub
            local bgColor = colorsConfig.background
            
            if i == currentIndex then
                textColor = colorsConfig.selectedMain
                translationColor = colorsConfig.selectedSub
                bgColor = colorsConfig.selectedBackground
            end
            
            -- 显示原文（第一行）
            if lyricPair.original and lyricPair.original ~= "" then
                local x = math.floor((screenWidth - getStringWidth(lyricPair.original, font)) / 2)
                displayUtf8String(lyricPair.original, font, x, pairY, textColor, bgColor)
            end
            
            -- 显示翻译（第二行）- 只有当notzh为false且有翻译时才显示
            if not notzh and hasTranslation and lyricPair.translation and lyricPair.translation ~= "" then
                local x = math.floor((screenWidth - getStringWidth(lyricPair.translation, font)) / 2)
                displayUtf8String(lyricPair.translation, font, x, pairY + fontHeight, translationColor, bgColor)
            end
        end
        
        sleep(0.5)
    end
    
    term.clear()
    term.setCursorPos(1, 1)
    print("歌词显示已退出")
end


-- 解析命令行参数
local function parseArgs(args)
    local url = nil
    local notzh = false
    local fontType = "8px"  -- 默认8px
    
    -- 默认颜色配置
    local colorsConfig = {
        background = colors.black,           -- 背景颜色
        normalMain = colors.gray,           -- 歌词主颜色
        normalSub = colors.gray,        -- 歌词辅颜色
        selectedMain = colors.white,        -- 歌词选中主颜色
        selectedSub = colors.lightGray,      -- 选中辅颜色
        selectedBackground = colors.black     -- 选中背景色
    }
    
    for i = 1, #args do
        local arg = args[i]
        
        -- 处理颜色参数
        if arg:match("--normabg=") then
            local colorName = arg:sub(6)
            colorsConfig.background = parseColor(colorName)
        elseif arg:match("--normalmain=") then
            local colorName = arg:sub(14)
            colorsConfig.normalMain = parseColor(colorName)
        elseif arg:match("--normalsub=") then
            local colorName = arg:sub(13)
            colorsConfig.normalSub = parseColor(colorName)
        elseif arg:match("--selectedmain=") then
            local colorName = arg:sub(16)
            colorsConfig.selectedMain = parseColor(colorName)
        elseif arg:match("--selectedsub=") then
            local colorName = arg:sub(15)
            colorsConfig.selectedSub = parseColor(colorName)
        elseif arg:match("--selectedbg=") then
            local colorName = arg:sub(14)
            colorsConfig.selectedBackground = parseColor(colorName)
        elseif arg == "--notzh" then
            notzh = true
        elseif arg == "--8px" then
            fontType = "8px"
        elseif arg == "--12px" then
            fontType = "12px"
        elseif not url and arg:sub(1, 4) == "http" then
            url = arg
        end
    end
    
    return url, notzh, fontType, colorsConfig
end

-- 主程序
local function main(...)
    local args = {...}
    local url, notzh, fontType, colorsConfig = parseArgs(args)
    
    -- 如果没有通过参数提供URL，则要求用户输入
    if not url then
        term.clear()
        term.setCursorPos(1, 1)
        write("请输入歌词URL: ")
        url = read()
        
        if not url or url == "" then
            print("URL不能为空")
            return
        end
    end
    
    displayLyrics(url, notzh, fontType, colorsConfig)
end

-- 运行主程序
main(...)

