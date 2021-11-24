; loader
%include "boot.inc"
SECTION LOADER vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR

; 0x8000
entry:
    jmp loader_start  ; 代码入口

; 0x8003
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

; 0x8203
gdt_ptr:
    dw GDT_LIMIT
    dd GDT_BASE

; total_mem_bytes dd 0
; ards_buf times 244 db 0
; ards_nr dw 0

loader_start:
    jmp setup_protection_mode

; 进入保护模式
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

    jmp dword SELECTOR_CODE:protection_mode_entry

; 保护模式代码入口
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

    ; 读取 kernel
    mov eax, KERNEL_START_SECTOR  ; rd_disk_m_32 参数 起始扇区
    mov ebx, KERNEL_BASE_ADDR  ; rd_disk_m_32 参数 目标地址
    mov ecx, KERNEL_SECTOR_LENGTH  ; rd_disk_m_32 参数 扇区数量
    call rd_disk_m_32

    ; 准备页表
    call setup_page

    ; 开启分页
    call enable_page

    jmp SELECTOR_CODE:enter_kernel

; 初始化页表
setup_page:

    ; 把页目录表空间先清零
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
    mov eax, PAGE_DIR_TABLE_POS  ; 页表位置，实际内存 1MB 处
    add eax, PAGE_SIZE  ; 0x1000 是页目录表自身大小 4KB，eax 现在是第0个页表项的地址
    mov ebx, eax  ; 备份一下第0个页表的地址
    or eax, PG_US_U | PG_RW_W | PG_P  ; 补充第0个页表的属性
    mov [PAGE_DIR_TABLE_POS + 0 * 4], eax  ; 写入第0个页目录项（页目录表地址 + 偏移 0）

    ; 将第768个页目录项，也指向第0个页表
    mov dword [PAGE_DIR_TABLE_POS + 768 * 4], eax
    ; 最后一个页目录项，指向页目录表自己
    sub eax, PAGE_SIZE
    mov dword [PAGE_DIR_TABLE_POS + 1023 * 4], eax

    ; 补充第0个页表的内容
    mov ecx, 256  ; 256 次，每次 4Byte，映射最开始的 1 MB 低端内存
    mov esi, 0
    mov edx, PG_US_U | PG_RW_W | PG_P
.create_pte:
    mov [ebx + esi * 4], edx  ; ebx 页表起始地址 0x400000
    add edx, PAGE_SIZE  ; 指向下一个 4KB 地址
    inc esi
    loop .create_pte

    ; 创建第769-1022个页目录项
    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x2000
    or eax, PG_US_U | PG_RW_W | PG_P
    mov ecx, 254  ; 0xfe
    mov esi, 769  ; 0x301
.create_kernel_pde:
    mov [PAGE_DIR_TABLE_POS + esi * 4], eax
    inc esi
    add eax, PAGE_SIZE
    loop .create_kernel_pde
    ret

enable_page:
    sgdt [gdt_ptr]

    ; gdt_ptr + 2 指向 GDT_BASE
    ; GDT_BASE + 0x18 指向 GDT[3]
    ; +4 指向段描述符段基址的 31-24 位
    mov ebx, [gdt_ptr + 2]
    or dword [ebx + 0x18 + 4], 0xC0000000
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; or dword [ebx + 0x08 + 4], 0xC0000000
    ; or dword [ebx + 0x10 + 4], 0xC0000000
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; GDT_BASE 的值 也加上 0xC0000000
    add dword [gdt_ptr + 2], 0xC0000000

    ; 保存原 esp 内的值
    ; mov eax, [esp]
    ; esp 移动到高地址
    add esp, 0xC0000000
    ; 将原 esp 的值 写入新 esp
    ; mov [esp], eax

    ; set page directory address to cr3 register
    mov eax, PAGE_DIR_TABLE_POS
    mov cr3, eax

    ; enable paging on cr0 register
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax  ; bug: (0).[17652418] ??? (physical address not available)

    ; load gdt again - gdt has been moved to > 0xC0000000
    lgdt [gdt_ptr]

    ; refresh video segment selector cache
    ; mov ax, SELECTOR_VIDEO
    ; mov gs, ax

    ret

rd_disk_m_32:
    mov esi, eax    ; eax: LBA 扇区号，备份到 esi
    mov di, cx  ; cx: 读入的扇区数目，备份到 di

    mov dx, 0x1f2   ; 写入读取的扇区数
    mov al, cl
    out dx, al

    mov eax, esi    ; 从 esi 恢复 eax

    mov dx, 0x1f3   ; 写入 LBA 地址7-0位
    out dx, al

    mov cl, 8   ; 写入 LBA 地址15-8位
    shr eax, cl
    mov dx, 0x1f4
    out dx, al

    shr eax, cl   ; 写入 LBA 地址23-16位
    mov dx, 0x1f5
    out dx, al

    shr eax, cl
    and al, 0x0f   ; 写入 LBA 地址27-24位
    or al, 0xe0   ; 设置 LBA 7-4位为1110，表示硬盘为 LBA 模式
    mov dx, 0x1f6
    out dx, al

    mov dx, 0x1f7   ; 写入命令：读取
    mov al, 0x20
    out dx, al

  .not_ready:
    nop
    in al, dx
    and al, 0x88    ; 10001000b
    cmp al, 0x08    ; 00001000b 第4位为1表示可读，第7位为1表示忙碌
    jnz .not_ready  ; 如果

    mov ax, di  ; 要读取的扇区数
    mov dx, 256 ; 每个扇区512Byte 每次2Byte 需要256次
    mul dx  ; 相乘
    mov cx, ax  ; 要读取的总次数，存入 cx

    mov dx, 0x1f0

  .go_on_read:
    in ax, dx
    mov [ebx], ax
    add ebx, 2
    loop .go_on_read
    ret

; 0x8379
enter_kernel:
    call kernel_init

    ; init floating point unit before entering the kernel
    finit

    ; move stack to 0xF0000000
    mov esp, KERNEL_STACK_TOP - 16
    mov ebp, esp

    ; let's jump to kernel entry :)
    jmp eax
    ret

    ; mov esp, 0xc009f00
    ; jmp KERNEL_ENTRY_POINT

; 0x838b
kernel_init:
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx

    ; [bug here]
    ; 00017649356e[CPU0  ] interrupt(): gate descriptor is not valid sys seg (vector=0x0e)
    ; 00017649356e[CPU0  ] interrupt(): gate descriptor is not valid sys seg (vector=0x08)
    ; ...
    ; (0).[17649356] [0x000000008390] 0008:0000000000008390 (unk. ctxt): mov dx, word ptr ds:0x0020002a ; 668b152a002000
    ; 00017649356e[CPU0  ] exception(): 3rd (13) exception with no resolution, shutdown status is 00h, resetting
    mov dx, [KERNEL_BASE_ADDR + 42]  ; e_phentsize 属性位置
    mov ebx, [KERNEL_BASE_ADDR + 28] ; e_phoff 属性位置

    add ebx, KERNEL_BASE_ADDR
    mov cx, [KERNEL_BASE_ADDR + 44]  ; e_phnum 属性位置

.each_segement:
    cmp byte [ebx + 0], PT_NULL
    je .PTNULL

    push dword [ebx + 16]
    mov eax, [ebx + 4]
    add eax, KERNEL_BASE_ADDR
    push eax
    push dword [ebx + 8]
    call mem_cpy

    add esp, 12  ; 清理栈中压入的三个参数

.PTNULL:
    add ebx, edx
    loop .each_segement
    ret

;--------------------- 逐字节拷贝 mem_cpy(dst, src, size) ------------------------
; 输入：栈中 3 个参数 dst src size
; 输出： 无
;-------------------------------------------------------------------------------
mem_cpy:
    cld  ; 方向标志位清零 cflags:DF 位
    push ebp
    mov ebp, esp
    push ecx
    mov edi, [ebp + 8]
    mov esi, [ebp + 12]
    ; 0x83d9
    mov ecx, [ebp + 16]
    ; jmp $
    ; bug here
    ; 00017649374e[CPU0  ] interrupt(): gate descriptor is not valid sys seg (vector=0x0e)
    ; 00017649374e[CPU0  ] interrupt(): gate descriptor is not valid sys seg (vector=0x08)
    ; 00017649374i[CPU0  ] CPU is in protected mode (active)
    ; 00017649374i[CPU0  ] CS.mode = 32 bit
    ; 00017649374i[CPU0  ] SS.mode = 32 bit
    ; 00017649374i[CPU0  ] EFER   = 0x00000000
    ; 00017649374i[CPU0  ] | EAX=00071000  EBX=00070034  ECX=0000003c  EDX=00000020
    ; 00017649374i[CPU0  ] | ESP=c0007fe4  EBP=c0007fe8  ESI=00071000  EDI=c0800000
    ; 00017649374i[CPU0  ] | IOPL=0 id vip vif ac vm RF nt of df if tf sf zf af PF cf
    ; 00017649374i[CPU0  ] | SEG sltr(index|ti|rpl)     base    limit G D
    ; 00017649374i[CPU0  ] |  CS:0008( 0001| 0|  0) 00000000 ffffffff 1 1
    ; 00017649374i[CPU0  ] |  DS:0010( 0002| 0|  0) 00000000 ffffffff 1 1
    ; 00017649374i[CPU0  ] |  SS:0010( 0002| 0|  0) 00000000 ffffffff 1 1
    ; 00017649374i[CPU0  ] |  ES:0010( 0002| 0|  0) 00000000 ffffffff 1 1
    ; 00017649374i[CPU0  ] |  FS:0000( 0005| 0|  0) 00000000 0000ffff 0 0
    ; 00017649374i[CPU0  ] |  GS:0018( 0003| 0|  0) 000b8000 00007fff 1 1
    ; 00017649374i[CPU0  ] | EIP=000083dc (000083dc)
    ; 00017649374i[CPU0  ] | CR0=0xe0000011 CR2=0xc0800000
    ; 00017649374i[CPU0  ] | CR3=0x00100000 CR4=0x00000000
    ; (0) [0x0000000083dc] 0008:00000000000083dc (unk. ctxt): rep movsb byte ptr es:[edi], byte ptr ds:[esi] ; f3a4
    ; 00017649374e[CPU0  ] exception(): 3rd (13) exception with no resolution, shutdown status is 00h, resetting
    ; https://wiki.osdev.org/Exceptions
    ; https://wiki.osdev.org/Exceptions#Double_Fault
    ; https://wiki.osdev.org/Exceptions#Page_Fault
    ; A Page Fault occurs when:
    ; - A page directory or table entry is not present in physical memory.
    ; - Attempting to load the instruction TLB with a translation for a non-executable page.
    ; - A protection check (privileges, read/write) failed.
    ; - A reserved bit in the page directory or table entries is set to 1.
    rep movsb  ; means: repeat move byte from ... to ...
    ; recover
    pop ecx
    pop ebp
    ret
