MAKE=make
NASM=nasm
NASM_ARGS=-o

BOOT_DIR=boot
BOCHS_DIR=bochs

all:
	nasm -o ${BOOT_DIR}/mbr ${BOOT_DIR}/mbr.S
	dd if=${BOOT_DIR}/mbr of=${BOCHS_DIR}/HD60M.img bs=512 count=1 conv=notrunc
	bochs -f ${BOCHS_DIR}/bochsrc
