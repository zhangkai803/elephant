; ---------- loader and kernel ----------
MBR_BASE_ADDR    equ 0x7c00
LOADER_BASE_ADDR equ 0x8000

LOADER_START_SECTOR  equ 0x1  ; 此值需要与 loader 在磁盘的扇区位置对应，即 dd 的 seek 参数
LOADER_SECTOR_LENGTH equ 0x8  ; 此值需要与 loader 占磁盘的扇区数量对应，即 dd 的 count 参数

; ---------------- gdt ------------------
DESC_G_4K equ 1 << 23  ; gdt 第23位 表示粒度为 4KB
DESC_D_32 equ 1 << 22  ; gdt 第22位 表示操作数位32位
DESC_L_32 equ 0 << 21  ; gdt 第21位 表示是否为64位代码段
DESC_AVL  equ 0 << 20  ; gdt 第20位 表示是否可用，暂时用不到，置零

DESC_LIMIT_CODE  equ 1111b << 16  ; gdt 第16-19位 代码段的段界限
DESC_LIMIT_DATA  equ 1111b << 16  ; gdt 第16-19位 数据段的段界限
DESC_LIMIT_VIDEO equ 0000b << 16  ; gdt 第16-19位 显存段的段界限

DESC_P     equ 1 << 15  ; gdt 第15位 表示是否存在于内存
DESC_DPL_0 equ 00b << 13  ; gdt 第13-14位 表示特权等级0
DESC_DPL_1 equ 01b << 13  ; gdt 第13-14位 表示特权等级1
DESC_DPL_2 equ 10b << 13  ; gdt 第13-14位 表示特权等级2
DESC_DPL_3 equ 11b << 13  ; gdt 第13-14位 表示特权等级3

DESC_S_CODE equ 1 << 12  ; gdt 代码段第12位 表示非系统段
DESC_S_DATA equ 1 << 12  ; gdt 数据段第12位 表示非系统段
DESC_S_SYS  equ 0 << 12  ; gdt 第12位 表示系统段

DESC_TYPE_CODE equ 1000b << 8  ; gdt 第8-11位 表示段类型 只执行代码段
DESC_TYPE_DATA equ 0010b << 8  ; gdt 第8-11位 表示段类型 可读写数据段

; 代码段
DESC_CODE_HIGH32 equ (0 << 24) + \
                   DESC_G_4K + \
                   DESC_D_32 + \
                   DESC_L_32 + \
                   DESC_AVL + \
                   DESC_LIMIT_CODE + \
                   DESC_P + \
                   DESC_DPL_0 + \
                   DESC_S_CODE + \
                   DESC_TYPE_CODE + \
                   0x0  ; 00000000110011111001100000000000
DESC_CODE_LOW32 equ 0x0000FFFF

; 数据段
DESC_DATA_HIGH32 equ (0 << 24) + \
                   DESC_G_4K + \
                   DESC_D_32 + \
                   DESC_L_32 + \
                   DESC_AVL + \
                   DESC_LIMIT_DATA + \
                   DESC_P + \
                   DESC_DPL_0 + \
                   DESC_S_DATA + \
                   DESC_TYPE_DATA + \
                   0x0  ; 00000000110011111001001000000000
DESC_DATA_LOW32 equ 0x0000FFFF

; 显存段的段基址为 0xB8000，即 0x000B8000，共32位
; 被分成3份存储
; 0x00 在 DESC_VIDEO_HIGH32 24-31位
; 0x0B 在 DESC_VIDEO_HIGH32 0-7位
; 0x8000 在 DESC_VIDEO_LOW32 16-31位
; 显存总共占8个段，即段界限为 0x00007，共20位 32K大小
; 被分成2份存储
; 0x0 在 DESC_VIDEO_HIGH32 16-19位
; 0x0007 在 DESC_VIDEO_LOW32 0-15位
DESC_VIDEO_HIGH32 equ (0 << 24) + \
                    DESC_G_4K + \
                    DESC_D_32 + \
                    DESC_L_32 + \
                    DESC_AVL + \
                    DESC_LIMIT_VIDEO + \
                    DESC_P + \
                    DESC_DPL_0 + \
                    DESC_S_DATA + \
                    DESC_TYPE_DATA + \
                    0xB  ; 00000000110000001001001000001011
DESC_VIDEO_LOW32 equ 0x80000007

; ------------- selector ----------------
RPL0 equ 00b
RPL1 equ 01b
RPL2 equ 10b
RPL3 equ 11b

TI_GDT equ 000b
TI_LDT equ 100b

; 选择子结构 第0-2位RPL 第3位TI 第4-15位描述符索引
SELECTOR_CODE  equ (0x0001 << 3) + TI_GDT + RPL0
SELECTOR_DATA  equ (0x0002 << 3) + TI_GDT + RPL0
SELECTOR_VIDEO equ (0x0003 << 3) + TI_GDT + RPL0

; ------------ page table ---------------
PG_P    equ 1
PG_RW_R equ 0 << 1
PG_RW_W equ 1 << 1
PG_US_S equ 0 << 2
PG_US_U equ 1 << 2

PAGE_SIZE          equ 0x1000  ; 页大小 4KB
PAGE_DIR_TABLE_POS equ 0x100000  ; 页目录表物理地址
