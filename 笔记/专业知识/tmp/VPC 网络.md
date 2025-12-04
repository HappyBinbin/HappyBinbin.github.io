# 用最简单的话聊聊 VPC（What / Why / How）

把云想成一座超级大的城市。每个用户都可以在城里划出一块属于自己的小区，围上篱笆，还能自己规划街道、门禁和保安——这块小区就是 **VPC (Virtual Private Cloud)**。按照“费曼学习法”+ “What / Why / How”的顺序来解释：用最朴素的比喻搞懂每一种场景是什么、为什么出现、又是怎么实现的。

## 先记住三件事
1. **VPC 是云上的私家小区**：你决定有哪些道路（子网）、房子（虚机/容器）、保安规则（安全组/ACL）。
2. **虚拟交换机像路口，虚拟路由器像交通灯**：它们按你的“路况图”调度所有车（数据包）。
3. **出口设施（NAT/VPN/专线等）就是门禁**：车出入要经过登记、换牌照或者走特殊通道。

---

## 场景 1：同一个路口里两栋楼互聊（同子网、同宿主机）
**What：** 同一子网、同一宿主机的两台虚机互相通信。

**Why：** 大部分应用都会部署在同一物理节点或同一子网里，期望延迟最低、速度最快。

**How：**
```mermaid
flowchart LR
    subgraph HostA[宿主机 = 一栋大楼]
        VM1["VM1<br/>住户甲"]
        VM2["VM2<br/>住户乙"]
        SwitchA["虚拟交换机<br/>= 电梯大厅"]
        VM1 --> SwitchA
        VM2 --> SwitchA
        SwitchA --> VM2
        SwitchA --> VM1
    end
```
- 两台虚机都挂在同一个虚拟交换机（电梯大厅），数据包在宿主机内直接完成转发，不需走外部网络。

---

## 场景 2：同一条街不同楼（同子网、跨宿主机）
**What：** 同一子网、但虚机在不同宿主机。

**Why：** 业务扩容或负载均衡需要把同一子网的实例放到不同物理机上。

**How：**
```mermaid
flowchart LR
    subgraph HostA[大楼 A]
        VM1A["VM1<br/>住户甲"]
        SwitchA[电梯大厅 A]
        VM1A --> SwitchA
    end
    subgraph HostB[大楼 B]
        VM2B["VM2<br/>住户乙"]
        SwitchB[电梯大厅 B]
        SwitchB --> VM2B
    end
    SwitchA -- "加上封条\n(隧道/VXLAN)" --> Street[小区道路]
    Street -- "送到 B 楼" --> SwitchB
```
- 虚拟交换机 A 给数据包套上 VXLAN 等“封条”，通过物理网络送到宿主机 B，再由虚拟交换机 B 解封并转发，保证仍在同一子网内。

---

## 场景 3：不同街区（跨子网）
**What：** 两台虚机分属不同子网。

**Why：** 业务按功能/安全要求划分子网，需要严格的网络边界。

**How：**
```mermaid
flowchart LR
    VM1["子网 X<br/>住户"]
    VM2["子网 Y<br/>住户"]
    SwitchX[路口 X]
    SwitchY[路口 Y]
    VROUTER["虚拟路由器<br/>= 区域交通灯"]
    VM1 --> SwitchX --> VROUTER
    VROUTER --> SwitchY --> VM2
    VROUTER -. "保安规则" .- VM1
```
- 先到虚拟路由器（交通灯）做三层转发，按路由表和安全组/ACL 控制流量，再进入目标子网的虚拟交换机。

---

## 场景 4：出小区上高速（公网/其它 VPC/混合云）
**What：** VPC 内实例访问公网、其他 VPC 或本地数据中心。

**Why：** 服务需要对外提供 API、访问第三方，或者与总部网络互联。

**How：**
```mermaid
flowchart LR
    VM1[住户]
    VSW[路口]
    VROUTER[交通灯]
    NAT["小区大门\n(NAT/VPN/专线)"]
    WAN["高速公路/其它小区/自家工厂"]
    VM1 --> VSW --> VROUTER --> NAT --> WAN
```
- 经过虚拟路由器后进入出口网关（NAT/VPN/专线等）：
  - NAT 换公网“车牌”；
  - VPN 走加密通道；
  - 专线走私人高速。

---

## 场景 5：跨可用区 = 两个小区之间的天桥
**What：** 同一 VPC 的资源部署在不同可用区，仍需互通。

**Why：** 防止单个可用区故障导致服务中断，实现高可用。

**How：**
```mermaid
flowchart LR
    subgraph AZ1["小区 A (AZ1)"]
        VM1AZ[住户]
        VSWAZ1[路口]
        VM1AZ --> VSWAZ1
    end
    subgraph AZ2["小区 B (AZ2)"]
        VM2AZ[住户]
        VSWAZ2[路口]
        VSWAZ2 --> VM2AZ
    end
    VSWAZ1 -- "穿过天桥" --> Spine[跨 AZ 骨干网络]
    Spine -- "再进 B 小区" --> VSWAZ2
```
- 云厂商提供跨 AZ 的骨干网络/SDN；数据包在离开 AZ 时套上 VXLAN 等隧道封装，到另一 AZ 再解封，延迟比同 AZ 略高，但保证以租户 ID 隔离。

---

## 场景 6：两个小区互开后门（VPC 对等连接）
**What：** 两个 VPC 之间建立直接互访。

**Why：** 多租户/多项目隔离部署，但某些服务需要互通，例如共享数据库、中心化认证等。

**How：**
```mermaid
flowchart LR
    subgraph VPCA[VPC A]
        RA[交通灯 A]
        VMA[住户 A]
        VMA --> RA
    end
    subgraph VPCB[VPC B]
        RB[交通灯 B]
        VMB[住户 B]
        VMB --> RB
    end
    RA -- "对等大门" --> Peering[(Peering Gateway)] --> RB
```
- 双方在控制面互相导入路由，把对方子网加入路由表，同时仍按各自安全组/ACL 控制。数据面通常走云厂商的骨干，无需经过公网。

---

## 场景 7：云上小区连到老家的工厂（专线/混合云）
**What：** 云上 VPC 与线下 IDC/办公室互联。

**Why：** 企业常有本地系统，需要与云上服务共享数据或做灾备。

**How：**
```mermaid
flowchart LR
    subgraph Cloud[VPC 小区]
        VRouter[交通灯]
        Workload[云上业务]
        Workload --> VRouter
    end
    DirectGW[专线网关]
    IDC[自建机房]
    VRouter --> DirectGW --> IDC --> LAN[工厂内部]
```
- 配置专线网关或 VPN 网关，通过 BGP/静态路由把云上、云下网段互相告知。数据走专线/隧道，或经 MPLS、SD-WAN 等接入网络。

---

## 场景 8：所有车出门必须经过安检（安全服务链）
**What：** 在流量路径上串接防火墙、入侵检测、负载均衡等 NFV 组件。

**Why：** 遵循合规/安全要求，确保南北向和东西向流量都被检查。

**How：**
```mermaid
flowchart LR
    Client[住户]
    VSWF[路口]
    FW["安检站\n(防火墙/NFV)"]
    RouterF[交通灯]
    Client --> VSWF --> FW --> RouterF --> Internet
```
- 控制面下发“服务链”规则，数据面强制流量按照顺序经过这些虚拟安全设备，可基于 SDN 或 Service Chaining 技术实现。

---

## 常见名词小抄
- **VPC**：云里的私家小区。
- **子网**：小区内的街区，划分住户。
- **虚拟交换机 (vSwitch)**：楼内或街区的路口，负责二层转发。
- **虚拟路由器 (vRouter)**：跨街区、进出小区的交通灯。
- **隧道 / VXLAN**：给车套上的封条，保证不同小区的车互不干扰。
- **骨干网络 / SDN**：连接所有小区的高速道路，由云厂商集中调度。
- **ToR / Leaf**：把每栋楼接入骨干的交换机。
- **安全组 / ACL**：保安名单。
- **NAT**：换车牌（私有地址转公网）。
- **VPN / 专线**：加密或独享的通行道路。
- **对等连接 (Peering)**：两个小区互开后门共享资源。
- **NFV / 服务链**：把虚拟防火墙、入侵检测等串在路上做安检。

> **总结**：每个场景都回答了“是什么”“为什么需要”“如何实现”。先理解这些“家常比喻”，再去看具体云厂商的参数/命令，就能很快入门 VPC 设计。


---

## 综合示例：一张图看懂 VPC 南北 / 东西流量 + 专线 + VPN + 隧道
**What：** 一个典型的企业级 VPC，既要对外提供服务（南北向），又要东西向分层部署，还要和自建机房、远程办公点互联。

**Why：**
- 对外业务需要通过 NAT/VPN 接入公网，满足客户访问（南北向）。
- 内部微服务/数据库之间有大量东西向通信，需要分层安全策略。
- 公司总部 / 分支机构 / 生产 IDC 要和云上互通，依赖专线与 VPN。

**How（示意图）：**
```mermaid
flowchart TB
    subgraph Users[互联网用户]
        ClientA[移动端/浏览器]
    end

    subgraph VPC[云上私有小区]
        subgraph PublicSubnet[公有子网]
            ALB[负载均衡]
            WAF[WAF/NFV]
        end
        subgraph SecChain[服务链]
            FW[防火墙]
            IDS[入侵检测]
        end
        subgraph EastWest[东西向区域]
            direction LR
            subgraph AppSubnet[应用子网]
                App1[应用集群 A]
                App2[应用集群 B]
            end
            subgraph DataSubnet[数据子网]
                DB[数据库]
            end
        end
        VRouter[虚拟路由器]
        NATGW[NAT 网关]
        VPNGW[VPN 网关]
        DirectGW[专线网关]

        ClientA -->|HTTP/TLS| ALB --> WAF --> FW --> IDS --> App1
        WAF --> App2
        App1 <--> App2
        App1 <-->|东西向流量| DB
        App2 --> DB
        App1 -.VXLAN/Overlay.- App2

        App1 --> VRouter
        DB --> VRouter
        VRouter --> NATGW --> Internet[公网]
        VRouter --> VPNGW --> BranchVPN[分支 VPN]
        VRouter --> DirectGW --> IDC[自建 IDC]
    end

    BranchVPN --> RemoteUsers[远程办公]
```

- **南北向流量**：Client → 负载均衡 → WAF → 服务链 → 应用，再经 NAT/出口访问公网或被公网访问。
- **东西向流量**：应用子网之间、应用与数据库之间通过 VXLAN/虚拟交换机互通，并由服务链策略检查。
- **VPN**：VPN 网关为远程办公或分支机构提供加密通道。
- **专线**：DirectGW 通过物理专线或 MPLS 连接 IDC，常上线 BGP 以实现动态路由。
- **隧道**：VPC 内部使用 VXLAN/隧道隔离不同子网，也可能在跨 AZ、专线、VPN 中叠加隧道封装。

通过这张图可以把前面各个场景串起来：VPC 就像一座有完善门禁、道路和跨城高速的小区，南北向、东西向、专线、VPN、NFV 安检都能在同一架构里组合使用。