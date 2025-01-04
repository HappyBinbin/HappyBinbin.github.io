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






