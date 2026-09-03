local wapi = require("WPToolkit.Mod.WApiMgr")
local win = wapi:GetWinAPI()
win.QueryPerformanceFrequency = Memory:GetFunctionFromDll("kernel32.dll", "QueryPerformanceFrequency", ValueTypes.VT_BOOLEAN, {ValueTypes.VT_USERDATA})
win.QueryPerformanceCounter = Memory:GetFunctionFromDll("kernel32.dll", "QueryPerformanceCounter", ValueTypes.VT_BOOLEAN, {ValueTypes.VT_USERDATA})
win.CreateThread = Memory:GetFunctionFromDll("kernel32.dll", "CreateThread", ValueTypes.VT_USERDATA, {
 ValueTypes.VT_USERDATA,
 ValueTypes.VT_INTEGER,
 {t = ValueTypes.VT_FUNCTION, ret = ValueTypes.VT_INTEGER, argTypes = {ValueTypes.VT_USERDATA}},
 ValueTypes.VT_USERDATA,
 ValueTypes.VT_INTEGER,
 ValueTypes.VT_USERDATA})
LuaTimer = {}
StructManager:addFormat("LuaTimer::AsyncTimer", {
    thread = { type = ValueTypes.VT_USERDATA, size = 8, offset = 0x0 },
    interval = { type = ValueTypes.VT_INTEGER, size = 8, offset = 0x8 },
    next_deadline = { type = ValueTypes.VT_INTEGER, size = 8, offset = 0x10 },
    count = { type = ValueTypes.VT_INTEGER, size = 4, offset = 0x18 },
    repeat_count = { type = ValueTypes.VT_INTEGER, size = 4, offset = 0x1C },
    callback = { type = ValueTypes.VT_INTEGER, size = 8, offset = 0x20 },
})
local timers = {}
local callbacks = {}
function LuaTimer.SleepUntil(ms)
    local remaining = ms - LuaTimer.getTimeMs()
    while remaining > 0 do
        Sleep(remaining)
        remaining = ms - LuaTimer.getTimeMs()
    end
end
function LuaTimer.cancelTimer(timerId)
    if timers[timerId] then
        timers[timerId] = nil
    end
end
function LuaTimer.getTimer(timerId)
       return timers[timerId]    
end
local function asyncThreadTimer(timerId)
    local asyncTimer = LuaTimer.getTimer(timerId)
    if asyncTimer then
        for _ = 1, asyncTimer.repeat_count > 0 and asyncTimer.repeat_count or math.huge do
            if not timers[timerId] then
                break
            end
            asyncTimer.next_deadline = asyncTimer.next_deadline + asyncTimer.interval
            LuaTimer.SleepUntil(asyncTimer.next_deadline)
            asyncTimer.count = asyncTimer.count + 1
            local callback = callbacks[asyncTimer.callback]
            if callback then
                callback(asyncTimer.count)
            end
            if asyncTimer.repeat_count > 0 and asyncTimer.count >= asyncTimer.repeat_count then
                LuaTimer.cancelTimer(timerId)
                break
            end
        end
    end
    return 0
end
function LuaTimer.scheduleTimer(callback, delay_ms, repeatCount)
    repeatCount = repeatCount or 0
    local AsyncTimer, timerId = StructManager:new("LuaTimer::AsyncTimer")
    table.insert(callbacks, callback)
    AsyncTimer.callback = #callbacks
    AsyncTimer.interval = delay_ms
    AsyncTimer.count = 0
    AsyncTimer.repeat_count = repeatCount
    AsyncTimer.next_deadline = LuaTimer.getTimeMs()
    timers[timerId] = AsyncTimer
    AsyncTimer.thread = win.CreateThread(nil, 0, asyncThreadTimer, timerId, 0, nil)
    return timerId
end
function LuaTimer.scheduleSyncTimer(callback, delay_ms, repeatCount)
    repeatCount = repeatCount or 0
    local count = 0
    local next = LuaTimer.getTimeMs()
    for _ = 1, repeatCount > 0 and repeatCount or math.huge do
        next = next + delay_ms
        LuaTimer.SleepUntil(next)
        count = count + 1
        callback(count)
        if repeatCount > 0 and count >= repeatCount then
            break
        end
    end
end
function LuaTimer.cancelAllTimers()
    for timerId in pairs(timers) do
        LuaTimer.cancelTimer(timerId)
    end
end
local frequency_m = Memory.VirtualWin:VirtualAlloc(8, 0x4)
win.QueryPerformanceFrequency(frequency_m)
local frequency = Memory:ReadInteger(frequency_m, 8)
Memory.VirtualWin:VirtualFree(frequency_m)
local function realGetTimeMs(counter)
    win.QueryPerformanceCounter(counter)
    local res =  Memory:ReadInteger(counter, 8) * 1000 // frequency
    return res
end
local realGetTimeMs_f, realGetTimeMs_m = NativeFunctionManager:GetCallStackFunc(8, realGetTimeMs)
LuaTimer.getTimeMs = realGetTimeMs_f
setmetatable(LuaTimer, {
__gc = function ()
    LuaTimer.cancelAllTimers()
    Memory.VirtualWin:VirtualFree(realGetTimeMs_m)
end
})