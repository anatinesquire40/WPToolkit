local asmInstructions = {}
local regop = {}
NativeFunctionManager.asmfuncs = asmInstructions
NativeFunctionManager.regop = regop
local list = NativeFunctionManager.InstructionList
local XMM = {
    xmm0=0, xmm1=1, xmm2=2, xmm3=3,
    xmm4=4, xmm5=5, xmm6=6, xmm7=7,
    xmm8=8, xmm9=9, xmm10=10, xmm11=11,
    xmm12=12, xmm13=13, xmm14=14, xmm15=15,
}
local REG64 = {
    rax=0, rcx=1, rdx=2, rbx=3,
    rsp=4, rbp=5, rsi=6, rdi=7,
    r8=8,  r9=9,  r10=10, r11=11,
    r12=12,r13=13,r14=14,r15=15,
}

local REG32 = {
    eax=0, ecx=1, edx=2, ebx=3,
    esp=4, ebp=5, esi=6, edi=7,
    r8d=8,  r9d=9,  r10d=10, r11d=11,
    r12d=12,r13d=13,r14d=14,r15d=15,
}

local REG16 = {
    ax=0, cx=1, dx=2, bx=3,
    sp=4, bp=5, si=6, di=7,
    r8w=8,  r9w=9,  r10w=10, r11w=11,
    r12w=12,r13w=13,r14w=14,r15w=15,
}

local REG8 = {
    al=0, cl=1, dl=2, bl=3,

    spl=4, bpl=5, sil=6, dil=7,

    r8b=8,  r9b=9,  r10b=10, r11b=11,
    r12b=12,r13b=13,r14b=14,r15b=15,
}
local OP_REG = 0
local OP_MEM = 1
local OP_IMM = 2
local OP_XMM = 3
local function getregbits(reg)
    if REG64[reg] then
        return 64
    elseif REG32[reg] then
        return 32
    elseif REG16[reg] then
        return 16
    elseif REG8[reg] then
        return 8
    end

    error(("Unknown register '%s'"):format(tostring(reg)), 2)
end
local function operand(id, bits, value)
      return {
        id = id,
        bits = bits,
        value = value
    }
end

local REG = setmetatable({}, {
    __index = function(_, k)
        return REG64[k]
            or REG32[k]
            or REG16[k]
            or REG8[k]
            or nil
    end
})
function regop.reg(name)
    local r = assert(REG[name], ("Unknown register '%s'"):format(name))
    return operand(OP_REG, getregbits(name), r)
end

function regop.xmm(name)
    local x = assert(XMM[name], ("Unknown XMM register '%s'"):format(name))
    return operand(OP_XMM, 128, x)
end

function regop.imm(value, bits)
    if type(value) == "userdata" then
        value = Memory:ResolvePointer(value)
    end

    assert(type(value) == "number",
        "Immediate value must be a number")

    assert(
        bits == 8 or bits == 16 or bits == 32 or bits == 64,
        "Immediate size must be 8, 16, 32 or 64"
    )

    return operand(OP_IMM, bits, value)
end

function regop.mem(base, disp, bits)
    local b = assert(REG[base], ("Unknown base register '%s'"):format(base))
    return operand(OP_MEM, bits or 0, {
        base = b,
        disp = disp or 0
    })
end
local function rex(w, r, x, b)
    return 0x40
        | (w and 8 or 0)
        | (r and 4 or 0)
        | (x and 2 or 0)
        | (b and 1 or 0)
end

local function modrm(mod, reg, rm)
    return ((mod & 3) << 6)
        | ((reg & 7) << 3)
        | (rm & 7)
end
local function encode_mem(regfield, mem)
    local base = mem.base
    local disp = mem.disp or 0

    local mod, extra, tail
    if disp == 0 and (base & 7) ~= 5 then
        mod, tail = 0, ""

    elseif disp >= -128 and disp <= 127 then
        mod, tail = 1, string.char(disp & 0xFF)

    else
        mod, tail = 2, string.pack("<i4", disp)
    end

    if (base & 7) == 4 then
        extra = "\x24"
    else
        extra = ""
    end

    return string.char(modrm(mod, regfield, base))
        .. extra
        .. tail
end
local MOV_REG8  = 0x88
local MOV_REGX  = 0x89
local SIZE16    = 0x66

local function mov_reg(dst, src)
    local out = {}

    if dst.bits == 16 then
        out[#out+1] = string.char(SIZE16)
    end

    if dst.bits == 64 or dst.value >= 8 or src.value >= 8 then
        out[#out+1] = string.char(
            rex(dst.bits == 64, src.value >= 8, false, dst.value >= 8)
        )
    end

    out[#out+1] = string.char(dst.bits == 8 and MOV_REG8 or MOV_REGX)
    out[#out+1] = string.char(modrm(3, src.value, dst.value))

    return table.concat(out)
end
local MOV_IMM_REG = 0xB8
local MOV_IMM8_REG = 0xB0
local function mov_imm(dst, src)
    local r = assert(dst.value)
    local v = assert(src.value)

    local op, prefix, pack

    if dst.bits == 64 then
        op = MOV_IMM_REG
        prefix = string.char(rex(true, false, false, r >= 8))
        pack = "<i8"

    elseif dst.bits == 32 then
        op = MOV_IMM_REG

        if r >= 8 then
            prefix = string.char(rex(false, false, false, true))
        else
            prefix = nil
        end

    pack = "<i4"

    elseif dst.bits == 16 then
        op = MOV_IMM_REG
        prefix = string.char(SIZE16)

        if r >= 8 then
            prefix = prefix .. string.char(rex(false, false, false, true))
        end

        pack = "<i2"

    elseif dst.bits == 8 then
        op = MOV_IMM8_REG
        prefix = string.char(rex(false, false, false, r >= 8))
        pack = "<i1"

    else
        error("Invalid MOV size")
    end

    local opcode = string.char(op | (r & 7))

    return (prefix or "") .. opcode .. pack:pack(v)
end

local function mov_load(dst, src)
    local d = dst.value
    local m = src.value

    return string.char(
        rex(dst.bits == 64, d >= 8, false, m.base >= 8),
        dst.bits == 64 and 0x8B or 0x8A
    ) .. encode_mem(d, m)
end
local MOV_RM = {
    [8]  = 0x88,
    [16] = 0x89,
    [32] = 0x89,
    [64] = 0x89,
}

local MOV_MR = {
    [8]  = 0x8A,
    [16] = 0x8B,
    [32] = 0x8B,
    [64] = 0x8B,
}
local function mov_store(dst, src)
    local out = {}

    if dst.bits == 16 then
        out[#out+1] = string.char(SIZE16)
    end

    if dst.bits == 64 or src.value >= 8 or dst.value.base >= 8 then
        out[#out+1] = rex(
            dst.bits == 64,
            src.value >= 8,
            false,
            dst.value.base >= 8
        )
    end

    out[#out+1] = MOV_RM[dst.bits]

    local mod = encode_mem(src.value, dst.value)

    return string.char(table.unpack(out)) .. mod
end
local function mov_store_imm(dst, src)
    assert(dst.id == OP_MEM)

    local out = {}

    if dst.bits == 16 then
        out[#out+1] = string.char(SIZE16)
    end

    if dst.bits == 64 then
        out[#out+1] = rex(true, false, false, dst.value.base >= 8)
    end

    -- MOV r/m, imm
    if dst.bits == 8 then
        out[#out+1] = 0xC6
    else
        out[#out+1] = 0xC7
    end
    -- /0 en ModRM
    out[#out+1] = encode_mem(0, dst.value)

    if dst.bits == 8 then
        out[#out+1] = string.pack("<I1", src.value)
    elseif dst.bits == 16 then
        out[#out+1] = string.pack("<I2", src.value)
    elseif dst.bits == 32 then
        out[#out+1] = string.pack("<I4", src.value)
    elseif dst.bits == 64 then
        out[#out+1] = string.pack("<I4", src.value)
    end

    return string.char(table.unpack(out))
end
local function mov_store_xmm(dst, src)
    local out = {}
    local STORE = 0x7E
    if dst.bits == 32 then
        out[#out+1] = string.char(SIZE16)
        out[#out+1] = string.char(rex(false, src.value >= 8, false, dst.value.base >= 8))
        out[#out+1] = string.char(0x0F, STORE)

    elseif dst.bits == 64 then
        out[#out+1] = string.char(SIZE16)
        out[#out+1] = string.char(rex(true, src.value >= 8, false, dst.value.base >= 8))
        out[#out+1] = string.char(0x0F, STORE)

    else
        error("Invalid MOVD/MOVQ store size")
    end

    out[#out+1] = encode_mem(src.value, dst.value)

    return table.concat(out)
end
local function mov_load_xmm(dst, src)
    local out = {}

    out[#out+1] = string.char(SIZE16)

    if dst.bits == 64 then
        out[#out+1] = string.char(rex(true, dst.value >= 8, false, src.value.base >= 8))
    elseif dst.value >= 8 or src.value.base >= 8 then
        out[#out+1] = string.char(rex(false, dst.value >= 8, false, src.value.base >= 8))
    end

    out[#out+1] = string.char(0x0F, 0x6E)
    out[#out+1] = encode_mem(dst.value, src.value)

    return table.concat(out)
end
local function mov_xmm2reg(dst, src)
    local out = {}

    out[#out+1] = string.char(SIZE16)

    if dst.bits == 64 then
        out[#out+1] = string.char(
            rex(true, src.value >= 8, false, dst.value >= 8)
        )
    elseif src.value >= 8 or dst.value >= 8 then
        out[#out+1] = string.char(
            rex(false, src.value >= 8, false, dst.value >= 8)
        )
    end

    out[#out+1] = string.char(0x0F, 0x7E)
    out[#out+1] = string.char(modrm(3, src.value, dst.value))

    return table.concat(out)
end
local function mov_reg2xmm(dst, src)
    local out = {}

    out[#out+1] = string.char(SIZE16)

    if src.bits == 64 then
        out[#out+1] = string.char(
            rex(true, dst.value >= 8, false, src.value >= 8)
        )
    elseif dst.value >= 8 or src.value >= 8 then
        out[#out+1] = string.char(
            rex(false, dst.value >= 8, false, src.value >= 8)
        )
    end

    out[#out+1] = string.char(0x0F, 0x6E)
    out[#out+1] = string.char(modrm(3, dst.value, src.value))

    return table.concat(out)
end
local function mov_xmm(dst, src)
    local out = {}

    if dst.value >= 8 or src.value >= 8 then
        out[#out+1] = string.char(
            rex(false, dst.value >= 8, false, src.value >= 8)
        )
    end

    out[#out+1] = string.char(0x0F, 0x28)
    out[#out+1] = string.char(modrm(3, dst.value, src.value))

    return table.concat(out)
end
function asmInstructions.mov(dst, src)
    if dst.id == OP_REG then
        if src.id == OP_REG then
            return mov_reg(dst, src)
        elseif src.id == OP_IMM then
            return mov_imm(dst, src)
        elseif src.id == OP_MEM then
            return mov_load(dst, src)
        elseif src.id == OP_XMM then
            return mov_xmm2reg(dst, src)
        end
    elseif dst.id == OP_MEM then
        if src.id == OP_REG then
            return mov_store(dst, src)
        elseif src.id == OP_IMM then
            return mov_store_imm(dst, src)
        elseif src.id == OP_XMM then
            return mov_store_xmm(dst, src)
        end
    elseif dst.id == OP_XMM then
        if src.id == OP_XMM then
            return mov_xmm(dst, src)
        elseif src.id == OP_REG then
            return mov_reg2xmm(dst, src)
        elseif src.id == OP_MEM then
            return mov_load_xmm(dst, src)
        end
    end

    error("Unsupported operand combination")
end
local function xor_reg(dst, src)
    local out = {}

    if dst.bits == 16 then
        out[#out+1] = string.char(SIZE16)
    end

    if dst.bits == 64 or dst.value >= 8 or src.value >= 8 then
        out[#out+1] = string.char(
            rex(dst.bits == 64, src.value >= 8, false, dst.value >= 8)
        )
    end

    out[#out+1] = string.char(
        dst.bits == 8 and 0x30 or 0x31
    )

    out[#out+1] = string.char(
        modrm(3, src.value, dst.value)
    )

    return table.concat(out)
end
function asmInstructions.xor(dst, src)
    if dst.id == OP_REG and src.id == OP_REG then
        return xor_reg(dst, src)
    end
    error("Unsupported XOR operands")
end
function asmInstructions.clean(reg)
    return asmInstructions.xor(
        reg, reg
    )
end
function asmInstructions.call(src)
    if src.id == OP_REG then
        local out = {}

        out[#out+1] = string.char(
            rex(false, false, false, src.value >= 8)
        )

        out[#out+1] = string.char(0xFF)
        out[#out+1] = string.char(modrm(3, 2, src.value))

        return table.concat(out)

    elseif src.id == OP_MEM then
        local out = {}

        if src.value.base >= 8 then
            out[#out+1] = string.char(
                rex(false, false, false, src.value.base >= 8)
            )
        end

        out[#out+1] = string.char(0xFF)
        out[#out+1] = encode_mem(2, src.value)

        return table.concat(out)

    elseif src.id == OP_IMM then
        assert(src.bits == 32, "CALL immediate must be rel32")

        return string.char(0xE8)
            .. string.pack("<i4", src.value)
    end

    error("Unsupported CALL operand")
end
asmInstructions.ret = string.char(0xC3)

function asmInstructions.jump(src)
    if src.id == OP_REG then
        local out = {}

        if src.value >= 8 then
            out[#out+1] = string.char(
                rex(false, false, false, src.value >= 8)
            )
        end

        out[#out+1] = string.char(0xFF)
        out[#out+1] = string.char(modrm(3, 4, src.value))

        return table.concat(out)

    elseif src.id == OP_MEM then
        local out = {}

        if src.value.base >= 8 then
            out[#out+1] = string.char(
                rex(false, false, false, src.value.base >= 8)
            )
        end

        out[#out+1] = string.char(0xFF)
        out[#out+1] = encode_mem(4, src.value)

        return table.concat(out)

    elseif src.id == OP_IMM then
        assert(src.bits == 32, "JMP immediate must be rel32")

        return string.char(0xE9)
            .. string.pack("<i4", src.value)
    end

    error("Unsupported JMP operand")
end

local function push_reg(src)
    local out = {}
    local r = src.value

    if r >= 8 then
        out[#out+1] = string.char(
            rex(false, false, false, true)
        )
    end

    out[#out+1] = string.char(
        0x50 + (r & 7)
    )

    return table.concat(out)
end

local function pop_reg(dst)
    local out = {}
    local r = dst.value

    if r >= 8 then
        out[#out+1] = string.char(
            rex(false, false, false, true)
        )
    end

    out[#out+1] = string.char(
        0x58 + (r & 7)
    )

    return table.concat(out)
end

function asmInstructions.push(src)
    if src.id == OP_REG then
        return push_reg(src)
    end

    error("Unsupported PUSH operand")
end

function asmInstructions.pop(dst)
    if dst.id == OP_REG then
        return pop_reg(dst)
    end

    error("Unsupported POP operand")
end
local function add_reg(dst, src)
    local out = {}

    if dst.bits == 16 then
        out[#out+1] = string.char(SIZE16)
    end

    if dst.bits == 64 or src.value >= 8 or dst.value >= 8 then
        out[#out+1] = string.char(
            rex(dst.bits == 64, src.value >= 8, false, dst.value >= 8)
        )
    end

    out[#out+1] = string.char(0x01)
    out[#out+1] = string.char(
        modrm(3, src.value, dst.value)
    )

    return table.concat(out)
end


local function add_imm(dst, src)
    local out = {}

    if dst.bits == 16 then
        out[#out+1] = string.char(SIZE16)
    end

    if dst.bits == 64 or dst.value >= 8 then
        out[#out+1] = string.char(
            rex(dst.bits == 64, false, false, dst.value >= 8)
        )
    end

    if src.bits == 8 then
        out[#out+1] = string.char(0x83)
        out[#out+1] = string.char(modrm(3, 0, dst.value))
        out[#out+1] = string.pack("<i1", src.value)
    else
        out[#out+1] = string.char(0x81)
        out[#out+1] = string.char(modrm(3, 0, dst.value))
        out[#out+1] = string.pack("<i4", src.value)
    end

    return table.concat(out)
end


local function add_xmm(dst, src)
    local out = {}

    out[#out+1] = string.char(0x0F, 0x58)

    if dst.value >= 8 or src.value >= 8 then
        table.insert(out, 1, string.char(
            rex(false, dst.value >= 8, false, src.value >= 8)
        ))
    end

    out[#out+1] = string.char(
        modrm(3, dst.value, src.value)
    )

    return table.concat(out)
end
local function sub_reg(dst, src)
    local out = {}

    if dst.bits == 16 then
        out[#out+1] = string.char(SIZE16)
    end

    if dst.bits == 64 or src.value >= 8 or dst.value >= 8 then
        out[#out+1] = string.char(
            rex(dst.bits == 64, src.value >= 8, false, dst.value >= 8)
        )
    end

    out[#out+1] = string.char(0x29)
    out[#out+1] = string.char(
        modrm(3, src.value, dst.value)
    )

    return table.concat(out)
end


local function sub_imm(dst, src)
    local out = {}

    if dst.bits == 16 then
        out[#out+1] = string.char(SIZE16)
    end

    if dst.bits == 64 or dst.value >= 8 then
        out[#out+1] = string.char(
            rex(dst.bits == 64, false, false, dst.value >= 8)
        )
    end

    if src.bits == 8 then
        out[#out+1] = string.char(0x83)
        out[#out+1] = string.char(modrm(3, 5, dst.value))
        out[#out+1] = string.pack("<i1", src.value)
    else
        out[#out+1] = string.char(0x81)
        out[#out+1] = string.char(modrm(3, 5, dst.value))
        out[#out+1] = string.pack("<i4", src.value)
    end

    return table.concat(out)
end


local function sub_xmm(dst, src)
    local out = {}

    if dst.value >= 8 or src.value >= 8 then
        out[#out+1] = string.char(
            rex(false, dst.value >= 8, false, src.value >= 8)
        )
    end

    out[#out+1] = string.char(0x0F, 0x5C)
    out[#out+1] = string.char(
        modrm(3, dst.value, src.value)
    )

    return table.concat(out)
end
function asmInstructions.sub(dst, src)

    if dst.id == OP_REG then

        if src.id == OP_REG then
            return sub_reg(dst, src)

        elseif src.id == OP_IMM then
            return sub_imm(dst, src)
        end

    elseif dst.id == OP_XMM then

        if src.id == OP_XMM then
            return sub_xmm(dst, src)

        elseif src.id == OP_MEM then
            return sub_xmm(dst, src)
        end
    end

    error("Unsupported SUB operands")
end

function asmInstructions.add(dst, src)

    if dst.id == OP_REG then

        if src.id == OP_REG then
            return add_reg(dst, src)

        elseif src.id == OP_IMM then
            return add_imm(dst, src)
        end

    elseif dst.id == OP_XMM then

        if src.id == OP_XMM then
            return add_xmm(dst, src)

        elseif src.id == OP_MEM then
            return add_xmm(dst, src)
        end
    end

    error("Unsupported ADD operands")
end
function asmInstructions.cvtss2sd(dst, src)
    local out = {}

    out[#out+1] = string.char(0xF3)

    if dst.value >= 8 or (src.id == OP_XMM and src.value >= 8)
       or (src.id == OP_MEM and src.value.base >= 8) then
        out[#out+1] = string.char(
            rex(false,
                dst.value >= 8,
                false,
                src.id == OP_MEM and src.value.base >= 8 or false)
        )
    end

    out[#out+1] = string.char(0x0F, 0x5A)

    if src.id == OP_XMM then
        out[#out+1] = string.char(
            modrm(3, dst.value, src.value)
        )
    elseif src.id == OP_MEM then
        out[#out+1] = encode_mem(dst.value, src.value)
    else
        error("Invalid CVTSS2SD source")
    end

    return table.concat(out)
end


function asmInstructions.cvtsd2ss(dst, src)
    local out = {}

    out[#out+1] = string.char(0xF2)

    if dst.value >= 8 or (src.id == OP_XMM and src.value >= 8)
       or (src.id == OP_MEM and src.value.base >= 8) then
        out[#out+1] = string.char(
            rex(false,
                dst.value >= 8,
                false,
                src.id == OP_MEM and src.value.base >= 8 or false)
        )
    end

    out[#out+1] = string.char(0x0F, 0x5A)

    if src.id == OP_XMM then
        out[#out+1] = string.char(
            modrm(3, dst.value, src.value)
        )
    elseif src.id == OP_MEM then
        out[#out+1] = encode_mem(dst.value, src.value)
    else
        error("Invalid CVTSD2SS source")
    end

    return table.concat(out)
end
asmInstructions.nop = string.char(0x90)

function asmInstructions.lea(dst, src)
    if dst.id == OP_REG and src.id == OP_MEM then
        local out = {}

        if dst.bits == 16 then
            out[#out+1] = string.char(SIZE16)
        end

        if dst.bits == 64
            or dst.value >= 8
            or src.value.base >= 8
        then
            out[#out+1] = string.char(
                rex(
                    dst.bits == 64,
                    dst.value >= 8,
                    false,
                    src.value.base >= 8
                )
            )
        end

        out[#out+1] = string.char(0x8D)
        out[#out+1] = encode_mem(dst.value, src.value)

        return table.concat(out)
    end

    error("Unsupported LEA operands")
end
