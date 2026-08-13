--- HTTP 通信与 Base64 工具（pamon/lib/http）
--- 从 aegis-autocraft 解耦的 HTTP 层，提供同步 GET/PUT 请求和 Base64 编解码。
--- 依赖：CC 内置 `http` API。
---
--- 用法示例：
---   local h = require "pamon.lib.http"
---   local data = h.httpGetSync("https://api.example.com/data", {})
---   local enc  = h.b64enc("hello")

-- ============================================================
--  Base64 编解码
-- ============================================================

local _B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

--- Base64 编码。
--- @param s string 原始字符串
--- @return string 编码后的字符串
local function b64enc(s)
    local r = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i+2); b = b or 0; c = c or 0
        local n = a*65536 + b*256 + c
        r[#r+1] = _B64:sub(math.floor(n/262144)%64+1, math.floor(n/262144)%64+1)
        r[#r+1] = _B64:sub(math.floor(n/4096)%64+1,   math.floor(n/4096)%64+1)
        r[#r+1] = _B64:sub(math.floor(n/64)%64+1,     math.floor(n/64)%64+1)
        r[#r+1] = _B64:sub(n%64+1,                    n%64+1)
    end
    local p = #s % 3
    if p == 1 then r[#r] = "="; r[#r-1] = "=" elseif p == 2 then r[#r] = "=" end
    return table.concat(r)
end

--- Base64 解码。
--- @param s string 编码后的字符串
--- @return string 解码后的字符串
local function b64dec(s)
    s = s:gsub("[^A-Za-z0-9+/=]", "")
    local r = {}
    for i = 1, #s, 4 do
        local function v(c) return c == "=" and 0 or (_B64:find(c, 1, true) - 1) end
        local a, b, c, d = v(s:sub(i,i)), v(s:sub(i+1,i+1)), v(s:sub(i+2,i+2)), v(s:sub(i+3,i+3))
        local n = a*262144 + b*4096 + c*64 + d
        r[#r+1] = string.char(math.floor(n/65536)%256)
        if s:sub(i+2,i+2) ~= "=" then r[#r+1] = string.char(math.floor(n/256)%256) end
        if s:sub(i+3,i+3) ~= "=" then r[#r+1] = string.char(n%256) end
    end
    return table.concat(r)
end

-- ============================================================
--  HTTP 同步请求
-- ============================================================

--- 同步 HTTP GET 请求。
--- 阻塞等待请求完成或失败。
--- @param url string 请求 URL
--- @param headers table|nil 请求头
--- @return string|nil data 响应内容，失败返回 nil
local function httpGetSync(url, headers)
    local ok, handle = pcall(http.get, url, headers)
    if not ok or not handle then return nil end
    local d = handle.readAll()
    handle.close()
    return d
end

--- 同步 HTTP PUT 请求（阻塞等待，20 秒超时）。
--- @param url string 请求 URL
--- @param body string 请求体
--- @param headers table|nil 请求头
--- @return string|nil data 响应内容
--- @return string|nil err 错误信息
local function httpPutSync(url, body, headers)
    local ok = pcall(function()
        http.request({url = url, method = "PUT", body = body, headers = headers})
    end)
    if not ok then return nil, "request failed" end
    local tm = os.startTimer(20)
    while true do
        local ev, a, b = os.pullEvent()
        if ev == "http_success" and a == url then
            local d = b.readAll()
            b.close()
            os.cancelTimer(tm)
            return d
        elseif ev == "http_failure" and a == url then
            local m = (type(b) == "string") and b or "error"
            os.cancelTimer(tm)
            return nil, m
        elseif ev == "timer" and a == tm then
            return nil, "timeout"
        end
    end
end

-- ============================================================
--  GitHub API 工具
-- ============================================================

--- 构建 GitHub API 请求头。
--- @param token string GitHub Personal Access Token
--- @return table headers
local function ghHeaders(token)
    return {
        ["Authorization"] = "token " .. (token or ""),
        ["Accept"]        = "application/vnd.github.v3+json",
        ["User-Agent"]    = "AutoCraft-CC",
        ["Content-Type"]  = "application/json"
    }
end

--- 从 "owner/repo" 字符串中解析 owner 和 repo。
--- @param repoStr string GitHub 仓库标识，如 "myuser/myrepo"
--- @return string|nil owner 仓库所有者
--- @return string|nil repo 仓库名
local function ghParseRepo(repoStr)
    local r = repoStr or ""
    return r:match("^([^/]+)/(.+)$")
end

--- 构建 GitHub API 的 contents URL。
--- @param path string 文件路径
--- @param repoStr string 仓库标识 "owner/repo"
--- @return string|nil url
local function ghApiUrl(path, repoStr)
    local owner, repo = ghParseRepo(repoStr)
    if not owner then return nil end
    return "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/contents/" .. path
end

--- 判断配方是否使用了自定义 IO 设备（本地特有，不应导出）。
--- @param rec table 配方对象
--- @return boolean
local function recipeHasCustomIO(rec)
    if type(rec) ~= "table" then return false end
    if rec.output_device       and rec.output_device       ~= "" then return true end
    if rec.item_input_device   and rec.item_input_device   ~= "" then return true end
    if rec.fluid_input_device  and rec.fluid_input_device  ~= "" then return true end
    if rec.item_output_device  and rec.item_output_device  ~= "" then return true end
    if type(rec.output_tanks) == "table" and next(rec.output_tanks) then return true end
    if type(rec.input_tanks)  == "table" and next(rec.input_tanks)  then return true end
    return false
end

--- 合并导入的配方表（保留本地自定义 IO 配方，覆盖非自定义 IO 配方）。
--- @param localMap table|nil 本地配方表
--- @param importedMap table|nil 导入的配方表
--- @return table 合并结果
local function mergeImportedMap(localMap, importedMap)
    local out = {}
    for k, v in pairs(localMap or {}) do
        if recipeHasCustomIO(v) then out[k] = v end
    end
    for k, v in pairs(importedMap or {}) do
        if type(v) == "table" and not recipeHasCustomIO(v) then
            v.imported = true
            out[k] = v
        end
    end
    return out
end

--- 合并导入的替代配方（保留本地自定义 IO 配方，覆盖非自定义 IO 配方）。
--- @param localAlts table|nil 本地替代配方表
--- @param importedAlts table|nil 导入的替代配方表
--- @return table 合并结果
local function mergeImportedAlts(localAlts, importedAlts)
    local out = {}
    for k, list in pairs(localAlts or {}) do
        if type(list) == "table" then
            for _, rec in ipairs(list) do
                if recipeHasCustomIO(rec) then out[k] = out[k] or {}; table.insert(out[k], rec) end
            end
        end
    end
    for k, list in pairs(importedAlts or {}) do
        if type(list) == "table" then
            for _, rec in ipairs(list) do
                if type(rec) == "table" and not recipeHasCustomIO(rec) then
                    rec.imported = true
                    out[k] = out[k] or {}; table.insert(out[k], rec)
                end
            end
        end
    end
    return out
end

return {
    b64enc       = b64enc,
    b64dec       = b64dec,
    httpGetSync  = httpGetSync,
    httpPutSync  = httpPutSync,

    -- GitHub API
    ghHeaders       = ghHeaders,
    ghParseRepo     = ghParseRepo,
    ghApiUrl        = ghApiUrl,
    recipeHasCustomIO = recipeHasCustomIO,
    mergeImportedMap  = mergeImportedMap,
    mergeImportedAlts = mergeImportedAlts,
}
