; ---------- loader and kernel ----------
LOADER_BASE_ADDR equ 0x900
LOADER_START_SECTOR equ 0x1  ; 此值需要与 loader 在磁盘的扇区位置对应，即 dd 的 seek 参数
LOADER_SECTOR_LENGTH equ 0x8  ; 此值需要与 loader 占磁盘的扇区数量对应，即 dd 的 count 参数
