local wapi = require("WPToolkit.Mod.WApiMgr")
local win = wapi:GetWinAPI()
local function clean_stub(p)
    Memory.VirtualWin:VirtualFree(p)
end
function Memory:GetFunction(addr, retType, argTypes, useDefaultTrampoline)
    retType = retType or ValueTypes.VT_VOID
    argTypes = argTypes or {}
    local auxiliarStruct = {}
    local auxiliarArray = {}
    local callbackFuncFmt = {}
    for i,v in ipairs(argTypes) do
        if type(v) == "string" and StructManager:hasFormat(v) then
            auxiliarStruct[i] = v
            argTypes[i] = ValueTypes.VT_USERDATA
        elseif type(v) == "table" and (v.t == ValueTypes.VT_FUNCTION) then
            callbackFuncFmt[i] = {r=v.ret, l=v.argTypes}
            argTypes[i] = ValueTypes.VT_USERDATA
        elseif v == ValueTypes.VT_ARRAY then
            auxiliarArray[i] = true
            argTypes[i] = ValueTypes.VT_USERDATA
        end
    end
    local tramp = win.Addr2Val(addr, retType, argTypes, (not useDefaultTrampoline) and NativeFunctionManager.LuaCall or nil, clean_stub)
    return function (...)
        local callArgs = {}
        for i=1, #argTypes do
            local sv = auxiliarStruct[i]
            local av = auxiliarArray[i]
            local fv = callbackFuncFmt[i]
            local argValue = select(i, ...)
            local typeArg = type(argValue)
            if sv then
                if StructManager:IsProxy(argValue) then
                    local raw = StructManager.getRawStruct(argValue)
                    table.insert(callArgs, raw)
                elseif typeArg == "userdata" then
                    table.insert(callArgs, argValue)
                elseif typeArg == "table" then
                    local raw = StructManager:attach(argValue, sv)
                    table.insert(callArgs, raw)
                else
                    error(string.format("arg #%d expected proxy, table or userdata, got: %s", i, typeArg), 2)
                end
            elseif av then
                assert(ArrayManager:IsProxy(argValue), string.format("arg #%d expected proxy, got: %s", i, typeArg))
                table.insert(callArgs, ArrayManager.getRaw(argValue))
            elseif fv then
                if typeArg == "function" then
                    local callBack = NativeFunctionManager:CreateNativeCallback(argValue, fv.r, fv.l)
                    table.insert(callArgs, callBack)
                elseif typeArg == "userdata" then
                    table.insert(callArgs, argValue)
                else
                    error(string.format("arg #%d expected function or userdata, got: %s", i, typeArg), 2)
                end
            else
                table.insert(callArgs, argValue)
            end
        end
        return tramp(table.unpack(callArgs))
    end
end
function Memory:GetFunctionAddrFromHModule(hmod, funcName)
    return win.GetProcAddress(hmod, funcName)
end
function Memory:GetFunctionFromHModule(hmod, funcName, ...)
    return self:GetFunction(self:GetFunctionAddrFromHModule(hmod, funcName), ...)
end
function Memory:GetFunctionAddrFromDll(dllName, funcName)
    local getModule = Library and Library.getModule or win.GetModuleHandle
    return self:GetFunctionAddrFromHModule(getModule(dllName), funcName)
end
function Memory:GetFunctionFromDll(dllName, ...)
    local getModule = Library and Library.getModule or win.GetModuleHandle
    return self:GetFunctionFromHModule(getModule(dllName), ...)
end
local argtypemap = {
    integer = ValueTypes.VT_INTEGER,
    float = ValueTypes.VT_DOUBLE,
    userdata = ValueTypes.VT_USERDATA,
    boolean = ValueTypes.VT_BOOLEAN,
    ["nil"] =  ValueTypes.VT_USERDATA,
    string = ValueTypes.VT_STRING
}
function Memory:CallFunction(addr, retType, ...)
local callArgs = {}
local args = table.pack(...)
local skipNext = false
    local argTypes = {}
    for i,v in ipairs(args)do
        if skipNext then
            skipNext = false
            goto continue
        end
        local t = type(v)
        if t == "number" then
            t = tostring(math.type(v))
        end
        local argSign = argtypemap[t]
        if t == "table" and StructManager:IsProxy(v) then
            argSign = StructManager.getData(v).fmtname
        end
        if t == "table" and ArrayManager:IsProxy(v) then
            argSign = ValueTypes.VT_ARRAY
        end
        if t == "function" then
            skipNext = true
            argSign = args[i + 1]
            local nextt = type(argSign)
            assert(nextt == "table", string.format("arg #%d, table expected, got %s", i+1, nextt))
            argSign.t = ValueTypes.VT_FUNCTION
        end
        assert(argSign, string.format("arg #%d, %s type is not suported!", i, t))
        table.insert(argTypes, argSign)
        table.insert(callArgs, v)
        ::continue::
    end
    return self:GetFunction(addr, retType, argTypes)(table.unpack(callArgs))
end
function Memory:CallFunctionFromHModule(hmod, funcName, ...)
    return self:CallFunction(win.GetProcAddress(hmod, funcName), ...)
end
function Memory:CallFunctionFromDll(dllName, ...)
    local getModule = Library and Library.getModule or win.GetModuleHandle
    return self:CallFunctionFromHModule(getModule(dllName), ...)
end