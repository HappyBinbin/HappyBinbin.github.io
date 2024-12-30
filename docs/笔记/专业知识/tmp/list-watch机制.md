## Reference & Recommend

- http://yost.top/2019/08/01/inside-list-watch-in-k8s/
- https://www.lixueduan.com/posts/etcd/05-watch/

## 前言
工作中遇到需要通过 k8s 的 watch 机制去监听某个资源的变化，于是想了解其实现的原理；就从 client-go 开始看起，了解了 streamWatcher 是怎么实现的，后面发现实际上并不是 k8s 做的，k8s 的这些机制，完全就是在适配 etcd 这个分布式键值对数据库的特性，最终进行 watch 的是 etcd 其本身就提供的 watch 机制，k8s 对于底层的存储，进行了抽象，可以由多种 storage 的底层实现，只要能提供 watch 机制即可；
因此，本文打算先介绍 k8s 是怎么实现的 watch机制的（list-watch和watch在实现上不太一样，但本质是都是利用了etcd的能力），后续有时间再讲解一下 etcd 的 watch 机制原理；

