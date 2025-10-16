-- sanjuuni_converter.lua
-- 使用Sanjuuni API的图像转换工具
-- Usage: sanjuuni_converter --url <input_url> --format <output_format> --out <output_file> [options]

local API_URL = "http://newgmapi.liulikeji.cn/api/sanjuuni"

-- 显示帮助信息
local function showHelp()
    print("Sanjuuni Image Converter - Usage:")
    print("sanjuuni_converter --url <input_url> --format <output_format> --out <output_file> [options]")
    print()
    print("Required arguments:")
    print("  --url <url>      Input image URL")
    print("  --format <fmt>   Output format (bimg, gif, etc.)")
    print("  --out <file>     Output file path")
    print()
    print("Options:")
    print("  --args <params>  Conversion parameters (default: \"-8\")")
    print("  --monitor <side> Use specified monitor for size reference")
    print("  --scale <num>    Set display scale before getting monitor size")
    print("  --help           Show this help message")
    print()
    print("Example:")
    print("sanjuuni_converter --url https://example.com/image.jpg --format bimg --out output.bimg")
    print("sanjuuni_converter --url https://example.com/image.jpg --format gif --out anim.gif --monitor top --scale 0.5")
end

-- 获取图像下载URL
local function getImageUrl(inputUrl, args, outputFormat)
    -- 准备请求数据
    local requestData = {
        input_url = inputUrl,
        args = args,
        output_format = outputFormat
    }

    print("Sending request to Sanjuuni API...")
    local response, err = http.post(
        API_URL,
        textutils.serializeJSON(requestData),
        { ["Content-Type"] = "application/json" }
    )

    if not response then 
        error("HTTP request failed: "..(err or "unknown error"))
    end

    -- 解析响应数据
    local responseData = textutils.unserializeJSON(response.readAll())
    response.close()

    if responseData.status ~= "success" then
        error("Conversion failed: "..(responseData.error or "unknown error"))
    end

    print("Conversion successful!")
    return responseData.download_url
end

-- 下载文件到本地
local function downloadFile(url, outputPath)
    print("Downloading converted file...")
    local response = http.get(url)
    if not response then
        error("Failed to download file from: "..url)
    end

    local file = fs.open(outputPath, "wb")
    if not file then
        error("Cannot open output file: "..outputPath)
    end

    file.write(response.readAll())
    file.close()
    response.close()
    
    print("File saved to: "..outputPath)
end

-- 解析命令行参数
local function parseArguments(args)
    local options = {
        args = {}  -- 默认参数
    }
    local required = {"url", "format", "out"}
    local seen = {}

    local i = 1
    while i <= #args do
        local arg = args[i]
        if arg == "--url" then
            i = i + 1
            options.url = args[i]
            seen.url = true
        elseif arg == "--format" then
            i = i + 1
            options.format = args[i]
            seen.format = true
        elseif arg == "--out" then
            i = i + 1
            options.out = args[i]
            seen.out = true
        elseif arg == "--args" then
            i = i + 1
            options.args = {args[i]}  -- 简单参数处理
        elseif arg == "--monitor" then
            i = i + 1
            options.monitor = args[i]
        elseif arg == "--scale" then
            i = i + 1
            options.scale = tonumber(args[i])
        elseif arg == "--help" then
            showHelp()
            return nil
        else
            error("Unknown option: "..arg)
        end
        i = i + 1
    end

    -- 检查必需参数
    for _, req in ipairs(required) do
        if not seen[req] then
            error("Missing required argument: --"..req)
        end
    end

    return options
end

-- 主函数
local function main(...)
    local args = {...}
    
    if #args == 0 then
        showHelp()
        return
    end

    -- 解析参数
    local ok, options = pcall(parseArguments, args)
    if not ok then
        printError(options)  -- options contains error message
        showHelp()
        return
    end

    if not options then return end  -- 用户请求帮助

    -- 获取终端/显示器尺寸
    local width, height
    if options.monitor then
        local monitor = peripheral.wrap(options.monitor)
        if not monitor then
            error("Invalid monitor: "..options.monitor)
        end
        
        if options.scale then
            monitor.setTextScale(options.scale)
        end
        
        width, height = monitor.getSize()
    else
        width, height = term.getSize()
    end

    -- 计算最终尺寸
    width = width * 2
    height = height * 3

    -- 准备转换参数
    local conversionArgs = options.args
    table.insert(conversionArgs, "--width="..width)
    table.insert(conversionArgs, "--height="..height)

    -- 调用API转换图像
    local downloadUrl = getImageUrl(options.url, conversionArgs, options.format)

    -- 下载转换后的文件
    downloadFile(downloadUrl, options.out)

    print("Image conversion completed successfully!")
end

-- 运行程序
main(...)