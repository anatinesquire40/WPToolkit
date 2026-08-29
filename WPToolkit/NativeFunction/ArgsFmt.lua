local bitMap = {
    [ValueTypes.VT_INTEGER64] = 64,
    [ValueTypes.VT_INTEGER32] = 32,
    [ValueTypes.VT_INTEGER16] = 16,
    [ValueTypes.VT_INTEGER8] = 8,
    [ValueTypes.VT_BOOLEAN] = 8,
    [ValueTypes.VT_DOUBLE] = 64,
    [ValueTypes.VT_FLOAT] = 32,
    [ValueTypes.VT_USERDATA] = 64,
    [ValueTypes.VT_STRING] = 64,
}
NativeFunctionManager.ThirdArgMap = {
    [ValueTypes.VT_INTEGER] = true,
    [ValueTypes.VT_DOUBLE] = true,
    [ValueTypes.VT_FLOAT] = true,
    [ValueTypes.VT_BOOLEAN] = true,
    [ValueTypes.VT_STRING] = true
}
local function MakeArg(arg)
    local bits = bitMap[arg]
    local fmt = { type = arg, bits = bits }
    return fmt
end
local function MakeArgFormatRecursive(t, argTypes)
    for _, str in ipairs(argTypes) do
        table.insert(t, MakeArg(str))
    end
end

function NativeFunctionManager:FormatArgs(ret, argTypes)
    local hasRet = (ret ~= nil) and (ret ~= ValueTypes.VT_NIL)
    local argsFmt = {}
    if hasRet then
        argsFmt.Ret = MakeArg(ret)
    end
    if argTypes then
        MakeArgFormatRecursive(argsFmt, argTypes)
    end
    return hasRet, argsFmt
end