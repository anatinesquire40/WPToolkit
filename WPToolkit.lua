assert(os.getenv"OS" == "Windows_NT", "This is only supported on windows")
local wapi = require("WPToolkit.Mod.WApiMgr")
local MultiLar = require"MultiLar"
local manifest = MultiLar:getMain():getManifest()
wapi:LoadWinAPI()
local _ENV = wapi:MkEnv()
local LUA_SEARCHER_IDX = 2
local function modulereq(mod)
    mod = "WPToolkit." .. mod
    local function executeandaddloaded(f)
        debug.setupvalue(f, 1, _ENV)
        local ret = f()
        package.loaded[mod] = ret
        return ret
    end
    if package.loaded[mod] then
        return package.loaded[mod]
    end
    if package.preload[mod] then
        local f = package.preload[mod]
        if debug.getinfo(f).what ~= "C" then
            return executeandaddloaded(f)
        end
    end
    local ret
    local searchers = package.searchers
    local searcherf = searchers[#searchers]
    if manifest.disableExternalLua then
        searcherf = searchers[LUA_SEARCHER_IDX]
    end
    if searcherf then
        ret = searcherf(mod)
    end
    if type(ret) == "function" then
        return executeandaddloaded(ret)
    else
        error("Module '" .. mod .. "' not found: " .. ret, 2)
    end
end
modulereq"Memory.NativeTypes"
modulereq"LuaInfo.LuaInfo"
modulereq"NativeFunction.NativeFunctionManager"
modulereq"NativeFunction.InstructionFunctions"
modulereq"NativeFunction.RegStorer"
modulereq"NativeFunction.luaAPI"
modulereq"NativeFunction.generators"
modulereq"NativeFunction.debug"
modulereq"NativeFunction.ArgsFmt"
modulereq"NativeFunction.Lua_CFunction"
modulereq"NativeFunction.CallStack"
modulereq"Memory.ReadWrite"
modulereq"Memory.MemMath"
modulereq"Memory.Create"
modulereq"Memory.Copy"
modulereq"Memory.Funcs"
modulereq"Memory.VirtualWin"
modulereq"Memory.StructManager"
modulereq"Memory.ArrayManager"
modulereq"Strings.StringManager"
modulereq"Strings.WideCharMgr"
modulereq"Mod.LoadedDlls"
modulereq"FileSystem.PathManager"
modulereq"FileSystem.FileManager"
modulereq"FileSystem.KnownPaths"
modulereq"timer.luatimer"
modulereq"Mod.library"
modulereq"Strings.clipboard"
LuaInfo:UpdateLuaAPIAddrs()
local M = setmetatable({
    WinAPI = wapi:GetWinAPI()
}, {__index = function (_,i)
    return rawget(_ENV, i)
end})
return M