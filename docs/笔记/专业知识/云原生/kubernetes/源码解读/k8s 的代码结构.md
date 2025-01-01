| 目录名称          | 说明                                                                                                                                                                            |
| :------------ | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| api/          | 存放 OpenAPI/Swagger 的 spec 文件，包括 JSON、Protocol 的定义等。          包含 Kubernetes 的 API 定义文件，如 Pod、Service、ReplicationController 等，但是现在 K8s 的 api 基本都移到 k8s.io/api 和 k8s.io/apis 项目下 |
| build/        | 存放构建相关的脚本                                                                                                                                                                     |
| **cmd/**      | 存放可执行文件的**入口代码**，每一个可执行文件都会对应有一个 main 函数                                                                                                                                      |
| docs/         | 存放设计或者用户使用文档                                                                                                                                                                  |
| hack/         | 存放与构建、测试相关的脚本                                                                                                                                                                 |
| **pkg/**      | 存放核心库代码，可被项目内部或外部，直接引用                                                                                                                                                        |
| plugin/       | 存放 kubernetes 的插件，例如认证插件、授权插件等                                                                                                                                                |
| staging/      |                                                                                                                                                                               |
| **test/**     | 存放测试工具，以及测试数据                                                                                                                                                                 |
| third_party/  | 存放第三方工具、代码或其他组件                                                                                                                                                               |
| translations/ | 存放 i18n(国际化)语言包的相关文件，可以在不修改内部代码的情况下支持不同语言及地区                                                                                                                                  |
| **vendor/**   | 存放项目**依赖的库代码**，一般为第三方库代码                                                                                                                                                      |

### **api**

包含 Kubernetes 的 API 定义文件，如 Pod、Service、ReplicationController 等。但是现在 K8s 的 api 基本都移到 k8s.io/api 和 k8s.io/apis 项目下。
### **build**

包含 Kubernetes 内部组件编译的脚本以及制作 Docker 镜像的 Dockerfile 等。

### **CHANGELOG**

本次版本更新的 Future 以及修复的 Bug 记录

### **cmd**

包含 Kubernetes 组件启动命令，如 kube-apiserver，kube-controller-manager 等

### **docs**

包含 Kubernetes 的文档，如开发者指南、API 文档等。这些文档是用 MkDocs 工具编写的，可以生成静态网站供用户参考。Kubernetes 的文档非常丰富，包括了从安装到使用到开发的所有内容。对于初学者来说，阅读 Kubernetes 的官方文档是非常必要的。

### **hack**

包含 Kubernetes 的构建和测试脚本。这些脚本用于自动化构建、测试和发布 Kubernetes。在这些脚本中，包含了大量的构建细节和测试用例。这些脚本可以大大提高我们的工作效率，同时也可以确保 Kubernetes 的代码质量和稳定性。

### **pkg**

包含 Kubernetes 的核心代码，如 API Server、Controller Manager、Scheduler 等。

### **plugin**

包含 Kubernetes 的插件，例如存储插件、认证插件等，它们都可以让 Kubernetes 更加灵活和强大。

### **test**

包含 Kubernetes 的测试用例。这些测试用例用于测试 Kubernetes 的功能是否正常。在 Kubernetes 的开发过程中，测试是非常重要的环节。通过测试，我们可以发现和解决各种问题，确保 Kubernetes 的功能正确性和稳定性。

### **vendor**

用于存放 Kubernetes 所有依赖的第三方库的代码。在编译 Kubernetes 源码时，需要使用大量的第三方库，例如 `etcd`、`docker`、`glog` 等。这些库的源码会被存放在 `vendor` 目录下，它们会被自动下载和编译，最终被打包到 Kubernetes 的二进制文件中。

### **Staging** 

