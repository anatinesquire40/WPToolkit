local wapi = require("WPToolkit.Mod.WApiMgr")
local win = wapi:GetWinAPI()
function Memory:CreateAddr(size)
    return win.Val2Addr(nil, size, true)
end
function Memory:CreateBuffer(size)
    return win.Val2Addr(nil, size)
end
function Memory:Number2Addr(num)
    return win.Val2Addr(num)
end