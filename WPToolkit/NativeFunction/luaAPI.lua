local lapi = {}
NativeFunctionManager.lapi = lapi
local function movlfunc(self, fname)
    local faddr = LuaInfo.neededLAPIFuncs[fname]

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rax"),
        self.regop.imm(faddr, 64)
    ))
end

function lapi.rotate(self, n1, n2)
    self:generateGetL()

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rdx"),
        self.regop.imm(n1, 32)
    ))

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("r8"),
        self.regop.imm(n2, 32)
    ))

    movlfunc(self, "lua_rotate")

    self:generateCallRaxASM()
end

function lapi.pop(self, i)
    self:generateGetL()

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rdx"),
        self.regop.imm(-(i)-1, 32)
    ))

    movlfunc(self, "lua_settop")

    self:generateCallRaxASM()
end
function lapi.rawgeti(self, tablei, i)
    self:generateGetL()

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rdx"),
        self.regop.imm(tablei, 32)
    ))

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("r8"),
        self.regop.imm(i, 64)
    ))

    movlfunc(self, "lua_rawgeti")

    self:generateCallRaxASM()
end
function lapi.rawseti(self, tablei, i)
    self:generateGetL()

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rdx"),
        self.regop.imm(tablei, 32)
    ))

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("r8"),
        self.regop.imm(i, 64)
    ))

    movlfunc(self, "lua_rawseti")

    self:generateCallRaxASM()
end
function lapi.pushcfunction(self, func, upvalues)
    upvalues = upvalues or 0
    self:generateGetL()

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rdx"),
        self.regop.imm(func, 64)
    ))

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("r8"),
        self.regop.imm(upvalues, 32)
    ))

    movlfunc(self, "lua_pushcclosure")

    self:generateCallRaxASM()
end
function lapi.call(self, numargs, retnum)
    local op = 40 + self.alignstack

    self:generateGetL()

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rdx"),
        self.regop.imm(numargs, 32)
    ))

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("r8"),
        self.regop.imm(retnum, 32)
    ))

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("r9"),
        self.regop.imm(0, 64)
    ))

    self:addLine(self.asmfuncs.sub(
        self.regop.reg("rsp"),
        self.regop.imm(op, 32)
    ))

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rax"),
        self.regop.imm(0, 64)
    ))

    self:addLine(self.asmfuncs.mov(
        self.regop.mem("rsp", 32, 64),
        self.regop.reg("rax")
    ))

    movlfunc(self, "lua_callk")

    self:addLine(self.asmfuncs.call(
        self.regop.reg("rax")
    ))

    self:addLine(self.asmfuncs.add(
        self.regop.reg("rsp"),
        self.regop.imm(op, 32)
    ))
end
function lapi.rawlen(self, tablei)
    self:generateGetL()

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rdx"),
        self.regop.imm(tablei, 32)
    ))

    movlfunc(self, "lua_rawlen")

    self:generateCallRaxASM()
end
function lapi.lua_touserdata(self, index)
    self:generateGetL()

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rdx"),
        self.regop.imm(index, 32)
    ))

    movlfunc(self, "lua_touserdata")

    self:generateCallRaxASM()
end
function lapi.lua_pushvalue(self, index)
    self:generateGetL()

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rdx"),
        self.regop.imm(index, 32)
    ))

    movlfunc(self, "lua_pushvalue")

    self:generateCallRaxASM()
    
end