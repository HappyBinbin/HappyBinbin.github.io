## Reference
- [ Go 每日一库之 net/http（基础和中间件）](https://darjun.github.io/2021/07/13/in-post/godailylib/nethttp/)
- https://draveness.me/golang/docs/part4-advanced/ch09-stdlib/golang-net-http/

## 目的
本文的目的是了解 golang 中使用 net/http 源码库，是怎么发起一个 http 请求，客户端和服务端是如何相互建立连接，读取、发送消息的。

## After read you should know
- http client 的初始化流程的？
- http client 是如何发起请求的？
- http server 是何如接受请求的？
- http client 的连接池是如何管理的？
- 发起一个 http 请求需要建立几个 socket 或者打开几个 fd？
- 发起一个 http 请求，会启动几个协程？

## 流程图
下图展示了http发起请求，并读取响应的大致流程
![net-http.drawio.png](https://happychan.oss-cn-shenzhen.aliyuncs.com/picgo/net-http.drawio.png)

## 关键数据结构和接口

 **RoundTripper**

```go
type RoundTripper interface {
    RoundTrip(*Request) (*Response, error)
}
```

RoundTripper 是 http 包提供的客户端的执行HTTP请求的接口，官方介绍是：

> RoundTripper is an interface representing the ability to execute a single HTTP transaction, obtaining the `[Response]` for a given `[Request]`

也就是能够保证 HTTP 请求和响应是事务性的，标准库中提供了多种实现方式，我们主要介绍最常用的 Transport 

![image.png | 500](https://happychan.oss-cn-shenzhen.aliyuncs.com/picgo/20250105181950.png )

**Transport**
RoundTripper 的实现，主要作用就是支持HTTP/HTTPs请求以及HTTP代理



## 从一个HTTP请求讲起
编写一个简单的HTTP请求：
```go
func requestHTTP(ctx context.Context, url string, method string) {  
   _, err := http.NewRequest(method, url, bytes.NewBuffer([]byte{}))  
   if err != nil {  
      _ = fmt.Errorf("rquest url: %s, err: %+v", url, err)  
      return  
   }  
  
   resp, err := http.Post(url, "text/plain", bytes.NewBuffer([]byte{}))  
   if err != nil {  
      fmt.Printf("post error: %+v", err)  
      return  
   }  
  
   if resp.StatusCode != http.StatusOK {  
      fmt.Printf("post error: %+v", err)  
      return  
   }  
  
   fmt.Printf("request success ... ")  
}
```












