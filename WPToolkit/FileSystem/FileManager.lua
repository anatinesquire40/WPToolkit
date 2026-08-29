local wapi = require("WPToolkit.Mod.WApiMgr")
local win = wapi:GetWinAPI()
FileManager = {
    INVALID_FILE_ATTRIBUTES = 0xFFFFFFFF
}
StructManager:addFormat("WIN32_FILE_ATTRIBUTE_DATA", {
    dwFileAttributes    = { offset = 0x0, size = 4, type = ValueTypes.VT_INTEGER },
    ftCreationTime      = { offset = 0x4, size = 8, type = ValueTypes.VT_INTEGER },
    ftLastAccessTime    = { offset = 0xC, size = 8, type = ValueTypes.VT_INTEGER },
    ftLastWriteTime     = { offset = 0x14, size = 8, type = ValueTypes.VT_INTEGER },
    nFileSizeHigh       = { offset = 0x1C, size = 4, type = ValueTypes.VT_INTEGER },
    nFileSizeLow        = { offset = 0x20, size = 4, type = ValueTypes.VT_INTEGER },
}, 4)
win.GetFileAttributes = Memory:GetFunctionFromDll("kernel32.dll", "GetFileAttributesA", ValueTypes.VT_INTEGER, {ValueTypes.VT_STRING})
win.SetFileAttributes = Memory:GetFunctionFromDll("kernel32.dll", "SetFileAttributesA", ValueTypes.VT_BOOLEAN, {ValueTypes.VT_STRING, ValueTypes.VT_INTEGER})
win.GetFileAttributesEx = Memory:GetFunctionFromDll("kernel32.dll", "GetFileAttributesExA", ValueTypes.VT_BOOLEAN, {ValueTypes.VT_STRING, ValueTypes.VT_INTEGER, "WIN32_FILE_ATTRIBUTE_DATA"})
function FileManager:readFile(fname)
    local f = assert(io.open(fname, "rb"))
    local text = f:read("a")
    f:close()
    return text
end
function FileManager:writeFile(fname, text)
    local f = assert(io.open(fname, "wb"))
    assert(f:write(text))
    f:close()
end
win.CopyFile = Memory:GetFunctionFromDll("kernel32.dll", "CopyFileA", ValueTypes.VT_BOOLEAN, {ValueTypes.VT_STRING, ValueTypes.VT_STRING, ValueTypes.VT_BOOLEAN})
function FileManager:copyFile(fin, fout)
    return win.CopyFile(fin, fout, false), win.GetLastError()
end
function FileManager:getFileAttributes(fileName)
    local attr = win.GetFileAttributes(fileName)
    if attr == self.INVALID_FILE_ATTRIBUTES then
        return nil, win.GetLastError()
    end
    return attr
end

function FileManager:setFileAttributes(fname, attr)
    local res = win.SetFileAttributes(fname, attr)
    if not res then
        return false, win.GetLastError()
    end
    return true
end
function FileManager:getFileInfo(fname)
    local data = StructManager:new("WIN32_FILE_ATTRIBUTE_DATA")
    assert(win.GetFileAttributesEx(fname, 0, data), "Failed to get file info for " .. fname .. ", error code: " .. win.GetLastError())
    return data
end
function FileManager:getFileSize(fname)
    local data = self:getFileInfo(fname)

    local low = data.nFileSizeLow
    local high = data.nFileSizeHigh

    return (high << 32) | low
end
function FileManager:exists(fileName)
    local attr, err = self:getFileAttributes(fileName)
    return attr ~= nil, err
end
function FileManager:isFile(fileName, attr)
    attr = attr or self:getFileAttributes(fileName)
    if not attr then
        return false
    end
    return (attr & 0x10) == 0
end
function FileManager:isReparsePoint(path)
    local attr = self:getFileAttributes(path)
    return attr and (attr & 0x400) ~= 0
end
function FileManager:deleteFile(fname, force)
    if force then
        self:setFileAttributes(fname, 0)
    end

    local ok, err = os.remove(fname)
    if not ok then
        return false, err
    end

    return true
end