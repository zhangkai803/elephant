; main boot record
SECTION MBR vstart=0x7c00

entry:
    call init_registers

    call clear_screen

    call print_by_graph

    ; call get_cursor

    ; mov ax, message
    ; mov cx, message_size
    ; call print

    jmp $

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

message:
    db "1 MBR"

message_size equ $ - message

times 510-($-$$) db 0
db 0x55, 0xaa
