local wapi = require("WPToolkit.Mod.WApiMgr")
local win = wapi:GetWinAPI()
local function checkoffset(addr, offset)
    if type(addr) ~= "userdata" then
        error("arg #1 must be userdata", 3)
    end
    if type(offset) ~= "number" then
        error("arg #2 must be an integer", 3)
    end
end
function Memory:PadSize(size, align)
    local align = align and align or 8
    local padding = align - (size % align)
    if padding == align then padding = 0 end
    return size + padding
end
function Memory:ResolvePointer(ptroraddr)
    if type(ptroraddr) == "number" then
        return win.Num2Addr(ptroraddr)
    else
        return win.Addr2Num(ptroraddr)
    end
end
function Memory:AddOffset(addr, offset)
    checkoffset(addr, offset)
    local ptr = self:ResolvePointer(addr)
    local ret = self:ResolvePointer(ptr + offset)
    return ret
end
function Memory:SubOffset(addr, offset)
    checkoffset(addr, offset)
    local ptr = self:ResolvePointer(addr)
    local ret = self:ResolvePointer(ptr - offset)
    return ret
end