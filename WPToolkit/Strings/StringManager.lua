local asm = NativeFunctionManager.asmfuncs
local op  = NativeFunctionManager.regop
StringManager = {}
function StringManager:checkStr()
    assert(type(self)=="string")
end
function StringManager:truncAtFirst0()
    local zeroPos = self:find"\0"
    if zeroPos then
        self = self:sub(1, zeroPos - 1)
    end
    return self
end
function StringManager:MergeWithGlbStr()
    setmetatable(string, {__index = StringManager})
end
local funcgetsprt = nil

local fgetnavivestringptr = setmetatable({ Memory.nullptr }, {
    __gc = function(t)
        if t[1] ~= Memory.nullptr then
            Memory.VirtualWin:VirtualFree(t[1])
            t[1] = Memory.nullptr
        end
    end
})

local function init_getptr()
    local lua_tolstring         = LuaInfo.neededLAPIFuncs.lua_tolstring
    local lua_pushlightuserdata = LuaInfo.neededLAPIFuncs.lua_pushlightuserdata

    local lines = NativeFunctionManager:newASM()
    local asm = NativeFunctionManager.asmfuncs
    local op  = NativeFunctionManager.regop

    ------------------------------------------------------------------------
    -- Prologue
    ------------------------------------------------------------------------

    lines:addLine(asm.push(op.reg("rbp")))
    lines:addLine(asm.push(op.reg("rbx")))

    lines:addLine(asm.mov(
        op.reg("rbp"),
        op.reg("rcx")
    ))

    ------------------------------------------------------------------------
    -- lua_tolstring(L, 1, NULL)
    --
    -- RCX = L
    -- RDX = index
    -- R8  = size_t *len = NULL
    ------------------------------------------------------------------------

    lines:addLine(asm.mov(
        op.reg("rcx"),
        op.reg("rbp")
    ))

    lines:addLine(asm.mov(
        op.reg("rdx"),
        op.imm(1, 32)
    ))

    lines:addLine(asm.mov(
        op.reg("r8"),
        op.imm(0, 64)
    ))

    lines:addLine(asm.mov(
        op.reg("rax"),
        op.imm(lua_tolstring, 64)
    ))

    lines:generateCallRaxASM()

    ------------------------------------------------------------------------
    -- RAX = const char *
    --
    -- lua_pushlightuserdata(L, RAX)
    ------------------------------------------------------------------------

    lines:addLine(asm.mov(
        op.reg("rdx"),
        op.reg("rax")
    ))

    lines:addLine(asm.mov(
        op.reg("rcx"),
        op.reg("rbp")
    ))

    lines:addLine(asm.mov(
        op.reg("rax"),
        op.imm(lua_pushlightuserdata, 64)
    ))

    lines:generateCallRaxASM()

    ------------------------------------------------------------------------
    -- return 1
    ------------------------------------------------------------------------

    lines:addLine(asm.mov(
        op.reg("rax"),
        op.imm(1, 32)
    ))

    ------------------------------------------------------------------------
    -- Epilogue
    ------------------------------------------------------------------------

    lines:addLine(asm.pop(op.reg("rbx")))
    lines:addLine(asm.pop(op.reg("rbp")))
    lines:addLine(asm.ret)

    local code = table.concat(lines.codef)
    local len = #code

    local addr = Memory.VirtualWin:VirtualAlloc(len, 0x4)
    Memory:WriteString(addr, code, len)
    Memory.VirtualWin:VirtualProtect(addr, len, 0x20)

    fgetnavivestringptr[1] = addr

    funcgetsprt = NativeFunctionManager:pushNativeCFunction(addr, 0)
end

function StringManager:getPtr()
    if not funcgetsprt then
        init_getptr()
    end
    return funcgetsprt(self)
end