local WinAPIMgr = {}
local WindowsValues = {}
function WinAPIMgr:LoadWinAPI()
   local lfuncsEnv = self:MkEnv()
   local function checkLuaFunc(f)
        if type(f) == "function" then
            if debug.getinfo(f).what ~= "C" then
                debug.setupvalue(f, 1, lfuncsEnv)
            end
        end
   end
   local oldmt = getmetatable(_G)
   local mt = { __newindex = function(_,i, v)
      checkLuaFunc(v)
      self:AddValue(i, v)
   end }
   setmetatable(_G, mt)
   require"ibexwin.h"
   setmetatable(_G, oldmt)
   for i,v in pairs(lfuncsEnv)do
    self:AddValue(i,v)
   end
end
function WinAPIMgr:GetValue(name)
    return WindowsValues[name]
end
function WinAPIMgr:AddValue(name, value)
    WindowsValues[name] = value
end
function WinAPIMgr:GetWinAPI()
    return WindowsValues
end
function WinAPIMgr:GetEnvMt()
    return {
        __index = function(_, i)
            return self:GetValue(i) or _G[i]
        end
    }
end
function WinAPIMgr:GetGlobalMt()
    return {
        __index = function(_, i)
            return self:GetValue(i)
        end
    }
end
function WinAPIMgr:MkEnv()
    local mt = self:GetEnvMt()
    return setmetatable({}, mt)
end
return WinAPIMgr