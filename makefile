BIN_DIR=bin
BOOT_DIR=boot
BOCHS_DIR=bochs
KERNEL_DIR=kernel

all:
	nasm -I ${BOOT_DIR} -o ${BIN_DIR}/mbr ${BOOT_DIR}/mbr.S
	nasm -I ${BOOT_DIR} -o ${BIN_DIR}/loader ${BOOT_DIR}/loader.S
	i386-elf-gcc -c -o ${KERNEL_DIR}/main.o ${KERNEL_DIR}/main.c
	i386-elf-ld ${KERNEL_DIR}/main.o -Ttext 0xc0800000 -o ${BIN_DIR}/kernel
	dd if=${BIN_DIR}/mbr of=${BOCHS_DIR}/HD60M.img bs=512 seek=0 count=1 conv=notrunc
	dd if=${BIN_DIR}/loader of=${BOCHS_DIR}/HD60M.img bs=512 seek=1 count=8 conv=notrunc
	dd if=${BIN_DIR}/kernel of=${BOCHS_DIR}/HD60M.img bs=512 seek=9 count=200 conv=notrunc
	bochs -qf ${BOCHS_DIR}/bochsrc
