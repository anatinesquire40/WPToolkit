local debugStrings = {}
local printfAddr = nil
setmetatable(debugStrings, {__gc = function (t)
    for i,v in pairs(t) do
        Memory.VirtualWin:VirtualFree(v)
        t[i] = nil
    end
end})
local function getPrintfAddr()
    if not printfAddr then
        local msvcrt = Library.getModule("msvcrt.dll")
        printfAddr = GetProcAddress(msvcrt, "printf")
    end
    return printfAddr
end

function NativeFunctionManager:debugRegStack(regName, t)
    local dstr = "[ASM] [Debug] Value print for %s\n"

    local isreal = t == ValueTypes.VT_DOUBLE or t == ValueTypes.VT_FLOAT

    if isreal then
        dstr = dstr .. "[ASM] [Debug] Decimal Value: %f\n"
    else
        dstr = dstr .. "[ASM] [Debug] Hex Value: %016llX\n[ASM] [Debug] Decimal Value: %lld\n"
    end

    local offset

    if type(regName) == "number" then
        offset = regName
        regName = string.format("[rsp+%d]", regName)
    end

    local straddr = Memory.VirtualWin:VirtualAlloc(#dstr + 1, 0x4)
    local regNameAddr = Memory.VirtualWin:VirtualAlloc(#regName + 1, 0x4)

    Memory:WriteString(regNameAddr, regName .. "\0", #regName + 1)
    Memory:WriteString(straddr, dstr .. "\0", #dstr + 1)

    table.insert(debugStrings, straddr)
    table.insert(debugStrings, regNameAddr)
    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rcx"),
        self.regop.imm(straddr, 64)
    ))

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rdx"),
        self.regop.imm(regNameAddr, 64)
    ))

    local value

    if offset then
        value = self.regop.mem(
            "rsp",
            offset,
            64
        )
    else
        value = self.regop.reg(regName)
    end

    if t == ValueTypes.VT_FLOAT then
        self:addLine(self.asmfuncs.mov(
            self.regop.reg("eax"),
            value
        ))

        self:addLine(self.asmfuncs.mov(
            self.regop.xmm("xmm0"),
            self.regop.reg("eax")
        ))

        self:addLine(self.asmfuncs.cvtsd2ss(
            self.regop.xmm("xmm0"),
            self.regop.xmm("xmm0")
        ))

        self:addLine(self.asmfuncs.mov(
            self.regop.reg("r8"),
            self.regop.xmm("xmm0")
        ))
    else
        self:addLine(self.asmfuncs.mov(
            self.regop.reg("r8"),
            value
        ))
    end

    if not isreal then
        self:addLine(self.asmfuncs.mov(
            self.regop.reg("r9"),
            value
        ))
    end

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rax"),
        self.regop.imm(getPrintfAddr(), 64)
    ))

    self:generateCallRaxASM()
end
function NativeFunctionManager:debugMsg(msg)
    local straddr = Memory.VirtualWin:VirtualAlloc(#msg + 1, 0x4)
    Memory:WriteString(straddr, msg .. "\0", #msg + 1)
    table.insert(debugStrings, straddr)

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rcx"),
        self.regop.imm(straddr, 64)
    ))

    self:addLine(self.asmfuncs.mov(
        self.regop.reg("rax"),
        self.regop.imm(getPrintfAddr(), 64)
    ))

    self:generateCallRaxASM()
end