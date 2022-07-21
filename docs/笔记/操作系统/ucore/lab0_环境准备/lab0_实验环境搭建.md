# lab 环境搭建

## Reference

[1] https://www.cnblogs.com/whileskies/p/13138491.html

## 开发环境

**换源**

比较简单，只是提醒一下，免得下载时太慢

**ucore**

```shell
git clone https://github.com/chyyuu/os_kernel_lab.git
```

**qemu**

ucore使用qemu模拟器运行，qemu支持多种cpu架构的模拟，如i386、arm、mips等，通过apt可安装qemu，如下：

```shell
sudo apt-get install qemu-system
```

**gcc、gdb**

```shell
sudo apt-get install build-essential
```

注意 gcc 的版本，最合适的为 gcc 4.9

- 太高在 make 时，会出现make error，超出字节大小的错误
- 太低在 make gdb 进行调试时，会出现 `gcc:  '-fdiagnostics-color=always'` 的问题

这就是一个大坑~

## 调试

有了这些之后，基本上就能进行 vscode + wsl 远程调试 ucore 代码了

**进入 wsl**

切换分支为 x86-32

进入到 /os_kernel_lab/labcodes_answer/lab1_result

```shell
make clean 

make

make gbd
```

**进入 vscode**

vscode 中，找到 init.c 打上断点，F5，即可调试

![image-20220320160444197](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/202203201604301.png)
