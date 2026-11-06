CROSS ?= riscv64-unknown-elf-

CC      = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy

CFLAGS = -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -O0 -Wall
LDFLAGS = -T ../firmware/link.ld -nostdlib -nostartfiles

all: smoke.hex

smoke.elf: smoke.S ../firmware/link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) smoke.S -o smoke.elf

smoke.bin: smoke.elf
	$(OBJCOPY) -O binary smoke.elf smoke.bin

smoke.hex: smoke.bin ../firmware/makehex.py
	python3 ../firmware/makehex.py smoke.bin smoke.hex

clean:
	rm -f smoke.elf smoke.bin smoke.hex

.PHONY: all clean
