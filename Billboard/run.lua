t = textutils.unserialise(fs.open("config.cfg","r").readAll())
for index, value in ipairs(t) do
    if monitor_id ~= "" then
        monitor_id = value["monitor_id"]
        http_url = value["http_url"]
        
        peripheral.wrap(monitor_id).setTextScale(0.5)
        w,h = peripheral.wrap(monitor_id).getSize()
        local w = w*2
        local h = h*3
        local format = "lua"
        local json = textutils.serialiseJSON({ ["url"] = http_url, ["w"] = w , ["h"] = h , ["format"] = format } )
        local luaURL = http.post("http://gmapi.liulikeji.cn:15842/image",json).readAll()
        str = http.get(luaURL).readAll()
        a = string.sub(str,1,string.len(str)-191)
        b = a:gsub("read","--read")
        function1 = "peripheral.wrap('"..monitor_id.."').setTextScale(0.5) \nterm.redirect(peripheral.wrap('"..monitor_id.."')) \n"..b
        f = fs.open("startup/"..monitor_id..".lua","w")
        f.write(function1)
        f.close()
    end
end
f = fs.open("startup/none.lua","w")
f.write("sleep(6) os.reboot()")
f.close()