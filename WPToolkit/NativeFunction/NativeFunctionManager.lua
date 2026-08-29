local wapi = require("WPToolkit.Mod.WApiMgr")
local win = wapi:GetWinAPI()
win.FlushInstructionCache = win.Addr2Val(win.GetProcAddress(win.GetModuleHandle("kernel32.dll"), "FlushInstructionCache"), ValueTypes.VT_BOOLEAN, {ValueTypes.VT_USERDATA, ValueTypes.VT_USERDATA, ValueTypes.VT_INTEGER})
local function gcfree(t)
    for _, v in pairs(t) do
        Memory.VirtualWin:VirtualFree(v)
    end
end

local function cachefunc(addr, len)
    return win.FlushInstructionCache(win.GetCurrentProcess(), addr, len)
end
local callback_cache = setmetatable({}, {__gc = gcfree})
NativeFunctionManager = {}
--Reverse Function Bridge
function NativeFunctionManager:CreateNativeCallback(...)
    self = self:new(...)
    return self:GenerateTrampoline(), self
end

function NativeFunctionManager:addLine(bin)
    table.insert(self.codef, bin)
end
local function makeCacheKey(self, ret, argTypes)
    local hash = self.findex

    hash = (hash << 5) ~ (hash + ret)
    for i = 1, #argTypes do
        local v = argTypes[i]
        hash = hash ~ (v + (i << 3))
        hash = (hash << 7) ~ (hash >> 3)
    end

    return hash
end
function NativeFunctionManager:new(f, ret, argTypes)
    self = setmetatable({}, {__index = NativeFunctionManager})
    self.nargs = #argTypes
    self.pushOffset = 0
    self.alignstack = 32
    self.pushAbsolute = 0
    self.codef = {}
    self.hasRet, self.argFormated = self:FormatArgs(ret, argTypes)
    self.findex = self:storeLuaFunction(f)
    self.cachekey = makeCacheKey(self, ret, argTypes)
    self.L = LuaInfo:getCurThread()
    return self
end
function NativeFunctionManager:newASM()
    self = setmetatable({}, {__index = NativeFunctionManager})
    self.pushOffset = 0
    self.alignstack = 0
    self.pushAbsolute = 0
    self.codef = {}
    return self
end
function NativeFunctionManager:close()
    if not self.cachekey then
        return
    end
    local addr = callback_cache[self.cachekey]

    if addr then
        Memory.VirtualWin:VirtualFree(addr)
        callback_cache[self.cachekey] = nil
    end

    if self.findex then
        self:removeLuaFunction(self.findex)
        self.findex = nil
    end
    self.cachekey = nil
end
function NativeFunctionManager:GenerateTrampoline()
    local cached = callback_cache[self.cachekey]
    if cached then
        return cached
    end
    LuaInfo:UpdateLuaAPIAddrs()
    self:generateHeaderASM()
    self:generateGetFunc()
    self:generatePushArgsASM()
    self.lapi.call(self, self.nargs, 1)
    self:generateReturnASM()
    self:generateBottomASM()
    local code = table.concat(self.codef)
    local fncSize = #code
    local finalAddr = Memory.VirtualWin:VirtualAlloc(fncSize, 0x4)
    Memory:WriteString(finalAddr, code, fncSize)
    Memory.VirtualWin:VirtualProtect(finalAddr, fncSize, 0x20)
    callback_cache[self.cachekey] = finalAddr
    cachefunc(finalAddr, fncSize)
    return finalAddr, fncSize
end
--Forward Function Bridge
function NativeFunctionManager.LuaCall(faddr, argtypes, args, nargs)
    local stackargs = 0x20 + ((nargs > 4) and (nargs - 4) * 8 or 0)

    local self = NativeFunctionManager:newASM()
    stackargs = stackargs + self:AlignStack(stackargs)
    local asm = self.asmfuncs
    local op = self.regop

    self:addLine(asm.sub(
        op.reg("rsp"),
        op.imm(stackargs, 32)
    ))

    local intRegs = {"rcx", "rdx", "r8", "r9"}
    local xmmRegs = {"xmm0", "xmm1", "xmm2", "xmm3"}

    for i = 1, nargs do
        local isDouble = argtypes[i] == ValueTypes.VT_DOUBLE
        local isFloat  = argtypes[i] == ValueTypes.VT_FLOAT

        if i <= 4 then
            if isDouble then
                self:addLine(asm.mov(
                    op.reg("rax"),
                    op.imm(args[i], 64)
                ))

                self:addLine(asm.mov(
                    op.xmm(xmmRegs[i]),
                    op.reg("rax")
                ))

            elseif isFloat then
                self:addLine(asm.mov(
                    op.reg("eax"),
                    op.imm(args[i], 32)
                ))

                self:addLine(asm.mov(
                    op.xmm(xmmRegs[i]),
                    op.reg("eax")
                ))

            else
                self:addLine(asm.mov(
                    op.reg(intRegs[i]),
                    op.imm(args[i], 64)
                ))
            end

        else
            local off = 0x20 + (i - 5) * 8

            if isDouble then
                self:addLine(asm.mov(
                    op.reg("rax"),
                    op.imm(args[i], 64)
                ))

                self:addLine(asm.mov(
                    op.mem("rsp", off, 64),
                    op.reg("rax")
                ))

            elseif isFloat then
                self:addLine(asm.mov(
                    op.reg("eax"),
                    op.imm(args[i], 32)
                ))

                self:addLine(asm.mov(
                    op.mem("rsp", off, 32),
                    op.reg("eax")
                ))

            else
                self:addLine(asm.mov(
                    op.reg("rax"),
                    op.imm(args[i], 64)
                ))

                self:addLine(asm.mov(
                    op.mem("rsp", off, 64),
                    op.reg("rax")
                ))
            end
        end
    end

    self:addLine(asm.mov(
        op.reg("rax"),
        op.imm(faddr, 64)
    ))

    self:addLine(asm.call(
        op.reg("rax")
    ))

    self:addLine(asm.add(
        op.reg("rsp"),
        op.imm(stackargs, 32)
    ))

    self:addLine(asm.ret)

    local inst = table.concat(self.codef)
    local len = #inst --without \0
    local trampoline = Memory.VirtualWin:VirtualAlloc(len, 0x4)
    Memory:WriteString(trampoline, inst, len)
    Memory.VirtualWin:VirtualProtect(trampoline, len, 0x20)

    cachefunc(trampoline, len)
    return trampoline
end