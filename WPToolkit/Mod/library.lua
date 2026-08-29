local libraryInstances = setmetatable({},{__index = function (t, k)
    local mod = GetModuleHandle(k)
    if mod == Memory.nullptr then
        return nil
    end
    return mod
end})
Library = {}
local function openNew(dllName)
    if libraryInstances[dllName] then
        return false, "Library already loaded: " .. dllName
    end
    local hModule = LoadLibrary(dllName)
    if hModule == nil then
        return false, "Failed to load library: " .. dllName
    end
    libraryInstances[dllName] = hModule
    return true
end
function Library.getModule(dllName)
    local l = libraryInstances[dllName]
    if not l then
        openNew(dllName)
        l = libraryInstances[dllName]
    end
    return l
end
setmetatable(Library, {__gc = function (t)
    for dllName, hModule in pairs(libraryInstances) do
        FreeLibrary(hModule)
        libraryInstances[dllName] = nil
    end

end})