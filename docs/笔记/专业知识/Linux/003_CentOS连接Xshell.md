https://blog.csdn.net/qq_38024403/article/details/82415217

https://www.cnblogs.com/chenhaoqiang/p/9491902.html

https://www.cnblogs.com/leezhxing/p/4482659.html

### Centos 如何连接 Xshell

因为我下载的是 centos的Minum版本，所以默认没有安装ipconfig

可以先检查主机能否ping通虚拟机的ip地址，可以	才能连接xshell

此时可以ping通 Internet网络，但主机无法通过xshell工具连接到虚拟机！下面来解决这个问题：

确保关闭虚拟机，启用下图中的网卡2：

![20180803221405457](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/20180803221405457.jpg)

即为虚拟机设置两张网卡：

1. 网卡1设置为网络地址转换（NAT）,实现虚拟机通过主机网络访问互联网；
2. 网卡2设置为**host-only**；实现主机与虚拟机互联,重启虚拟机；

输入ifconfig 查看网络网卡信息：由于我们的安装包是最小化CentOS,默认没有安装ifconfig命令，先升级下系统：

yum update; 
yum search ifconfig, 搜索ifconfig命令所在的安装包：

再执行yum install net-tools.x86_64

ip addr

![image-20210315161017928](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20210315161017928.png)
