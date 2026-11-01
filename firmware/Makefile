CROSS ?= riscv64-unknown-elf-

CC      = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy

DELAY_N ?= 100000
STAMP    = .delay_$(DELAY_N).stamp

CFLAGS = \
	-march=rv32i \
	-mabi=ilp32 \
	-nostdlib \
	-nostartfiles \
	-ffreestanding \
	-Os \
	-Wall \
	-Wextra

CFLAGS += -DDELAY_N=$(DELAY_N)

LDFLAGS = \
	-T link.ld \
	-nostdlib \
	-nostartfiles

all: firmware.hex

$(STAMP):
	rm -f .delay_*.stamp
	touch $@

firmware.elf: start.S main.c link.ld $(STAMP)
	$(CC) $(CFLAGS) $(LDFLAGS) start.S main.c -o firmware.elf

firmware.bin: firmware.elf
	$(OBJCOPY) -O binary firmware.elf firmware.bin

firmware.hex: firmware.bin makehex.py
	python3 makehex.py firmware.bin firmware.hex

clean:
	rm -f firmware.elf firmware.bin firmware.hex .delay_*.stamp

.PHONY: all clean
