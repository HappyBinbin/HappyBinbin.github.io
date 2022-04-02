# Ubuntu18.04安装gcc-4.9若是直接使用

sudo apt install gcc-4.9会报如下错误，步骤如下：

1.修改源

sudo gedit /etc/apt/sources.list
2.打开的文件最后添加如下两行


deb http://dk.archive.ubuntu.com/ubuntu/ xenial main

deb http://dk.archive.ubuntu.com/ubuntu/ xenial universe

3.更新源

sudo apt update

4.安装

sudo apt install gcc-4.9

此时，终端输入gcc --version发现默认版本仍然是7.4，更改为4.9，步骤如下

sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.9 100

此时，默认版本为gcc-4.9