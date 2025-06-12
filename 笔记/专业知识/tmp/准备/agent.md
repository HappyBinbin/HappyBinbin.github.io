## agent 手动安装

托管云 agent 的手动安装命令可以拆分为两部分：

```bash
curl -kf4 -m 30 -X GET https://10.134.88.95:8888/api/download/aops-agent-service-linux-amd64 -H 'x-agent-id: 5402204854438' -o aops-agent-service-linux-amd64
&& chmod +x aops-agent-service-linux-amd64 && ./aops-agent-service-linux-amd64 --control install --version c57f6a1d --agentId 5402204854438 --endpoint https://10.134.88.95:8888
```

1、下载“下载器 aops-agent-service-linux-amd64” 

```bash
curl -kf4 -m 30 -X GET https://10.134.88.95:8888/api/download/aops-agent-service-linux-amd64 -H 'x-agent-id: 5402204854438' -o aops-agent-service-linux-amd64
```

到 transfer-gateway 下载 super-agent 的可执行文件

2、给下载器执行权限、执行下载器的安装命令

```bash
&& chmod +x aops-agent-service-linux-amd64 && ./aops-agent-service-linux-amd64 --control install --version c57f6a1d --agentId 5402204854438 --endpoint https://10.134.88.95:8888
```

## agent 管理

### 项目整体架构

该项目是一个基于Go语言开发的超级代理系统，主要包含以下核心组件：

#### 核心组件

- SPM (Super Agent Manager): 超级代理管理器，负责管理子agent的生命周期
- SPA (Super Agent): 超级代理，负责监控SPM进程并在异常时重启
- aops-agent-service: 服务管理程序，负责整个系统的安装、卸载、启动、停止等操作

### 打包机制

#### 构建流程

项目使用RPM build，通过 SPEC 文件打包为 RPM

支持的架构平台：

- windows/386
- windows/amd64
- linux/386
- linux/amd64

构建命令：

rpm build xxx   # 执行完整的多架构打包

#### 打包过程详解

环境准备：使用Docker镜像 registry.me/acmp/golang-cross-builder

依赖安装：安装 github.com/akavel/rsrc 用于Windows资源文件处理

交叉编译：

- 为每个目标平台设置对应的编译器（GCC/MinGW）
- Windows平台添加manifest资源文件
- Linux 386使用静态编译以支持32位程序在64位平台运行

生成的文件：

- aops-spm: SPM主程序
- aops-spa: SPA监控程序
- aops-agent-service: 服务管理程序
- control: 控制脚本（Linux）或 control.exe（Windows）
- 配置文件和目录结构

打包输出：

- 生成 aops-spm-{VERSION}_{OS}_{ARCH}.tar.gz 压缩包
- 包含签名验证文件
- 为不同平台生成对应的服务程序

### Agent管理机制

#### 管理层次结构

aops-agent-service (服务层)
 ↓
aops-spa (监控层) 
 ↓  ↑

aops-spm (管理层)
 ↓
sub-agents (子代理层)

#### 生命周期管理

**安装 (Install)**

aops-agent-service --control=install --agentId=xxx --endpoint=https://xxx:8888

安装流程：

1. 停止并清理旧版本
2. 从服务器下载指定版本的agent包
3. 验证签名并解压到目标目录
4. 生成agentId文件
5. 更新配置文件
6. 注册系统服务（非HCI/SCP环境）
7. 启动服务

![image-20250610100459129](agent.assets/image-20250610100459129.png)

**启动 (Start)**

- 服务启动：通过系统服务管理器启动，先拉起SPM，SPM再拉起SPA
- 脚本启动：HCI环境下直接通过脚本启动
- 监控机制：SPA监控SPM进程，异常时自动重启

![spm 启动](agent.assets/spm 启动.jpg)

**停止 (Stop)**

- 停止系统服务
- 强制终止SPM和SPA进程
- 停止所有子agent进程

**卸载 (Uninstall)**

- 停止所有相关进程
- 卸载系统服务
- 删除所有相关文件和目录

#### 不同架构的管理差异

Linux平台

- 使用bash脚本 control 进行管理
- 支持systemd服务管理
- 使用进程信号进行控制

Windows平台

- 使用Python脚本 control.py 进行管理，py文件会被 rem 编译为 exe 文件
- 通过Windows服务管理器注册服务
- 使用WMI和taskkill进行进程管理
- 支持文件重命名机制处理文件占用问题

### SPA和SPM的管理机制

#### SPA (Super Agent)

职责：

- 监控SPM进程状态
- SPM异常时自动重启
- 自身健康检查（内存、文件完整性）

关键特性：

- 单进程文件锁防止重复启动
- 定时检查基础目录和日志目录完整性
- 内存使用监控，超限自动退出

#### SPM (Super Agent Manager)

职责：

- 与服务器进行心跳通信
- 管理子agent的安装、升级、卸载
- 处理服务器下发的管理指令

核心功能：

- 心跳机制：定期向服务器报告状态并接收指令
- 子agent管理：根据服务器配置动态管理子agent
- 自升级：支持自身版本升级
- 环境变量管理：为子agent传递必要的环境变量

#### 伴生机制

SPA 是 SPM 的伴生进程，两者相互监督，检测到异常就相互拉起

![spm和spa watch 机制](agent.assets/spm和spa watch 机制.jpg)

### 升级场景处理

#### SPM、SPA 自升级

触发条件：心跳响应中包含升级指令 (cmd: "upgrade")

升级流程：

- 下载新版本压缩包并验证签名
- 解压到当前目录覆盖旧文件
- 更新配置文件中的服务器地址
- 修改新文件的执行权限
- 退出当前进程，由服务自动拉起新版本



#### 子Agent升级

升级策略：

- 版本比较：比较本地和远程版本号
- 环境变量比较：检查环境变量是否变化
- 增量更新：只更新有变化的agent
- 批量管理：支持同时管理多个子agent

升级流程：

- 停止旧版本agent
- 下载并安装新版本
- 更新环境变量配置
- 启动新版本agent
- 验证运行状态

#### 容错机制

- 下载失败重试：支持文件下载重试机制
- 回滚保护：升级失败时保持原有版本运行
- 健康检查：升级后验证服务状态
- 日志记录：详细记录升级过程和错误信息

### 配置管理

配置文件结构

- 主配置：etc/conf.yml - 系统核心配置
- 动态配置：支持配置文件热更新
- 环境适配：根据不同产品环境（HCI/SCP）调整行为

关键配置项

- heartbeatSrv: 心跳服务器地址
- heartbeatInterval: 心跳间隔时间
- spmMaxMem/spaMaxMem: 内存限制
- downloadTimeout: 下载超时时间

### 监控机制

- 进程监控：SPA监控SPM，SPM监控子agent
- 内存监控：定期检查内存使用，超限自动退出
- 文件完整性检查：定期验证关键文件存在性

通过分层架构和心跳机制实现了高可用的agent管理系统，支持多平台部署和动态升级，具有良好的容错和监控能力

## agent 打包



## agent架构

![agent架构](agent.assets/agent架构.jpg)



























