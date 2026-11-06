.section .text.start
.global _start

_start:
    # Initialize x0 test: write to x0, verify it stays 0
    li x1, 0xDEADBEEF
    add x0, x1, x1        # write to x0 (should be ignored)
    bne x0, zero, fail    # x0 must be 0
    # Expected: x0 == 0

    # -------------------------------------------------------------------------
    # R-type ALU operations
    # -------------------------------------------------------------------------

    # ADD
    li x1, 10
    li x2, 20
    add x3, x1, x2
    li x4, 30
    bne x3, x4, fail      # 10 + 20 == 30
    # Expected: x3 == 30

    # SUB
    li x1, 50
    li x2, 20
    sub x3, x1, x2
    li x4, 30
    bne x3, x4, fail      # 50 - 20 == 30
    # Expected: x3 == 30

    # SLL
    li x1, 1
    li x2, 4
    sll x3, x1, x2
    li x4, 16
    bne x3, x4, fail      # 1 << 4 == 16
    # Expected: x3 == 16

    # SLT (signed less than, positive)
    li x1, 5
    li x2, 10
    slt x3, x1, x2
    li x4, 1
    bne x3, x4, fail      # 5 < 10 == 1
    # Expected: x3 == 1

    # SLT (signed less than, negative)
    li x1, -10
    li x2, 5
    slt x3, x1, x2
    li x4, 1
    bne x3, x4, fail      # -10 < 5 == 1
    # Expected: x3 == 1

    # SLTU (unsigned less than)
    li x1, 5
    li x2, 10
    sltu x3, x1, x2
    li x4, 1
    bne x3, x4, fail      # 5 <u 10 == 1
    # Expected: x3 == 1

    # SLTU (unsigned, negative is large)
    li x1, -1
    li x2, 5
    sltu x3, x1, x2
    li x4, 0
    bne x3, x4, fail      # 0xFFFFFFFF <u 5 == 0
    # Expected: x3 == 0

    # XOR
    li x1, 0xFF
    li x2, 0x0F
    xor x3, x1, x2
    li x4, 0xF0
    bne x3, x4, fail      # 0xFF ^ 0x0F == 0xF0
    # Expected: x3 == 0xF0

    # SRL
    li x1, 0x80
    li x2, 4
    srl x3, x1, x2
    li x4, 0x08
    bne x3, x4, fail      # 0x80 >> 4 == 0x08
    # Expected: x3 == 0x08

    # SRA (positive)
    li x1, 0x80
    li x2, 4
    sra x3, x1, x2
    li x4, 0x08
    bne x3, x4, fail      # 0x80 >>> 4 == 0x08
    # Expected: x3 == 0x08

    # SRA (negative)
    li x1, -128
    li x2, 4
    sra x3, x1, x2
    li x4, -8
    bne x3, x4, fail      # -128 >>> 4 == -8
    # Expected: x3 == -8

    # OR
    li x1, 0xF0
    li x2, 0x0F
    or x3, x1, x2
    li x4, 0xFF
    bne x3, x4, fail      # 0xF0 | 0x0F == 0xFF
    # Expected: x3 == 0xFF

    # AND
    li x1, 0xFF
    li x2, 0x0F
    and x3, x1, x2
    li x4, 0x0F
    bne x3, x4, fail      # 0xFF & 0x0F == 0x0F
    # Expected: x3 == 0x0F

    # -------------------------------------------------------------------------
    # I-type operations
    # -------------------------------------------------------------------------

    # ADDI
    li x1, 100
    addi x2, x1, 50
    li x3, 150
    bne x2, x3, fail      # 100 + 50 == 150
    # Expected: x2 == 150

    # ADDI with immediate 0x400 (must stay ADD, not become something else)
    li x1, 0
    addi x2, x1, 0x400
    li x3, 0x400
    bne x2, x3, fail      # 0 + 0x400 == 0x400
    # Expected: x2 == 0x400

    # ADDI with negative immediate
    li x1, 100
    addi x2, x1, -50
    li x3, 50
    bne x2, x3, fail      # 100 + (-50) == 50
    # Expected: x2 == 50

    # SLTI
    li x1, 10
    slti x2, x1, 20
    li x3, 1
    bne x2, x3, fail      # 10 < 20 == 1
    # Expected: x2 == 1

    # SLTIU
    li x1, 10
    sltiu x2, x1, 20
    li x3, 1
    bne x2, x3, fail      # 10 <u 20 == 1
    # Expected: x2 == 1

    # XORI
    li x1, 0xFF
    xori x2, x1, 0x0F
    li x3, 0xF0
    bne x2, x3, fail      # 0xFF ^ 0x0F == 0xF0
    # Expected: x2 == 0xF0

    # ORI
    li x1, 0xF0
    ori x2, x1, 0x0F
    li x3, 0xFF
    bne x2, x3, fail      # 0xF0 | 0x0F == 0xFF
    # Expected: x2 == 0xFF

    # ANDI
    li x1, 0xFF
    andi x2, x1, 0x0F
    li x3, 0x0F
    bne x2, x3, fail      # 0xFF & 0x0F == 0x0F
    # Expected: x2 == 0x0F

    # SLLI
    li x1, 1
    slli x2, x1, 8
    li x3, 256
    bne x2, x3, fail      # 1 << 8 == 256
    # Expected: x2 == 256

    # SRLI
    li x1, 256
    srli x2, x1, 4
    li x3, 16
    bne x2, x3, fail      # 256 >> 4 == 16
    # Expected: x2 == 16

    # SRAI (positive)
    li x1, 256
    srai x2, x1, 4
    li x3, 16
    bne x2, x3, fail      # 256 >>> 4 == 16
    # Expected: x2 == 16

    # SRAI (negative)
    li x1, -256
    srai x2, x1, 4
    li x3, -16
    bne x2, x3, fail      # -256 >>> 4 == -16
    # Expected: x2 == -16

    # -------------------------------------------------------------------------
    # LUI and AUIPC
    # -------------------------------------------------------------------------

    # LUI
    lui x1, 0x12345
    li x2, 0x12345000
    bne x1, x2, fail      # LUI x1, 0x12345 == 0x12345000
    # Expected: x1 == 0x12345000

    # AUIPC
    auipc x1, 0
    # x1 should be the address of this instruction
    # We'll just check it's non-zero
    beq x1, zero, fail
    # Expected: x1 != 0

    # -------------------------------------------------------------------------
    # Load/Store operations
    # -------------------------------------------------------------------------

    # Setup base address for data region (0x1000)
    lui x10, 0x1           # x10 = 0x1000

    # SW and LW
    li x1, 0xDEADBEEF
    sw x1, 0(x10)          # store to 0x1000
    lw x2, 0(x10)          # load from 0x1000
    bne x1, x2, fail       # loaded value should match stored
    # Expected: x2 == 0xDEADBEEF

    # SH and LH (signed)
    li x1, 0x8000          # negative halfword
    sh x1, 4(x10)          # store to 0x1004
    lh x2, 4(x10)          # load signed
    li x3, -32768          # 0xFFFF8000 sign-extended
    bne x2, x3, fail
    # Expected: x2 == 0xFFFF8000

    # SH and LHU (unsigned)
    lhu x2, 4(x10)         # load unsigned
    li x3, 0x8000
    bne x2, x3, fail
    # Expected: x2 == 0x00008000

    # SB and LB (signed)
    li x1, 0x80            # negative byte
    sb x1, 8(x10)          # store to 0x1008
    lb x2, 8(x10)          # load signed
    li x3, -128            # 0xFFFFFF80 sign-extended
    bne x2, x3, fail
    # Expected: x2 == 0xFFFFFF80

    # SB and LBU (unsigned)
    lbu x2, 8(x10)         # load unsigned
    li x3, 0x80
    bne x2, x3, fail
    # Expected: x2 == 0x00000080

    # Multiple byte stores and loads at different offsets
    li x1, 0x11
    sb x1, 12(x10)         # byte 0
    li x1, 0x22
    sb x1, 13(x10)         # byte 1
    li x1, 0x33
    sb x1, 14(x10)         # byte 2
    li x1, 0x44
    sb x1, 15(x10)         # byte 3

    lw x2, 12(x10)         # load all 4 bytes
    li x3, 0x44332211      # little-endian
    bne x2, x3, fail
    # Expected: x2 == 0x44332211

    # -------------------------------------------------------------------------
    # Branch operations
    # -------------------------------------------------------------------------

    # BEQ (taken)
    li x1, 5
    li x2, 5
    beq x1, x2, beq_taken
    j fail
beq_taken:
    # Expected: branch taken

    # BEQ (not taken)
    li x1, 5
    li x2, 6
    beq x1, x2, fail
    # Expected: branch not taken

    # BNE (taken)
    li x1, 5
    li x2, 6
    bne x1, x2, bne_taken
    j fail
bne_taken:
    # Expected: branch taken

    # BNE (not taken)
    li x1, 5
    li x2, 5
    bne x1, x2, fail
    # Expected: branch not taken

    # BLT (taken, positive)
    li x1, 5
    li x2, 10
    blt x1, x2, blt_taken
    j fail
blt_taken:
    # Expected: branch taken

    # BLT (taken, negative)
    li x1, -10
    li x2, 5
    blt x1, x2, blt_taken2
    j fail
blt_taken2:
    # Expected: branch taken

    # BLT (not taken)
    li x1, 10
    li x2, 5
    blt x1, x2, fail
    # Expected: branch not taken

    # BGE (taken)
    li x1, 10
    li x2, 5
    bge x1, x2, bge_taken
    j fail
bge_taken:
    # Expected: branch taken

    # BGE (not taken)
    li x1, 5
    li x2, 10
    bge x1, x2, fail
    # Expected: branch not taken

    # BLTU (taken)
    li x1, 5
    li x2, 10
    bltu x1, x2, bltu_taken
    j fail
bltu_taken:
    # Expected: branch taken

    # BLTU (not taken, negative is large)
    li x1, -1
    li x2, 5
    bltu x1, x2, fail
    # Expected: branch not taken

    # BGEU (taken)
    li x1, 10
    li x2, 5
    bgeu x1, x2, bgeu_taken
    j fail
bgeu_taken:
    # Expected: branch taken

    # BGEU (not taken)
    li x1, 5
    li x2, 10
    bgeu x1, x2, fail
    # Expected: branch not taken

    # Backward branch loop: sum 1..10
    li x1, 0               # sum = 0
    li x2, 1               # counter = 1
    li x3, 10              # limit = 10
loop_start:
    add x1, x1, x2         # sum += counter
    addi x2, x2, 1         # counter++
    ble x2, x3, loop_start # if counter <= 10, loop
    # Expected: x1 == 55 (1+2+3+4+5+6+7+8+9+10)
    li x4, 55
    bne x1, x4, fail

    # -------------------------------------------------------------------------
    # JAL and JALR
    # -------------------------------------------------------------------------

    # JAL
    jal x1, jal_target
    j fail                 # should not reach here
jal_target:
    # x1 should contain the return address (address of the j fail instruction)
    # We'll just verify it's non-zero and reasonable
    beq x1, zero, fail
    # Expected: x1 == return address

    # JALR (function call/return simulation)
    la x1, func
    jalr x2, x1, 0         # call func, x2 = return address
    # After return, x3 should be 42
    li x4, 42
    bne x3, x4, fail
    # Expected: x3 == 42

    j test_complete

func:
    li x3, 42              # function body
    jalr x0, x2, 0         # return to caller
    # Expected: return to address in x2

test_complete:
    # -------------------------------------------------------------------------
    # Success: store 0x600D to 0x1FFC
    # -------------------------------------------------------------------------
    lui x10, 0x2           # x10 = 0x2000
    addi x10, x10, -4      # x10 = 0x1FFC
    li x1, 0x600D
    sw x1, 0(x10)
    ebreak                 # halt the core
    j fail

fail:
    # -------------------------------------------------------------------------
    # Failure: store 0xDEAD to 0x1FFC
    # -------------------------------------------------------------------------
    lui x10, 0x2           # x10 = 0x2000
    addi x10, x10, -4      # x10 = 0x1FFC
    li x1, 0xDEAD
    sw x1, 0(x10)
    ebreak                 # halt the core
    j fail
