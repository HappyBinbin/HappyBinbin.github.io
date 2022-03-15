# 1. vi 与 vim 的使用

## 1.1 简介

Linux 系统会内置 vi 文本编辑器 

Vim 具有程序编辑的能力，可以看做是 Vi 的增强版本，可以主动的以字体颜色辨别语法的正确性，方便程序设计。 代码补完、编译及错误跳转等方便编程的功能特别丰富，在程序员中被广泛使用。

## 1.2 安装vim

```shell
rpm -qa|grep vim // 查看是否安装了vim
vim-enhanced-7.0.109-7.el5
vim-minimal-7.0.109-7.el5
vim-common-7.0.109-7.el5
如果少了其中的某一条,比如 vim-enhanced 的,就用命令 yum -y install vim-enhanced 来安裝:
yum -y  install  vim-enhanced
如果上面的三条一条都沒有返回, 可以直接用 yum -y install vim* 命令
yum -y  install  vim*
```

## 1.3 三种模式

### 1.3.1 正常模式

以 vim 打开一个档案就直接进入一般模式了(这是**默认的模式**)。在这个模式中， 你可以使用『上下左右』按键来 移动光标，你可以使用『删除字符』或『删除整行』来处理档案内容， 也可以使用『复制、粘贴』来处理你的文件数据

### 1.3.2 插入模式

按下 i, I, o, O, a, A, r, R 等任何一个字母之后才会进入编辑模式, 一般来说按 i 即可

### 1.3.3 命令行模式

输入 esc 再输入：在这个模式当中， 可以提供你相关指令，完成读取、存盘、替换、离开 vim 、显示行号等的动作则是在此模式中达成的！

![image-20210321170359406](https://gitee.com/HappyBinbin/pcigo/raw/master/pic/20210321170359.png)

## 1.4 快捷键

1. 拷贝当前行 

    yy , 拷贝当前行向下的 5 行 5yy，并粘贴（输入 p）。 

2. 删除当前行 dd , 删除当前行向下的 5 行 5dd 

3. 在文件中查找某个单词 [命令行下 /关键字 ， 回车 查找 , 输入 n 就是查找下一个 ] 

4. 设置文件的行号，取消文件的行号.[命令行下 : set nu 和 :set nonu] 

5. 编辑 /etc/profile 文件，在一般模式下, 使用快捷键到该文档的最末行[G]和最首行[gg] 

6. 在一个文件中输入 "hello" ,在一般模式下, 然后又撤销这个动作 u 

7. 编辑 /etc/profile 文件，在一般模式下, 并将光标移动到 , 输入 20,再输入 shift+g 

8. 更多的看整理的文档 

9. 快捷键的键盘对应图

![查看源图像](https://th.bing.com/th/id/R04f5bab4a81718b894b6cdbde940e283?rik=%2f9DVJx%2bqwDQiwQ&riu=http%3a%2f%2falanhou.org%2fhomepage%2fwp-content%2fuploads%2f2014%2f05%2fvi-vim-keyboard.png&ehk=40nnJ13%2bXMu8gOqeliu8o%2bAOIOE0cz%2fhSQjyhkSSNMI%3d&risl=&pid=ImgRaw)



























