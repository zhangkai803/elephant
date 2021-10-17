; loader
%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR

entry:
    jmp loader_start

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

loader_start:
    call print_by_graph
    jmp setup_protection_mode

print_by_graph:
    mov byte [gs:0x00], '2'
    mov byte [gs:0x01], 0xA4

    mov byte [gs:0x02], ' '
    mov byte [gs:0x03], 0xA4

    mov byte [gs:0x04], 'L'
    mov byte [gs:0x05], 0xA4

    mov byte [gs:0x06], 'D'
    mov byte [gs:0x07], 0xA4

    mov byte [gs:0x08], 'R'
    mov byte [gs:0x09], 0xA4
    ret

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

[bits 32]
protection_mode_entry:
    mov ax, SELECTOR_DATA
    mov dx, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax

    mov byte [gs: 160], 'P'

    jmp $
