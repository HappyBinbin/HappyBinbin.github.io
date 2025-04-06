### Docker-Desktop-Mac
在设置中可以直接启动，需要下载镜像

- https://xiangflight.github.io/build-kubernetes-on-mac-os/


### 部署 k8s-dashboard

``` bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

### 创建用户或者token

虽然 `kubectl` 没有直接支持通过 Token 创建用户和上下文的子命令，但可以通过组合使用 `kubectl config` 命令来完成配置。

1. ​​获取 API 服务器地址和 CA 数据​：
```bash
# 获取 API 服务器地址
APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# 获取 CA 数据（如果需要）
CACERT=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
if [ "$CACERT" == "" ]; then
CACERT="/path/to/ca.crt"  # 替换为实际的 CA 证书路径
fi
```

2. ​创建新的上下文和用户​*：
```bash
# 定义变量
CONTEXT_NAME="dashboard-context"
USER_NAME="dashboard-admin"
TOKEN=$(kubectl -n kubernetes-dashboard create token kubernetes-dashboard-admin --duration=10000h)

# 创建用户
kubectl config set-credentials $USER_NAME --token=$TOKEN

# 创建上下文
kubectl config set-context $CONTEXT_NAME --cluster=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}') --user=$USER_NAME --namespace=kubernetes-dashboard

# 使用新上下文
kubectl config use-context $CONTEXT_NAME
```

3. ​验证配置​：
``` bash
kubectl config current-context
kubectl get pods -n kubernetes-dashboard
```

如果配置正确，您应该能够看到 `kubernetes-dashboard` 命名空间中的 Pod 列表
