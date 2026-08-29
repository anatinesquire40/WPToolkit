local function isReal(t)
    return t == ValueTypes.VT_DOUBLE or t == ValueTypes.VT_FLOAT
end
local asm = NativeFunctionManager.asmfuncs
local regop = NativeFunctionManager.regop
local stackLocs = {"rbx", "r12", "r13", "r15"}
local argsSave = {
    {
        asm.mov(
            regop.reg("rbx"),
            regop.reg("rcx")
        ),
        asm.mov(
            regop.reg("rbx"),
            regop.xmm("xmm0")
        )
    },

    {
        asm.mov(
            regop.reg("r12"),
            regop.reg("rdx")
        ),
        asm.mov(
            regop.reg("r12"),
            regop.xmm("xmm1")
        )
    },

    {
        asm.mov(
            regop.reg("r13"),
            regop.reg("r8")
        ),
        asm.mov(
            regop.reg("r13"),
            regop.xmm("xmm2")
        )
    },

    {
        asm.mov(
            regop.reg("r15"),
            regop.reg("r9")
        ),
        asm.mov(
            regop.reg("r15"),
            regop.xmm("xmm3")
        )
    }
}   

local function getArgStack(self, i)
    if i <= 4 then
        return nil
    end

    return self.regop.mem(
        "rsp",
        self.pushAbsolute + (i - 4) * 8,
        64
    )
end

local function getRdxArgType(self, i, t)
    if isReal(t) then
        return self.regop.xmm("xmm1")
    end

    if i > 4 then
        local bits = self.argFormated[i].bits

        if bits == 8 or t == ValueTypes.VT_BOOLEAN then
            return self.regop.reg("dl")

        elseif bits == 16 then
            return self.regop.reg("dx")

        elseif bits == 32 then
            return self.regop.reg("edx")

        else
            return self.regop.reg("rdx")
        end
    else
        return self.regop.reg("rdx")
    end
end
local function getValueArgType(self, i)
    if i < 5 then
        return self.regop.reg(stackLocs[i])
    else
        return getArgStack(self, i)
    end
end

function NativeFunctionManager:generateGetL()
    self:addLine(asm.mov(
        self.regop.reg("rcx"),
        self.regop.imm(self.L, 64)
    ))
end

function NativeFunctionManager:generateCallRaxASM()
    local op = 40 + self.alignstack

    self:addLine(asm.sub(
        self.regop.reg("rsp"),
        self.regop.imm(op, 8)
    ))

    self:addLine(asm.call(
        self.regop.reg("rax")
    ))

    self:addLine(asm.add(
        self.regop.reg("rsp"),
        self.regop.imm(op, 8)
    ))
end

function NativeFunctionManager:generateHeaderASM()
    for i, arg in ipairs(self.argFormated) do
        if i > 4 then
            break
        end

        local h = argsSave[i]
        local t = arg.type
        local fh = 1

        if isReal(t) then
            fh = 2
        end

        local reg = stackLocs[i]

        self:addLine(asm.push(
            self.regop.reg(reg)
        ))

        self.pushOffset = self.pushOffset + 8
        self.alignstack = self.alignstack - 8

        self:addLine(h[fh])
    end

    self.pushAbsolute = self.pushOffset + 32
end


function NativeFunctionManager:generateGetFunc()
    self.lapi.rawgeti(self, LuaInfo:getRegistryIndex(), self.tregi)
    self.lapi.rawgeti(self, -1, self.findex)
    self.lapi.rotate(self, -2, -1)
    self.lapi.pop(self, 1)
end


function NativeFunctionManager:generatePushArgsASM()
    local lua_pushxxxxmap = LuaInfo:GetPusherAndToMap()

    for i, arg in ipairs(self.argFormated) do
        local t = arg.type
        local lapif = lua_pushxxxxmap[t]

        if not lapif then
            error(
                string.format(
                    "Failed making a NativeCallback: in %d arg, %s is not supported!\n%s",
                    i,
                    t,
                    self:getFormatSupportedArgTypes()
                ),
                4
            )
        end

        if not isReal(t) then
            self:addLine(asm.clean(
                self.regop.reg("rdx")
            ))
        end


        local rdx = getRdxArgType(self, i, t)
        local value = getValueArgType(self, i)

        self:generateGetL()

        self:addLine(asm.mov(
            rdx,
            value
        ))

        if t == ValueTypes.VT_FLOAT then
            self:addLine(asm.cvtss2sd(
                self.regop.xmm("xmm1"),
                self.regop.xmm("xmm1")
            ))
        end

        self:addLine(asm.mov(
            self.regop.reg("rax"),
            self.regop.imm(lapif, 64)
        ))

        self:generateCallRaxASM()
    end
end


function NativeFunctionManager:generateReturnASM()
    if not self.hasRet then
        return
    end

    local _, lua_toxxxxmap = LuaInfo:GetPusherAndToMap()

    local t = self.argFormated.Ret.type
    local addr = Memory:ResolvePointer(lua_toxxxxmap[t])

    self:generateGetL()

    self:addLine(asm.mov(
        self.regop.reg("rdx"),
        self.regop.imm(-1, 64)
    ))

    if self.ThirdArgMap[t] then
        self:addLine(asm.mov(
            self.regop.reg("r8"),
            self.regop.imm(0, 64)
        ))
    end

    self:addLine(asm.mov(
        self.regop.reg("rax"),
        self.regop.imm(addr, 64)
    ))

    self:generateCallRaxASM()

    if t == ValueTypes.VT_FLOAT then
        self:addLine(asm.cvtsd2ss(
            self.regop.xmm("xmm0"),
            self.regop.xmm("xmm0")
        ))
    end
end


function NativeFunctionManager:generateBottomASM()
    self:addLine(asm.mov(
        self.regop.reg("rbx"),
        self.regop.reg("rax")
    ))

    self.lapi.pop(self, 1)

    self:addLine(asm.mov(
        self.regop.reg("rax"),
        self.regop.reg("rbx")
    ))

    local i = self.pushOffset / 8

    while i > 0 do
        self:addLine(asm.pop(
            self.regop.reg(stackLocs[i])
        ))

        i = i - 1
    end

    self:addLine(asm.ret)
end