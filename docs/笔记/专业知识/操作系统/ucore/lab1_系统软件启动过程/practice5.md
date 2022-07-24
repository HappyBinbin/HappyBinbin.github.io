### 练习5：实现函数调用堆栈跟踪函数 （需要编程）

我们需要在lab1中完成kdebug.c中函数print_stackframe的实现，可以通过函数print_stackframe来跟踪函数调用堆栈中记录的返回地址。在如果能够正确实现此函数，可在lab1中执行 “make qemu”后，在qemu模拟器中得到类似如下的输出：

```c
……
ebp:0x00007b28 eip:0x00100992 args:0x00010094 0x00010094 0x00007b58 0x00100096
    kern/debug/kdebug.c:305: print_stackframe+22
ebp:0x00007b38 eip:0x00100c79 args:0x00000000 0x00000000 0x00000000 0x00007ba8
    kern/debug/kmonitor.c:125: mon_backtrace+10
ebp:0x00007b58 eip:0x00100096 args:0x00000000 0x00007b80 0xffff0000 0x00007b84
    kern/init/init.c:48: grade_backtrace2+33
ebp:0x00007b78 eip:0x001000bf args:0x00000000 0xffff0000 0x00007ba4 0x00000029
    kern/init/init.c:53: grade_backtrace1+38
ebp:0x00007b98 eip:0x001000dd args:0x00000000 0x00100000 0xffff0000 0x0000001d
    kern/init/init.c:58: grade_backtrace0+23
ebp:0x00007bb8 eip:0x00100102 args:0x0010353c 0x00103520 0x00001308 0x00000000
    kern/init/init.c:63: grade_backtrace+34
ebp:0x00007be8 eip:0x00100059 args:0x00000000 0x00000000 0x00000000 0x00007c53
    kern/init/init.c:28: kern_init+88
ebp:0x00007bf8 eip:0x00007d73 args:0xc031fcfa 0xc08ed88e 0x64e4d08e 0xfa7502a8
<unknow>: -- 0x00007d72 –
……
```

请完成实验，看看输出是否与上述显示大致一致，并解释最后一行各个数值的含义

提示：可阅读小节“函数堆栈”，了解编译器如何建立函数调用关系的。在完成lab1编译后，查看

- lab1/obj/bootblock.asm，了解bootloader源码与机器码的语句和地址等的对应关系；查看
- lab1/obj/kernel.asm，了解 ucore OS源码与机器码的语句和地址等的对应关系

要求完成函数kern/debug/kdebug.c::print_stackframe的实现，提交改进后源代码包（可以编译执行），并在实验报告中简要说明实现过程，并写出对上述问题的回答

补充材料：

由于显示完整的栈结构需要解析内核文件中的调试符号，较为复杂和繁琐。代码中有一些辅助函数可以使用。例如可以通过调用print_debuginfo函数完成查找对应函数名并打印至屏幕的功能。具体可以参见kdebug.c代码中的注释

#### 函数堆栈

栈是一个很重要的编程概念（编译课和程序设计课都讲过相关内容），与编译器和编程语言有紧密的联系。理解调用栈最重要的两点是：栈的结构，EBP寄存器的作用。一个函数调用动作可分解为：零到多个PUSH指令（用于参数入栈），一个CALL指令。CALL指令内部其实还暗含了一个将返回地址（即CALL指令下一条指令的地址）压栈的动作（由硬件完成）。几乎所有本地编译器都会在每个函数体之前插入类似如下的汇编指令：

```assembly
pushl   %ebp
movl   %esp , %ebp
```

这样在程序执行到一个函数的实际指令前，已经有以下数据顺序入栈：参数、返回地址、ebp寄存器。由此得到类似如下的栈结构（参数入栈顺序跟调用方式有关，这里以C语言默认的CDECL为例）：

```text
+|  栈底方向        | 高位地址
 |    ...        |
 |    ...        |
 |  参数3        |
 |  参数2        |
 |  参数1        |
 |  返回地址        |
 |  上一层[ebp]    | <-------- [ebp]
 |  局部变量        |  低位地址
```

这两条汇编指令的含义是：首先将ebp寄存器入栈，然后将栈顶指针esp赋值给ebp。“mov %esp , %ebp”这条指令表面上看是用esp覆盖ebp原来的值，其实不然。因为给ebp赋值之前，原ebp值已经被压栈（位于栈顶），而新的ebp又恰恰指向栈顶。此时ebp寄存器就已经处于一个非常重要的地位，该寄存器中存储着栈中的一个地址（原ebp入栈后的栈顶），从该地址为基准，向上（栈底方向）能获取返回地址、参数值，向下（栈顶方向）能获取函数局部变量值，而该地址处又存储着上一层函数调用时的ebp值

一般而言，ss:[ebp+4]处为返回地址，ss:[ebp+8]处为第一个参数值（最后一个入栈的参数值，此处假设其占用4字节内存），ss:[ebp-4]处为第一个局部变量，ss:[ebp]处为上一层ebp值。由于ebp中的地址处总是“上一层函数调用时的ebp值”，而在每一层函数调用中，都能通过当时的ebp值“向上（栈底方向）”能获取返回地址、参数值，“向下（栈顶方向）”能获取函数局部变量值。如此形成递归，直至到达栈底。这就是函数调用栈

#### 输出堆栈信息

1. 首先使用read_ebp和read_eip函数获取当前stack frame的base pointer以及`call read_eip`这条指令下一条指令的地址，存入ebp, eip两个临时变量中；
2. 接下来使用cprint函数打印出ebp, eip的数值；
3. 接下来打印出当前栈帧对应的函数可能的参数，根据c语言编译到x86汇编的约定，可以知道参数存放在ebp+8指向的内存上（栈），并且第一个、第二个、第三个...参数所在的内存地址分别为ebp+8, ebp+12, ebp+16, ...，根据要求读取出当前函数的前四个参数(用可能这些参数并不是全都存在，视具体函数而定)，并打印出来；
4. 使用print_debuginfo打印出当前函数的函数名；
5. 根据动态链查找当前函数的调用者(caller)的栈帧, 根据约定，caller的栈帧的base pointer存放在callee的ebp指向的内存单元，将其更新到ebp临时变量中，同时将eip(代码中对应的变量为ra)更新为调用当前函数的指令的下一条指令所在位置（return address），其根据约定存放在ebp+4所在的内存单元中；
6. 如果ebp非零并且没有达到规定的STACKFRAME DEPTH的上限，则跳转到2，继续循环打印栈上栈帧和对应函数的信息；

注意点

- `eip`指向异常指令的下一条指令，所以要传入`print_debuginfo`的参数为`eip-1`

- 在切换栈帧时，先切换`eip`，后切换`ebp`，两者顺序不能颠倒。原因是当先切换ebp后，再切换的eip是已切换后的栈帧的上一个栈帧eip。eip隔着一个栈帧进行了切换，会导致输出错误

```c
void
print_stackframe(void) {
     /* LAB1 YOUR CODE : STEP 1 */
     /* (1) call read_ebp() to get the value of ebp. the type is (uint32_t);
      * (2) call read_eip() to get the value of eip. the type is (uint32_t);
      * (3) from 0 .. STACKFRAME_DEPTH
      *    (3.1) printf value of ebp, eip
      *    (3.2) (uint32_t)calling arguments [0..4] = the contents in address (unit32_t)ebp +2 [0..4]
      *    (3.3) cprintf("\n");
      *    (3.4) call print_debuginfo(eip-1) to print the C calling function name and line number, etc.
      *    (3.5) popup a calling stackframe
      *           NOTICE: the calling funciton's return addr eip  = ss:[ebp+4]
      *                   the calling funciton's ebp = ss:[ebp]
      */
    uint32_t ebp = read_ebp();
    uint32_t eip = read_eip();
    int i = 0;
    for(; i < STACKFRAME_DEPTH && ebp != 0; i++){
        
        cprintf("ebp: 0x%08x eip:0x%08x", ebp, eip);

        cprintf("args: 0x%08x 0x%08x 0x%08x 0x%08x", *(uint32_t *)(ebp + 8), *(uint32_t *)(ebp + 12), *(uint32_t *)(ebp + 16), *(uint32_t *)(ebp + 20));
        
        cprintf("\n");

        print_debuginfo(eip-1);
        
        eip = *(uint32_t *)(ebp + 4);
        ebp = *(uint32_t *)(ebp);

    }
}
```

可通过指针索引的方式访问指针所指内容。

获取当前的eip值较为巧妙，代码如下：

- 在调用该函数时会创建相应堆栈，通过创建函数时压入的上一级函数返回地址来间接得到当前的eip

```C
static __noinline uint32_t
read_eip(void) {
    uint32_t eip;
    asm volatile("movl 4(%%ebp), %0" : "=r" (eip));
    return eip;
}
```

#### 根据输出分析数值含义

最后一行的数据：

```assembly
ebp:0x00007bf8 eip:0x00007d6e args:0xc031fcfa 0xc08ed88e 0x64e4d08e 0xfa7502a8
    <unknow>: -- 0x00007d6d --
```

ebp是第一个被调用函数的栈帧的base pointer

eip是在该栈帧对应函数中调用下一个栈帧对应函数的指令的下一条指令的地址（return address）

args是传递给这第一个被调用的函数的参数

不妨在反汇编出来的kernel.asm和bootblock.asm中寻找0x7d6e这个地址，可以发现这个地址上的指令恰好是bootmain函数中调用OS kernel入口函数的指令的下一条，也就是说最后一行打印出来的是bootmain这个函数对应的栈帧信息。由于bootmain函数不需要任何参数，因此这些打印出来的数值并没有太大的意义，后面的`unkonw`之后的`0x00007d6d`则是bootmain函数内调用OS kernel入口函数的该指令的地址

关于其他每行输出中各个数值的意义为：

```assembly
ebp:0x00007b38 eip:0x00100a28 args:0x00010094 0x00010094 0x00007b68 0x0010007f
    kern/debug/kdebug.c:306: print_stackframe+22
```

ebp, eip等这一行数值意义与上述一致，下一行的输出调试信息，在*.c之后的数字表示当前所在函数进一步调用其他函数的语句在源代码文件中的行号，而后面的+22一类数值表示从该函数汇编代码的入口处到进一步调用其他函数的call指令的最后一个字节的偏移量，以字节为单位
