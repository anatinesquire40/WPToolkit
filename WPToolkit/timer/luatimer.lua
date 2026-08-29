LuaTimer = {}

local timers = {}

function LuaTimer.cancelTimer(timerId)
    if timers[timerId] then
        KillTimer(nil, timerId)
        timers[timerId] = nil
    end
end
function LuaTimer.getTimer(timerId)
       return timers[timerId]    
end
function LuaTimer.scheduleTimer(callback, delay_ms, repeatCount)
    repeatCount = repeatCount or 0
    local count = 0
    local timerId

    timerId = SetTimer(nil, 0, delay_ms, function()
        count = count + 1
        callback(count)
        if repeatCount > 0 and count >= repeatCount then
            LuaTimer.cancelTimer(timerId)
        end
    end)

    timers[timerId] = true
    return timerId
end
function LuaTimer.scheduleSyncTimer(callback, delay_ms, repeatCount)
    repeatCount = repeatCount or 0
    local count = 0

    for i = 1, repeatCount > 0 and repeatCount or math.huge do
        Sleep(delay_ms)
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

setmetatable(LuaTimer, {
__gc = function ()
    LuaTimer.cancelAllTimers()
end
})
LuaTimer = LuaTimer
