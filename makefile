MAKE=make
NASM=nasm
NASM_ARGS=-o

BIN_DIR=bin
BOOT_DIR=boot
BOCHS_DIR=bochs

all:
	nasm -I ${BOOT_DIR} -o ${BIN_DIR}/mbr ${BOOT_DIR}/mbr.S
	nasm -I ${BOOT_DIR} -o ${BIN_DIR}/loader ${BOOT_DIR}/loader.S
	dd if=${BIN_DIR}/mbr of=${BOCHS_DIR}/HD60M.img bs=512 seek=0 count=1 conv=notrunc
	dd if=${BIN_DIR}/loader of=${BOCHS_DIR}/HD60M.img bs=512 seek=1 count=8 conv=notrunc
	bochs -qf ${BOCHS_DIR}/bochsrc
