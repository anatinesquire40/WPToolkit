local wapi = require("WPToolkit.Mod.WApiMgr")
local win = wapi:GetWinAPI()

LoadedDlls = {}
if win.GetModuleHandle("psapi.dll") == Memory.nullptr then
    local hMod = win.LoadLibrary("psapi.dll")
    setmetatable(LoadedDlls, {__gc = function (t)
        win.FreeLibrary(hMod)
    end})
end
win.EnumProcessModules = Memory:GetFunctionFromDll(
    "psapi.dll",
    "EnumProcessModules",
    ValueTypes.VT_BOOLEAN,
    { ValueTypes.VT_USERDATA, ValueTypes.VT_ARRAY, ValueTypes.VT_INTEGER, ValueTypes.VT_USERDATA }
)
win.GetModuleFileNameEx = Memory:GetFunctionFromDll(
    "psapi.dll",
    "GetModuleFileNameExA",
    ValueTypes.VT_INTEGER,
    { ValueTypes.VT_USERDATA, ValueTypes.VT_USERDATA, ValueTypes.VT_STRING, ValueTypes.VT_INTEGER }
)

function LoadedDlls:GetLoadedDlls(process)
    process = process or win.GetCurrentProcess()

    local maxMods = 1024
    local ptrSize = 8
    local lphMod = ArrayManager:new(maxMods, ValueTypes.VT_USERDATA, ptrSize)
    local neededPtr = Memory:CreateAddr(4)
    if not win.EnumProcessModules(process, lphMod, maxMods * ptrSize, neededPtr) then
        return nil
    end

    local needed = Memory:ReadInteger(neededPtr, 4)
    local count = needed // ptrSize
    local mods = {}

    for i = 1, count do
        local hMod = lphMod[i]
        local pathBuf = Memory:CreateBuffer(260)
        local len = win.GetModuleFileNameEx(process, hMod, pathBuf, 260)
        assert(len ~= 0, win.GetLastError())
        local path = pathBuf:sub(1, len)
        mods[#mods + 1] = {
            handle = hMod,
            path = path
        }
    end

    return mods
end
