local function CopyTextUTF8(copyString, hWnd)
    if not copyString then
        return false, "No string input."
    end
    if not OpenClipboard(hWnd) then
        return false, "Couldn't open clipboard"
    end

    EmptyClipboard()

    local work, wstring, _, bytelen = pcall(function()
        return WideCharManager:Encode(copyString)
    end)
    if not work then
        CloseClipboard()
        return false, "Conversion failed: " .. wstring
    end

    local hMem = GlobalAlloc(GMEM_MOVEABLE, bytelen)
    local bufPtr = GlobalLock(hMem)
    if not bufPtr then
        GlobalFree(hMem)
        CloseClipboard()
        return false, "Couldn't lock global memory"
    end
    Memory:WriteAddr(bufPtr, wstring, bytelen)
    GlobalUnlock(hMem)

    if not SetClipboardData(CF_UNICODETEXT, hMem) then
        GlobalFree(hMem)
        CloseClipboard()
        return false, "Couldn't set clipboard data"
    end

    CloseClipboard()
    return true
end

Clipboard = {
    CopyTextUTF8 = CopyTextUTF8
}
