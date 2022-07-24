## 练习3：分析bootloader进入保护模式的过程。（要求在报告中写出分析）

BIOS将通过读取硬盘主引导扇区到内存，并转跳到对应内存中的位置执行bootloader。请分析bootloader是如何完成从实模式进入保护模式的。

提示：需要阅读**小节“保护模式和分段机制”**和lab1/boot/bootasm.S源码，了解如何从实模式切换到保护模式，需要了解：

- 为何开启A20，以及如何开启A20
- 如何初始化GDT表
- 如何使能和进入保护模式



### 为何要开启 A20？

为了兼容之前的处理器，cpu刚启动时处于实模式下，如8086只有20根地址线，采用分段的方式访问物理地址。其最大的寻址范围可以达到 0xffff << 4 + 0xffff = 0x10ffef，超出了20根地址线范围，但是在8086中会发生地址回卷，最高的20位会被丢掉，变成 0x0ffef。

所以在之后的处理器80286、80386中为了兼容8086，实模式下的第20根地址线恒位0，只有在进入保护模式下才会开启，因为保护模式下80386需要使用32位地址线，访问4GB内存地址

### 如何开启 A20？

通过修改0x92端口来开启/关闭 A20

在当前环境中，所用到的键盘控制器8042的IO端口只有0x60和0x64两个端口。8042通过这些端口给键盘控制器或键盘发送命令或读取状态。输出端口P2用于特定目的。位0（P20引脚）用于实现CPU复位操作，位1（P21引脚）用于控制A20信号线的开启与否

该过程主要分为

1. 等待8042控制器Inpute Buffer为空
2. 发送P2命令到Input Buffer
3. 等待Input Buffer为空
4. 将P2得到的第二个位（A20选通）置为1
5. 写回Input Buffer

### 如何进入保护模式？

通过将cr0寄存器的第0位（PE位：保护模式允许位）置1，cpu进入保护模式

### 代码分析

boot/bootasm.S

#### 初始化

```assembly
# start address should be 0:7c00, in real mode, the beginning address of the running bootloader
.globl start
start:
.code16                                             # Assemble for 16-bit mode
    cli                                             # Disable interrupts
    cld                                             # String operations increment, 字符串操作时方向递增

    # Set up the important data segment registers (DS, ES, SS).
    xorw %ax, %ax                                   # Segment number zero
    movw %ax, %ds                                   # -> Data Segment
    movw %ax, %es                                   # -> Extra Segment
    movw %ax, %ss                                   # -> Stack Segment
```

#### 开启 A20

以下是开启 A20 的某种方式，还可以通过向位于0x92端口的Fast Gate A20的第1位置1来开启A20

```assembly
# Enable A20:
#  For backwards compatibility with the earliest PCs, physical
#  address line 20 is tied low, so that addresses higher than
#  1MB wrap around to zero by default. This code undoes this.
seta20.1:
    # 读取0x64端口 ———— 读Status Register 中 8042的状态到 al
    inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
    testb $0x2, %al                                 # 测试该字节第二位是否为0
    jnz seta20.1                                    # 直到input buffer，即第二位为0，说明没数据

    movb $0xd1, %al                                 # 0xd1 -> port 0x64
    outb %al, $0x64                                 # 0xd1 means: write data to 8042's P2 port

seta20.2:
    inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
    testb $0x2, %al
    jnz seta20.2

    movb $0xdf, %al                                 # 0xdf -> port 0x60
    outb %al, $0x60                                 # 0xdf = 11011111, means set P2's A20 bit(the 1 bit) to 1
```

#### 初始化 GDT 表

注意点：

- x86采用的小端模式，即低位为低地址，高位高地址。而程序的可执行文件的内存地址随着代码的行数增加向下不断增大

**asm.h**

```assembly
/* Assembler macros to create x86 segments */

/* Normal segment */
#define SEG_NULLASM                                             \
    .word 0, 0;                                                 \
    .byte 0, 0, 0, 0

#define SEG_ASM(type,base,lim)                                  \
    .word (((lim) >> 12) & 0xffff), ((base) & 0xffff);          \
    .byte (((base) >> 16) & 0xff), (0x90 | (type)),             \
        (0xC0 | (((lim) >> 28) & 0xf)), (((base) >> 24) & 0xff)
```

- asm.h文件通过宏的方式来定义了初始化段描述符的宏函数。该函数中，段描述符的G=1，段界限已4K为单位，但参数lim以字节为单位，因此在段界限分片时均右移12位（除以4K）


word分别定义了段界限15、段基址

.byte分别定义了如下四部分：

1. 段基址23~16
2. P=1、DPL=00、S=1、TYPE=type
3. G=1、D/B=1、L=0、AVL=0、段界限19~16
4. 段基址31~24



**bootasm.S**

```assembly
# Bootstrap GDT 静态描述
.p2align 2                                          # force 4 byte alignment
gdt:
    SEG_NULLASM                                     # null seg
    SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)           # code seg for bootloader and kernel
    SEG_ASM(STA_W, 0x0, 0xffffffff)                 # data seg for bootloader and kernel

gdtdesc:
    .word 0x17                                      # sizeof(gdt) - 1
    .long gdt                                       # address gdt
```

- GDT中将代码段和数据段的base均设置为了0，而limit设置为了2^32-1即4G，此时就使得逻辑地址等于线性地址，方便后续对于内存的操作

#### 载入 GDT 表

```assembly
# Switch from real to protected mode, using a bootstrap GDT
# and segment translation that makes virtual addresses
# identical to physical addresses, so that the
# effective memory map does not change during the switch.
lgdt gdtdesc
movl %cr0, %eax
orl $CR0_PE_ON, %eax
movl %eax, %cr0
```

- 在完成A20开启之后，只需要使用命令`lgdt gdtdesc`即可载入全局描述符表；接下来只需要将cr0寄存器的PE位置1，即可从实模式切换到保护模式

#### 跳转到保护模式下的代码

```assembly
# Start the CPU: switch to 32-bit protected mode, jump into C.
# The BIOS loads this code from the first sector of the hard disk into
# memory at physical address 0x7c00 and starts executing in real mode
# with %cs=0 %ip=7c00.

.set PROT_MODE_CSEG,        0x8                     # kernel code segment selector
.set PROT_MODE_DSEG,        0x10                    # kernel data segment selector
.set CR0_PE_ON,             0x1                     # protected mode enable flag

# Jump to next instruction, but in 32-bit code segment.
# Switches processor into 32-bit mode.
ljmp $PROT_MODE_CSEG, $protcseg
```

- 接下来则使用一个长跳转指令，将cs修改为32位段寄存器，以及跳转到protcseg这一32位代码入口处，此时CPU进入32位模式
- ljmp 长跳转指令，把cs值变为PROT_MODE_CSEG 变量，把EIP指令寄存器的数值变为 $protcseg代码段的值。**其中CS的前12位为0x001，将其乘以8为0x008作为gdt表的偏移值来选择段描述符，所以其选择即为CS段描述符，其Base为0，偏移地址即为protcseg的地址。**

#### 设定运行时的栈

```assembly
.code32                                             # Assemble for 32-bit mode
protcseg:
    # Set up the protected-mode data segment registers
    movw $PROT_MODE_DSEG, %ax                       # Our data segment selector
    movw %ax, %ds                                   # -> DS: Data Segment
    movw %ax, %es                                   # -> ES: Extra Segment
    movw %ax, %fs                                   # -> FS
    movw %ax, %gs                                   # -> GS
    movw %ax, %ss                                   # -> SS: Stack Segment

    # Set up the stack pointer and call into C. The stack region is from 0--start(0x7c00)
    movl $0x0, %ebp
    movl $start, %esp
    call bootmain

    # If bootmain returns (it shouldn't), loop.
spin:
    jmp spin
```

- 接下来执行的32位代码功能为：设置ds、es, fs, gs, ss这几个段寄存器，然后初始化栈的frame pointer和stack pointer，然后调用使用C语言编写的bootmain函数，进行操作系统内核的加载，至此，bootloader已经完成了从实模式进入到保护模式的任务

- 由于段地址向下递减，所以我们设定初始栈顶指针起始位置在bootloader下，然后即可调用函数

![image-20220407102037722](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/202204071020813.png)



#### 整体代码

```assembly
#include <asm.h>

# Start the CPU: switch to 32-bit protected mode, jump into C.
# The BIOS loads this code from the first sector of the hard disk into
# memory at physical address 0x7c00 and starts executing in real mode
# with %cs=0 %ip=7c00.

.set PROT_MODE_CSEG,        0x8                     # kernel code segment selector
.set PROT_MODE_DSEG,        0x10                    # kernel data segment selector
.set CR0_PE_ON,             0x1                     # protected mode enable flag

# start address should be 0:7c00, in real mode, the beginning address of the running bootloader
.globl start
start:
.code16                                             # Assemble for 16-bit mode
    cli                                             # Disable interrupts
    cld                                             # String operations increment

    # Set up the important data segment registers (DS, ES, SS).
    xorw %ax, %ax                                   # Segment number zero
    movw %ax, %ds                                   # -> Data Segment
    movw %ax, %es                                   # -> Extra Segment
    movw %ax, %ss                                   # -> Stack Segment

    # Enable A20:
    #  For backwards compatibility with the earliest PCs, physical
    #  address line 20 is tied low, so that addresses higher than
    #  1MB wrap around to zero by default. This code undoes this.
seta20.1:
    inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
    testb $0x2, %al
    jnz seta20.1

    movb $0xd1, %al                                 # 0xd1 -> port 0x64
    outb %al, $0x64                                 # 0xd1 means: write data to 8042's P2 port

seta20.2:
    inb $0x64, %al                                  # Wait for not busy(8042 input buffer empty).
    testb $0x2, %al
    jnz seta20.2

    movb $0xdf, %al                                 # 0xdf -> port 0x60
    outb %al, $0x60                                 # 0xdf = 11011111, means set P2's A20 bit(the 1 bit) to 1

    # Switch from real to protected mode, using a bootstrap GDT
    # and segment translation that makes virtual addresses
    # identical to physical addresses, so that the
    # effective memory map does not change during the switch.
    lgdt gdtdesc
    movl %cr0, %eax
    orl $CR0_PE_ON, %eax
    movl %eax, %cr0

    # Jump to next instruction, but in 32-bit code segment.
    # Switches processor into 32-bit mode.
    ljmp $PROT_MODE_CSEG, $protcseg

.code32                                             # Assemble for 32-bit mode
protcseg:
    # Set up the protected-mode data segment registers
    movw $PROT_MODE_DSEG, %ax                       # Our data segment selector
    movw %ax, %ds                                   # -> DS: Data Segment
    movw %ax, %es                                   # -> ES: Extra Segment
    movw %ax, %fs                                   # -> FS
    movw %ax, %gs                                   # -> GS
    movw %ax, %ss                                   # -> SS: Stack Segment

    # Set up the stack pointer and call into C. The stack region is from 0--start(0x7c00)
    movl $0x0, %ebp
    movl $start, %esp
    call bootmain

    # If bootmain returns (it shouldn't), loop.
spin:
    jmp spin

# Bootstrap GDT
.p2align 2                                          # force 4 byte alignment
gdt:
    SEG_NULLASM                                     # null seg
    SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)           # code seg for bootloader and kernel
    SEG_ASM(STA_W, 0x0, 0xffffffff)                 # data seg for bootloader and kernel

gdtdesc:
    .word 0x17                                      # sizeof(gdt) - 1
    .long gdt                                       # address gdt

```





















































