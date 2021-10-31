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
