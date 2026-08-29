local wapi = require("WPToolkit.Mod.WApiMgr")
local win = wapi:GetWinAPI()
local registryIndex = nil
local VERSION_NUM = nil
local LUA_RIDX_MAINTHREAD = nil
local mainth = nil
LuaInfo = {}
local init = false
LuaInfo.neededLAPIFuncs = {
    lua_rotate = true,
    lua_settop        = true,
    lua_pushnumber    = true,
    lua_pushinteger   = true,
    lua_pushboolean   = true,
    lua_pushstring    = true,
    lua_pushlightuserdata = true,
    lua_pushvalue        = true,
    lua_pushnil          = true,
    lua_rawgeti        = true,
    lua_callk         = true,
    lua_tonumberx     = true,
    lua_tointegerx    = true,
    lua_toboolean     = true,
    lua_tolstring      = true,
    lua_touserdata    = true,
    lua_remove          = true,
    lua_pushcclosure    = true,
    lua_rawseti          = true,
    lua_rawlen          = true,
    lua_gettop          = true,
    lua_getglobal       = true,
}

function LuaInfo:UpdateLuaAPIAddrs()
    if init then
        return
    end
    local _, hmod = PathManager:GetLuaDll()
    for name, v in pairs(self.neededLAPIFuncs) do
        if v == true then
            self.neededLAPIFuncs[name] = win.GetProcAddress(hmod, name)
        end
    end
    init = true
end


function LuaInfo:GetLuaVersionNum()
    if not VERSION_NUM then
        local major, minor = _VERSION:match("Lua%s+(%d+)%.(%d+)")
        major, minor = tonumber(major), tonumber(minor)

        VERSION_NUM = major * 100 + minor
    end

    return VERSION_NUM
end

function LuaInfo:GetRidxMainThread()
    if not LUA_RIDX_MAINTHREAD then
        if self:GetLuaVersionNum() < 505 then
            LUA_RIDX_MAINTHREAD = 1
        else
            LUA_RIDX_MAINTHREAD = 3
        end
    end
    return LUA_RIDX_MAINTHREAD
end

function LuaInfo:getCurThread()
    local th = coroutine.running()
    local n = win.Addr2Num(th)
    return win.Num2Addr(n)
end
function LuaInfo:getMainThread()
    if not mainth then
        local registry = debug.getregistry()
        local th = registry[self:GetRidxMainThread()]
        local n = win.Addr2Num(th)
        mainth = win.Num2Addr(n)
    end
    return mainth
end
function LuaInfo:getRegistryIndex()
    if registryIndex then
        return registryIndex
    end
    local i4 = Memory:CreateAddr(4)
    local c255 = "\255"
    local maxi4 = ""
    for _=1, 3 do
        maxi4 = maxi4 .. c255
    end
    maxi4 = maxi4 .. "\127"
    Memory:WriteString(i4, maxi4)
    local INT32_MAX = Memory:ReadInteger(i4, 4)
    local midINT32_MAX = INT32_MAX // 2
    local idx = midINT32_MAX + 1000
    local RegistryIndex = -idx
    registryIndex = RegistryIndex
    return RegistryIndex
end

function LuaInfo:GetPusherAndToMap()
   self:UpdateLuaAPIAddrs()
   local luaAPI = self.neededLAPIFuncs
   local lua_toxxxxmap = {
    [ValueTypes.VT_INTEGER] = luaAPI.lua_tointegerx,
    [ValueTypes.VT_FLOAT] = luaAPI.lua_tonumberx,
    [ValueTypes.VT_DOUBLE] = luaAPI.lua_tonumberx,
    [ValueTypes.VT_USERDATA] = luaAPI.lua_touserdata,
    [ValueTypes.VT_BOOLEAN] = luaAPI.lua_toboolean,
    [ValueTypes.VT_STRING] = luaAPI.lua_tolstring,
   }
   local lua_pushxxxxmap = {
    [ValueTypes.VT_INTEGER] = luaAPI.lua_pushinteger,
    [ValueTypes.VT_FLOAT] = luaAPI.lua_pushnumber,
    [ValueTypes.VT_DOUBLE] = luaAPI.lua_pushnumber,
    [ValueTypes.VT_USERDATA] = luaAPI.lua_pushlightuserdata,
    [ValueTypes.VT_BOOLEAN] = luaAPI.lua_pushboolean,
    [ValueTypes.VT_STRING] = luaAPI.lua_pushstring
   }
   return lua_pushxxxxmap, lua_toxxxxmap
end