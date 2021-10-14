# 开发日志

此代码与《操作系统真象还原》书中代码并不完全一致，原因有3个：

1. 书中代码仍需勘误
2. 看完之后尝试重写，实践加深印象
3. 此前在centos6.3中尝试临摹，旨在与书中环境保持一致，实际情况却不如人意，该系统已不再维护，
centos6生态下的软件也非常古老，开发体验很差，学习进度也非常缓慢，所以在本机重新搭建开发环境。
macos和centos本身有差异，相关软件也已迭代多次，存在不兼容的情况，故无法做到一致。

## 流程

1. 按照`README.md`中的环境安装软件
2. 修改`bochs/bochsrc:21`的硬盘地址为`${cur_dir}/bochs/HD60M.img`

## 第一版MBR

利用 BIOS 中断打印字符

```shell
git checkout v_mbr
```

## 第二版MBR

操作显存打印字符

```shell
git checkout v_mbr_print_by_graph
```
