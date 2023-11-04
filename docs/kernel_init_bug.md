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

    `门描述符不是有效的sys段`，这个门描述符是什么类型，在哪存着，我没有显式修改门描述符，其他内存区域被覆盖了？

    章节 5.4.4 中说，门描述符用来实现从低特权级的代码段转向高特权级的代码段，共 4 种：
        - 任务门，对应 TSS（任务状态段）的描述符
        - 中断门，对应一段例程
        - 陷阱门，对应一段例程
        - 调用门，对应一段例程

    所以我覆盖了 IDT ？还是说，我得初始化一下 IDT ？

    ```text
    [Page 37] 而 Linux 内核是在进入保护模式后才建立中断例程的，不过在保护模式下，中断向量表已经不存在了， 取而代之的是中断描述符表(Interrupt Descriptor Table，IDT)。该表与中断向量表的区别会在讲解中断时详 细介绍。所以在 Linux 下执行的中断调用，访问的中断例程是在中断描述符表中，已不在中断向量表里了。
    [Page 86] 对于中断描述符表寄存器 IDTR，咱们也是要通过 lidt 指令为其指定中断描述符表的地址。
    [Page 130] info idt 显示中断向量表 IDT
    [Page 249] 在咱们的系统中也只用到了中断门
    [Page 249] 中断门只存在于 IDT（中断描述符表）中，因此不能主动 调用，只能由中断信号来触发调用
    [Page 316] 所有的描述符大小都是 8 字节，而门其实就是描述符
    ```

    使用`info idt`查看 BUG 发生前的 IDT

    ```log
    <bochs:2> info idt
    Interrupt Descriptor Table (base=0x0000000000000000, limit=1023):
    ...
    IDT[0x08]=Code segment, base=0xf04dc000, limit=0x00000152, Execute-Only, Non-Conforming, 16-bit
    ...
    IDT[0x0e]=??? descriptor hi=0x00000000, lo=0xf000ff53
    ...
    ```

    IDT 有，结合报错日志看下，最先报的是 0x0e，然后是 0x08，是指 IDT[0x0e] 和 IDT[0x08] 吗？

    字符串“搬运”指令族: movsb、movsw、movsd。其中的 movs 代表 move string，后面的 b 代表 byte，w 代表 word，d 代表 dword。

    将 DS:[E]SI 指向的地址处的 1、2 或 4 个字节搬到 ES:[E]DI 指向的地址处。此处用到了 DS 和 ES，它们的此时值是

    ```log
    <bochs:3> sreg
    es:0x0010, dh=0x00cf9300, dl=0x0000ffff, valid=1
        Data segment, base=0x00000000, limit=0xffffffff, Read/Write, Accessed
    cs:0x0008, dh=0x00cf9900, dl=0x0000ffff, valid=1
            Code segment, base=0x00000000, limit=0xffffffff, Execute-Only, Non-Conforming, Accessed, 32-bit
    ss:0x0010, dh=0x00cf9300, dl=0x0000ffff, valid=31
            Data segment, base=0x00000000, limit=0xffffffff, Read/Write, Accessed
    ds:0x0010, dh=0x00cf9300, dl=0x0000ffff, valid=31
            Data segment, base=0x00000000, limit=0xffffffff, Read/Write, Accessed
    fs:0x0000, dh=0x00009300, dl=0x0000ffff, valid=1
            Data segment, base=0x00000000, limit=0x0000ffff, Read/Write, Accessed
    gs:0x0018, dh=0x00c0930b, dl=0x80000007, valid=1
            Data segment, base=0x000b8000, limit=0x00007fff, Read/Write, Accessed
    ldtr:0x0000, dh=0x00008200, dl=0x0000ffff, valid=1
    tr:0x0000, dh=0x00008b00, dl=0x0000ffff, valid=1
    gdtr:base=0x00000000c0000903, limit=0x1ff
    idtr:base=0x0000000000000000, limit=0x3ff
    ```

    群大佬思路：手动改下ecx 先改成1 没问题了再放回原来的值 再报就是越界了 页表填错。具体思路就是只写一个字节 没问题那就是首次访问没报异常 问题出现在后边某一次拷贝也就是越界 页表没写对 这时候应该还没贴idt吧 所以IDT无效

- 原因

    暂未排查出来
