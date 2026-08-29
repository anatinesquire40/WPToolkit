StructManager = {
    structFormats = {}
}
local dataField = Memory:CreateAddr(1)
local alignmentfield = Memory:CreateAddr(1)
function StructManager:addFormat(name, fmt, alignment)
    if self.structFormats[name] then
      error("There's already a format called ".. name, 2)
    end
    fmt[alignmentfield] = alignment
    self.structFormats[name] = fmt
    return self:calcSize(fmt)
end
function StructManager:getData()
    return self[dataField]
end
function StructManager:getFormat()
    local data = StructManager.getData(self)
    if not data then
        return nil
    end
    return StructManager.structFormats[data.fmtname]
end
function StructManager:hasFormat(fmtName)
    return self.structFormats[fmtName] ~= nil
end
function StructManager:getRawStruct()
    local data = StructManager.getData(self)
    if not data then
        return nil
    end
    return data.raw
end
local knownSizes = {
    [ValueTypes.VT_FLOAT] = 4,
    [ValueTypes.VT_DOUBLE] = 8,
    [ValueTypes.VT_USERDATA] = 8,
    [ValueTypes.VT_BOOLEAN] = 1,
}
local function getFieldSize(field)
    return field.size or knownSizes[field.type]
end
function StructManager:calcSize(structfmt)
    if not structfmt then
        return 0
    end

    local maxEnd = 0

    for _, field in pairs(structfmt) do
        if _ ~= alignmentfield then 
        local fieldSize = getFieldSize(field) or 0
        local fieldEnd = field.offset + fieldSize

        if fieldEnd > maxEnd then
            maxEnd = fieldEnd
        end
    end
    end

    return Memory:PadSize(maxEnd, structfmt[alignmentfield])
end
function StructManager:sizeOf(fmtName)
    return self:calcSize(self.structFormats[fmtName])
end
local readers = {
    [ValueTypes.VT_INTEGER] = function(addr, d)
        return Memory:ReadInteger(addr, d.size, d.isBigEndian)
    end,
    [ValueTypes.VT_DOUBLE] = function(addr, d)
        return Memory:ReadDouble(addr, d.isBigEndian)
    end,
    [ValueTypes.VT_FLOAT] = function (addr, d)
        return Memory:ReadFloat(addr, d.isBigEndian)
    end,
    [ValueTypes.VT_BOOLEAN] = function(addr)
        return Memory:ReadBoolean(addr)
    end,
    [ValueTypes.VT_STRING] = function(addr, d)
        return Memory:ReadString(addr, d.size)
    end,
    [ValueTypes.VT_USERDATA] = function(addr)
        local ptr = Memory:ReadInteger(addr, 8)
        return Memory:ResolvePointer(ptr)
    end
}
local writers = {
    [ValueTypes.VT_INTEGER] = function(addr, d, value)
        Memory:WriteInteger(addr, value, d.size, d.isBigEndian)
    end,
    [ValueTypes.VT_DOUBLE] = function(addr, d, value)
        Memory:WriteDouble(addr, value, d.isBigEndian)
    end,
    [ValueTypes.VT_FLOAT] = function (addr, d, value)
        Memory:WriteFloat(addr, value, d.isBigEndian)
    end,
    [ValueTypes.VT_BOOLEAN] = function(addr, _, value)
        Memory:WriteBoolean(addr, value)
    end,
    [ValueTypes.VT_STRING] = function(addr, d, value)
        Memory:WriteString(addr, value, d.size)
    end,
    [ValueTypes.VT_USERDATA] = function(addr, d, value)
        local wr = readers[ValueTypes.VT_USERDATA](addr)
        Memory:WriteAddr(wr, value, d.size)
    end
}

function StructManager:Index(name)
    local structfmt = StructManager.getFormat(self)
    if not structfmt then
        return nil
    end
    local raw = StructManager.getRawStruct(self)
    if not raw then
        return nil
    end
    local data = structfmt[name]
    if not data then
        return nil
    end
    local addr = Memory:AddOffset(raw, data.offset)
    local tp = data.type
    if not tp then
        return addr
    end
    local f = readers[tp]
    if f then
        return f(addr, data)
    end
    return nil
end

function StructManager:NewIndex(name, value)
    local structfmt = StructManager.getFormat(self)
    assert(structfmt, "no struct format, check the table is valid")
    local data = structfmt[name]

    if not data then
        error(
            "attempt to write unknown field \""..tostring(name) .. "\"",
            2
        )
    end

    local raw = StructManager.getRawStruct(self)
    local addr = Memory:AddOffset(raw, data.offset)
    local tp = data.type
    if not tp then
        Memory:WriteAddr(addr, value, data.size)
        return
    end
    local f = writers[tp]

    if not f then
        error("No writer for type "..tostring(tp), 2)
    end

    f(addr, data, value)
end
function StructManager:Pairs()
    local strfmt = StructManager.getFormat(self)
    assert(strfmt)
    local function iter(_, k)
        local nextK = next(strfmt, k)
        if not nextK then
            return nil, nil
        end
        local value = self[nextK]
        return nextK, value
    end
    return iter, nil, nil
end
function StructManager:Len()
    return StructManager:calcSize(StructManager.getFormat(self))
end
function StructManager:ToString()
    local data = StructManager.getData(self)
    if not data then
        return nil
    end
    local fmtname = data.fmtname
    local raw = StructManager.getRawStruct(self)
    if not fmtname or not raw then
        return nil
    end
    local udstring = string.format("%s: %p", fmtname, raw)
    return udstring
end
function StructManager:makeMetatable()
    return {
        __index    = StructManager.Index,
        __newindex = StructManager.NewIndex,
        __pairs    = StructManager.Pairs,
        __len      = StructManager.Len,
        __tostring = StructManager.ToString
    }
end
function StructManager:parseStruct(raw, fmtname)
    if type(raw) ~= "userdata" then
        error("arg #1 expected userdata", 2)
    end
    if not self.structFormats[fmtname] then
        error("no valid struct format name specified", 2)
    end
    local mt = self:makeMetatable()
    local data = {fmtname = fmtname, raw = raw}
    local ret = setmetatable({ [dataField] = data }, mt)
    return ret
end
function StructManager:new(fmtName)
    assert(self.structFormats[fmtName], "the format name must be a valid format")
    local raw = Memory:CreateAddr(self:sizeOf(fmtName))
    local proxy = self:parseStruct(raw, fmtName)
    return proxy, raw
end
function StructManager:fromTable(t, fmtName)
    local proxy, raw = self:new(fmtName)
    for i,v in pairs(t) do
        proxy[i] = v
    end
    return proxy, raw
end
function StructManager:attach(t, fmtName)
    local raw = Memory:CreateAddr(self:sizeOf(fmtName))
    local dataCpy = {}
    setmetatable(t, nil)
    for i,v in pairs(t)do
        dataCpy[i] = v
        t[i] = nil
    end
    t[dataField] = {fmtname = fmtName, raw = raw}
    setmetatable(t, self:makeMetatable())
    for i,v in pairs(dataCpy) do
        t[i] = v
    end
    return raw
end
function StructManager:IsProxy(t)
    local data = self.getData(t)
    if type(data) ~= "table" then return false end
    local hasCorrectData = type(data.fmtname) == "string" and type(data.raw) == "userdata"
    local mt = getmetatable(t)
    local hasMt = mt ~= nil
    if not hasMt then return false end
    local hasIndex = mt.__index == StructManager.Index
    local hasNewIndex = mt.__newindex == StructManager.NewIndex
    local hasPairs = mt.__pairs == StructManager.Pairs
    local hasLen = mt.__len == StructManager.Len
    local hasToString = mt.__tostring == StructManager.ToString
    return hasCorrectData and hasIndex and hasNewIndex and hasPairs and hasLen and hasToString
end