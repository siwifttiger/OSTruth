BUILD_DIR=./build
ASM=nasm
CC=gcc
LD=ld
ENTRY_POINT=0xc0001500
LIB=-I lib/ -I lib/kernel -I kernel/  
ASMFLAG=-f elf
LOADERFLAG= -I boot/include/
CFLAGS=-m32 -Wall $(LIB) -c -fno-builtin -W -Wstrict-prototypes \
       -Wmissing-prototypes -fno-stack-protector 
LDFLAGS=-m elf_i386 -Ttext $(ENTRY_POINT) -e main 
OBJS=$(BUILD_DIR)/main.o $(BUILD_DIR)/print.o $(BUILD_DIR)/interrupt.o \
	 $(BUILD_DIR)/init.o $(BUILD_DIR)/kernel.o 

############C代码编译################
$(BUILD_DIR)/main.o: kernel/main.c lib/stdint.h lib/kernel/print.h  kernel/init.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/init.o: kernel/init.c kernel/init.h lib/kernel/print.h\
					 lib/stdint.h kernel/interrupt.h
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/interrupt.o: kernel/interrupt.c kernel/interrupt.h \
						  lib/stdint.h kernel/global.h lib/kernel/io.h \
						  lib/kernel/print.h
	$(CC) $(CFLAGS) $< -o $@

###########汇编代码编译#############
$(BUILD_DIR)/loader.bin: boot/loader.s boot/include/boot.inc
	$(ASM) $(LOADERFLAG) $< -o $@

$(BUILD_DIR)/mbr.bin: boot/mbr.s boot/include/boot.inc 
	$(ASM) $(LOADERFLAG) $< -o $@

$(BUILD_DIR)/print.o: lib/kernel/print.s
	$(ASM) $(ASMFLAG) $< -o $@

$(BUILD_DIR)/kernel.o: kernel/kernel.s
	$(ASM) $(ASMFLAG) $< -o $@


############链接所有目标文件############
$(BUILD_DIR)/kernel.bin: $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@

.PHONY : mk_dir hd clean all

mk_dir:
	if [ ! -d $(BUILD_DIR) ];then mkdir $(BUILD_DIR);fi

hd:
	dd if=$(BUILD_DIR)/mbr.bin bs=512 count=1 conv=notrunc of=bochsImages/hd60M.img 
	dd if=$(BUILD_DIR)/loader.bin bs=512 seek=2 count=3 conv=notrunc of=bochsImages/hd60M.img 
	dd if=$(BUILD_DIR)/kernel.bin bs=512 seek=9 count=200 conv=notrunc of=bochsImages/hd60M.img

clean:
	cd $(BUILD_DIR) && rm -rf ./*

build: $(BUILD_DIR)/mbr.bin \
	$(BUILD_DIR)/loader.bin \
	$(BUILD_DIR)/kernel.bin

all: mk_dir build hd


