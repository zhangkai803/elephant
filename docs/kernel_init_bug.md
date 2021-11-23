# 解析 elf 文件时的 BUG

## BUG 位置

```asm
; 逐字节拷贝
mem_cpy:
    ...
    rep movsb  ; bug here
    ...
```

## BUG日志

bochs日志

```log
00017649372e[CPU0  ] interrupt(): gate descriptor is not valid sys seg (vector=0x0e)
00017649372e[CPU0  ] interrupt(): gate descriptor is not valid sys seg (vector=0x08)
00017649372i[CPU0  ] CPU is in protected mode (active)
00017649372i[CPU0  ] CS.mode = 32 bit
00017649372i[CPU0  ] SS.mode = 32 bit
00017649372i[CPU0  ] EFER   = 0x00000000
00017649372i[CPU0  ] | EAX=00071000  EBX=00070034  ECX=0000003c  EDX=00000020
00017649372i[CPU0  ] | ESP=c00008e4  EBP=c00008e8  ESI=00071000  EDI=c0800000
00017649372i[CPU0  ] | IOPL=0 id vip vif ac vm RF nt of df if tf sf zf af PF cf
00017649372i[CPU0  ] | SEG sltr(index|ti|rpl)     base    limit G D
00017649372i[CPU0  ] |  CS:0008( 0001| 0|  0) 00000000 ffffffff 1 1
00017649372i[CPU0  ] |  DS:0010( 0002| 0|  0) 00000000 ffffffff 1 1
00017649372i[CPU0  ] |  SS:0010( 0002| 0|  0) 00000000 ffffffff 1 1
00017649372i[CPU0  ] |  ES:0010( 0002| 0|  0) 00000000 ffffffff 1 1
00017649372i[CPU0  ] |  FS:0000( 0005| 0|  0) 00000000 0000ffff 0 0
00017649372i[CPU0  ] |  GS:0018( 0003| 0|  0) 000b8000 00007fff 1 1
00017649372i[CPU0  ] | EIP=00000cd6 (00000cd6)
00017649372i[CPU0  ] | CR0=0xe0000011 CR2=0xc0800000
00017649372i[CPU0  ] | CR3=0x00100000 CR4=0x00000000
00017649372e[CPU0  ] exception(): 3rd (13) exception with no resolution, shutdown status is 00h, resetting
```

异常发生之前的信息

```log
<bochs:86> info tab
cr3: 0x000000100000
0x0000000000000000-0x00000000000fffff -> 0x000000000000-0x0000000fffff
0x00000000c0000000-0x00000000c00fffff -> 0x000000000000-0x0000000fffff
0x00000000ffc00000-0x00000000ffc00fff -> 0x000000101000-0x000000101fff
0x00000000fff00000-0x00000000ffffefff -> 0x000000101000-0x0000001fffff
0x00000000fffff000-0x00000000ffffffff -> 0x000000100000-0x000000100fff
<bochs:87> r
rax: 00000000_00071000
rbx: 00000000_00070034
rcx: 00000000_0000003c
rdx: 00000000_00000020
rsp: 00000000_c00008e4
rbp: 00000000_c00008e8
rsi: 00000000_00071000
rdi: 00000000_c0800000
r8 : 00000000_00000000
r9 : 00000000_00000000
r10: 00000000_00000000
r11: 00000000_00000000
r12: 00000000_00000000
r13: 00000000_00000000
r14: 00000000_00000000
r15: 00000000_00000000
rip: 00000000_00000cd6
eflags 0x00000006: id vip vif ac vm rf nt IOPL=0 of df if tf sf zf af PF cf
<bochs:88> info gdt
Global Descriptor Table (base=0x00000000c0000903, limit=511):
GDT[0x0000]=??? descriptor hi=0x00000000, lo=0x00000000
GDT[0x0008]=Code segment, base=0x00000000, limit=0xffffffff, Execute-Only, Non-Conforming, Accessed, 32-bit
GDT[0x0010]=Data segment, base=0x00000000, limit=0xffffffff, Read/Write, Accessed
GDT[0x0018]=Data segment, base=0xc00b8000, limit=0x00007fff, Read/Write, Accessed
GDT[0x0020]=??? descriptor hi=0x00000000, lo=0x00000000
```

## 排查

- 代码功能

    此时已从硬盘加载了 kernel 代码，并开启了分页机制，页表数据正常。下一步是要解析 kernel
    的 elf header，解析对应的段。

- 重点信息

    ```log
    gate descriptor is not valid sys seg
    rdx: 00000000_00000020
    GDT[0x0008]=Code segment, base=0x00000000, limit=0xffffffff, Execute-Only, Non-Conforming, Accessed, 32-bit
    ```

    感觉是这个地方的问题，此时 edx=0x00000020，对应的描述符索引为 0x8，这个段已经被初始化为
    代码段。段基址是 0x00000000，段界限是 0xffffffff。

    门描述符区域被覆盖？

- 原因

    暂未排查出来
