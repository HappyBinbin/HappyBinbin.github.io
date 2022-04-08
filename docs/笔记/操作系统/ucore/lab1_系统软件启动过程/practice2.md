### 练习2：使用qemu执行并调试lab1中的软件。（要求在报告中简要写出练习过程）

为了熟悉使用qemu和gdb进行的调试工作，我们进行如下的小练习：

1. 从CPU加电后执行的第一条指令开始，单步跟踪BIOS的执行。
2. 在初始化位置0x7c00设置实地址断点,测试断点正常。
3. 从0x7c00开始跟踪代码运行,将单步跟踪反汇编得到的代码与bootasm.S和 bootblock.asm进行比较。
4. 自己找一个bootloader或内核中的代码位置，设置断点并进行测试。

> 提示：参考附录“启动后第一条执行的指令”，可了解更详细的解释，以及如何单步调试和查看BIOS代码。
>
> 提示：查看 labcodes_answer/lab1_result/tools/lab1init 文件，用如下命令试试如何调试bootloader第一条指令：
>
> ```bash
>  $ cd labcodes_answer/lab1_result/
>  $ make lab1-mon
> ```
> 



#### 1. 从CPU加电后执行的第一条指令开始，单步跟踪BIOS的执行

在Makefile中增加以下伪目标：

```shell
my-debug: $(UCOREIMG)
	$(V)$(QEMU) -S -s -parallel stdio -hda $< -serial null &
	$(V)sleep 2
	$(V)$(TERMINAL)  -e "gdb -tui -q -x tools/gdbinit"
```

其中tools/gdbinit文件内容为：

```cmake
set architecture i8086
target remote :1234
```

my-debug对应如下两条shell命令：

```shell
qemu-system-i386 -S -s -parallel stdio -hda bin/ucore.img -serial null &
gnome-terminal -e "gdb -tui -q -x tools/gdbinit"
```

输入`make my-debug`命令进行调试

![image-20220406231452344](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/202204062314409.png)可以看到第一条指令的cs内容为0xf000，eip内容为0xfff0，此时cpu处于实模式，物理地址=cs * 16 + ip，即当前指令地址为0xffff0

0xffff0处的指令为`ljmp $0x3630,$0xf000e05b` ，地址0xffff0为BIOS的入口地址，该地址的指令为跳转指令，跳转到0xf000:0xe05b处执行BIOS代码

正常在8086 16位模式下该处的指令为`ljmp $0xf000,$0xe05b` ，图上显示的可能是按照32位模式进行解释的，和预想不太一样

![image-20220406231459191](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/202204062314243.png)输入`si`后执行下一条指令，可见此时pc地址跳转到0xf000:0xe05b处，即0xfe05b，从此处开始执行BIOS代码，BIOS程序读取首扇区MBR上的bootloader代码放到0x7c00处，进而cpu控制权交给bootloader进行执行

#### 2. 在初始化位置0x7c00设置实地址断点,测试断点正常

输入`b *0x7c00`在0x7c00处打断点，输入`continue`运行到断点处

![image-20220406231506249](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/202204062315315.png)



#### 3. 从0x7c00开始跟踪代码运行,将单步跟踪反汇编得到的代码与bootasm.S和 bootblock.asm进行比较

输入`x /5i 0x7c00`显示0x7c00地址开始的连续5条指令，可见于bootasm.S中的前五条指令是一致的

[![image-20220406231514918](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/202204062315976.png)](https://img2020.cnblogs.com/blog/1159891/202007/1159891-20200716105340625-1642079072.png)

![image-20220406231520199](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/202204062315255.png)

### 4. 自己找一个bootloader或内核中的代码位置，设置断点并进行测试

见ucore lab0 实验准备
