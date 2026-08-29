local wapi = require("WPToolkit.Mod.WApiMgr")
local win = wapi:GetWinAPI()
function Memory:CopyAddr(addr, size)
    assert(type(addr) == "userdata", "arg #1 must be userdata")
    return win.CopyAddr(addr, size)
end
function Memory:CopyAddr2String(addr, size)
    assert(type(addr) == "userdata", "arg #1 must be userdata")
    return win.CopyAddr(addr, size, true)
end
function Memory:CopyString(str, size)
    assert(type(str) == "string", "arg #1 must be string")
    return win.CopyAddr(str, size)
end
function Memory:CopyString2Addr(str, size)
    assert(type(str) == "string", "arg #1 must be string")
    return win.CopyAddr(str, size or #str + 1, true)
end