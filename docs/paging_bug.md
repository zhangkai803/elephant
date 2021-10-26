# 开启分页机制时的BUG

## BUG位置

```asm
; 初始化页表
setup_page:

    ; 把页表空间先清零
    mov ecx, 4096
    mov esi, 0
.clear_page_dir:
    mov byte [PAGE_DIR_TABLE_POS + esi], 0  ; FIXME: bug here
    inc esi
    loop .clear_page_dir
```

## BUG日志

bochs日志

```log
00052200210e[CPU0  ] write_virtual_checks(): write beyond limit, r/w
00052200210e[CPU0  ] interrupt(): gate descriptor is not valid sys seg (vector=0x0d)
00052200210e[CPU0  ] interrupt(): gate descriptor is not valid sys seg (vector=0x08)
00052200210i[CPU0  ] CPU is in protected mode (active)
00052200210i[CPU0  ] CS.mode = 32 bit
00052200210i[CPU0  ] SS.mode = 32 bit
00052200210i[CPU0  ] EFER   = 0x00000000
00052200210i[CPU0  ] | EAX=60000018  EBX=00000000  ECX=00001000  EDX=00000010
00052200210i[CPU0  ] | ESP=000008fc  EBP=00000000  ESI=00000000  EDI=0000ffac
00052200210i[CPU0  ] | IOPL=0 id vip vif ac vm RF nt of df if tf sf zf af PF cf
00052200210i[CPU0  ] | SEG sltr(index|ti|rpl)     base    limit G D
00052200210i[CPU0  ] |  CS:0008( 0001| 0|  0) 00000000 ffffffff 1 1
00052200210i[CPU0  ] |  DS:0000( 0005| 0|  0) 00000000 0000ffff 0 0
00052200210i[CPU0  ] |  SS:0010( 0002| 0|  0) 00000000 ffffffff 1 1
00052200210i[CPU0  ] |  ES:0010( 0002| 0|  0) 00000000 ffffffff 1 1
00052200210i[CPU0  ] |  FS:0000( 0005| 0|  0) 00000000 0000ffff 0 0
00052200210i[CPU0  ] |  GS:0018( 0003| 0|  0) 000b8000 00007fff 1 1
00052200210i[CPU0  ] | EIP=00000b9d (00000b9d)
00052200210i[CPU0  ] | CR0=0x60000011 CR2=0x00000000
00052200210i[CPU0  ] | CR3=0x00000000 CR4=0x00000000
00052200210e[CPU0  ] exception(): 3rd (13) exception with no resolution, shutdown status is 00h, resetting
```

异常发生之前的GDT信息

```log
<bochs:14> info gdt
Global Descriptor Table (base=0x0000000000000903, limit=511):
GDT[0x0000]=??? descriptor hi=0x00000000, lo=0x00000000
GDT[0x0008]=Code segment, base=0x00000000, limit=0xffffffff, Execute-Only, Non-Conforming, Accessed, 32-bit
GDT[0x0010]=Data segment, base=0x00000000, limit=0xffffffff, Read/Write, Accessed
GDT[0x0018]=Data segment, base=0x000b8000, limit=0x00007fff, Read/Write, Accessed
GDT[0x0020]=??? descriptor hi=0x00000000, lo=0x00000000
```

## 排查

- 代码功能

    此时刚进入保护模式，开始准备页目录表，先将页目录表空间清零，页目录表大小为 4KB，所以循环
    4096 次，每次写入 1Byte 的 0。写入语句为：
    `mov byte [PAGE_DIR_TABLE_POS + esi], 0`

    此处`PAGE_DIR_TABLE_POS`为页目录表地址 0x100000，esi 为循环控制变量，初始化为 0，每次
    加 1。

    执行到此处时，虚拟机会重启。

- 重点信息

    ```log
    00052200210e[CPU0  ] write_virtual_checks(): write beyond limit, r/w
    00052200210e[CPU0  ] interrupt(): gate descriptor is not valid sys seg (vector=0x0d)
    00052200210e[CPU0  ] interrupt(): gate descriptor is not valid sys seg (vector=0x08)
    ...
    00052200210e[CPU0  ] exception(): 3rd (13) exception with no resolution, shutdown status is 00h, resetting
    ```

    首先看`exception(): 3rd (13)`，13 号异常是`general protection fault`，`3rd`指的
    是：故障发生时，CPU调用异常处理程序。如果在尝试调用异常处理程序时发生错误，则称为双重错误，
    CPU将尝试使用另一个异常处理程序来处理该错误。如果该调用也导致了一个故障，那么系统将以三重故
    障重新启动。
    参见[double-fault triple-fault](https://cn.bing.com/search?q=double-fault+triple-fault)

    日志最上面 3 行，可以看出异常的处理流程。首先是
    `write_virtual_checks(): write beyond limit`引发了异常，由中断
