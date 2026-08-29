local greg = debug.getregistry()
local treg = {}
table.insert(greg, treg)
NativeFunctionManager.tregi = #greg
local function checknodupli(lfnc, index)
    for i, v in pairs(treg) do
        if v == lfnc then
            Memory:WriteInteger(index, i, 8)
            return true
        end
    end
    return false
end
function NativeFunctionManager:storeLuaFunction(lfunc)
    local i = Memory:CreateAddr(8)
    if checknodupli(lfunc, i) then
        return Memory:ReadInteger(i, 8)
    end
    table.insert(treg, lfunc)
    return #treg
end
function NativeFunctionManager:removeLuaFunction(index)
    treg[index] = nil
end