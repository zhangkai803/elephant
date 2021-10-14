; main boot record
SECTION MBR vstart=0x7c00

entry:
    call init_registers

    call clear_screen

    call get_cursor

    mov ax, message
    mov cx, message_size
    call print

    jmp $

init_registers:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00
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

message:
    db "1 MBR"

message_size equ $ - message

times 510-($-$$) db 0
db 0x55, 0xaa
