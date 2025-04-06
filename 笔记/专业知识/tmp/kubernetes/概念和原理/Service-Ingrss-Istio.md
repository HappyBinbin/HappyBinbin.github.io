系列好文：
- https://readmedium.com/kubernetes-services-simply-visually-explained-2d84e58d70e5


概念：
- K8s Ingress or APISIX
- LoadBalancer
- Kube-vip or (HAProxy and keepalived)

疑问：
1. 为什么要有 Ingress ？
2. 为什么有 k8s ingress 还需要 apisix ingress ？
3. 目前的 vip 方案有哪些？（https://www.qikqiak.com/post/use-kube-vip-ha-k8s-lb/）
4. LoadBalancer 和 Ingress 的区别？



外部流量 → LoadBalancer/NodePort → Ingress-Nginx Pod → Nignx 进程 → Service → Endpoints
1. LoadBalancer 作用外部的负载均衡器，通过 selector  绑定 Ingress Controller
2. 集群的节点，通过kube-proxy将流量转发到 Ingress Nginx Pod 上
3. Ingress Nginx Controller 进程，负责解析 Ingress 规则，动态加载Nginx配置，Ingress Nginx 进程，负责反向代理，将请求路由到 service
4. service 则根据 endpoint 分发流量

![image.png](https://happychan.oss-cn-shenzhen.aliyuncs.com/picgo/20250406112753.png)

![image.png](https://happychan.oss-cn-shenzhen.aliyuncs.com/picgo/20250406113828.png)
