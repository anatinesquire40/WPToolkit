local wapi = require("WPToolkit.Mod.WApiMgr")
local win = wapi:GetWinAPI()
Memory = {
    nullptr = win.Val2Addr(nil)
}
function Memory:ReadString(addr, len)
    return win.Addr2Val(addr, ValueTypes.VT_STRING, len)
end
function Memory:ReadInteger(addr, intSize, isBigEndian)
    intSize = intSize or 4
    local str = self:ReadString(addr, intSize)
    local fmt = (isBigEndian and ">I" or "<I") .. intSize
    return fmt:unpack(str)
end
function Memory:ReadFloat(addr, isBigEndian)
    local str = self:ReadString(addr, 4)
    local fmt = (isBigEndian and ">f" or "<f")
    return fmt:unpack(str)
end
function Memory:ReadDouble(addr, isBigEndian)
    local str = self:ReadString(addr, 8)
    local fmt = (isBigEndian and ">d" or "<d")
    return fmt:unpack(str)
end
function Memory:ReadBoolean(addr)
    return win.Addr2Val(addr, ValueTypes.VT_BOOLEAN, 1)
end
function Memory:ReadUserdata(addr)
    local dir = self:ReadInteger(addr, 8)
    return self:ResolvePointer(dir)
end
function Memory:WriteString(addr, str, size)
    if type(str) ~= "string" then
        error("arg #2 must be a string", 2)
    end
    win.WriteAddr(addr, str, size)
end
function Memory:WriteAddr(addr, ptr, size)
    if type(ptr) ~= "userdata" then
        error("arg #2 must be userdata", 2)
    end
    win.WriteAddr(addr, ptr, size)
end
function Memory:WriteInteger(addr, value, intSize, isBigEndian)
    intSize = intSize or 4
    local fmt = (isBigEndian and ">I" or "<I") .. intSize
    local str = fmt:pack(value)
    self:WriteString(addr, str)
end
function Memory:WriteFloat(addr, value, isBigEndian)
    local fmt = (isBigEndian and ">f" or "<f")
    local str = fmt:pack(value)
    self:WriteString(addr, str)
end
function Memory:WriteDouble(addr, value, isBigEndian)
    local fmt = (isBigEndian and ">d" or "<d")
    local str = fmt:pack(value)
    self:WriteString(addr, str)
end
function Memory:WriteBoolean(addr, value)
    self:WriteString(addr, value and "\1" or "\0")
end
function Memory:WriteUserdata(addr, value)
    local dir = self:ResolvePointer(value)
    self:WriteInteger(addr, dir, 8)
end