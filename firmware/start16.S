.section .text.start

.global _start
.type _start, @function

_start:
    li sp, 0x00004000
    jal ra, main

1:
    j 1b

.size _start, .-_start
