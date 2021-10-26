; loader
%include "boot.inc"
SECTION LOADER vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR

entry:
    jmp loader_start  ; 代码入口

; gdt index 0
GDT_BASE:
    dd 0x00000000
    dd 0x00000000

DESC_CODE:
    dd DESC_CODE_LOW32
    dd DESC_CODE_HIGH32

DESC_DATA:
    dd DESC_DATA_LOW32
    dd DESC_DATA_HIGH32

DESC_VIDEO:
    dd DESC_VIDEO_LOW32
    dd DESC_VIDEO_HIGH32

times 60 dq 0

GDT_SIZE equ $ - GDT_BASE
GDT_LIMIT equ GDT_SIZE - 1

gdt_ptr:
    dw GDT_LIMIT
    dd GDT_BASE

; total_mem_bytes dd 0
; ards_buf times 244 db 0
; ards_nr dw 0

loader_start:
    jmp setup_protection_mode

setup_protection_mode:
    ; A20
    in al, 0x92
    or al, 0000_0010b
    out 0x92, al
    ; lgdt
    lgdt [gdt_ptr]
    ; cr0
    mov eax, cr0
    or eax, 0x00000001
    mov cr0, eax
    ; jmp $

    jmp dword SELECTOR_CODE:protection_mode_entry

[bits 32]
protection_mode_entry:
    ; 当一个程序要执行时，就要决定程序代码、数据和堆栈各要用到内存的哪些位置
    ; 通过设定段寄存器 CS，DS，SS 来指向这些起始位置，通常是将 DS 固定，而根据需要修改 CS

    ; set data segement
    mov ax, SELECTOR_DATA
    mov ds, ax  ; ds: data segement register
    mov es, ax  ; es: extra segement register
    mov ss, ax  ; ss: stack segement register

    ; set video segement
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax

    call setup_page

    jmp $

; 初始化页表
setup_page:

    ; 把页表空间先清零
    mov ecx, 4096
    mov esi, 0
.clear_page_dir:
    mov byte [PAGE_DIR_TABLE_POS + esi], 0  ; FIXME: bug here
    inc esi
    loop .clear_page_dir

; 页目录项：页表物理地址高 20 位 + 属性 12 位，共 32 位，4Byte
; 页表项：内存物理地址高 20 位 + 属性 12 位，共 32 位，4Byte
; 为什么只记录物理地址的高 20 位，因为每项都是 4KB 大小，低 12 位都是 0
; 所以低 12 位被用来记录属性
; 开始创建页目录表
.create_pde:
    mov eax, PAGE_DIR_TABLE_POS  ; 0x000100000
    add eax, PAGE_SIZE  ; 0x1000 是页目录表自身大小 4KB，eax 现在是第0个页表项的地址
    mov ebx, eax  ; 备份一下第0个页表的地址
    or eax, PG_US_U | PG_RW_W | PG_P  ; 补充第0个页表的属性，得到完整的第0个页目录项
    mov [PAGE_DIR_TABLE_POS + 0 * 4], eax  ; 将第0个页目录项写入到页目录表对应的位置

    mov [PAGE_DIR_TABLE_POS + 768 * 4], eax  ; 将第768个页目录项，也指向第0个页表

    ; 创建第769-1022个页目录项
    mov edx, eax
    or edx, PG_US_U | PG_RW_W | PG_P
    mov ecx, 254
    mov esi, 769
.create_kernel_pde:
    mov [PAGE_DIR_TABLE_POS + esi * 4], edx
    add edx, PAGE_SIZE
    inc esi
    loop .create_kernel_pde

    ; 最后一个页目录项，指向页目录表自己
    mov eax, PAGE_DIR_TABLE_POS
    mov [PAGE_DIR_TABLE_POS + 1023 * 4], eax

    ; 补充第0个页表的内容
    mov edx, 0x0  ; 初始化地址为 0x0
    or edx, PG_US_U | PG_RW_W | PG_P
    mov ecx, 256  ; 这里只写 256 次，每次 4Byte，映射低 1MB 内存
    mov esi, 0
.create_pte:
    mov [ebx + esi * 4], edx
    add edx, PAGE_SIZE  ; 指向下一个 4KB 地址
    inc esi
    loop .create_pte
    ret
