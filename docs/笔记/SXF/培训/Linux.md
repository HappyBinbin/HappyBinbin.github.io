#### 账号管理

用户

- useradd
- userdel

用户组

- groupadd
- groupdel

修改密码

- passwd



#### 目录文件管理

可读 r=4 、可写 w=2、可执行 x=1

所属用户、所属用户组、其他用户

用户属主

- chown root:root -R data

权限位

- chmod 777 [文件名]
- chmod +x [文件名]

#### 账号提权

特权账号

- root

普通账号提权

- su
- sudo

#### CPU硬件信息查询

查看CPU的信息

- cat /proc/cupinfo

CPU利用率查询

- mpstat -P ALL 1

实时显示进程的动态

- top

查看所有进程

- ps aux
- ps auxf 树型结构
- ps -efHF 进程所在的CPU
- ps xaf -o pid,vsz,rss,state 指定显示某些列

#### Kill 命令

杀死进程

- kill 

强制杀死

- kill -9 [pid]
- killall -9 [name]

#### 内存硬件信息查询

查询内存硬件信息

- cat /proc/meninfo 

内存使用率.0

- free

查询进程的内存分布情况

- pmap [-x] [-d] [-q] [-A] pid

监控CPU使用、内存使用、进程状态（系统资源）

- vmstat [-a] [刷新延时 刷新次数]



#### 硬盘信息查询

查看所有块设备

- lsblk -d

硬件介质查询

- smartctl -i '设备路径'

#### 存储性能指标

IOPS：每秒处理的IO次数

时延：每个IO处理时间

吞吐：每秒处理的IO速率

固态硬盘 SDD

机械硬盘 HDD



#### 块设备统计

监视系统输入/输出、设备负载

- iostat -d -x [块号]

IO慢的定位手段

1. 先看util，100%说明硬盘可能存在瓶颈；过低则表示压力不够，瓶颈不在IO
2. await超过10ms，则业务会感知到IO慢
3. svctm > 10ms，硬盘寿命或raid卡故障
4. avgqu >60，业务压力过载

#### 进程IO统计

查询进程IO情况

- pidstat -d [pid]

#### 挂载新硬盘

分区命令

- fdisk

- parted

文件系统格式化

- mkfs

文件系统挂载

- mount

#### 文件系统

显示目前在 Linux 系统上的文件系统磁盘使用情况统计

- df -h

默认显示所有文件对象

- du
    - -d 统计目录深度 例如：du -d 1 统计一级目录

#### 小结

![image-20220710121646959](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20220710121646959.png)

#### 问题

![image-20220710121712168](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20220710121712168.png)







