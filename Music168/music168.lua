-----------------------------------------------------------------系统启动阶段-------------------------------------------------------------------------------------------------
--*获取程序所在目录

local mypath = "/"..fs.getDir(shell.getRunningProgram())
if not fs.exists(mypath.."/lib/basalt.lua") then shell.run("wget https://git.liulikeji.cn/GitHub/Basalt/releases/download/v1.6.6/basalt.lua "..mypath.."/lib/basalt.lua") end
if not fs.exists(mypath.."/speakerlib.lua") then shell.run("wget https://git.liulikeji.cn/xingluo/ComputerCraft-Music168-Player/raw/branch/main/speakerlib.lua "..mypath.."/speakerlib.lua") end
if not fs.exists(mypath.."/MusicLyrics.lua") then shell.run("wget https://git.liulikeji.cn/xingluo/ComputerCraft-Music168-Player/raw/branch/main/MusicLyrics.lua "..mypath.."/MusicLyrics.lua") end

--*GUI库导入
basalt = require(mypath.."/lib/basalt")
--*初始化GUI框架
local mainf = basalt.createFrame()
main  = {
    mainf:addFrame():setPosition(1, 1):setSize("parent.w", "parent.h"):setBackground(colors.red),
}
_G.Playprint = false
_G.Playopen =false
--*GUI框架配置表
local sub = {
    ["UI"] = {
        main[1]:addFrame():setPosition(1, 1):setSize("parent.w", "parent.h -2"):setBackground(colors.red),
        main[1]:addFrame():setPosition(1, 1):setSize("parent.w", "parent.h -2"):setBackground(colors.white):hide(),
        main[1]:addFrame():setPosition(1, 1):setSize("parent.w", "parent.h -2"):setBackground(colors.white):hide(),
        main[1]:addFrame():setPosition(1, 1):setSize("parent.w", "parent.h -2"):setBackground(colors.red):hide(),
        main[1]:addFrame():setPosition(1, 1):setSize("parent.w", "parent.h -2"):setBackground(colors.white):hide(),
    },
    ["menu"] ={
        main[1]:addFrame():setPosition(1, "parent.h"):setSize("parent.w", 1):setBackground(colors.lightGray),
    },
    ["BF"] = {
        mainf:addFrame():setPosition(1, "parent.h + 1"):setSize("parent.w", "parent.h"):setBackground(colors.red),
        main[1]:addFrame():setPosition(1, "parent.h - 1"):setSize("parent.w", 1):setBackground(colors.lightGray):hide(),
    },
    ["play_table"] = {
        mainf:addFrame():setPosition(2, "parent.h + 1"):setSize("parent.w-2", 13):setBackground(colors.orange),
    }
}
--创建动画
play_Gui_UP = mainf:addAnimation():setObject(sub["BF"][1]):move(1,1,0.3)
play_Gui_DO = mainf:addAnimation():setObject(sub["BF"][1]):move(1,mainf:getHeight()+1,1)
play_table_Gui_UP = mainf:addAnimation():setObject(sub["play_table"][1]):move(2,mainf:getHeight()-12,0.3)
play_table_Gui_DO = mainf:addAnimation():setObject(sub["play_table"][1]):move(2,mainf:getHeight()+1,1)
--play_Gui_UP:play()
--main[1]:hide()
--main[1]:addAnimation():setObject(sub["BF"][1]):move(1,"parent.h+1",1.5):play()
--创建播放界面
play_name = "NO Music"
play_id = "NO Music"
play_Gui = {
    sub["BF"][1]:addButton():setPosition(1,1):setSize(3, 1):setText("V"):onClick(function() play_Gui_DO:play() play_GUI_state=false main[1]:enable() end):setBackground(colors.red):setForeground(colors.white),
    sub["BF"][1]:addLabel():setText("NO Music"):setPosition(sub["BF"][1]:getWidth()/2 - #play_name/2,1):setBackground(colors.red):setForeground(colors.white),
    sub["BF"][1]:addLabel():setText("NO Music"):setPosition(sub["BF"][1]:getWidth()/2 - #play_id/2,2):setBackground(colors.red):setForeground(colors.white),
    sub["BF"][1]:addProgram():setPosition(2,2):setSize("parent.w-2", "parent.h-4"),
    1,--sub["BF"][1]:addButton():setPosition(3,"parent.h-5"):setSize(1, 1):setText("\3"):onClick(function() end):setForeground(colors.white):setBackground(colors.red),
    1,--sub["BF"][1]:addButton():setPosition(8,"parent.h-5"):setSize(1, 1):setText("\25"):onClick(function() end):setForeground(colors.white):setBackground(colors.red),
    1,--sub["BF"][1]:addButton():setPosition("parent.w/2","parent.h-5"):setSize(2, 1):setText("+-"):onClick(function() end):setForeground(colors.white):setBackground(colors.red),
    1,--sub["BF"][1]:addButton():setPosition("parent.w-3","parent.h-5"):setSize(1, 1):setText("@"):onClick(function() end):setForeground(colors.white):setBackground(colors.red),
    1,--sub["BF"][1]:addButton():setPosition("parent.w-8","parent.h-5"):setSize(1, 1):setText("E"):onClick(function() end):setForeground(colors.white):setBackground(colors.red),
    sub["BF"][1]:addProgressbar():setPosition(3, "parent.h - 2"):setSize("parent.w - 4", 1):setProgressBar(colors.red, "=", colors.white):setBackground(colors.red):setBackgroundSymbol("-"):setForeground(colors.white),
    sub["BF"][1]:addLabel():setText("00:00"):setPosition("3", "parent.h - 1"):setSize(5, 1):setForeground(colors.white),
    sub["BF"][1]:addLabel():setText("00:00"):setPosition("parent.w - 6", "parent.h - 1"):setSize(5, 1):setForeground(colors.white),
    sub["BF"][1]:addButton():setPosition(3, "parent.h - 0"):setSize(3, 1):setText("=O="):onClick(function()  end):setForeground(colors.white):setBackground(colors.red),
    sub["BF"][1]:addButton():setPosition("parent.w /2 - 4","parent.h - 0"):setSize(2, 1):setText("|\17"):onClick(function() play_set_1() end):setForeground(colors.white):setBackground(colors.red),
    sub["BF"][1]:addButton():setPosition("parent.w / 2 ", "parent.h - 0"):setSize(2, 1):setText("I>"):onClick(function()  if play_data_table["play"] then _G.Playstop = true play_data_table["play"]=false else play_data_table["play"]=true end end):setForeground(colors.white):setBackground(colors.red),
    sub["BF"][1]:addButton():setPosition("parent.w / 2 +4", "parent.h - 0"):setSize(2, 1):setText("\16|"):onClick(function() play_set_0() end):setForeground(colors.white):setBackground(colors.red),
    sub["BF"][1]:addButton():setPosition("parent.w - 4", "parent.h - 0"):setSize(3, 1):setText("=T="):onClick(function() play_table_Gui_UP:play() main[1]:disable() sub["BF"][1]:disable() end):setForeground(colors.white):setBackground(colors.red),
    sub["BF"][1]:addSlider():setPosition(3, "parent.h - 2"):setSize("parent.w - 4", 1):setMaxValue(100):setBackground(colors.red):setForeground(colors.white),--:setBackgroundSymbol("\x8c"):setSymbol(" "),
}
--创建播放UI
play_column_Gui = {
    sub["BF"][2]:addLabel():setText(""):setPosition(1,1):setSize("parent.w-7",1):setBackground(colors.lightGray):setForeground(colors.white),
    sub["BF"][2]:addButton():setPosition("parent.w -4 ", 1):setSize(2, 1):setText("I>"):onClick(function()  if play_data_table["play"] then _G.Playstop = true play_data_table["play"]=false else play_data_table["play"]=true end end):setForeground(colors.white):setBackground(colors.lightGray),
    sub["BF"][2]:addButton():setPosition("parent.w-1", 1):setSize(1, 1):setText("T"):onClick(function() play_table_Gui_UP:play() main[1]:disable() end):setForeground(colors.white):setBackground(colors.lightGray),
    sub["BF"][2]:addButton():setPosition(1, 1):setSize("parent.w -5", 1):setText(""):onClick(function() play_Gui_UP:play() play_GUI_state=true main[1]:disable() end):setBackground(colors.lights),
}
play_table_Gui = {
    sub["play_table"][1]:addButton():setPosition("parent.w-3",1):setSize(3, 1):setText("V"):onClick(function() if not play_GUI_state then main[1]:enable() end sub["BF"][1]:enable() play_table_Gui_DO:play() end):setBackground(colors.no):setForeground(colors.white),
    sub["play_table"][1]:addLabel():setText("PlyaTable"):setPosition(1,1):setForeground(colors.white),
    sub["play_table"][1]:addList():setPosition(2,3):setSize("parent.w-2", "parent.h-2"):setScrollable(true),
}
--创建菜单栏
menuBut = {
    sub["menu"][1]:addButton():setPosition(3,1):setSize(3, 1):setText("{Q}"):onClick(function() for index, value in ipairs(menuBut) do value:setBackground(colors.lightGray) end menuBut[1]:setBackground(colors.red) for index, value in ipairs(sub["UI"]) do value:hide() end sub["UI"][1]:show() end):setForeground(colors.white):setBackground(colors.red),
    sub["menu"][1]:addButton():setPosition(8,1):setSize(3, 1):setText("{T}"):onClick(function() for index, value in ipairs(menuBut) do value:setBackground(colors.lightGray) end menuBut[2]:setBackground(colors.red) for index, value in ipairs(sub["UI"]) do value:hide() end sub["UI"][2]:show() end):setForeground(colors.white):setBackground(colors.lightGray),
    sub["menu"][1]:addButton():setPosition(12,1):setSize(4, 1):setText("{PH}"):onClick(function() for index, value in ipairs(menuBut) do value:setBackground(colors.lightGray) end menuBut[3]:setBackground(colors.red) for index, value in ipairs(sub["UI"]) do value:hide() end sub["UI"][3]:show() end):setForeground(colors.white):setBackground(colors.lightGray),
    sub["menu"][1]:addButton():setPosition(17,1):setSize(3, 1):setText("{G}"):onClick(function() for index, value in ipairs(menuBut) do value:setBackground(colors.lightGray) end menuBut[4]:setBackground(colors.red) for index, value in ipairs(sub["UI"]) do value:hide() end sub["UI"][4]:show() end):setForeground(colors.white):setBackground(colors.lightGray),
    sub["menu"][1]:addButton():setPosition(22,1):setSize(3, 1):setText("{Z}"):onClick(function() for index, value in ipairs(menuBut) do value:setBackground(colors.lightGray) end menuBut[5]:setBackground(colors.red) for index, value in ipairs(sub["UI"]) do value:hide() end sub["UI"][5]:show() end):setForeground(colors.white):setBackground(colors.lightGray),
}
-----------------------------------------------------------------DATA---------------------------------------------------------------------------------------------------------
play_data_table = { ["music"] = {} ,  ["play"] = false  ,["play_table"] = {}, ["play_table_index"] = 0, ["mode"] = "" , }
_G.Playopen = false
_G.getPlay = 0
_G.getPlaymax = 0
_G.setPlay = nil
-----------------------------------------------------------------模块---------------------------------------------------------------------------------------------------------

--音乐+
function play_set_1()
    _G.music168_playopen = false os.queueEvent("music168_play_stop") 
    _G.getPlay = 0
    _G.Playopen = false
    _G.Playstop = false
    table_index = play_table_Gui[3]:getItemIndex() 
    if table_index <= 1 then 
        play_table_Gui[3]:selectItem(play_table_Gui[3]:getItemCount()) 
    else 
        play_table_Gui[3]:selectItem(table_index-1) 
    end
end
--音乐-
function play_set_0()
    _G.music168_playopen = false os.queueEvent("music168_play_stop")
    _G.getPlay = 0
    _G.Playopen = false
    _G.Playstop = false
    table_index = play_table_Gui[3]:getItemIndex() 
    if table_index >= play_table_Gui[3]:getItemCount() then 
        play_table_Gui[3]:selectItem(1) 
    else 
        play_table_Gui[3]:selectItem(table_index+1) 
    end
end
--获取URL
function GetmusicUrl(music_id)
    while true do
        local http = http.post(server_url.."api/song/url",textutils.serialiseJSON({["id"]=music_id}))
        if http then
            json_str = http.readAll()
            local table = textutils.unserialiseJSON(json_str)
            if table["data"][1]["url"]  then
                return(table["data"][1]["url"])
            end
        end
    end
end
--dfpwm转码
--播放
function playmusic(music_name,music_id,play_table,index)
    _G.getPlay = 0
    _G.getPlaymax = 0
    _G.Playopen = false
    _G.music168_playopen = false os.queueEvent("music168_play_stop")

    play_Gui[2]:setText(music_name):setPosition(sub["BF"][1]:getWidth()/2 +1 - #music_name/2,1)
    play_Gui[3]:setText(music_id):setPosition(sub["BF"][1]:getWidth()/2 +1 - #tostring(music_id)/2,2)
    play_column_Gui[1]:setText(music_name.." | "..tostring(music_id))
    play_data_table["music"] = { ["music_id"] = music_id, ["music_name"] = music_name }
    play_data_table["play_table"] = play_table
    play_data_table["play_table_index"] = index
    play_data_table["play"] = true
    play_table_Gui[3]:clear()
    for index, value in ipairs(play_table) do
        play_table_Gui[3]:addItem(value["name"].." | "..tostring(value["id"]))
    end
    

    play_table_Gui[3]:selectItem(index)
    _G.music168_music_id = music_id

    _G.music168_playopen = true
    --basalt.debug("true")
    --play_thread_id = AddThread(function () 
        --
    --end)
end

printUtf8 = load(http.get("https://git.liulikeji.cn/xingluo/ComputerCraft-Utf8/raw/branch/main/utf8ptrint.lua").readAll())()
--搜索
server_url = "http://music168.liulikeji.cn:15843/"
function Search(input_str,GUI_in,api)
    Search_table = {}
    while true do
        kg_a=false
        if api=="search" then
            http1 = http.post(server_url.."api/search",textutils.serialiseJSON({["value"]=input_str}))
            json_str = http1.readAll()
            table_get = textutils.unserialiseJSON(json_str)
            if table_get["result"]["songCount"] ~= 0 then kg_a=true end
        elseif api=="playlist" then
            http1 = http.post(server_url.."api/playlist/detail",textutils.serialiseJSON({["id"]=input_str}))
            json_str = http1.readAll()
            table_get = textutils.unserialiseJSON(json_str)
            if table_get["code"] ~= 404 then kg_a=true end
        end
        if http1 then
            if kg_a then
                if api=="search" then
                    for index, value in ipairs(table_get["result"]["songs"]) do
                        out_table = {["id"] = value["id"],["name"]=value["name"],["artists_id"]=value["artists"][1]["id"],["artists_name"]=value["artists"][1]["name"]}
                        Search_table[index]=out_table
                    end
                elseif api=="playlist" then
                    for index, value in ipairs(table_get["playlist"]["tracks"]) do
                        out_table = {["id"] = value["id"],["name"]=value["name"],["artists_id"]=value["ar"][1]["id"],["artists_name"]=value["ar"][1]["name"]}
                        Search_table[index]=out_table
                    end
                end
                a=2
                if play_lib_F then play_lib_F:remove() end
                play_lib_F = GUI_in[3]:addFrame():setPosition(1, 1):setSize("parent.w", "parent.h"):setBackground(colors.white):setScrollable()
                for index, value in ipairs(Search_table) do
                    id = value["id"]
                    local frame = play_lib_F:addFrame():setPosition(2, a):setSize("parent.w-2", 4):setBackground(colors.lightBlue):onClick(function() if play_data_table["play"] then shell.run(mypath.."/speakerlib.lua stop") if _G.Playopen then   end _G.music168_playopen = false os.queueEvent("music168_play_stop") play_data_table["play"]=false end play_Gui_UP:play() play_GUI_state = true main[1]:disable() _G.music168_playopen = false os.queueEvent("music168_play_stop")  playmusic(value["name"],value["id"],Search_table,index) end)
                    local textf = frame:addFrame():setPosition(1, 1):setSize("parent.w", 3)
                    textf:addProgram():setPosition(1, 1):setSize("parent.w + 200", 4):execute(function ()
                        term.setBackgroundColor(colors.lightGray)
                        term.clear()
                        printUtf8(value["name"],colors.white,colors.lightGray)
                    end):injectEvent("char", false, "w"):disable()
                    --frame:addLabel():setText(value["name"]):setPosition(1, 1)
                    frame:addLabel():setText("name:"..value["name"].."  id:"..value["id"].."  artists:"..value["artists_name"]):setPosition(1, 4)
                    --frame:addLabel():setText("artists: "..value["artists_name"]):setPosition(1, 3)
                    a=a+5
                end

                break;
            else
                frame = GUI_in[3]:addFrame():setPosition(2, 2):setSize("parent.w-2", 3):setBackground(colors.lightBlue)
                frame:addLabel():setText("[songCount] == 0"):setPosition(1, 1)
                break;
            end
        end
        
    end
end

play_Gui[4]:onError(function(self, event, err)

end)

play_Gui[4]:onDone(function()

end)

-----------------------------------------------------------------渲染界面阶段-------------------------------------------------------------------------------------------------
GUI = {
    {
        sub["UI"][1]:addInput():setPosition(2,1):setSize("parent.w-3", 1):setForeground(colors.gray):setBackground(colors.lightGray),
        sub["UI"][1]:addButton():setPosition("parent.w-1",1):setSize(1, 1):setText("Q"):onClick(function() Search(GUI[1][1]:getValue(),GUI[1],"search") end):setForeground(colors.white):setBackground(colors.lightGray),
        sub["UI"][1]:addFrame():setPosition(1, 3):setSize("parent.w", "parent.h -3"):setBackground(colors.white)
    },
    {
        sub["UI"][4]:addInput():setPosition(2,1):setSize("parent.w-3", 1):setForeground(colors.gray):setBackground(colors.lightGray),
        sub["UI"][4]:addButton():setPosition("parent.w-1",1):setSize(1, 1):setText("Q"):onClick(function() Search(GUI[1][1]:getValue(),GUI[2],"playlist") end):setForeground(colors.white):setBackground(colors.lightGray),
        sub["UI"][4]:addFrame():setPosition(1, 3):setSize("parent.w", "parent.h -3"):setBackground(colors.white)
    },
}

function thread2()
    while true do
        --basalt.debug(_G.music168_playopen = false os.queueEvent("music168_play_stop"))
        local screenWidth, _ = term.getSize()
        
        -- 处理用户拖动进度条设置播放位置
        
        w,h = term.getSize()
        if w >= 100 and h >= 30 then px = "--12px" else px = "--8px" end

        if play_Gui[18]:getIndex() ~=1 then
            local sliderValue = play_Gui[18]:getValue() or 0
            _G.setPlay = _G.getPlaymax * (sliderValue / 100)
            play_Gui[18]:setIndex(1)
        end
        
        sleep(0.1)
        
        -- 更新播放进度条
        if _G.getPlay ~= nil and _G.getPlaymax ~= nil and _G.getPlaymax > 0 then 
            play_Gui[10]:setProgress((_G.getPlay / _G.getPlaymax) * 100)
            
            -- 更新当前播放时间显示
            local current = _G.getPlay or 0
            local total = _G.getPlaymax or 0
            local currentTimeStr = string.format("%02d:%02d", math.floor(current / 60), current % 60)
            local totalTimeStr = string.format("%02d:%02d", math.floor(total / 60), total % 60)
            
            play_Gui[11]:setText(currentTimeStr)     -- 当前播放时间
            play_Gui[12]:setText(totalTimeStr)       -- 总时间
        end
        
        if  play_data_table["play"]== true then
            _G.Playstop = false
            play_Gui[15]:setText("II")
            play_column_Gui[2]:setText("II")
            sub["BF"][2]:show()
        else
            play_Gui[15]:setText("I>")
            play_column_Gui[2]:setText("I>")
            --play_Gui[11]:setText("00:00")
            _G.Playstop = true
        end
        if play_data_table["play_table_index"] ~= 0 then
            if play_data_table["play_table_index"] ~= play_table_Gui[3]:getItemIndex() then
                index = play_table_Gui[3]:getItemIndex()
                if play_data_table["play"] then 
                    
                    shell.run(mypath.."/speakerlib.lua stop")
                    if _G.Playopen then
                         
                    end 
                    play_data_table["play"]=false 
                end 
                _G.music168_playopen = false os.queueEvent("music168_play_stop")
                sleep(0.1)
                playmusic(play_data_table["play_table"][index]["name"],play_data_table["play_table"][index]["id"],play_data_table["play_table"],index)
    
            end
        end
    end
end

function paste()
    while true do
        local event, text = os.pullEvent("paste")
        GUI[1][1]:setValue(text)
        GUI[2][1]:setValue(text)
    end
end

function speakerp()
    function speaker_thread()
        local startTime = os.clock()

        if _G.music168_music_id then
            --basalt.debug(music168_music_id)
            
            
            _G.Playopen = true
            play_Gui[4]:stop()

            play_Gui[4]:execute(function ()
                shell.run(mypath.."/MusicLyrics.lua http://music168.liulikeji.cn:15843/api/song/lyric?id=".._G.music168_music_id.." "..px)
            end)
            play_Gui[4]:injectEvent("char","w")
            sleep(0.1)

            --dfpwmURL = http.post("http://gmapi.liulikeji.cn:15842/dfpwm",textutils.serialiseJSON({ ["url"] = GetmusicUrl(_G.music168_music_id) } ))
            shell.run(mypath.."/speakerlib.lua play "..GetmusicUrl(_G.music168_music_id))
            -- 检查是否播放完成自动跳转下一首
            if _G.music168_playopen then
                play_set_0()
                play_Gui[4]:stop()
            
            end
        end
    end
    
    function while_thread() 
        os.pullEvent("music168_play_stop")
        _G.getPlay = 0
        _G.getPlaymax = 0
        play_Gui[4]:stop()
    end
    
    while true do
        if _G.music168_playopen  then 
            parallel.waitForAny(speaker_thread, while_thread) 
            sleep(0.1)
        end
        sleep(0.01)
    end
end

function gc()
    while true do
        play_Gui[4]:injectEvent(os.pullEvent())
    end
    
end
_G.music168_playopen = false os.queueEvent("music168_play_stop")
-----------------------------------------------------------------启动循环渲染器-----------------------------------------------------------------------------------------------
parallel.waitForAll(basalt.autoUpdate, thread2, paste, speakerp,gc)
-----------------------------------------------------------------以下结束-----------------------------------------------------------------------------------------------------
