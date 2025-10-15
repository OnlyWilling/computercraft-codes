local tb = { 1, 2, 3 }
local fs = fs.open("test.bimg", "w")
fs.write(textutils.serialize(tb))
fs.close()
