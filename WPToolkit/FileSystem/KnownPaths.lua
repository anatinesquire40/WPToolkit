local wapi = require("WPToolkit.Mod.WApiMgr")
local win = wapi:GetWinAPI()
StructManager:addFormat("GUID", {
    Data1 = { offset = 0x0, size = 4, type = ValueTypes.VT_INTEGER },
    Data2 = { offset = 0x4, size = 2, type = ValueTypes.VT_INTEGER },
    Data3 = { offset = 0x6, size = 2, type = ValueTypes.VT_INTEGER },
    Data4 = { offset = 0x8, size = 8, type = ValueTypes.VT_INTEGER, isBigEndian = true },
})
PathManager.KnownFolders = {
    Desktop = "{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}",
    Documents = "{FDD39AD0-238F-46AF-ADB4-6C85480369C7}",
    Downloads = "{374DE290-123F-4565-9164-39C4925E467B}",
    Pictures = "{33E28130-4E1E-4676-835A-98395C3BC3BB}",
    Videos = "{18989B1D-99B5-455B-841C-AB7C74E4DDFC}",
    Music = "{4BD8D571-6D19-48D3-BE97-422220080E43}",
    LocalAppData = "{F1B32785-6FBA-4FCF-9D55-7B8E7F157091}",
    RoamingAppData = "{3EB685DB-65F9-4CF6-A03A-E3EF65729F3D}",
    ProgramData = "{62AB5D82-FDC1-4DC3-A9DD-070D1D495D97}",
    PublicDesktop = "{C4AA340D-F20F-4863-AFEF-F87EF2E6BA25}",
    Templates = "{A63293E8-664E-48DB-A079-DF759E0509F7}",
    Favorites = "{1777F761-68AD-4D8A-87BD-30B759FA33DD}",
    Contacts = "{56784854-C6CB-462B-8169-88E350ACB882}",
    SavedGames = "{4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4}",
    CameraRoll = "{AB5FB87B-7CE2-4F83-915D-550846C9537B}",
    RecordedTV = "{1A6FDBA2-F42D-4358-A798-B74D745926C5}"
}
win.SHGetKnownFolderPath = Memory:GetFunctionFromDll("shell32.dll", "SHGetKnownFolderPath", ValueTypes.VT_INTEGER, {"GUID", ValueTypes.VT_INTEGER, ValueTypes.VT_USERDATA, ValueTypes.VT_USERDATA})
local function folderID2GUID(folderID)
    local clean = folderID:gsub("[{}]", ""):upper()

    local d1 = clean:sub(1,8)
    local d2 = clean:sub(10,13)
    local d3 = clean:sub(15,18)
    local d4a = clean:sub(20,23)
    local d4b = clean:sub(25,36)
    if not d1 then
        error("Invalid GUID format: "..folderID)
    end
    local d4 = d4a .. d4b
    local bin = ""
    for hex in d4:gmatch("..") do
        bin = bin .. string.char(tonumber(hex, 16))
    end
    local d4addr = Memory:CopyString2Addr(bin, 8)

    local GUID = StructManager:new("GUID")
    
    GUID.Data1 = tonumber(d1, 16)
    GUID.Data2 = tonumber(d2, 16)
    GUID.Data3 = tonumber(d3, 16)
    GUID.Data4 = Memory:ReadInteger(d4addr, 8, true)

    return GUID
end

function PathManager:GetKnownFolderPath(folderID)
    local guid = folderID2GUID(folderID)
    if #guid ~= 16 then
        error("Invalid GUID length")
    end
    local pathPtr = Memory:CreateAddr(8)

    local hr = win.SHGetKnownFolderPath(guid, 0, nil, pathPtr)
    if hr ~= 0 then
        error("SHGetKnownFolderPath failed")
    end

    local wideStrIPtr = Memory:ReadInteger(pathPtr, 8)
    local wideStr = Memory:ResolvePointer(wideStrIPtr)
    local path = WideCharManager:Decode(wideStr)
    win.CoTaskMemFree(wideStr)
    return PathManager:CheckBackslash(path)
end