## 本文目的

日常使用mac进行工作开发，win玩游戏，但是有时候需要在两端进行文件传输，由于生态不一样，只能用第三方工具来实现，例如：网盘、微信等；

所以想搭建一个 FTP 用于两端的文件传输，解决上述问题；

## 配置说明

- macbook  192.168.0.104
- win11 ip地址 192.168.0.106
- 通过wifi相连

## 搭建步骤

### win 搭建 ftp 服务端 

网上的教程很多了，而且操作也比较明确，可以参考这这篇文章；

https://blog.csdn.net/bai_langtao/article/details/126625683

### Mac连接到win到ftp服务器

在win上ipconfig查看一下ip地址，ftp服务器的默认端口号是21，可以先在 mac 上telnet 一下，检查端口和网络是否放通了；

方式1，使用本身的floder（不支持刷新，只能每次都重新连上去，很傻）

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/pcigo/image-20241110164835668.png" alt="image-20241110164835668" style="zoom: 33%;" />

方式2，使用第三方的ftp客户端，这里推荐 transmit，可以支持双向操作，手动刷新；

https://xclient.info/s/transmit.html#versions

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/picgo/image-20241110190416907.png" alt="image-20241110190416907" style="zoom:50%;" />

### Q&A

#### 1、mac无法ping通win11，但是win正常ping通Mac

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/pcigo/image-20241110162636650.png" style="zoom:50%;" />

原因：

- win的防火墙拦截了mac的请求，可以配置入站规则方通一下即可；
- 因为macbook可能连接别的wifi，导致ip地址变更，所以mac不建议配置固定ip，可以在win防火墙规则中，放通某个网段的ip即可解决问题；因为DHCP 分配的ip肯定在子网掩码的范围，即 192.169.0.0 ~ 192.168.0.255 之间

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/picgo/1731233525269.jpg" alt="1731233525269" style="zoom: 50%;" />

#### 2、win 重启后，DHCP 重新分配ip地址，导致mac又得重连

在 win 的网络设置中，取消 DHCP 动态分配ip，改为固定的，ip 地址、子网掩码、网关，可以先通过 ipconfig 命令查看；DNS 则去网上查一下你的运营商，例如，中国电信的DNS服务器地址，首选和备选即可；

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/picgo/1731232469617.jpg" alt="1731232469617" style="zoom:50%;" />
