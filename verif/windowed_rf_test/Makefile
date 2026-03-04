# Build windowed RF CSR test for CVA6
# Default: 64-bit ELF (for target=cv64a6_imafdc_sv39)
# ELF32=1: 32-bit ELF (for target=cv32a6_imac_sv32)
# Requires: RISCV set to toolchain root

RISCV ?= /opt/riscv
SRC_DIR = .
BUILD_DIR = build

ifeq ($(ELF32),1)
  CC = $(RISCV)/bin/riscv32-unknown-elf-gcc
  CFLAGS  = -march=rv32gc -mabi=ilp32d -nostdlib -ffreestanding -O2 -Wall
  LINKER  = $(SRC_DIR)/link32.ld
  ELF = $(BUILD_DIR)/windowed_rf_csr_test_32.riscv
else
  CC = $(RISCV)/bin/riscv64-unknown-elf-gcc
  CFLAGS  = -march=rv64gc -mabi=lp64d -mcmodel=medlow -nostdlib -ffreestanding -O2 -Wall
  LINKER  = $(SRC_DIR)/link.ld
  ELF = $(BUILD_DIR)/windowed_rf_csr_test.riscv
endif

LDFLAGS = -nostdlib -Wl,-T,$(LINKER)

.PHONY: all clean

all: $(ELF)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(ELF): $(BUILD_DIR) $(SRC_DIR)/windowed_rf_csr_test.c $(SRC_DIR)/start.S $(SRC_DIR)/tohost.S $(LINKER)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRC_DIR)/start.S $(SRC_DIR)/tohost.S $(SRC_DIR)/windowed_rf_csr_test.c

clean:
	rm -rf $(BUILD_DIR)
