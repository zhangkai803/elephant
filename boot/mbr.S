; main boot record
%include "boot.inc"
SECTION MBR vstart=MBR_BASE_ADDR

entry:
    call init_registers

    call clear_screen

    ; call print_by_graph

    call load_loader
    jmp LOADER_BASE_ADDR

    ; call get_cursor

    ; mov ax, message
    ; mov cx, message_size
    ; call print

init_registers:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00
    mov ax, 0xb800
    mov gs, ax
    ret

; clear screen by BIOS interupt
clear_screen:
    mov ax, 0x600
    mov bx, 0x700
    mov cx, 0
    mov dx, 0x184f
    int 0x10
    ret

; get cursor position
get_cursor:
    mov ah, 3
    mov bh, 0
    int 0x10
    ret

; print message by BIOS interupt
; message in ax
; message length in cx
print:
    mov bp, ax
    mov ax, 0x1301
    mov bx, 0x2
    int 0x10
    ret

print_by_graph:
    mov byte [gs:0x00], '1'
    mov byte [gs:0x01], 0xA4

    mov byte [gs:0x02], ' '
    mov byte [gs:0x03], 0xA4

    mov byte [gs:0x04], 'M'
    mov byte [gs:0x05], 0xA4

    mov byte [gs:0x06], 'B'
    mov byte [gs:0x07], 0xA4

    mov byte [gs:0x08], 'R'
    mov byte [gs:0x09], 0xA4
    ret

load_loader:
    mov eax, LOADER_START_SECTOR
    mov bx, LOADER_BASE_ADDR
    mov cx, LOADER_SECTOR_LENGTH
    call rd_disk_m_16
    ret

rd_disk_m_16:
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
    mov [bx], ax
    add bx, 2
    loop .go_on_read
    ret

message:
    db "1 MBR"

message_size equ $ - message

times 510-($-$$) db 0
db 0x55, 0xaa
