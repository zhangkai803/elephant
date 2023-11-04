# mac编译i386可执行文件

## 资料

<https://wiki.osdev.org/GCC_Cross-Compiler>

<https://wiki.osdev.org/Why_do_I_need_a_Cross_Compiler>

<https://blog.csdn.net/weixin_40080866/article/details/89373262>

<https://danirod.es/blog/2015/i386-elf-gcc-on-mac>

<https://visualgmq.gitee.io/2020/06/11/Mac%E4%B8%8B%E5%AE%89%E8%A3%85i386%E7%BC%96%E8%AF%91%E5%B7%A5%E5%85%B7/>

## 我的步骤

```shell
# 指定安装目录
export PREFIX=$HOME/opt
mkdir -p $PREFIX
# 设置PATH
export PATH="$PREFIX/bin:$PATH"
# 安装包保存目录
mkdir -p $HOME/src
cd $HOME/src
# 安装包下载
wget ftp://ftp.gnu.org/gnu/binutils/binutils-2.25.tar.gz
# http://ftp.gnu.org/gnu/gcc/gcc-5.2.0/ 打开网页手动下载比较快
wget ftp://ftp.gnu.org/gnu/gcc/gcc-5.2.0/gcc-5.2.0.tar.gz
for pkg in *.tar.gz; do tar zxf $pkg; done

# compile binutils
mkdir build-binutils
cd build-binutils
../binutils-2.25/configure --prefix=$PREFIX \
   --target=i386-elf --disable-multilib \
   --disable-nls --disable-werror
make
make install

# compile gcc
cd $HOME/src/gcc-5.2.0
./contrib/download_prerequisites
cd ..
mkdir build-gcc
cd build-gcc
../gcc-5.2.0/configure --prefix=$PREFIX --target=i386-elf \
   --disable-multilib --disable-nls --disable-werror \
   --without-headers --enable-languages=c,c++
make all-gcc install-gcc
make all-target-libgcc install-target-libgcc
```
