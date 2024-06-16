# win10下vscode远程VB下centos7，调试c++

## 写在开头

​	配置这个，是因为在学习cs144的时候，需要编写代码，进行测试用例的调试。可恨自己不是mac，不能无缝开发。双系统对于我这种从不关机的来说太痛苦了，每次都要关机开机，来回横跳。所以就想着搞个VirtualBox->Centos7。其实我更建议买个云服务器，这样不用自己配置虚拟机，省事多了。然后就开始在centos上搞了，搞完一个lab0，噢噢，还行，肉眼debug，强行debug，lab1就GG了，实在受不了，就根据互联网前辈们的cs144环境搭建文章，自己也摸索了3、4天，总算把这个环境给配置好了，希望接下来能好好写lab，不辜负我这几天的幸苦。

如果有学习 cs144 的兄弟，可以私信我，一起讨论。

注：这篇配置是我针对调试 cs144 而配置的，但是也能跑其他的项目，嘿嘿:smile:

遇到问题可以先看下面的[问题总结]() 

## 必要条件

windows

- openssh ：确保win的cmd运行 ssh --version 命令能看到版本号
- vscode

虚拟机

- cmake
- gcc g++ gdb 8.x 以上
- 能和主机相互 ping 通
- 能上网

## 配置过程

我讲的很简单，建议看这位老哥的配置过程，非常详细。

[Windows使用VSCode远程Linux（ConteOS）开发/调试C/C++（超详细）](https://blog.csdn.net/zy_workjob/article/details/104400805?utm_medium=distribute.pc_relevant.none-task-blog-2%7Edefault%7EBlogCommendFromBaidu%7Edefault-5.withoutpai&depth_1-utm_source=distribute.pc_relevant.none-task-blog-2%7Edefault%7EBlogCommendFromBaidu%7Edefault-5.withoutpai)

查看虚拟机 IP 地址，centos7 是 ip addr即可查看

![image-20210609200257721](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210609200257721.png)

### Remote Development

在vs code左侧列图表中，找到Extensions，然后搜索Remote Development，安装  Remote Development插件【这个包括了wsl、ssh、contains】，安装成功后，会在相同列下方出现Remote Explore（远程资源管理器）图标。点进去，选择添加，再选择当前用户下的 .ssh\config文件。

```shell
Host centos   # 名称（随便乱写）
    HostName x.xx.x.x  # ip
    User Happy   # 远程登录用户名
    IdentityFile ~/.ssh/id_rsa_32  # 私钥文件，如果没配置，默认使用 [UserHome]/.ssh/下的私钥文件（私钥文件如果不成功，需要检查文件权限问题。有时候直接从linux复制文件过来可以，但是windous本地创建文件再粘贴内容就不行）
```

然后连接成功后是这样的

![image-20210610202330683](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210610202330683.png)

### 配置c++

插件安装 

- c/c++中文
- 简化

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210610205601312.png" alt="image-20210610205601312" style="zoom:50%;" />

### 编译配置

建议先阅读

[vscode做C++开发，launch.json、tasks.json、settings.json写法示例](https://blog.csdn.net/qq_29935433/article/details/103690243?ops_request_misc=%257B%2522request%255Fid%2522%253A%2522160385708219724838523612%2522%252C%2522scm%2522%253A%252220140713.130102334.pc%255Fall.%2522%257D&request_id=160385708219724838523612&biz_id=0&utm_medium=distribute.pc_search_result.none-task-blog-2~all~first_rank_v2~rank_v28_p-16-103690243.pc_first_rank_v2_rank_v28p&utm_term=vscode%E7%9A%84tasks.json%E6%80%8E%E4%B9%88%E9%85%8D%E7%BD%AE&spm=1018.2118.3001.4187)

我主要想讲的是这部分，vscode的各种配置，配置不好就无法debug，这里也是搞了我最久时间的地方。

在虚拟机上随便一个位置创建一个测试程序，test1.cpp，点击左侧的运行和调试，ctrl+shift+p，然后随便选择一项，我这里选择的g++

![img](https://img-blog.csdnimg.cn/20200220153405255.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3p5X3dvcmtqb2I=,size_16,color_FFFFFF,t_70)

![img](https://img-blog.csdnimg.cn/20200220153535362.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3p5X3dvcmtqb2I=,size_16,color_FFFFFF,t_70)

#### lanuch.json

以上会在.vscode文件夹下，生成一个tasks.json的配置文件，和默认配置

![image-20210610205949756](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210610205949756.png)

以下是我修改好的配置，每个人的可能都不太一样，请认真看注释

```json
{
    // 使用 IntelliSense 了解相关属性。 
    // 悬停以查看现有属性的描述。
    // 欲了解更多信息，请访问: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "g++ - 生成和调试活动文件", //名称，就是调试程序的名称，这个随便写
            "type": "cppdbg", //配置类型，一般都是 cppdbg
            "request": "launch", //请求配置类型，默认 launch
            // "program": "${fileDirname}/${fileBasenameNoExtension}",
            // "program": "${workspaceFolder}/build/tests/${fileBasenameNoExtension}",
            "program": "/usr/local/cs_course/cs144_lab/sponge/build/tests/byte_stream_capacity", //可执行文件的路径，注意：这里是最重要是地方。你【编译后的文件】在哪，这里就怎么配置，注意名称！！！
            "args": [], //传参，就是 main() 里面的args
            "stopAtEntry": false, //可选参数。如果为 true，则调试程序应在目标的入口点处停止。如果传递了 processId，则不起任何作用。
            "cwd": "${workspaceFolder}",  //目标的工作目录
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "setupCommands": [
                {
                    "description": "为 gdb 启用整齐打印",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                }
            ],
            //"preLaunchTask": "C/C++: g++ 生成活动文件", //调试会话开始前要运行的任务，即tasks.josn要做的事情，编译文件，我因为cs144的tests都是编译好了的，所以直接可以运行，不用事先编译，所以我注释掉这行
            "miDebuggerPath": "/usr/bin/gdb" //这里运行 which gcc 出现的路径就是
        }
    ]
}
```

#### tasks.json

这个文件，可以配置执行launch.json 执行之前的操作，即执行编译过程。这也是为什么 launch.json中，"preLaunchTask": "C/C++: g++ 生成活动文件" 这个参数要与 task.json中的 label 一样

```json
{
    "tasks": [
        {
            "type": "cppbuild", //默认都是这个
            "label": "C/C++: g++ 生成活动文件", //要于lanch.json中的preLaunchTask一样
            "command": "/usr/bin/g++", //顾名思义，命令，其实这个json就是帮我们在terminal执行命令行，就cd到要运行的文件目录下，然后执行命令行， /usr/bin/g++ -g HelloWorld.cpp  -L /lib/xxx -o HelloWorld，这里生成的HelloWorld就会被 lanuch 所运行，所以一定要注意生成后的路径和名称问题
            "args": [  //命令行的参数，-g 要编译哪个文件，-L，链接库，-o 生成的可执行文件
                "-g",
                "${file}",
                "-L",
                "",
                "-o",
                "${fileDirname}/${fileBasenameNoExtension}"
            ],
            "options": {
                "cwd": "${fileDirname}"
            },
            "problemMatcher": [
                "$gcc"
            ],
            "group": {
                "kind": "build",
                "isDefault": true
            },
            "detail": "调试器生成的任务。"
        }
    ],
    "version": "2.0.0"
}
```

#### cpp_properties.json

这个也是非常重要的文件，没有这个很可能会报错，找不到各种头文件

```json
{
    "configurations": [
        {
            "name": "Linux",
            //includePath的官方解释：
            //              在搜索包含的标头时 IntelliSense 引擎要使用的路径列表。对这些路径的搜索不是递归搜索。指定 "**" 可指示递归搜索。例如: "${workspaceFolder}/**" 将搜索所有子目录，而 "${workspaceFolder}" 将不搜索所有子目录。
            // 意思就是说，把你可能需要的所有库的路径都加进来，这样就不会出现vscode对 #includ<xxx> 报错，找不到之类的
            "includePath": [ 
                "${workspaceFolder}/**",
                // "usr/include",
                // " /usr/local/include",
                // " /opt/rh/devtoolset-7/root/usr/include",
                // " /usr/include",
                "/usr/local/cs_course/cs144_lab/sponge/libsponge/**",
                "/opt/rh/devtoolset-7/root/usr/lib/gcc/x86_64-redhat-linux/7/include",
                "/opt/rh/devtoolset-7/root/usr/include/c++/7/backward",
                "/opt/rh/devtoolset-7/root/usr/include/c++/7/x86_64-redhat-linux",
                "/opt/rh/devtoolset-7/root/usr/include/c++/7"
            ],
            "defines": [],
            "compilerPath": "/usr/bin/gcc",
            // 这里是c++的版本，根据自己的项目配置，有些头文件需要高点的版本才有，如果配置完无效，重启vscode试试
            "cStandard": "c17",
            "cppStandard": "c++17",
            "intelliSenseMode": "linux-gcc-x64",
            "browse": {
                "path": [
                    "/usr/include/**"
                ]
            }
        }
    ],
    "version": 4
}
```

## CS144 环境搭建

按照lab的步骤，先git克隆sponge，然后创建build，然后进入build，执行 cmake ..

如果出现 `cmake commond not found`，就先安装cmake，再执行，遇到的错误大家搜索一下都能解决

执行make命令，注意，这里实验环境要求是 gcc 8 以上，如果不是的话，make可能会失败的。

如果使用 yum 安装 gcc 的话，默认安装的是 gcc 4.x，在 cmake 的时候就会提示报错。

```shell
You must compile this project with g++ >= 8 or clang >= 6.
```

所以，如果一开始没装，那么请直	接安装 gcc 8+

如果已经装了，先查看gcc版本，如果低于8，那么就需要更新gcc 的版本

### 更新 gcc

1、安装centos-release-scl

```shell
sudo yum install centos-release-scl
```

2、安装devtoolset，注意，如果想安装7.*版本的，就改成devtoolset-7-gcc*，以此类推

```shell
sudo yum install devtoolset-8-gcc*
```

3、激活对应的devtoolset，所以你可以一次安装多个版本的devtoolset，需要的时候用下面这条命令切换到对应的版本

```shell
scl enable devtoolset-8 bash
```

大功告成，查看一下gcc版本

```shell
gcc -v
版本更新成功
gcc version 8.3.1 20190311 (Red Hat 8.3.1-3) (GCC) 
```

补充：这条激活命令只对本次会话有效，重启会话后还是会变回原来的4.8.5版本，要想随意切换可按如下操作。

首先，安装的devtoolset是在 /opt/sh 目录下的

 每个版本的目录下面都有个 enable 文件，如果需要启用某个版本，所以要想切换到版本8，只需要执行

```shell
source /opt/rh/devtoolset-8/enable
```

可以将对应版本的切换命令写个shell文件放在配了环境变量的目录下，需要时随时切换，或者开机自启

4、直接替换旧的gcc

旧的gcc是运行的 /usr/bin/gcc，所以将该目录下的gcc/g++替换为刚安装的新版本gcc软连接，免得每次enable

```shell
mv /usr/bin/gcc /usr/bin/gcc-4.8.5
ln -s /opt/rh/devtoolset-8/root/bin/gcc /usr/bin/gcc
mv /usr/bin/g++ /usr/bin/g++-4.8.5
ln -s /opt/rh/devtoolset-8/root/bin/g++ /usr/bin/g++
gcc --version
g++ --version
```



## 运行成功

建议，连接到远程服务器后，会提示打开文件夹，这里建议选择你需要跑的项目文件夹，按 f5 生成 vscode，想下面这样，直接在cs144_lab下生成 .vscode 文件。

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210613115503730.png" alt="image-20210613115503730" style="zoom:50%;" />

f5运行时，请确保你按 f5 时所在的文件，其编译后的可执行文件能够在launch.json所配置的路径下找到，否则无法运行。

![image-20210613115713535](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210613115713535.png)

## 问题

### field ‘ifru_addr’ has incomplete type ‘sockaddr’

![image-20210610193055719](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210610193055719.png)

在sponge/libsponge/util/tun.cc 中插入

```c++
如果加入了还是报错，那么就是顺序错误，参考以下
Add the
#include <sys/socket.h>
#include <sys/types.h>
before the
#include <linux/if.h>
```

另外，如果你CMAKE的时候报出了如下错误：

```shell
CopyCMake Error: The following variables are used in this project, but they are set to NOTFOUND.
Please set them or make sure they are set and tested correctly in the CMake files:
LIBPCAP
    linked by target "udp_tcpdump" in directory /home/kangyu/sponge/apps
    linked by target "ipv4_parser" in directory /home/kangyu/sponge/tests
    linked by target "ipv4_parser" in directory /home/kangyu/sponge/tests
    linked by target "tcp_parser" in directory /home/kangyu/sponge/tests
    linked by target "tcp_parser" in directory /home/kangyu/sponge/tests
```

此时安装`libpcap-dev`库来解决，大多数的Linux发行版的软件源中应该都有这玩意。

### Bad owner or permissions 

> vscode中报错 Bad owner or permissions on C:\\Users\\user-name/.ssh/config

原因是由于使用Remote - SSH 扩展所依赖的Remote - SSH: Editing Configuration Files 扩展编辑了 C:\Users\Administrator.ssh\config</strong> 文件后，此文件的权限发生了改变。

在编辑了 %USER_HOME%\.ssh\config 文件后，不但在 VSCode 中由于配置文件权限问题而无法进行 SSH 远程连接，就连使用系统的 PowerShell 进行 SSH 连接时也会报此错误，而把此配置文件删除后，使用  PowerShell即可正常进行远程连接。但 VSCode 的 SSH 连接又依赖此配置文件，所以就产生了冲突，要么只有 PowerShell 能用，要么就都不能用。

#### 解决方法

1. 上Gitee 后者 Github 上下载 openssh-portable 项目

    ```shell
    git clone https://gitee.com/syk2wly/openssh-portable.git
    ```

2. 进入 openssh-portable 项目的 contrib\win32\openssh目录，用管理员身份执行 powershell 命令行，执行以下命令

    ```shell
    .\FixUserFilePermissions.ps1 -Confirm:$false
    ```

    执行此命令时若提示无法加载文件 FixUserFil ePermissions.ps1，因为在此系统上禁止运行脚本 错误，则先执行以下命令，然后输入 Y 回车确认后再重新执行（执行完毕后可以再执行以下命令输入 N 恢复默认配置）：

    ```shell
    Set-ExecutionPolicy RemoteSigned
    ```

3. 完成之后，重启vscode即可完成连接



### F5执行程序时报各种错误

对于能够连接上远程主机了，但是写好demo，直接f5测试时，就出现各样的问题，多半是 json文件没配置好。我建议先好好读一读文件的意思，磨刀不误砍柴工，我就是想不明所以，想直接抄别人的json配置，越搞越错，浪费了大量时间。

列举问题：

- launch :  xxxx does not exist，launch 的program 路径配置错误

![image-20210610214326240](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210610214326240.png)



建议阅读这位老哥的说明

[vscode做C++开发，launch.json、tasks.json、settings.json写法示例](https://blog.csdn.net/qq_29935433/article/details/103690243?ops_request_misc=%257B%2522request%255Fid%2522%253A%2522160385708219724838523612%2522%252C%2522scm%2522%253A%252220140713.130102334.pc%255Fall.%2522%257D&request_id=160385708219724838523612&biz_id=0&utm_medium=distribute.pc_search_result.none-task-blog-2~all~first_rank_v2~rank_v28_p-16-103690243.pc_first_rank_v2_rank_v28p&utm_term=vscode%E7%9A%84tasks.json%E6%80%8E%E4%B9%88%E9%85%8D%E7%BD%AE&spm=1018.2118.3001.4187)

## Reference

感谢下面的博主们！！！

[Windows使用VSCode远程Linux（ConteOS）开发/调试C/C++（超详细）](https://blog.csdn.net/zy_workjob/article/details/104400805?utm_medium=distribute.pc_relevant.none-task-blog-2%7Edefault%7EBlogCommendFromBaidu%7Edefault-5.withoutpai&depth_1-utm_source=distribute.pc_relevant.none-task-blog-2%7Edefault%7EBlogCommendFromBaidu%7Edefault-5.withoutpai)

[手把手教你VSCode+SSH+C++编译运行调试远程开发配置](https://blog.csdn.net/weixin_45646006/article/details/105021237)

[Windows使用VSCode远程Linux（Ubuntu/CentOS）开发/调试C/C++（超详细）](https://blog.csdn.net/weixin_44517656/article/details/109339071)

[vscode做C++开发，launch.json、tasks.json、settings.json写法示例](https://blog.csdn.net/qq_29935433/article/details/103690243?ops_request_misc=%257B%2522request%255Fid%2522%253A%2522160385708219724838523612%2522%252C%2522scm%2522%253A%252220140713.130102334.pc%255Fall.%2522%257D&request_id=160385708219724838523612&biz_id=0&utm_medium=distribute.pc_search_result.none-task-blog-2~all~first_rank_v2~rank_v28_p-16-103690243.pc_first_rank_v2_rank_v28p&utm_term=vscode%E7%9A%84tasks.json%E6%80%8E%E4%B9%88%E9%85%8D%E7%BD%AE&spm=1018.2118.3001.4187)

[B站](https://www.bilibili.com/video/BV1GC4y187fx?from=search&seid=12628300960475687544) 

[【计算机网络】Stanford CS144 Lab Assignments 学习笔记](https://www.cnblogs.com/kangyupl/p/stanford_cs144_labs.html) 

[【计算机网络】Stanford CS144 LAB0/LAB1/LAB2/LAB3](https://blog.csdn.net/weixin_44520881/article/details/108911578)

