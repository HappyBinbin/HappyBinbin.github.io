## Reference
- [ Go 每日一库之 net/http（基础和中间件）](https://darjun.github.io/2021/07/13/in-post/godailylib/nethttp/)

## 目的
本文的目的是了解 golang 中使用 net/http 源码库，是怎么发起一个 http 请求，客户端和服务端是如何相互建立连接，读取、发送消息的。

## 主要知识点
- http client 的初始化流程的？
- http client 是如何发起请求的？
- http server 是何如接受请求的？
- http client 的连接池是如何管理的？
- 发起一个 http 请求需要建立几个 socket 或者打开几个 fd？
- 发起一个 http 请求，会启动几个协程？

