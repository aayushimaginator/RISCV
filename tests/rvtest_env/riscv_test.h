#ifndef _ENV_RV32I_MIN_H
#define _ENV_RV32I_MIN_H
#define RVTEST_RV32U
#define RVTEST_RV64U
#define TESTNUM gp
#define RVTEST_CODE_BEGIN .section .text.start; .globl _start; _start: li TESTNUM, 0;
#define RVTEST_CODE_END ecall
#define RVTEST_PASS fence; li TESTNUM, 1; li a7, 93; li a0, 0; ecall
#define RVTEST_FAIL fence; 1: beqz TESTNUM, 1b; sll TESTNUM, TESTNUM, 1; or TESTNUM, TESTNUM, 1; li a7, 93; addi a0, TESTNUM, 0; ecall
#define RVTEST_DATA_BEGIN .align 4; .global begin_signature; begin_signature:
#define RVTEST_DATA_END .align 4; .global end_signature; end_signature:
#endif
