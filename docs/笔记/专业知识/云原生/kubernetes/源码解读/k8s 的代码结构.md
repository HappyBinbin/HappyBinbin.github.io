## Reference
- https://blog.csdn.net/m0_45406092/article/details/144408906
- https://zhuanlan.zhihu.com/p/645269730

| 目录名称          | 说明                                                                                                                                                                            |
| :------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| api/          | 存放 OpenAPI/Swagger 的 spec 文件，包括 JSON、Protocol 的定义等。          包含 Kubernetes 的 API 定义文件，如 Pod、Service、ReplicationController 等，但是现在 K8s 的 api 基本都移到 k8s.io/api 和 k8s.io/apis 项目下 |
| build/        | 存放构建相关的脚本                                                                                                                                                                     |
| **cmd/**      | 存放可执行文件的**入口代码**，每一个可执行文件都会对应有一个 main 函数                                                                                                                                      |
| docs/         | 存放设计或者用户使用文档                                                                                                                                                                  |
| hack/         | 存放与构建、测试相关的脚本                                                                                                                                                                 |
| **pkg/**      | 存放核心库代码，可被项目内部或外部，直接引用                                                                                                                                                        |
| plugin/       | 存放 kubernetes 的插件，例如认证插件、授权插件等                                                                                                                                                |
| staging/      | 比较特殊，单独讲解，目前存放的是即将要独立发布的仓库代码                                                                                                                                                  |
| **test/**     | 存放测试工具，以及测试数据                                                                                                                                                                 |
| third_party/  | 存放第三方工具、代码或其他组件                                                                                                                                                               |
| translations/ | 存放 i18n(国际化)语言包的相关文件，可以在不修改内部代码的情况下支持不同语言及地区                                                                                                                                  |
| **vendor/**   | 存放项目**依赖的库代码**，一般为第三方库代码                                                                                                                                                      |
## Staging

### 1. 什么是 `staging` 目录？

staging 目录位于 Kubernetes 源代码的根目录下（例如 kubernetes-1.22.3/staging）。
它的主要作用是存放 Kubernetes 项目自身的模块化代码，用于逐步拆分、独立开发和发布成单独的 Go 模块。

### 2. 为什么需要 `staging` 目录？

在 Kubernetes 中，有许多代码需要被多个组件（如 kubelet、kube-proxy）复用，例如：
- API 定义
- 客户端工具
- 通用库
为了实现这些代码的模块化开发和独立发布，staging 目录被设计为一个过渡阶段，解决模块拆分和跨依赖管理问题。

背景问题
- Kubernetes 项目依赖自身的模块（如 k8s.io/apimachinery
- 直接分离模块可能会导致循环依赖问题。
- 独立模块需要逐步开发和测试，而不是一次性完成。

解决方法
- 将即将独立的模块代码暂时放入 staging 目录。
- 构建时，通过 vendor 机制 伪装成外部依赖，避免循环依赖问题。
- 在模块稳定后，正式发布到独立的仓库和 Go 模块仓库。

### 3. `staging` 目录的作用
#### 3.1  模块化开发
staging 目录中的子目录对应 Kubernetes 的官方 Go 模块，例如：

- k8s.io/apimachinery
- k8s.io/client-go
- k8s.io/api
- k8s.io/apiserver

#### 3.2 管理跨模块依赖

- staging 目录中的代码被 Kubernetes 主项目和其他组件复用
- 构建时，这些模块会被以软链接的方式同步到 vendor 目录，使 Go 编译器将其视为外部依赖 [[依赖管理#依赖查找顺序]]

任意找一个目录，查看其 import 的内容，可以发现，对于 k8s 主项目的引用，都是以 k8s.io 开头的，而不是我们常见的 github.xxx，k8s.io/kubernetes 就是 k8s 项目的 module 名

``` go
package scheduler  
  
import (  
   "fmt"  
   "io/ioutil"   "os"   "time"  
   "k8s.io/klog"  
   v1 "k8s.io/api/core/v1"  
   metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"  
   "k8s.io/apimachinery/pkg/runtime"   "k8s.io/apimachinery/pkg/util/wait"   appsinformers "k8s.io/client-go/informers/apps/v1"  
   coreinformers "k8s.io/client-go/informers/core/v1"  
   policyinformers "k8s.io/client-go/informers/policy/v1beta1"  
   storageinformersv1 "k8s.io/client-go/informers/storage/v1"  
   storageinformersv1beta1 "k8s.io/client-go/informers/storage/v1beta1"  
   clientset "k8s.io/client-go/kubernetes"  
   "k8s.io/client-go/tools/events"   schedulerapi "k8s.io/kubernetes/pkg/scheduler/api"  
   latestschedulerapi "k8s.io/kubernetes/pkg/scheduler/api/latest"  
   kubeschedulerconfig "k8s.io/kubernetes/pkg/scheduler/apis/config"  
   "k8s.io/kubernetes/pkg/scheduler/core"   "k8s.io/kubernetes/pkg/scheduler/factory"   framework "k8s.io/kubernetes/pkg/scheduler/framework/v1alpha1"  
   internalcache "k8s.io/kubernetes/pkg/scheduler/internal/cache"  
   internalqueue "k8s.io/kubernetes/pkg/scheduler/internal/queue"  
   "k8s.io/kubernetes/pkg/scheduler/metrics"   "k8s.io/kubernetes/pkg/scheduler/volumebinder")

// 主项目的 go.mod 

module k8s.io/kubernetes  
  
// scheduler 的 go.mod

module k8s.io/kube-scheduler
```


#### 3.3 发布和版本化

- 每次 Kubernetes 发布新版本时，staging 中的模块会同步发布到独立的 GitHub 仓库，例如：
	- kubernetes/client-go
	- kubernetes/apimachinery
