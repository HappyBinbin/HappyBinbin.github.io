
kubeadm是官方社区推出的一个用于快速部署kubernetes集群的工具。

这个工具能通过两条指令完成一个kubernetes集群的部署：

```
# 创建一个 Master 节点
$ kubeadm init

# 将一个 Node 节点加入到当前集群中
$ kubeadm join <Master节点的IP和端口 >
```

## 1. 安装要求

在开始之前，部署Kubernetes集群机器需要满足以下几个条件：

- 一台或多台机器，操作系统 CentOS7.x-86_x64
- 硬件配置：2GB或更多RAM，2个CPU或更多CPU，硬盘30GB或更多
- 可以访问外网，需要拉取镜像，如果服务器不能上网，需要提前下载镜像并导入节点
- 禁止swap分区

## 2. 准备环境

### 创建虚拟机

下载 VMWare Pro ，密钥懂的都懂，搜一搜就有

下载 Centos7 x-86_x64.ios 镜像,选择最小可运行版本即可

打开 VMWare => 典型 => 安装程序光盘映像文件（选择前边下载的centos7）=> Linux，Centos7 => 虚拟机名称和位置可以自定 =>  最大磁盘 30 G，拆不拆分随意 => 自定义内存为2G， CPU 核数为 2 => 按照步骤操作即可

### 网络配置

激活网卡，编辑`ifcfg_ens33`文件激活

```bash
cd /etc/sysconfig/network-scripts/
vi ifcfg-ens33
```

将 ONBOOT 改为 yes， ip 地址就会 DHCP 自定生成，但是这样每次重开都会改变，所以我们要改为静态IP

第一步：设置VMWare 虚拟机的网关

![image-20220731211606605](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20220731211606605.png)

![image-20220731213019194](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20220731213019194.png)

![image-20220731213055202](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20220731213055202.png)

第二步：配置虚拟机网卡 ifcfg-ens33

![image-20220731213355574](https://happychan.oss-cn-shenzhen.aliyuncs.com/img/image-20220731213355574.png)

修改BOOTPROTO，并添加静态IP、网关、掩码等，修改完成后，执行 `service network restart`

再次查看 ip 地址，就可以发现被固定为 `192.168.5.101`

### 其他信息配置

```bash
# 关闭防火墙
systemctl stop firewalld
systemctl disable firewalld

# 关闭selinux
sed -i 's/enforcing/disabled/' /etc/selinux/config  # 永久
setenforce 0  # 临时

# 关闭swap
swapoff -a  # 临时
sed -ri 's/.*swap.*/#&/' /etc/fstab    # 永久

# 时间同步
yum install ntpdate -y
ntpdate time.windows.com
```

### 软件安装

yum 换源

```bash
# 下载Centos7的repo文件
curl -o /etc/yum.repos.d/CentOS-Base.repo  http://mirrors.aliyun.com/repo/Centos-7.repo

# 清楚缓存
yum clean all
# 生成缓存
yum makecache

# 备份CentOS 7系统自带yum源配置文件/etc/yum.repos.d/CentOS-Base.repo命令
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup

# 更新 yum 源
yum makecake

# 如果有问题，把 CentOS-Base.repo 中的 http 开头的地址都改为 https
```

安装Docker

```bash
# 安装docker
wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo

yum -y install docker-ce-18.06.1.ce-3.el7

systemctl enable docker && systemctl start docker

# 查看版本
docker --version
Docker version 18.06.1-ce, build e68fc7a
```

```bash
# 配置docker 源
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["https://b9pmyelo.mirror.aliyuncs.com"]
}
EOF
```

添加阿里yum kubernetes 软件源

```
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```

安装 kubeadm、kubelet、kubectl

```
# 由于版本更新频繁，这里指定版本号部署
yum install -y kubelet-1.18.0 kubeadm-1.18.0 kubectl-1.18.0
systemctl enable kubelet
```

安装 jdk、go 环境

```bash
# jdk
# 查看是否已存在jdk环境
yum list installed | grep java
# 如果不存在则安装你想要的版本
yum search java | geep jdk
yum install -y java-1.8.0-openjdk.* 
java -version

# go
# 下载二进制包
wget https://dl.google.com/go/go1.17.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.12.linux-amd64.tar.gz
# 配置 go 环境变量
vi /etc/profile 
# 写入
export GOROOT=/usr/local/go
export GOPATH=/usr/local/gopath
export PATH=$PATH:$GOROOT/bin
# 生效
source /etc/profile
go version
```

### 克隆虚拟机

1. 快照 => 拍摄快照
2. 管理 => 克隆 => 当前虚拟机状态/现有快照 => 创建完整克隆

克隆完成后，修改静态 ip 和 hostname

```
# 根据规划设置主机名
hostnamectl set-hostname xxx
```

## 3.集群配置   

| 角色   | IP            |
| ------ | ------------- |
| master | 192.168.5.101 |
| node1  | 192.168.5.102 |
| node2  | 192.168.5.103 |


```
# 在master添加hosts
cat >> /etc/hosts << EOF
192.168.5.101 k8smaster
192.168.5.102 k8snode1
192.168.5.103 k8snode2
EOF

# 将桥接的IPv4流量传递到iptables的链
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system  # 生效
```

## 4.部署Kubernetes Master

在192.168.5.101（Master）执行。

```bash
kubeadm init \
  --apiserver-advertise-address=192.168.5.101 \
  --image-repository registry.aliyuncs.com/google_containers \
  --kubernetes-version v1.18.0 \
  --service-cidr=10.96.0.0/12 \
  --pod-network-cidr=10.244.0.0/16
```

由于默认拉取镜像地址k8s.gcr.io国内无法访问，这里指定阿里云镜像仓库地址。

使用kubectl工具：

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes
```

## 5. 加入Kubernetes Node

在192.168.5.102/103（Node）执行。

向集群添加新节点，执行在kubeadm init输出的kubeadm join命令：

```
kubeadm join 192.168.5.101:6443 --token esce21.q6hetwm8si29qxwn \
    --discovery-token-ca-cert-hash sha256:00603a05805807501d7181c3d60b478788408cfe6cedefedb1f97569708be9c5
```

默认token有效期为24小时，当过期之后，该token就不可用了。这时就需要重新创建token，操作如下：

```bash
kubeadm token create --print-join-command
```

## 6. 部署CNI网络插件

```bash
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

如果上面的默认镜像地址无法访问，sed命令修改为docker hub镜像仓库【则执行下面的一命令即可】

```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

kubectl get pods -n kube-system
NAME                          READY   STATUS    RESTARTS   AGE
kube-flannel-ds-amd64-2pc95   1/1     Running   0          72s
```

完成后，请等待一会，然后通过 kubectl get nodes 就可以看到节点的状态为 Ready 了

## 7. 测试kubernetes集群

在Kubernetes集群中创建一个pod，验证是否正常运行：

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get pod,svc
```

访问地址：http://NodeIP:Port  



