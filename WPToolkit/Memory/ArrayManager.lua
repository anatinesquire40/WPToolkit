ArrayManager = {}
local dataField = Memory:CreateAddr(1)
local definedTypeSize = {
    [ValueTypes.VT_USERDATA] = 8,
    [ValueTypes.VT_DOUBLE] = 8,
    [ValueTypes.VT_FLOAT] = 4,
    [ValueTypes.VT_BOOLEAN] = 1,
}
function ArrayManager:getData()
    return assert(self[dataField])
end
function ArrayManager:IsStructArray()
    return ArrayManager.getData(self).structarray
end
function ArrayManager:getRaw()
    return assert(ArrayManager.getData(self).p)
end
function ArrayManager:getFieldSize()
    local l = ArrayManager.getData(self).l
    if not l then
        l = definedTypeSize[ArrayManager.getFieldType(self)]
    end
    assert(l)
    return l
end
function ArrayManager:IsBigEndian()
    return ArrayManager.getData(self).bigendian
end
function ArrayManager:getFieldType()
    return ArrayManager.getData(self).t
end
local readers = {
    [ValueTypes.VT_INTEGER] = function(addr, fieldsize, bigendian)
        return Memory:ReadInteger(addr, fieldsize, bigendian)
    end,
    [ValueTypes.VT_DOUBLE] = function(addr, _, bigendian)
        return Memory:ReadDouble(addr, bigendian)
    end,
    [ValueTypes.VT_FLOAT] = function (addr, _, bigendian)
        return Memory:ReadFloat(addr, bigendian)        
    end,
    [ValueTypes.VT_BOOLEAN] = function(addr)
        return Memory:ReadBoolean(addr)
    end,
    [ValueTypes.VT_STRING] = function(addr, fieldsize)
        return Memory:ReadString(addr, fieldsize)
    end,
    [ValueTypes.VT_USERDATA] = function(addr)
        local ptr = Memory:ReadInteger(addr, 8)
        return Memory:ResolvePointer(ptr)
    end
}
local writers = {
    [ValueTypes.VT_INTEGER] = function(addr, fieldsize, value, bigendian)
        Memory:WriteInteger(addr, value, fieldsize, bigendian)
    end,
    [ValueTypes.VT_DOUBLE] = function(addr, _, value, bigendian)
        Memory:WriteDouble(addr, value, bigendian)
    end,
    [ValueTypes.VT_FLOAT] = function (addr, _, value, bigendian)
        Memory:WriteFloat(addr, value, bigendian)
    end,
    [ValueTypes.VT_BOOLEAN] = function(addr, _, value)
        Memory:WriteBoolean(addr, value)
    end,
    [ValueTypes.VT_STRING] = function(addr, fieldsize, value)
        Memory:WriteString(addr, value, fieldsize)
    end,
    [ValueTypes.VT_USERDATA] = function(addr, fieldsize, value)
        Memory:WriteAddr(addr, value, fieldsize)
    end
}
local argtypemap = {
    integer = ValueTypes.VT_INTEGER,
    float = ValueTypes.VT_FLOAT,
    userdata = ValueTypes.VT_USERDATA,
    boolean = ValueTypes.VT_BOOLEAN,
    ["nil"] =  ValueTypes.VT_USERDATA,
    string = ValueTypes.VT_STRING
}
function ArrayManager:Index(i)
    local p = ArrayManager.getRaw(self)
    local l = ArrayManager.getFieldSize(self)
    local t = ArrayManager.getFieldType(self)
    local o = l * (i-1)
    local vp = Memory:AddOffset(p, o)
    if not t then
        return vp
    elseif ArrayManager.IsStructArray(self) then
        return StructManager:parseStruct(vp, t)
    else
        local v = readers[t](vp, l, ArrayManager.IsBigEndian(self))
        return v
    end
end

local function checktype(v, fieldt)
    local t = type(v)
    if t == "number" then
        if fieldt == ValueTypes.VT_FLOAT or fieldt == ValueTypes.VT_DOUBLE then
            assert(math.type(v) == "float")
            return
        else
            assert(math.type(v) == "integer")
            return
        end
    end
    assert(argtypemap[t] == fieldt)
end
function ArrayManager:NewIndex(i, v)
    local p = ArrayManager.getRaw(self)
    local l = ArrayManager.getFieldSize(self)
    local t = ArrayManager.getFieldType(self)
    local o = l * (i-1)
    local vp = Memory:AddOffset(p, o)
    if not t then
        Memory:WriteAddr(vp, v, l)
        return
    elseif ArrayManager.IsStructArray(self) then
        assert(type(v) == "table")
        local raw = StructManager.getRawStruct(v)
        writers[ValueTypes.VT_USERDATA](vp, l, raw)
    end
    checktype(v, t)
    writers[t](vp, l, v, ArrayManager.IsBigEndian(self))
end

function ArrayManager:ToString()
    local t = ArrayManager.getFieldType(self)
    if not t then
        t = "UNKNOWN"
    end
    local p = ArrayManager.getRaw(self)
    local udstring = string.format("%s: %p", t, p)
    return udstring
end

function ArrayManager:parseArray(addr, fieldtype, fieldsize, isbigendian)
    local data = {
        p = addr,
        structarray = StructManager:hasFormat(fieldtype),
        t = fieldtype,
        l = fieldsize,
        bigendian = isbigendian
    }
    if data.structarray then
        data.l = StructManager:calcSize(fieldtype)
    end
    return setmetatable({ [dataField] = data
    }, {
            __index = ArrayManager.Index,
            __newindex = ArrayManager.NewIndex,
            __tostring = ArrayManager.ToString
        }
    )
end
function ArrayManager:new(nfields, fieldtype, fieldsize, bigendian)
    local l = fieldsize
    local t = fieldtype
    if StructManager:hasFormat(fieldtype) then
        l = StructManager:calcSize(fieldtype)
    else
    if not fieldsize then
        assert(fieldsize, "fieldsize is required if type is not predefined")
    end
    t = fieldtype
    if not l then
        l = definedTypeSize[t]
    end
    end
    local p = Memory:CreateAddr(nfields * l)
    return self:parseArray(p, t, l, bigendian), p
end
function ArrayManager:IsProxy(candidate)
    return type(candidate) == "table" and candidate[dataField] ~= nil
end