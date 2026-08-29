local registry = debug.getregistry()

local asm = NativeFunctionManager.asmfuncs
local op  = NativeFunctionManager.regop

local func = nil
local nullptr = Num2Addr(0)
local fpushnative = setmetatable({ nullptr }, {
    __gc = function(t)
        if t[1] ~= nullptr then
            Memory.VirtualWin:VirtualFree(t[1])
            t[1] = nullptr
        end
    end
})

local function init_pushf()
    local lines = NativeFunctionManager:newASM() -- int pushf(lua_State *L)

    local lua_pushcclosure = LuaInfo.neededLAPIFuncs.lua_pushcclosure
    local lua_touserdata   = LuaInfo.neededLAPIFuncs.lua_touserdata
    local lua_gettop   = LuaInfo.neededLAPIFuncs.lua_gettop
    -- Preserve registers
    lines:addLine(asm.push(op.reg("rsi"))) -- lua_State*
    lines:addLine(asm.push(op.reg("rbx"))) -- lua_CFunction

    -- lua_touserdata(L, 1)
    lines:addLine(asm.mov(op.reg("rsi"), op.reg("rcx")))
    lines:addLine(asm.mov(op.reg("rdx"), op.imm(1, 32)))
    lines:addLine(asm.mov(op.reg("rax"), op.imm(lua_touserdata, 64)))
    lines:generateCallRaxASM()

    lines:addLine(asm.mov(op.reg("rbx"), op.reg("rax")))
    lines:addLine(asm.mov(op.reg("rcx"), op.reg("rsi")))
    lines:addLine(asm.mov(op.reg("rax"), op.imm(lua_gettop, 64)))
    lines:generateCallRaxASM()
    lines:addLine(asm.sub(op.reg("rax"), op.imm(1, 8)))
    -- lua_pushcclosure(L, func, nupvalues)
    lines:addLine(asm.mov(op.reg("rcx"), op.reg("rsi")))
    lines:addLine(asm.mov(op.reg("rdx"), op.reg("rbx")))
    lines:addLine(asm.mov(op.reg("r8"), op.reg("rax")))
    lines:addLine(asm.mov(op.reg("rax"), op.imm(lua_pushcclosure, 64)))
    lines:generateCallRaxASM()

    -- Restore registers
    lines:addLine(asm.pop(op.reg("rbx")))
    lines:addLine(asm.pop(op.reg("rsi")))

    lines:addLine(asm.mov(op.reg("rax"), op.imm(1, 8)))
    lines:addLine(asm.ret)

    local code = table.concat(lines.codef)
    local len = #code

    fpushnative[1] = Memory.VirtualWin:VirtualAlloc(len, 0x4)
    Memory:WriteString(fpushnative[1], code, len)
    Memory.VirtualWin:VirtualProtect(fpushnative[1], len, 0x20)

    -------------------------------------------------------------------------

    local linespush = NativeFunctionManager:newASM()

    linespush.L = LuaInfo:getCurThread()
    linespush:generateGetL()

    lines.lapi.pushcfunction(linespush, fpushnative[1], 0)
    lines.lapi.rawseti(linespush, LuaInfo:getRegistryIndex(), #registry + 1)

    linespush:addLine(asm.ret)

    local codepush = table.concat(linespush.codef)
    local lenpush = #codepush

    local mempush = Memory.VirtualWin:VirtualAlloc(lenpush, 0x4)

    Memory:WriteString(mempush, codepush, lenpush)
    Memory.VirtualWin:VirtualProtect(mempush, lenpush, 0x20)

    Memory:CallFunction(mempush, ValueTypes.VT_NIL)

    Memory.VirtualWin:VirtualFree(mempush)
end

local function get_pushf()
    if not func then
        init_pushf()

        func = registry[#registry]
        table.remove(registry, #registry)
    end

    return func
end

function NativeFunctionManager:pushNativeCFunction(f_addr, ...)
    return get_pushf()(f_addr, ...)
end