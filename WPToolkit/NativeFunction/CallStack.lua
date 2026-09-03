local asm = NativeFunctionManager.asmfuncs
local op  = NativeFunctionManager.regop
function NativeFunctionManager:AlignStack(stack)
    local oldstack = stack
    local align = stack % 16
    if align == 8 then
        return 0
    end
    stack = align ~= 0 and (stack + (16 - align)) or stack

    if stack % 16 == 0 then
        stack = stack + 8
    end

    return stack - oldstack
end
function NativeFunctionManager:GetCallStackFunc(...)
    local args = table.pack(...)
    local lua_pushlightuserdata = LuaInfo.neededLAPIFuncs.lua_pushlightuserdata
    local lua_callk             = LuaInfo.neededLAPIFuncs.lua_callk
    local lua_gettop            = LuaInfo.neededLAPIFuncs.lua_gettop
    local lines = self:newASM()
------------------------------------------------------------------------
-- Prologue
------------------------------------------------------------------------

    lines:addLine(asm.push(op.reg("rbp")))
    lines:addLine(asm.push(op.reg("rbx")))
    lines:addLine(asm.mov(
        op.reg("rbp"),
        op.reg("rcx")
    ))


local stackadded = 16
for i = 1, #args - 1 do
    local size = args[i]

    if size > 0 then
            stackadded = stackadded + size
    end
end
if (stackadded - 16) > 0 then
    lines:addLine(asm.sub(
        op.reg("rsp"),
        op.imm(stackadded - 16, 64)
    ))

    lines.alignstack = self:AlignStack(stackadded+40)
end
------------------------------------------------------------------------
-- oldtop = lua_gettop(L)
------------------------------------------------------------------------
lines:addLine(asm.mov(op.reg("rcx"), op.reg("rbp")))
lines:addLine(asm.mov(op.reg("rax"), op.imm(lua_gettop, 64)))
lines:generateCallRaxASM()
lines:addLine(asm.sub(
    op.reg("rax"),
    op.imm(1, 8)
))
lines:addLine(asm.mov(
    op.reg("rbx"),
    op.reg("rax")
))
------------------------------------------------------------------------
-- Push every allocated stack block as lightuserdata
------------------------------------------------------------------------

local offset = 0

for i = 1, #args - 1 do
    local size = args[i]

    if size > 0 then
        lines:addLine(asm.mov(
            op.reg("rcx"),
            op.reg("rbp")
        ))

        lines:addLine(asm.lea(
            op.reg("rdx"),
            op.mem("rsp", offset, 64)
        ))

        lines:addLine(asm.mov(
            op.reg("rax"),
            op.imm(lua_pushlightuserdata, 64)
        ))

        lines:generateCallRaxASM()

        offset = offset + size
    end
end

------------------------------------------------------------------------
-- callback(...)
------------------------------------------------------------------------
lines:addLine(asm.mov(op.reg("rcx"), op.reg("rbp")))
lines:addLine(asm.mov(op.reg("edx"), op.imm(#args - 1, 32)))
lines:addLine(asm.mov(op.reg("r8d"), op.imm(-1, 32))) -- LUA_MULTRET
lines:addLine(asm.mov(op.reg("r9"), op.imm(0, 64))) -- ctx
local align = 40 + lines.alignstack
lines:addLine(asm.sub(op.reg("rsp"), op.imm(align, 8)))
lines:addLine(asm.mov(op.reg("rax"), op.imm(0, 64)))
lines:addLine(asm.mov(op.mem("rsp", 32, 64), op.reg("rax"))) -- kfunction
lines:addLine(asm.mov(op.reg("rax"), op.imm(lua_callk, 64)))
lines:addLine(asm.call(op.reg("rax")))
lines:addLine(asm.add(op.reg("rsp"), op.imm(align, 8)))
------------------------------------------------------------------------
-- return lua_gettop(L) - oldtop
------------------------------------------------------------------------
---
lines:addLine(asm.mov(op.reg("rcx"), op.reg("rbp")))
lines:addLine(asm.mov(op.reg("rax"), op.imm(lua_gettop, 64)))
lines:generateCallRaxASM()
lines:addLine(asm.sub(
    op.reg("rax"),
    op.reg("rbx")
))
------------------------------------------------------------------------
-- Epilogue
------------------------------------------------------------------------

if stackadded ~= 0 then
    lines:addLine(asm.add(
        op.reg("rsp"),
        op.imm(stackadded - 16, 64)
    ))
end
lines:addLine(asm.pop(op.reg("rbx")))
lines:addLine(asm.pop(op.reg("rbp")))

lines:addLine(asm.ret)

local code = table.concat(lines.codef)
local len = #code
local addr = Memory.VirtualWin:VirtualAlloc(len, 0x4)
Memory:WriteString(addr, code, len)
Memory.VirtualWin:VirtualProtect(addr, len, 0x20)
local func = self:pushNativeCFunction(addr)
return function()
    return func(args[#args])
end, addr
end