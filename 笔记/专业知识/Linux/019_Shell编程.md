# 17. Shell编程

## 17.1 为什么要学习 Shell 编程

1. Linux 运维工程师在进行服务器集群管理时，需要编写 Shell 程序来进行服务器管理。
2. 对于 JavaEE 和 Python 程序员来说，工作的需要，你的老大会要求你编写一些 Shell 脚本进行程序或者是服务器的维护，比如编写一个定时备份数据库的脚本。
3. 对于大数据程序员来说，需要编写 Shell 程序来管理集群

## 17.2 Shell 是什么

Shell 是一个命令行解释器，它为用户提供了一个向 Linux 内核发送请求以便运行程序的界面系统级程序，用户可以用 Shell 来启动、挂起、停止甚至是编写一些程序。

看一个示意图

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/20210407232521.png" alt="image-20210407232520399" style="zoom: 50%;" />

## 17.3 Shell 脚本的执行方式

### 17.3.1 脚本格式要求

1. 脚本以#!/bin/bash 开头
2. 脚本需要有可执行权限

### 17.3.2 编写第一个 Shell 脚本

需求说明：创建一个 Shell 脚本，输出 hello world!

```shell
vim hello.sh
#!/bin/bash
echo "hello,world~"
```

### 17.3.3 脚本的常用执行方式

方式 1(输入脚本的绝对路径或相对路径)

- 说明：首先要赋予 helloworld.sh 脚本的+x 权限， 再执行脚本
- 比如 ./hello.sh 或者使用绝对路径 /root/shcode/hello.sh

方式 2(sh+脚本)

- 说明：不用赋予脚本+x 权限，直接执行即可
- 比如 sh hello.sh , 也可以使用绝对路径

## 17.4 Shell 的变量

### 17.4.1 Shell 变量介绍

1. Linux Shell 中的变量分为，系统变量和用户自定义变量。
2. 系统变量：$HOME、$PWD、$SHELL、$USER 等等，比如： echo $HOME 等等..
3. 显示当前 shell 中所有变量：set

### 17.4.2 shell 变量的定义

基本语法

1. 定义变量：变量名=值
2. 撤销变量：unset 变量
3. 声明静态变量：readonly 变量，注意：不能 unset

快速入门

案例 1：定义变量 A

案例 2：撤销变量 A

案例 3：声明静态的变量 B=2，不能 unset

```shell
#!/bin/bash
#案例 1：定义变量 A
A=100
#输出变量需要加上$
echo A=$A
echo "A=$A"
#案例 2：撤销变量 A
unsetA
echo "A=$A"
#案例 3：声明静态的变量 B=2，不能 unset
readonly B=2
echo "B=$B"
#unset B
#将指令返回的结果赋给变量
shell 脚本的多行注释  :<<!   内容   !
:<<!
C=`date`
D=$(date)
echo "C=$C"
echo "D=$D"
!
#使用环境变量 TOMCAT_HOME
echo "tomcat_home=$TOMCAT_HOME"
```

案例 4：可把变量提升为全局环境变量，可供其他 shell 程序使用[该案例后面讲]

### 17.4.3 shell 变量的定义

定义变量的规则

1. 变量名称可以由字母、数字和下划线组成，但是不能以数字开头。5A=200(×)
2. 等号两侧不能有空格
3. 变量名称一般习惯为大写， 这是一个规范，我们遵守即可

将命令的返回值赋给变量

1. A=`date`反引号，运行里面的命令，并把结果返回给变量 A
2. A=$(date) 等价于反引号

## 17.5 设置环境变量

### 17.5.1 基本语法

1. export 变量名=变量值 （功能描述：将 shell 变量输出为环境变量/全局变量）
2. source 配置文件 （功能描述：让修改后的配置信息立即生效）
3. echo $变量名 （功能描述：查询环境变量的值）
4. 示意

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/20210407232809.png" alt="image-20210407232809649" style="zoom:50%;" />

### 17.5.2 快速入门

1. 在/etc/profile 文件中定义 TOMCAT_HOME 环境变量
2. 查看环境变量 TOMCAT_HOME 的值
3. 在另外一个 shell 程序中使用 TOMCAT_HOME
    注意：在输出 TOMCAT_HOME 环境变量前，需要让其生效
    source /etc/profile

![image-20210407232840423](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/20210407232840.png)

```shell
shell 脚本的多行注释
:<<! 内容 !
```

## 17.6 位置参数变量

### 17.6.1 介绍

当我们执行一个 shell 脚本时，如果希望获取到命令行的参数信息，就可以使用到位置参数变量，比如 ： ./myshell.sh 100 200 , 这个就是一个执行 shell 的命令行，可以在 myshell 脚本中获取到参数信息

### 17.6.2 基本语法

$n （功能描述：n 为数字，$0 代表命令本身，$1-$9 代表第一到第九个参数，十以上的参数，十以上的参数需要用大括号包含，如${10}）
$* （功能描述：这个变量代表命令行中所有的参数，$*把所有的参数看成一个整体）
$@（功能描述：这个变量也代表命令行中所有的参数，不过$@把每个参数区分对待）
$#（功能描述：这个变量代表命令行中所有参数的个数）

### 17.6.3 位置参数变量

案例：编写一个 shell 脚本 position.sh ， 在脚本中获取到命令行的各个参数信息。

![image-20210407232949128](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/20210407232949.png)

## 17.7 预定义变量

### 17.7.1 基本介绍

就是 shell 设计者事先已经定义好的变量，可以直接在 shell 脚本中使用

### 17.7.2 基本语法

1. $$ （功能描述：当前进程的进程号（PID））
2. $! （功能描述：后台运行的最后一个进程的进程号（PID））
3. $？（功能描述：最后一次执行的命令的返回状态。如果这个变量的值为 0，证明上一个命令正确执行；如果这个变量的值为非 0（具体是哪个数，由命令自己来决定），则证明上一个命令执行不正确了。）

### 17.7.3 应用实例

在一个 shell 脚本中简单使用一下预定义变量
preVar.sh

```shell
#!/bin/bash
echo "当前执行的进程 id=$$"
#以后台的方式运行一个脚本，并获取他的进程号
/root/shcode/myshell.sh &
echo "最后一个后台方式运行的进程 id=$!"
echo "执行的结果是=$?"
```

## 17.8 运算符

### 17.8.1 基本介绍

学习如何在 shell 中进行各种运算操作。

### 17.8.2 基本语法

1. “$((运算式))”或“$[运算式]”或者 expr m + n //expression 表达式
2. 注意 expr 运算符间要有空格, 如果希望将 expr 的结果赋给某个变量，使用 ``
3. expr m - n
4. expr \*, /, % 乘，除，取余

### 17.8.3 应用实例 oper.sh

案例 1：计算（2+3）X4 的值
案例 2：请求出命令行的两个参数[整数]的和 20 50

```shell
#!/bin/bash
#案例 1：计算（2+3）X4 的值
#使用第一种方式
RES1=$(((2+3)*4))
echo "res1=$RES1"
#使用第二种方式, 推荐使用
RES2=$[(2+3)*4]
echo "res2=$RES2"
#使用第三种方式 expr
TEMP=`expr 2 + 3`
RES4=`expr $TEMP \* 4`
echo "temp=$TEMP"
echo "res4=$RES4"
#案例 2：请求出命令行的两个参数[整数]的和 20 50
SUM=$[$1+$2]
echo "sum=$SUM"
```

## 17.9 条件判断

### 17.9.1 判断语句

- 基本语法
    	[ condition ]（注意 condition 前后要有空格）

- ​	#非空返回 true，可使用$?验证（0 为 true，>1 为 false）

应用实例

- [ hspEdu ] 返回 true
- [ ] 返回 false
- [ condition ] && echo OK || echo notok 条件满足，执行后面的语句

判断语句

常用判断条件

1. = 字符串比较
2. 两个整数的比较
    - -lt 小于
    - -le 小于等于 little equal
    - -eq 等于
    - -gt 大于
    - -ge 大于等于
    - -ne 不等于
3. 按照文件权限进行判断
    - -r 有读的权限
    - -w 有写的权限
    - -x 有执行的权限
4. 按照文件类型进行判断
    - -f 文件存在并且是一个常规的文件
    - -e 文件存在
    - -d 文件存在并是一个目录

应用实例

案例 1："ok"是否等于"ok"

- 判断语句：使用 =

案例 2：23 是否大于等于 22

- 判断语句：使用 -ge

案例 3：/root/shcode/aaa.txt 目录中的文件是否存在

- 判断语句： 使用 -f

![image-20210407233250892](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/20210407233251.png)

## 17.10流程控制

### 17.10.1 if 判断

基本语法

```shell
if [ 条件判断式 ]
then
	代码
fi
	或者 , 多分支

if [ 条件判断式 ]
then
	代码
elif [条件判断式]
then
	代码
fi
```

注意事项：[ 条件判断式 ]，中括号和条件判断式之间必须有空格

应用实例 ifCase.sh

案例：请编写一个 shell 程序，如果输入的参数，大于等于 60，则输出 "及格了"，如果小于 60,则输出 "不及格"

![image-20210407233407096](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/20210407233407.png)

### 17.10.2 case 语句

基本语法

```shell
case $变量名 in
"值 1"）
 如果变量的值等于值 1，则执行程序 1
;;
"值 2"）
 如果变量的值等于值 2，则执行程序 2
;;
 …省略其他分支…
*）
如果变量的值都不是以上的值，则执行此程序
;;
esac
```

![image-20210407233554160](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/20210407233554.png)

### 17.10.3 for 循环

基本语法 1

```shell
for 变量 in 值 1 值 2 值 3…
do
程序/代码
done
应用实例 testFor1.sh
```

案例 1 ：打印命令行输入的参数 [这里可以看出$* 和 $@ 的区别]

基本语法 2

```shell
for (( 初始值;循环控制条件;变量变化 ))
do
程序/代码
done
```

应用实例 testFor2.sh

案例 1 ：从 1 加到 100 的值输出显示

![image-20210407233703917](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/20210407233704.png)

![](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/20210407233704.png)

### 17.10.4 while 循环

基本语法 1

```
while [ 条件判断式 ]
do
程序 /代码
done
```

注意：while 和 [有空格，条件判断式和 [也有空格

应用实例 testWhile.sh

案例 1 ：从命令行输入一个数 n，统计从 1+..+ n 的值是多少?

```shell
#!/bin/bash
#案例 1 ：从命令行输入一个数 n，统计从 1+..+ n 的值是多少？
SUM=0
i=0
while [ $i -le $1 ]
do
SUM=$[$SUM+$i]
#i 自增
i=$[$i+1]
done
echo "执行结果=$SUM"
```

## 17.11read 读取控制台输入

### 17.11.1 基本语法

read(选项)(参数)

选项：

- -p：指定读取值时的提示符；
- -t：指定读取值时等待的时间（秒），如果没有在指定的时间内输入，就不再等待了。。

参数

变量：指定读取值的变量名

### 17.11.2 应用实例 testRead.sh

案例 1：读取控制台输入一个 NUM1 值

案例 2：读取控制台输入一个 NUM2 值，在 10 秒内输入。

代码:

```shell
#!/bin/bash
#案例 1：读取控制台输入一个 NUM1 值
read -p "请输入一个数 NUM1=" NUM1
echo "你输入的 NUM1=$NUM1"
#案例 2：读取控制台输入一个 NUM2 值，在 10 秒内输入。
read -t 10 -p "请输入一个数 NUM2=" NUM2
echo "你输入的 NUM2=$NUM2"
```

## 17.12函数

### 17.12.1 函数介绍

shell 编程和其它编程语言一样，有系统函数，也可以自定义函数。系统函数中，我们这里就介绍两个。

### 17.12.2 系统函数

basename 基本语法

- 功能：返回完整路径最后 / 的部分，常用于获取文件名
- basename [pathname] [suffix]
- basename [string] [suffix] （功能描述：basename 命令会删掉所有的前缀包括最后一个（‘/’）字符，然后将字符串显示出来。

选项：

- suffix 为后缀，如果 suffix 被指定了，basename 会将 pathname 或 string 中的 suffix 去掉。

应用实例

案例 1：请返回 /home/aaa/test.txt 的 "test.txt" 部分

- basename /home/aaa/test.txt

dirname 基本语法

功能：返回完整路径最后 / 的前面的部分，常用于返回路径部分 dirname 文件绝对路径 （功能描述：从给定的包含绝对路径的文件名中去除文件名（非目录的部分），然后返回剩
下的路径（目录的部分））

应用实例

案例 1：请返回 /home/aaa/test.txt 的 /home/aaa

- dirname /home/aaa/test.txt

### 17.12.3 自定义函数

基本语法

```shell
[ function ] funname[()]
{
	Action;
	[return int;]
}
调用直接写函数名：funname [值]
```

应用实例

案例 1：计算输入两个参数的和(动态的获取)， getSum

代码

```shell
#!/bin/bash
#案例 1：计算输入两个参数的和(动态的获取)， getSum
#定义函数 getSum
function getSum() {
	SUM=$[$n1+$n2]
	echo "和是=$SUM"
}
#输入两个值
read -p "请输入一个数 n1=" n1
read -p "请输入一个数 n2=" n2
#调用自定义函数
getSum $n1 $n2
```



## 17.13Shell 编程综合案例

### 17.13.1 需求分析

1. 每天凌晨 2:30 备份 数据库 hspedu 到 /data/backup/db
2. 备份开始和备份结束能够给出相应的提示信息
3. 备份后的文件要求以备份时间为文件名，并打包成 .tar.gz 的形式，比如：2021-03-12_230201.tar.gz
4. 在备份的同时，检查是否有 10 天前备份的数据库文件，如果有就将其删除。
5.  画一个思路分析图

![image-20210407234335134](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/pic/20210407234335.png)

### 17.13.2 代码 /usr/sbin/mysql_db.backup.sh

```shell
#备份目录
BACKUP=/data/backup/db
#当前时间
DATETIME=$(date +%Y-%m-%d_%H%M%S)
echo $DATETIME
#数据库的地址
HOST=localhost
#数据库用户名
DB_USER=root
#数据库密码
DB_PW=hspedu100
#备份的数据库名
DATABASE=hspedu
#创建备份目录, 如果不存在，就创建
[ ! -d "${BACKUP}/${DATETIME}" ] && mkdir -p "${BACKUP}/${DATETIME}"
#备份数据库
mysqldump -u${DB_USER} -p${DB_PW} --host=${HOST} -q -R --databases ${DATABASE} | gzip >
${BACKUP}/${DATETIME}/$DATETIME.sql.gz
#将文件处理成 tar.gz
cd ${BACKUP}
tar -zcvf $DATETIME.tar.gz ${DATETIME}
#删除对应的备份目录
rm -rf ${BACKUP}/${DATETIME}
#删除 10 天前的备份文件
find ${BACKUP} -atime +10 -name "*.tar.gz" -exec rm -rf {} \;
echo "备份数据库${DATABASE} 成功~"
```