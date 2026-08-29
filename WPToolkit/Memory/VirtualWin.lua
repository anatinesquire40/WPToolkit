local wapi = require("WPToolkit.Mod.WApiMgr")
local win = wapi:GetWinAPI()
local VirtualWin = {}
Memory.VirtualWin = VirtualWin
local k32 = win.GetModuleHandle("kernel32.dll")
win.VirtualProtect = win.Addr2Val(win.GetProcAddress(k32, "VirtualProtect"), ValueTypes.VT_BOOLEAN, {ValueTypes.VT_USERDATA, ValueTypes.VT_INTEGER, ValueTypes.VT_INTEGER, ValueTypes.VT_USERDATA})
win.VirtualAlloc = win.Addr2Val(win.GetProcAddress(k32, "VirtualAlloc"), ValueTypes.VT_USERDATA, {ValueTypes.VT_USERDATA, ValueTypes.VT_INTEGER, ValueTypes.VT_INTEGER, ValueTypes.VT_INTEGER})
win.VirtualFree = win.Addr2Val(win.GetProcAddress(k32, "VirtualFree"), ValueTypes.VT_BOOLEAN, {ValueTypes.VT_USERDATA, ValueTypes.VT_INTEGER, ValueTypes.VT_INTEGER})
function VirtualWin:VirtualProtect(addr, size, perms, oldProtect)
    if type(oldProtect) ~= "number" then
        oldProtect = Memory:CreateAddr(4)
    else
        oldProtect = Memory:Number2Addr(oldProtect)
    end
    local ret = win.VirtualProtect(addr, size, perms, oldProtect)
    assert(ret, "VirtualProtect failed! Error Code: " .. win.GetLastError())
    return oldProtect
end
function VirtualWin:VirtualAlloc(size, perms)
    local addr = win.VirtualAlloc(Memory.nullptr, size, 0x3000, perms)
    assert(addr ~= Memory.nullptr, "VirtualAlloc failed! Error: " .. win.GetLastError())
    return addr
end
function VirtualWin:VirtualFree(addr)
    return win.VirtualFree(addr, 0, 0x8000)
end