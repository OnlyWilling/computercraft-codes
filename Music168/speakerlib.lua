-- SPDX-FileCopyrightText: 2021 The CC: Tweaked Developers
--
-- SPDX-License-Identifier: MPL-2.0

-- 全局控制变量
_G.getPlaymax = 0    -- 总时间（秒）
_G.getPlay = 0       -- 当前播放时间（秒）
_G.setPlay = 0       -- 设置播放进度（秒）
_G.Playopen = true   -- 播放开关（false停止）
_G.Playstop = false  -- 暂停控制（true暂停，false恢复）
_G.Playprint = false  -- 信息输出开关（true开，false关）
_G.setVolume = 1     -- 音量控制（0-3）

local API_URL = "http://newgmapi.liulikeji.cn/api/ffmpeg"
local mypath = "/"..fs.getDir(shell.getRunningProgram())

-- 扬声器配置
local speakerlist = {
    main = {},
    left = {},
    right = {}
}

local function printlog(...)
    if _G.Playprint then
        print(...)
    end
end

local function loadSpeakerConfig()
    local speaker_groups = fs.open(mypath.."/speaker_groups.cfg","r")
    if speaker_groups then
        local content = speaker_groups.readAll()
        speaker_groups.close()
        if content then
            local success, tableData = pcall(textutils.unserialise, content)
            if success and type(tableData) == "table" then
                speakerlist = { main = {}, left = {}, right = {} }
                for group_name, speakers in pairs(tableData) do
                    if speakerlist[group_name] then
                        for _, speaker_name in ipairs(speakers) do
                            local speaker = peripheral.wrap(speaker_name)
                            if speaker and peripheral.hasType(speaker_name, "speaker") then
                                table.insert(speakerlist[group_name], speaker)
                            end
                        end
                    end
                end
                return
            end
        end
    end
    
    -- 默认配置：所有扬声器都在main组
    speakerlist = { 
        main = { peripheral.find("speaker") },
        left = {}, 
        right = {}
    }
end

local function Get_dfpwm_url(INPUT_URL, args)
    local requestData = {
        input_url = INPUT_URL,
        args = args,
        output_format = "dfpwm"
    }

    local response, err = http.post(
        API_URL,
        textutils.serializeJSON(requestData),
        { ["Content-Type"] = "application/json" }
    )

    if not response then 
        error("HTTP Request Failure: "..(err or "Unknown error")) 
    end
    
    local responseData = textutils.unserializeJSON(response.readAll())
    response.close()

    if responseData.status ~= "success" then 
        error("Conversion failed: "..(responseData.error or "Unknown error")) 
    end
    
    return responseData.download_url
end

local function get_total_duration(url)
    if _G.Playprint then printlog("Calculating duration...") end
    local handle, err = http.get(url)
    if not handle then
        error("Could not get duration: " .. (err or "Unknown error"))
    end
    
    local data = handle.readAll()
    handle.close()
    
    -- DFPWM: 每字节8个样本，48000采样率
    local total_length = (#data * 8) / 48000
    return total_length, #data
end

local function play_audio_chunk(speakers, buffer)
    if #speakers > 0 and buffer and #buffer > 0 then
        for _, speaker in pairs(speakers) do
            local success = false
            while not success and _G.Playopen do
                success = speaker.playAudio(buffer, _G.setVolume)
                if not success then
                    os.pullEvent("speaker_audio_empty")
                end
            end
        end
    end
end

local cmd = ...

if cmd == "stop" then
    local all_speakers = {}
    for _, group in pairs(speakerlist) do
        for _, speaker in pairs(group) do
            table.insert(all_speakers, speaker)
        end
    end
    
    for _, speaker in pairs(all_speakers) do
        speaker.stop()
    end
elseif cmd == "play" then
    local _, file = ...
    if not file then
        error("Usage: speaker play <url>", 0)
    end

    if not http or not file:match("^https?://") then
        error("Only HTTP/HTTPS URLs are supported", 0)
    end

    -- 加载扬声器配置
    loadSpeakerConfig()

    -- 检查是否有扬声器
    local has_speakers = false
    for _, group in pairs(speakerlist) do
        if #group > 0 then
            has_speakers = true
            break
        end
    end
    
    if not has_speakers then
        error("No speakers attached", 0)
    end

    -- 获取DFPWM转换URL
    local main_dfpwm_url, left_dfpwm_url, right_dfpwm_url
    local main_httpfile, left_httpfile, right_httpfile
    
    if _G.Playprint then printlog("Converting audio...") end
    
    if #speakerlist.main > 0 then
        main_dfpwm_url = Get_dfpwm_url(file, { "-vn", "-ar", "48000", "-ac", "1" })
    end

    if #speakerlist.left > 0 then
        left_dfpwm_url = Get_dfpwm_url(file, { "-vn", "-ar", "48000", "-filter_complex", "pan=mono|c0=FL" })
    end

    if #speakerlist.right > 0 then
        right_dfpwm_url = Get_dfpwm_url(file, { "-vn", "-ar", "48000", "-filter_complex", "pan=mono|c0=FR" })
    end

    -- 计算总时长（使用任意一个通道）
    local total_length, total_size
    if main_dfpwm_url then
        total_length, total_size = get_total_duration(main_dfpwm_url)
    elseif left_dfpwm_url then
        total_length, total_size = get_total_duration(left_dfpwm_url)
    elseif right_dfpwm_url then
        total_length, total_size = get_total_duration(right_dfpwm_url)
    else
        error("No audio channels available", 0)
    end

    -- 设置总时间
    _G.getPlaymax = total_length
    _G.getPlay = 0

    if _G.Playprint then
        printlog("Playing " .. file .. " (" .. math.ceil(total_length) .. "s)")
    end

    -- 创建HTTP连接
    if main_dfpwm_url then
        main_httpfile = http.get(main_dfpwm_url)
        if not main_httpfile then
            error("Could not open main audio stream")
        end
    end

    if left_dfpwm_url then
        left_httpfile = http.get(left_dfpwm_url)
        if not left_httpfile then
            error("Could not open left audio stream")
        end
    end

    if right_dfpwm_url then
        right_httpfile = http.get(right_dfpwm_url)
        if not right_httpfile then
            error("Could not open right audio stream")
        end
    end

    -- 初始化DFPWM解码器
    local decoder = require "cc.audio.dfpwm".make_decoder()
    local left_decoder = require "cc.audio.dfpwm".make_decoder()
    local right_decoder = require "cc.audio.dfpwm".make_decoder()

    -- 每次读取的字节数（DFPWM: 每秒6000字节）
    local chunk_size = 6000
    local bytes_read = 0

    -- 初始化播放位置
    if _G.setPlay > 0 then
        local skip_bytes = math.floor(_G.setPlay * 6000)
        if skip_bytes < total_size then
            -- 跳过指定字节数
            local skipped = 0
            while skipped < skip_bytes and _G.Playopen do
                local to_skip = math.min(8192, skip_bytes - skipped)
                if main_httpfile then main_httpfile.read(to_skip) end
                if left_httpfile then left_httpfile.read(to_skip) end
                if right_httpfile then right_httpfile.read(to_skip) end
                skipped = skipped + to_skip
                bytes_read = bytes_read + to_skip
            end
            _G.getPlay = _G.setPlay
            _G.setPlay = 0
        end
    end

    -- 主播放循环
    while bytes_read < total_size and _G.Playopen do
        -- 检查是否需要设置播放位置
        if _G.setPlay > 0 then
            -- 重新打开所有连接并跳转
            if main_httpfile then main_httpfile.close() end
            if left_httpfile then left_httpfile.close() end
            if right_httpfile then right_httpfile.close() end

            if main_dfpwm_url then
                main_httpfile = http.get(main_dfpwm_url)
                if not main_httpfile then error("Could not reopen main stream") end
            end

            if left_dfpwm_url then
                left_httpfile = http.get(left_dfpwm_url)
                if not left_httpfile then error("Could not reopen left stream") end
            end

            if right_dfpwm_url then
                right_httpfile = http.get(right_dfpwm_url)
                if not right_httpfile then error("Could not reopen right stream") end
            end

            local skip_bytes = math.floor(_G.setPlay * 6000)
            if skip_bytes < total_size then
                local skipped = 0
                while skipped < skip_bytes and _G.Playopen do
                    local to_skip = math.min(8192, skip_bytes - skipped)
                    if main_httpfile then main_httpfile.read(to_skip) end
                    if left_httpfile then left_httpfile.read(to_skip) end
                    if right_httpfile then right_httpfile.read(to_skip) end
                    skipped = skipped + to_skip
                    bytes_read = skip_bytes
                end
                _G.getPlay = _G.setPlay
                _G.setPlay = 0
            end
        end

        -- 检查暂停状态
        while _G.Playstop and _G.Playopen do
            os.sleep(0.1)
        end

        -- 检查停止状态
        if not _G.Playopen then
            break
        end

        -- 读取音频数据
        local main_chunk, left_chunk, right_chunk
        local main_buffer, left_buffer, right_buffer

        if main_httpfile then
            main_chunk = main_httpfile.read(chunk_size)
        end

        if left_httpfile then
            left_chunk = left_httpfile.read(chunk_size)
        end

        if right_httpfile then
            right_chunk = right_httpfile.read(chunk_size)
        end

        -- 检查是否所有通道都没有数据
        if (not main_chunk or #main_chunk == 0) and 
           (not left_chunk or #left_chunk == 0) and 
           (not right_chunk or #right_chunk == 0) then
            break
        end

        -- 解码音频数据
        if main_chunk and #main_chunk > 0 then
            main_buffer = decoder(main_chunk)
        end

        if left_chunk and #left_chunk > 0 then
            left_buffer = left_decoder(left_chunk)
        end

        if right_chunk and #right_chunk > 0 then
            right_buffer = right_decoder(right_chunk)
        end

        -- 并行播放所有通道
        parallel.waitForAll(
            function() 
                if main_buffer and #main_buffer > 0 then
                    play_audio_chunk(speakerlist.main, main_buffer)
                end
            end,
            function() 
                if right_buffer and #right_buffer > 0 then
                    play_audio_chunk(speakerlist.right, right_buffer)
                end
            end,
            function() 
                if left_buffer and #left_buffer > 0 then
                    play_audio_chunk(speakerlist.left, left_buffer)
                end
            end
        )

        -- 更新进度
        local max_chunk_size = math.max(
            main_chunk and #main_chunk or 0,
            left_chunk and #left_chunk or 0,
            right_chunk and #right_chunk or 0
        )
        bytes_read = bytes_read + max_chunk_size
        _G.getPlay = bytes_read / 6000
        
        if _G.Playprint then
            term.setCursorPos(1, term.getCursorPos())
            printlog(("Playing: %ds / %ds"):format(math.floor(_G.getPlay), math.ceil(total_length)))
        end
    end

    -- 关闭HTTP连接
    if main_httpfile then main_httpfile.close() end
    if left_httpfile then left_httpfile.close() end
    if right_httpfile then right_httpfile.close() end

    if _G.Playprint and _G.Playopen then
        printlog("Playback finished.")
    end
    
    -- 重置播放状态
    _G.Playopen = true
    _G.Playstop = false
    _G.getPlay = 0
else
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    printlog("Usage:")
    printlog(programName .. " play <url>")
    printlog(programName .. " stop")
end
