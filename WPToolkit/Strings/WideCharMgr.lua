local wapi = require("WPToolkit.Mod.WApiMgr")
local win = wapi:GetWinAPI()

WideCharManager = {}
local CP_UTF8 = win.CP_UTF8
    if not win.WideCharToMultiByte then
        win.WideCharToMultiByte = Memory:GetFunctionFromDll(
            "kernel32.dll",
            "WideCharToMultiByte",
            ValueTypes.VT_INTEGER,
            {ValueTypes.VT_INTEGER, ValueTypes.VT_INTEGER, ValueTypes.VT_USERDATA, ValueTypes.VT_INTEGER, ValueTypes.VT_USERDATA, ValueTypes.VT_INTEGER, ValueTypes.VT_USERDATA, ValueTypes.VT_USERDATA}
        )
    end
function WideCharManager:Encode(str)
    local len = win.MultiByteToWideChar(
        CP_UTF8,
        0,
        str,
        nil,
        0
    )
    if len == 0 then
        error("MultiByteToWideChar failed")
    end

    local buf = Memory:CreateAddr((len + 1) * 2)

    win.MultiByteToWideChar(
        CP_UTF8,
        0,
        str,
        buf,
        len
    )
    local endPtr = Memory:AddOffset(buf, len * 2)
    Memory:WriteString(endPtr, "\0\0")
    len = len + 1
    local bytelen = len*2
    return buf, len, bytelen
end

function WideCharManager:Decode(widePtr, wideLen)
    if not wideLen then
        wideLen = -1
    end
    local len = win.WideCharToMultiByte(
        CP_UTF8,
        0,
        widePtr,
        wideLen,
        0,
        0,
        nil,
        nil
    )
    if len == 0 then
        error("WideCharToMultiByte failed")
    end

    local buf = Memory:CreateAddr(len)

    win.WideCharToMultiByte(
        CP_UTF8,
        0,
        widePtr,
        wideLen,
        buf,
        len,
        nil,
        nil
    )

    return Memory:ReadString(buf, len)
end
function WideCharManager:GetWideLen(ptr)
    local offset = 0
    while true do
        local val = Memory:ReadInteger(Memory:AddOffset(ptr, offset), 2)
        if val == 0 then
            return offset // 2, offset
        end
        offset = offset + 2
    end
end
