## Reference

1. [了解 DNS 解析 和 resolv.conf](https://medium.com/@hsahu24/understanding-dns-resolution-and-resolv-conf-d17d1d64471c)
2. [Linux Networking：DNS](https://yuminlee2.medium.com/linux-networking-dns-7ff534113f7d)
3. [Kubenetes：DNS](https://yuminlee2.medium.com/kubernetes-dns-bdca7b7cb868)
4. [从 Service DNS 记录到 IP 地址，KubeDNS 工作原理（重点推荐阅读）](https://www.lixueduan.com/posts/kubernetes/16-kubedns-workflow/) 这篇文章写的确实太好了，解决困扰我很久的"dns是怎么解析的问题？"

## Linux  DNS 

一般配置在 /etc/resolv.conf 中，有以下几个组成结构：

- nameserver：定义 DNS 服务器的 IP 地址，可以有多个
- domain：定义本地域名，即主机的域名
- search：定义域名的搜索列表，查询顺序
- sortlist：对返回的域名进行排序

举例：

```shell
cat /etc/resolv.conf
domain  example.com
search  www.example.com  example.com
nameserver 202.102.192.68
nameserver 202.102.192.69
```

作用解析：

- nameserver 顾名思义，去这个ip地址查询对应的DNS
- search，简单来说就是帮你省略了查询域名的后缀，当你没有使用FQDN时，可以自动帮你填充；例如：你在/etc/hosts 配置了 192.168.1.1 happy.example.com，那么当你 ping happy.example.com 时，就能成功；但当你直接 ping happy 时，就会失败；所以，在 配置 search example.com 后，再 ping happy ，就能成功了，当然也开可以再 /etc/hosts 中再添加一条 192.168.1.1 happy 的记录。
- domain：在没有配置search的情况下，search默认为domain的值

## Linux  Network

这里不得不提一下，Linux 的 Network 或者 NetworkManager 服务，会更新  /etc/resolv.conf 的配置，如果ifcfg-eth* 中包含了DNS的配置，则需要注意，重启网络服务后，DNS配置会更新到 /etc/resolv.conf 下

> 曾经就在工作中遇到这个坑，一直排查不到是哪里修改了 /etc/resolve.conf 文件的 dns 服务器地址

## K8s NDS

前置知识：
- Kubernetes Service 通过虚拟 IP 地址或者节点端口为用户应用提供访问入口，然而这些 IP 地址和端口是动态分配的，实际项目中无法把一个可变的入口发布出去供用户访问。为了解决这个问题，Kubernetes 提供了内置的域名服务，用户定义的服务会自动获取域名，通过域名解析，可以对外向用户提供一个固定的服务访问地址

在日常工作中，我们在podA中要访问另外一个podB服务，都是直接以 `[podB名称：port]` 的形式访问的，k8s 自动帮我们解析`podB`这个域名为对应的ip的

几个核心问题：
- service 的 dns 记录是怎么解析为 ip 地址的？
- 哪个服务负责解析？是怎么解析的？
- pod 怎么知道要把请求发给谁进行解析？

Pod 的 DNS 的配置，由dnspolicy决定，以下为官方的说明：

- "Default": Pod 从运行所在的节点继承名称解析配置。
- "ClusterFirst": 与配置的集群域后缀不匹配的任何 DNS 查询（例如 "www.kubernetes.io"） 都会由 DNS 服务器转发到上游名称服务器。集群管理员可能配置了额外的存根域和上游 DNS 服务器。 
- "ClusterFirstWithHostNet": 对于以 hostNetwork 方式运行的 Pod，应将其 DNS 策略显式设置为 "ClusterFirstWithHostNet"。否则，以 hostNetwork 方式和 "ClusterFirst" 策略运行的 Pod 将会做出回退至 "Default" 策略的行为。注意：这在 Windows 上不支持。
- "None": 此设置允许 Pod 忽略 Kubernetes 环境中的 DNS 设置。Pod 会使用其 dnsConfig 字段所提供的 DNS 设置。 

在容器 Pod 中，发起一个请求时，dns 的解析过程如下：

<img src="https://happychan.oss-cn-shenzhen.aliyuncs.com/img/202407312057356.jpg" alt="1722430603862" style="zoom: 40%;" />

Step1：POd 的DNS 处理流程：

1、读取 /etc/resolv.conf 

- 这个文件是基于 pod 的 dnsPolicy 生成的

2、查询 nameservers，通常配置的都是 k8s-cluster-dns

3、应用 search 和 domain 参数进行搜索

4、dns 查询流程：

- 解析器会根据 search 中的配置，检查主机名是否需要其他域名后缀，即是否为FQDN
- 如果搜索的域名不是并不是内部名称，则将其视为 FQDN

Step2：CoreDns 处理过程

当请求到达CoreDNS后，就会根据 Corefile 配置文件，进行处理

```nginx
.:53 {
    forward . 8.8.8.8
    cache 30
    log
    errors
}

cluster.local:53 {
    kubernetes cluster.local in-addr.arpa ip6.arpa {
        pods verified
        upstream
        fallthrough in-addr.arpa ip6.arpa
    }
    cache 30
    log
    errors
}

```

1、接收DNS查询

- CoreDNS 接收查询并根据配置进行转发响应

2、检查 Corefile 的配置

- 检查配置的区域和记录，以用于解析内部集群域或服务

3、内部处理

- 如果访问的域是内部集群的，则使用内部的DNS记录进行解析；即 kubenetes 插件处理的域
    - cluster.local 默认域、in-addr.arpa  IPv4 地址的反向DNS查询域；ip6-arpa 同理；
    - pods verified 允许用 pod 的 ip 进行 DNS 查询

4、外部处理

- 如果访问域是非内部集群的，例如：example.com，则会转发到Corefile中指定的上游 DNS 服务器，这里会转发到 8.8.8.8 


![image.png](https://happychan.oss-cn-shenzhen.aliyuncs.com/picgo/20250103185205.png)