local wapi = require("WPToolkit.Mod.WApiMgr")
local win = wapi:GetWinAPI()
PathManager = {
    cleanPath = Memory:CreateBuffer(win.MAX_PATH),
    INVALID_HANDLE_VALUE = Memory:ResolvePointer(-1)
}

StructManager:addFormat("WIN32_FIND_DATAA", {
    dwFileAttributes    = { offset = 0x0,   size = 4,   type = ValueTypes.VT_INTEGER },
    ftCreationTime      = { offset = 0x4,   size = 8,   type = ValueTypes.VT_INTEGER },
    ftLastAccessTime    = { offset = 0xC,   size = 8,   type = ValueTypes.VT_INTEGER },
    ftLastWriteTime     = { offset = 0x14,  size = 8,   type = ValueTypes.VT_INTEGER },
    nFileSizeHigh       = { offset = 0x1C,  size = 4,   type = ValueTypes.VT_INTEGER },
    nFileSizeLow        = { offset = 0x20,  size = 4,   type = ValueTypes.VT_INTEGER },
    dwReserved0         = { offset = 0x24,  size = 4,   type = ValueTypes.VT_INTEGER },
    dwReserved1         = { offset = 0x28,  size = 4,   type = ValueTypes.VT_INTEGER },
    cFileName           = { offset = 0x2C,  size = win.MAX_PATH, type = ValueTypes.VT_STRING },
    cAlternateFileName  = { offset = 0x130, size = 14,  type = ValueTypes.VT_STRING },
})

win.FindFirstFile   = Memory:GetFunctionFromDll("kernel32.dll", "FindFirstFileA", ValueTypes.VT_USERDATA, {ValueTypes.VT_STRING, "WIN32_FIND_DATAA"})
win.FindNextFile    = Memory:GetFunctionFromDll("kernel32.dll", "FindNextFileA",  ValueTypes.VT_BOOLEAN, {ValueTypes.VT_USERDATA, "WIN32_FIND_DATAA"})
win.FindClose       = Memory:GetFunctionFromDll("kernel32.dll", "FindClose",      ValueTypes.VT_BOOLEAN, {ValueTypes.VT_USERDATA})
win.CreateDirectory = Memory:GetFunctionFromDll("kernel32.dll", "CreateDirectoryA", ValueTypes.VT_BOOLEAN, {ValueTypes.VT_STRING, ValueTypes.VT_USERDATA})
win.RemoveDirectory = Memory:GetFunctionFromDll("kernel32.dll", "RemoveDirectoryA", ValueTypes.VT_BOOLEAN, {ValueTypes.VT_STRING})
function PathManager:CheckBackslash(path)
    StringManager.checkStr(path)
    local last = path:sub(-1)
    if last ~= "\\" and last ~= "/" then
        path = path .. "\\"
    end
    return path
end
function PathManager:dirRecursive(path, callback)
    path = self:CheckBackslash(path)
    local findData = StructManager:new("WIN32_FIND_DATAA")
    local hFind = win.FindFirstFile(path .. "*", findData)
    if hFind == self.INVALID_HANDLE_VALUE then
        return false, win.GetLastError()
    end
    repeat
        callback(StringManager.truncAtFirst0(findData.cFileName), findData)
        findData.cFileName = self.cleanPath
    until not win.FindNextFile(hFind, findData)
    win.FindClose(hFind)
    return true
end
function PathManager:createDirectory(path)
    if not win.CreateDirectory(path, Memory.nullptr) then
        return false, win.GetLastError()
    end
    return true
end
function PathManager:dirRecursiveIter(path)
    local fnames = {}
    local suc, err = self:dirRecursive(path, function (fileName)
        table.insert(fnames, fileName)
    end)
    if not suc then
        error(string.format("Error enumerating directory, eror code: %d", err))
    end
    local i = 0
    local ipairsIter = ipairs(fnames)
    return function ()
        local _, val = ipairsIter(fnames, i)
        i = i+1
        return val
    end, fnames, nil
end
function PathManager:GetExePath()
    local data = assert(LoadedDlls:GetLoadedDlls())
    local exePath = data[1].path
    return exePath
end
function PathManager:GetLuaDll()
    local dlls = assert(LoadedDlls:GetLoadedDlls())
    for _, m in ipairs(dlls) do
        local addr = win.GetProcAddress(m.handle, "lua_gettop")
        if addr ~= Memory.nullptr then
            return m.path, m.handle
        end
    end
    return nil
end
function PathManager:CopyFolderContent(bDir, oDir)
    bDir = self:CheckBackslash(bDir)
    oDir = self:CheckBackslash(oDir)
    local function copyRecursive(name, findData)
        if name ~= "." and name ~= ".." then
            local attrs = findData.dwFileAttributes
            local srcPath  = bDir .. name
            local destPath = oDir .. name
            if self:isDirectory(nil, attrs) then
                copyRecursive(srcPath .. "\\", destPath .. "\\")
            elseif FileManager:isFile(nil, attrs) or FileManager:isReparsePoint(srcPath) then
                FileManager:copyFile(srcPath, destPath)
            end
        end
    end
    self:dirRecursive(bDir, copyRecursive)
end
function PathManager:CopyDirectory(bDir, nDir)
    if not self:createDirectory(nDir) then
        return false, win.GetLastError()
    end
    return self:CopyFolderContent(bDir, nDir)
end
function PathManager:DeleteDirectory(dir)
    dir = self:CheckBackslash(dir)
    local function deleteRecursive(name, findData)
       if name ~= "." and name ~= ".." then
            local attrs = findData.dwFileAttributes
            local path = dir .. name
            if self:isDirectory(nil, attrs) then
                self:DeleteDirectory(path)
            elseif FileManager:isFile(nil, attrs) or FileManager:isReparsePoint(path) then
                if not FileManager:deleteFile(path) then
                    assert(FileManager:deleteFile(path, true))
                end
            end
       end
    end
    self:dirRecursive(dir, deleteRecursive)
    win.RemoveDirectory(dir)
end
function PathManager:isDirectory(dirName, attr)
    attr = attr or FileManager:getFileAttributes(dirName)
    if not attr then
        return false
    end
    return (attr & 0x10) ~= 0
end