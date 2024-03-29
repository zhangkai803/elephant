# elephant

## 资料

官方随书代码：<https://github.com/elephantos/elephant>

<https://github.com/yifengyou/os-elephant>

<https://github.com/yifengyou/os-elephant/blob/master/doc/%E3%80%8A%E6%93%8D%E4%BD%9C%E7%B3%BB%E7%BB%9F%E7%9C%9F%E8%B1%A1%E8%BF%98%E5%8E%9F%E3%80%8B%E5%8B%98%E8%AF%AF.md>

<https://segmentfault.com/a/1190000040124650?utm_source=sf-similar-article>

<https://love6.blog.csdn.net/article/details/119133589>

<https://juejin.cn/post/6990603677685940231>

<https://pdos.csail.mit.edu/>

## 环境

```txt
macOS==11.6
VSCode==1.61.0
bochs==2.6.11
nasm==2.15.05
```

以及 [i386 可执行文件的编译环境](./docs/mac编译i386可执行文件.md)

## bochs常用调试命令

- 继续执行：`c`
- 单步执行：`s`
- 显示调用：`show int`
- 显示中断：`show call`
- 打断点：`b 0x7c00`
- 反汇编：`u/16 0x7c00`
- 查看内存数据：`xp 0x7c00`
- 查看寄存器值：`r`
- 查看GDT：`info gdt`
- 查看CPU状态：`info cpu`

## 实用工具

进制转换器

## 快捷地址

- 中断向量表IVT 22页

## 思路整理

### 第一棒 BIOS（不需要写）

CPU 上电之后，会执行 0xFFFF0 处的代码（CS=0xF000, IP=0xFFF0）

此处是一条跳转指令 JMP F000:E05B，此地址处就是 BIOS 的代码。此代码是保存在硬件 ROM 里。
（Bochs 模拟时自带默认的 BIOS，在 bochsrc 中配置）

主要功能是硬件检测及初始化、准备一些数据结构（如 IVT），最后会检测磁盘中 0 盘 0 道 1 扇区的
内容是否以 0x55 和 0xAA 结尾，如果是，就将此扇区加载到内存物理地址 0x7C00 处，并跳转执行。

### 第二棒 MBR（需要写）

从 BIOS 加载并跳转至此，代码是 mbr.S，mbr 全称 Main Boot Record，意为 主引导记录。
（引导记录分很多种，如 OBR、DBR、EBR，此处不展开）

mbr.S 存放在硬盘最开始的部分，即 0 盘 0 道 1 扇区，大小为 512 Byte。并且以 0x55 和 0xAA 结尾。

主要功能是加载 loader.S 到内存（读盘函数 rd_disk_m_16），并跳转至 loader 去执行。（一些辅助功能略去，如打印进度提示信息）

### 第三棒 loader（需要写）

从 mbr 加载并跳转至此，代码是 loader.S，loader 是加载内核的最后一步，此处内容较多，并且与
硬件强相关，也严重关系到操作系统的工作方式。

loader 保存在硬盘上，在硬盘上位置也是事先约定的，加载到内存地址也是约定的。
以本代码为例，loader 代码从硬盘第 1 个扇区开始，占据后 8 个扇区。共 4 KB。（1 扇区是 mbr）
加载到内存地址 0x8000 处。

#### 第一步，进入保护模式

保护模式工作在 32 位环境。为什么要有保护模式：

实模式下的问题

1. 安全问题
    - 操作系统程序和用户程序无区分
    - 引用的地址都是真实物理地址
    - 用户可自由访问所有内存
2. 效率问题（使用方式带来的缺陷）
    - 实模式下的分段模型一次只能访问 64 KB 大小的内存区域，偏移地址只有 16 位
    - 单任务
3. 瓶颈
    - 最大寻址 1 MB 空间

保护模式带来的解决方案

1. CPU、地址总线、数据总线、寄存器宽度都发展到了 32 位
2. 引入全局描述符表、局部描述符表，段要提前定义好才能访问
3. 兼容 16 位运行环境，[bits 16]、虚拟 8086 模式
4. 其他（寻址方式扩展、指令扩展等）

进入保护模式三步

1. 打开 A20 Gate
2. 提前在内存中准备好 GDT，并加载
3. 保护模式的标志，CR0 第 0 位 置 1

#### 第二步 加载 kernel 至内存

与 loader 相同，kernel 保存在硬盘上，在硬盘上位置也是事先约定的，加载到内存地址也是约定的。
以本代码为例，kernel 代码从硬盘第 9 个扇区开始，占据后 200 个扇区。共 100 KB。
读取到内存地址 0x200000 处（读盘函数 rd_disk_m_32）。

#### 第三步 开启分页机制

1. 准备页表
    - 清空页目录地址处原内容
    - 写页目录表
    - 写页表
    - 补充页目录项
        - 重要：分隔内核与用户程序的内存空间
2. 开启分页
    - 保存原 GDT 地址
    - 手动改写每个段的段基址
    - 页目录表地址存入 CR3
    - 分页基址标志位，CR0 第 31 置 1
    - 重新加载 GDT

#### 第四步 初始化 kernel

解析 kernel elf 的 header，加载每个段到对应的位置

elf 文件格式 `/usr/include/elf.h`
